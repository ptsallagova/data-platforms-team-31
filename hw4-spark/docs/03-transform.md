## 3. Обработка данных

PySpark-скрипт `scripts/transform_data.py` берет сырой CSV из части 2, приводит типы, фильтрует, агрегирует помесячно по странам, проверяет результат и сохраняет его в HDFS для части 4.

Перед этим должны быть выполнены шаги 1 и 2 (Spark на YARN, датасет в HDFS).

### Запуск

На `team-31-nn` от пользователя `team`, из папки `hw4-spark`:

```bash
bash scripts/04-transform-data.sh
```

Скрипт копирует `transform_data.py` в `/home/hadoop/hw4/` и запускает его через `spark-submit --master yarn --deploy-mode client` с ограниченными ресурсами (драйвер и 2 executor по 512 МБ): на `team-31-nn` кроме Spark работают NameNode, ResourceManager, Hive и PostgreSQL. Если свободной памяти меньше 900 МБ, скрипт не запускает задачу.

На `team-31-nn` всего 3.8 ГБ памяти, и почти всю занимают демоны Hadoop и Hive. NodeManager на этой ноде принимает контейнеры YARN, и при запуске Spark они могут занять последнюю память — нода зависает. Поэтому на время запуска NodeManager на `team-31-nn` останавливается, контейнеры идут на `team-31-00` и `team-31-01`:

```bash
sudo -iu hadoop yarn --daemon stop nodemanager     # до запуска
bash scripts/04-transform-data.sh
sudo -iu hadoop yarn --daemon start nodemanager    # после
``` Запускать лучше внутри `tmux`, чтобы обрыв SSH не прервал задачу. Приложение `hw4-transform-data` видно в ResourceManager: http://team-31-nn:8088. Если задача упадет, скрипт покажет конец лога, полный лог лежит в `/tmp/hw4-transform-data.log`.

### Трансформации

| # | Что | Как |
|---|---|---|
| 1 | Преобразование типов | `Date` → `date` (`to_date`, `yyyy-MM-dd`); `Confirmed`, `Recovered`, `Deaths` → `long`. Некорректные значения становятся `null` |
| 2 | Фильтрация | убираются строки с пустой датой/страной/числами, отрицательные значения, `Deaths > Confirmed`, а также дни до первого случая в стране (`Confirmed = 0`) |
| 3 | Новые колонки | `year`, `month` из даты |
| 4 | Агрегация | `groupBy(country, year, month)`: числа в датасете накопительные, поэтому значение на конец месяца — `max`; плюс последняя дата и число дней с данными |
| 5 | Оконная функция | прирост за месяц `new_confirmed`, `new_deaths` = значение месяца − значение прошлого месяца (`lag` по окну страны). Отрицательный прирост (ретроспективные исправления в источнике) обрезается до 0 |
| 6 | Производная метрика | `mortality_rate = deaths / confirmed` |

### Проверки корректности

После обработки скрипт проверяет DataFrame и печатает `[OK]` / `[FAIL]` по каждому пункту:

- результат не пустой;
- типы всех колонок совпадают с ожидаемыми;
- нет `null`;
- пара `(country, year, month)` уникальна;
- `month` в диапазоне 1–12, `mortality_rate` в [0, 1], прирост не отрицательный;
- `last_date` относится к своему году и месяцу;
- итоговый `confirmed` по каждой стране равен максимуму в исходных данных;
- после записи в HDFS прочитано столько же строк, сколько было в DataFrame.

Если хоть одна проверка не прошла, результат не сохраняется и скрипт завершается с ошибкой.

Дополнительно выводятся число стран, список лет, пример по Италии за 2020 год и топ-10 стран по числу случаев.

### Результат (передается в часть 4)

```
hdfs://team-31-nn:9000/data/covid/processed/country_monthly
```

Parquet, **без партиций** — партиционирование и регистрация таблицы в Hive делаются в части 4. Одна строка = одна страна за один месяц.

| Колонка | Тип | Что это |
|---|---|---|
| `country` | string | страна |
| `year` | int | год (2020–2022) — удобный ключ для `partitionBy` |
| `month` | int | месяц 1–12 |
| `last_date` | date | последняя дата с данными в этом месяце |
| `days_reported` | int | сколько дней в месяце есть данные |
| `confirmed` | bigint | подтвержденные случаи на конец месяца, накопительно |
| `deaths` | bigint | умершие на конец месяца, накопительно |
| `recovered` | bigint | выздоровевшие на конец месяца, накопительно (источник перестал их считать в августе 2021, дальше 0) |
| `new_confirmed` | bigint | новые случаи за месяц |
| `new_deaths` | bigint | новые смерти за месяц |
| `mortality_rate` | double | `deaths / confirmed`, от 0 до 1 |

### Для части 4

Прочитать результат:

```python
df = spark.read.parquet("hdfs://team-31-nn:9000/data/covid/processed/country_monthly")
```

- Партиционировать удобно по `year` (3 партиции) или по `year, month` (28 партиций: январь 2020 — апрель 2022). `partitionBy` переносит эти колонки в путь каталога, в Hive они станут `PARTITIONED BY`.
- Spark 3.5.7 содержит клиент Hive 2.3, а Metastore у нас 4.0.0-alpha-2 — прямой `saveAsTable` через `enableHiveSupport()` может не заработать из-за разницы версий. Надежный вариант: записать Parquet с `partitionBy` в отдельный каталог (например, `/user/hive/warehouse/hw4.db/covid_monthly`), затем через beeline выполнить `CREATE EXTERNAL TABLE ... PARTITIONED BY (year INT) STORED AS PARQUET LOCATION '...'` и `MSCK REPAIR TABLE` — Hive сам найдет партиции.
- Подключение к Hive: `beeline -u jdbc:hive2://team-31-nn:10000/default -n hadoop` (от пользователя `hadoop`), Metastore — `thrift://team-31-nn:9083`. Готовые функции для beeline из bash есть в `hw3-hive/scripts/hive-common.sh`.
- Перезапуск `04-transform-data.sh` перезаписывает результат (`mode("overwrite")`).
