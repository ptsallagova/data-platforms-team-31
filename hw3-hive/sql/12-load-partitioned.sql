-- Загрузка staging -> партиционированная таблица с динамическими партициями.
-- INSERT OVERWRITE перезаписывает только партиции, которые есть в выборке,
-- поэтому повторный запуск не создает дубликатов.

USE ${hivevar:db};

-- Уже включено в hive-site.xml HiveServer2, дублируем для независимости от конфига
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

INSERT OVERWRITE TABLE ${hivevar:tbl} PARTITION (sale_year, sale_month)
SELECT
    order_id,
    order_date,
    customer_id,
    category,
    amount,
    year(order_date)  AS sale_year,
    month(order_date) AS sale_month
FROM ${hivevar:tbl}_raw
WHERE order_date IS NOT NULL;
