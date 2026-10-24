"""Часть 3: обработка датасета COVID-19 в PySpark.

Вход:  hdfs://team-31-nn:9000/data/covid/countries-aggregated.csv (часть 2, все колонки — string)
Выход: hdfs://team-31-nn:9000/data/covid/processed/country_monthly (Parquet, без партиций)
       — помесячная статистика по странам, ее забирает часть 4.

Шаги:
  1. Преобразование типов: Date -> date, Confirmed/Recovered/Deaths -> long.
  2. Фильтрация: битые строки, отрицательные значения, Deaths > Confirmed,
     дни до первого подтвержденного случая в стране.
  3. Новые колонки: year, month.
  4. Агрегация по стране и месяцу: значения на конец месяца (max накопительных чисел).
  5. Оконная функция: прирост за месяц (new_confirmed, new_deaths).
  6. Производная метрика: mortality_rate = deaths / confirmed.
  7. Проверки корректности итогового DataFrame.
"""

import sys

from pyspark.sql import SparkSession, Window
from pyspark.sql import functions as F
from pyspark.sql.types import DateType, IntegerType, LongType, StringType, DoubleType

INPUT_PATH = "hdfs://team-31-nn:9000/data/covid/countries-aggregated.csv"
OUTPUT_PATH = "hdfs://team-31-nn:9000/data/covid/processed/country_monthly"

if len(sys.argv) > 1:
    INPUT_PATH = sys.argv[1]
if len(sys.argv) > 2:
    OUTPUT_PATH = sys.argv[2]

spark = SparkSession.builder.appName("hw4-transform-data").getOrCreate()
spark.sparkContext.setLogLevel("WARN")

print("Spark master:", spark.sparkContext.master)
print("Application id:", spark.sparkContext.applicationId)

raw = spark.read.option("header", "true").csv(INPUT_PATH)
raw_rows = raw.count()
print("Raw rows:", raw_rows)

# 1. Преобразование типов. Некорректные значения превращаются в null и отсеиваются ниже.
typed = raw.select(
    F.to_date(F.trim("Date"), "yyyy-MM-dd").alias("date"),
    F.trim("Country").alias("country"),
    F.col("Confirmed").cast(LongType()).alias("confirmed"),
    F.col("Recovered").cast(LongType()).alias("recovered"),
    F.col("Deaths").cast(LongType()).alias("deaths"),
)

# 2. Фильтрация
valid = typed.filter(
    F.col("date").isNotNull()
    & F.col("country").isNotNull() & (F.col("country") != "")
    & F.col("confirmed").isNotNull()
    & F.col("deaths").isNotNull()
    & (F.col("confirmed") >= 0)
    & (F.col("deaths") >= 0)
    & (F.col("deaths") <= F.col("confirmed"))
)
valid = valid.fillna({"recovered": 0})
valid = valid.withColumn("recovered", F.greatest(F.col("recovered"), F.lit(0)))

# дни до первого случая в стране не несут информации
cases = valid.filter(F.col("confirmed") > 0)

print("Rows after type casting and filtering:", cases.count())

# 3. Год и месяц
cases = cases.withColumn("year", F.year("date")).withColumn("month", F.month("date"))

# 4. Агрегация: числа в датасете накопительные, поэтому значение на конец месяца — max
monthly = cases.groupBy("country", "year", "month").agg(
    F.max("confirmed").alias("confirmed"),
    F.max("deaths").alias("deaths"),
    F.max("recovered").alias("recovered"),
    F.max("date").alias("last_date"),
    F.count("*").alias("days_reported"),
)

# 5. Прирост за месяц. Для первого месяца страны прирост = накопленное значение.
#    Отрицательный прирост (ретроспективные исправления в источнике) обрезается до 0.
w = Window.partitionBy("country").orderBy("year", "month")
monthly = (
    monthly
    .withColumn(
        "new_confirmed",
        F.greatest(F.col("confirmed") - F.coalesce(F.lag("confirmed").over(w), F.lit(0)), F.lit(0)),
    )
    .withColumn(
        "new_deaths",
        F.greatest(F.col("deaths") - F.coalesce(F.lag("deaths").over(w), F.lit(0)), F.lit(0)),
    )
)

# 6. Смертность от подтвержденных случаев
monthly = monthly.withColumn(
    "mortality_rate",
    F.round(F.col("deaths") / F.col("confirmed"), 6),
)

