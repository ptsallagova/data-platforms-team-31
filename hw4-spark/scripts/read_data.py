import sys

from pyspark.sql import SparkSession

DATA_PATH = "hdfs://team-31-nn:9000/data/covid/countries-aggregated.csv"

spark = (
    SparkSession.builder
    .appName("hw4-read-data")
    .master("yarn")
    .getOrCreate()
)
spark.sparkContext.setLogLevel("WARN")

df = (
    spark.read
    .option("header", "true")
    .csv(DATA_PATH)
)

print("Spark master:", spark.sparkContext.master)
print("Application id:", spark.sparkContext.applicationId)

print("Schema:")
df.printSchema()

rows = df.count()
print("Rows:", rows)

print("First rows:")
df.show(10, truncate=False)

spark.stop()

if rows == 0:
    print("ERROR: dataset is empty")
    sys.exit(1)
