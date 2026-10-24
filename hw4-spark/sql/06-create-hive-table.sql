CREATE DATABASE IF NOT EXISTS hw4;

CREATE EXTERNAL TABLE IF NOT EXISTS hw4.covid_monthly (
    country STRING,
    month INT,
    last_date DATE,
    days_reported INT,
    confirmed BIGINT,
    deaths BIGINT,
    recovered BIGINT,
    new_confirmed BIGINT,
    new_deaths BIGINT,
    mortality_rate DOUBLE
)
PARTITIONED BY (year INT)
STORED AS PARQUET
LOCATION '/user/hive/warehouse/hw4.db/covid_monthly';


MSCK REPAIR TABLE hw4.covid_monthly;

SHOW PARTITIONS hw4.covid_monthly;