result = monthly.select(
    F.col("country").cast(StringType()),
    F.col("year").cast(IntegerType()),
    F.col("month").cast(IntegerType()),
    F.col("last_date").cast(DateType()),
    F.col("days_reported").cast(IntegerType()),
    F.col("confirmed").cast(LongType()),
    F.col("deaths").cast(LongType()),
    F.col("recovered").cast(LongType()),
    F.col("new_confirmed").cast(LongType()),
    F.col("new_deaths").cast(LongType()),
    F.col("mortality_rate").cast(DoubleType()),
).cache()

print("Result schema:")
result.printSchema()

# 7. Проверки корректности
errors = []


def check(name, ok, details=""):
    status = "OK" if ok else "FAIL"
    print(f"[{status}] {name}{(': ' + str(details)) if details != '' else ''}")
    if not ok:
        errors.append(name)


result_rows = result.count()
check("result is not empty", result_rows > 0, result_rows)

expected_types = {
    "country": "string", "year": "int", "month": "int", "last_date": "date",
    "days_reported": "int", "confirmed": "bigint", "deaths": "bigint",
    "recovered": "bigint", "new_confirmed": "bigint", "new_deaths": "bigint",
    "mortality_rate": "double",
}
actual_types = dict(result.dtypes)
check("column types", actual_types == expected_types, actual_types)

nulls = result.select(
    [F.sum(F.col(c).isNull().cast("int")).alias(c) for c in result.columns]
).first().asDict()
check("no nulls", all(v == 0 for v in nulls.values()), {k: v for k, v in nulls.items() if v})

duplicates = result.groupBy("country", "year", "month").count().filter("count > 1").count()
check("(country, year, month) is unique", duplicates == 0, duplicates)

bad_months = result.filter(~F.col("month").between(1, 12)).count()
check("month in 1..12", bad_months == 0, bad_months)

bad_rate = result.filter(~F.col("mortality_rate").between(0, 1)).count()
check("mortality_rate in [0, 1]", bad_rate == 0, bad_rate)

negative = result.filter((F.col("new_confirmed") < 0) | (F.col("new_deaths") < 0)).count()
check("monthly growth is not negative", negative == 0, negative)

wrong_month = result.filter(
    (F.year("last_date") != F.col("year")) | (F.month("last_date") != F.col("month"))
).count()
check("last_date matches year/month", wrong_month == 0, wrong_month)

# Сверка с исходными данными: итог по каждой стране = максимум в сырых данных
raw_max = cases.groupBy("country").agg(F.max("confirmed").alias("raw_max"))
res_max = result.groupBy("country").agg(F.max("confirmed").alias("res_max"))
mismatch = raw_max.join(res_max, "country", "full_outer").filter(
    F.col("raw_max").isNull() | F.col("res_max").isNull() | (F.col("raw_max") != F.col("res_max"))
).count()
check("max confirmed per country matches raw data", mismatch == 0, mismatch)

countries = result.select("country").distinct().count()
years = sorted(r["year"] for r in result.select("year").distinct().collect())
print("Countries:", countries)
print("Years:", years)

print("Sample (Italy, 2020):")
result.filter((F.col("country") == "Italy") & (F.col("year") == 2020)) \
    .orderBy("month").show(12, truncate=False)

print("Top-10 countries by confirmed cases at the end of the data:")
(
    result.withColumn("rn", F.row_number().over(
        Window.partitionBy("country").orderBy(F.desc("year"), F.desc("month"))))
    .filter("rn = 1")
    .orderBy(F.desc("confirmed"))
    .select("country", "year", "month", "confirmed", "deaths", "mortality_rate")
    .show(10, truncate=False)
)

if errors:
    print("ERROR: checks failed:", ", ".join(errors))
    spark.stop()
    sys.exit(1)

# Передача результата участнику 4: Parquet в HDFS, без партиций
# (partitionBy и регистрация таблицы в Hive — задача части 4)
result.coalesce(1).write.mode("overwrite").parquet(OUTPUT_PATH)

saved_rows = spark.read.parquet(OUTPUT_PATH).count()
check("saved rows match", saved_rows == result_rows, f"{saved_rows} / {result_rows}")
print("Saved to:", OUTPUT_PATH)

spark.stop()

if errors:
    sys.exit(1)

print("Result rows:", result_rows)
