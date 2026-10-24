# 4. Партиционирование и Hive

Берём обработанные данные из шага 3, сохраняем их через Spark с партиционированием по годам и создаём таблицу Hive. Затем проверяем, что данные читаются через Beeline.

## 1. Запись данных

Входной Parquet лежит в HDFS:

`/data/covid/processed/country_monthly`

В нём 5076 строк со статистикой COVID-19 по странам и месяцам. Все типы уже приведены на предыдущем шаге.

Для записи используются `05-write-partitioned.py` и `05-write-partitioned.sh`.

Партиционируем по `year`:

```python
df.write.mode("overwrite").partitionBy("year").parquet(OUTPUT_PATH)
```

Результат сохраняется в `/user/hive/warehouse/hw4.db/covid_monthly`. Spark создаёт три каталога:

```text
covid_monthly/
├── year=2020/
├── year=2021/
└── year=2022/
```

После записи скрипт повторно читает данные и проверяет количество строк и список годов.

**Запуск на `team-31-nn` из папки `hw4-spark`:**

```bash
bash scripts/05-write-partitioned.sh
```

На NameNode всего 3,8 ГБ памяти, поэтому на время Spark-задачи скрипт останавливает локальный NodeManager и запускает Spark с ограниченными ресурсами: два executor по 512 МБ и driver 512 МБ. После выполнения NodeManager запускается обратно.

Лучше запускать через `tmux`, потому что SSH иногда обрывается. После задачи стоит отдельно проверить состояние NodeManager.

**Результат:** Spark прочитал и сохранил 5076 строк. Все три партиции появились в HDFS, данные после записи совпали с исходными по количеству строк.

## 2. Таблица Hive

Чтобы данные были доступны через Hive, создаём внешнюю таблицу `hw4.covid_monthly` поверх записанного Parquet.

За это отвечают `06-create-hive-table.sql` и `06-register-hive.sh`.

В таблице указываем `PARTITIONED BY (year INT)` и путь к данным через `LOCATION`. Затем регистрируем партиции:

```sql
MSCK REPAIR TABLE hw4.covid_monthly;
```

Такой способ используем вместо `saveAsTable()`, чтобы не зависеть от совместимости встроенных Hive-компонентов Spark 3.5.7 с Hive 4.0.0-alpha-2.

**Запуск:**

```bash
bash scripts/06-register-hive.sh
```

Скрипт выполняет SQL через Beeline. Повторный запуск тоже проверили — таблица остаётся на месте, партиции не дублируются.

`SHOW PARTITIONS hw4.covid_monthly` вернул:

```text
year=2020
year=2021
year=2022
```

## 3. Проверка

Для проверки написан `07-check-hive.sh`:

```bash
bash scripts/07-check-hive.sh
```

Он проверяет работу HiveServer2 и Metastore, наличие трёх партиций в HDFS и Hive, а также чтение данных через Beeline.

SQL-запрос для проверки:

```sql
SELECT country, year, month, confirmed
FROM hw4.covid_monthly
WHERE year = 2020
LIMIT 5;
```

Hive вернул пять записей за 2020 год.

Итоговый вывод:

```text
OK: hive-metastore is running
OK: hive-server2 is running
OK: HDFS year=2020
OK: HDFS year=2021
OK: HDFS year=2022
OK: All 3 partitions registered in Hive
OK: Hive SQL read successful
=== All Spark/Hive checks passed ===
```

Таким образом, Spark сохранил все 5076 строк в три партиции, Hive их зарегистрировал, а Beeline успешно прочитал данные.

Все скрипты проверены на работающем кластере. Для запуска из папки `hw4-spark` репозиторий должен находиться на NameNode. При проверке файлы копировались с edge-ноды в `/tmp` на NameNode и запускались оттуда.

Полный `COUNT(*)` через Hive отдельно не запускали, чтобы не нагружать NameNode. Количество строк проверили через Spark.
