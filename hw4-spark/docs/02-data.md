## 2. Загрузка и чтение данных

### Датасет

COVID-19 по странам, файл `countries-aggregated.csv` (около 5 МБ) из открытого набора [datasets/covid-19](https://datahub.io/core/covid-19).

| Колонка | Пример | Что это |
|---|---|---|
| `Date` | `2020-03-15` | дата |
| `Country` | `Italy` | страна |
| `Confirmed` | `24747` | подтвержденные случаи, накопительно |
| `Recovered` | `2335` | выздоровевшие, накопительно |
| `Deaths` | `1809` | умершие, накопительно |

Данные за несколько лет по почти 200 странам: есть что агрегировать (по странам, годам, месяцам) и по чему партиционировать (например, по году).

### Запуск

На `team-31-nn` от пользователя `team`, из папки `hw4-spark`:

```bash
bash scripts/02-load-data.sh
bash scripts/03-read-data.sh
```

`02-load-data.sh` скачивает файл (с GitHub, а если не получилось, с datahub.io), проверяет заголовок и кладет файл в HDFS:

```
hdfs://team-31-nn:9000/data/covid/countries-aggregated.csv
```

`03-read-data.sh` запускает `read_data.py` через `spark-submit --master yarn`. Скрипт создает Spark-сессию на YARN, читает CSV из HDFS через `spark.read` и выводит схему, число строк и первые 10 записей.

Все колонки читаются как строки, без `inferSchema`. Типы приводятся на следующем шаге, при обработке данных.

Если Spark-задача упадет, скрипт покажет конец лога. Полный лог лежит в `/tmp/hw4-read-data.log`.

### Проверка

Пример успешного вывода:

```
Spark master: yarn
Application id: application_1791832174044_0003
Schema:
root
 |-- Date: string (nullable = true)
 |-- Country: string (nullable = true)
 |-- Confirmed: string (nullable = true)
 |-- Recovered: string (nullable = true)
 |-- Deaths: string (nullable = true)

Rows: 161568
First rows:
+----------+-----------+---------+---------+------+
|Date      |Country    |Confirmed|Recovered|Deaths|
+----------+-----------+---------+---------+------+
|2020-01-22|Afghanistan|0        |0        |0     |
|2020-01-23|Afghanistan|0        |0        |0     |
...
```

То, что приложение выполнялось в YARN, видно и в ResourceManager: http://team-31-nn:8088, приложение `hw4-read-data`.

Вручную данные в HDFS можно посмотреть так:

```bash
sudo -iu hadoop
hdfs dfs -ls /data/covid
hdfs dfs -cat /data/covid/countries-aggregated.csv | head
```
