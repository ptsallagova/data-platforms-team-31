-- Таблицы для загрузки данных. Переменные передаются из скриптов через --hivevar.

CREATE DATABASE IF NOT EXISTS ${hivevar:db};
USE ${hivevar:db};

-- Staging: внешняя таблица поверх CSV в HDFS.
-- DROP внешней таблицы не удаляет файлы, поэтому её можно безопасно пересоздавать.
DROP TABLE IF EXISTS ${hivevar:tbl}_raw;
CREATE EXTERNAL TABLE ${hivevar:tbl}_raw (
    order_id    BIGINT,
    order_date  DATE,
    customer_id INT,
    category    STRING,
    amount      DECIMAL(10,2)
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '${hivevar:raw_dir}'
TBLPROPERTIES ('skip.header.line.count' = '1');

-- Целевая таблица, партиционированная по году и месяцу заказа.
-- EXTERNAL с явным LOCATION: данные лежат в /user/hive/warehouse, а Hive 4 не
-- превращает таблицу в транзакционную. external.table.purge=true — при DROP данные удаляются.
CREATE EXTERNAL TABLE IF NOT EXISTS ${hivevar:tbl} (
    order_id    BIGINT,
    order_date  DATE,
    customer_id INT,
    category    STRING,
    amount      DECIMAL(10,2)
)
PARTITIONED BY (sale_year INT, sale_month INT)
STORED AS PARQUET
LOCATION '${hivevar:table_dir}'
TBLPROPERTIES ('external.table.purge' = 'true');

SHOW TABLES;
SHOW CREATE TABLE ${hivevar:tbl};
