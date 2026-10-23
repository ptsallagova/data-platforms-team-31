-- Проверка партиций и запросы к партиционированной таблице.
USE ${hivevar:db};

-- Список партиций (по сгенерированным данным: 2 года x 12 месяцев = 24)
SHOW PARTITIONS ${hivevar:tbl};

-- Число строк и выручка по партициям
SELECT sale_year, sale_month, count(*) AS orders, round(sum(amount), 2) AS revenue
FROM ${hivevar:tbl}
GROUP BY sale_year, sale_month
ORDER BY sale_year, sale_month;

-- Запрос с фильтром по ключу партиции: читается только одна партиция
SELECT category, count(*) AS orders, round(avg(amount), 2) AS avg_check
FROM ${hivevar:tbl}
WHERE sale_year = 2025 AND sale_month = 3
GROUP BY category
ORDER BY orders DESC;
