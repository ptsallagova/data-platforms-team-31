#!/usr/bin/env python3

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

INPUT_PATH = "hdfs://team-31-nn:9000/data/covid/processed/country_monthly"

OUTPUT_PATH = "hdfs://team-31-nn:9000/user/hive/warehouse/hw4.db/covid_monthly"

print("=== Writing partitioned data ===")

spark = (
    SparkSession.builder
    .appName("hw4-write-partitioned")
    .master("yarn")
    .getOrCreate()
)

spark.sparkContext.setLogLevel("WARN")

try:
    print("Spark master:", spark.sparkContext.master)
    print("Application ID:", spark.sparkContext.applicationId)

    # Читаем что там сделала арина
    df = spark.read.parquet(INPUT_PATH)

    print("=== Input schema ===")
    df.printSchema()

    input_count = df.count()
    print("Input rows:", input_count)

    if input_count == 0:
        raise RuntimeError("Input DataFrame is empty")

    #Проверяем колонку партиционирования
    if "year" not in df.columns:
        raise RuntimeError("Column 'year' not found")

    if dict(df.dtypes)["year"] != "int":
        raise RuntimeError("Column 'year' must have integer type")

    if df.filter(F.col("year").isNull()).limit(1).count() > 0:
        raise RuntimeError("Column 'year' contains NULL")

    years = sorted(row.year for row in df.select("year").distinct().collect())
    print("Years:", years)

    if years != [2020, 2021, 2022]:
        raise RuntimeError(f"Unexpected partition years: {years}")

    # сохраняем паркет с физическими партициями
    print("=== Writing Parquet with partitionBy(year) ===")

    (
        df.write
        .mode("overwrite")
        .partitionBy("year")
        .parquet(OUTPUT_PATH)
    )

    #повтрно читаем записанные данные
    print("=== Verifying output ===")

    saved = spark.read.parquet(OUTPUT_PATH)
    output_count = saved.count()

    saved_years = sorted(
        row.year for row in saved.select("year").distinct().collect()
    )

    print("Input rows:", input_count)
    print("Output rows:", output_count)
    print("Output partitions:", saved_years)

    if output_count != input_count:
        raise RuntimeError("Row count mismatch")

    if saved_years != years:
        raise RuntimeError("Partition years mismatch")

    print("Output path:", OUTPUT_PATH)
    print("=== Partitioned data saved successfully ===")

finally:
    spark.stop()

