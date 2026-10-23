## 4. Партиционированная таблица и загрузка данных

Перед этим должны работать HDFS, YARN, Hive Metastore и HiveServer2 (шаги 1–3).

### Запуск

На `team-31-nn` от пользователя `team`, из папки `hw3-hive`:

```bash
bash scripts/10-prepare-dataset.sh
bash scripts/11-create-tables.sh
bash scripts/12-load-data.sh
bash scripts/13-check-partitions.sh
```

Все шаги идемпотентны, их можно запускать повторно.

### Датасет

`10-prepare-dataset.sh` генерирует CSV с заказами интернет-магазина за 2024–2025 годы (50 000 строк, seed 42 — данные всегда одинаковые) и кладет его в HDFS:

```
/data/hw3/sales_raw/sales_2024_2025.csv
```

| Колонка | Пример | Что это |
|---|---|---|
| `order_id` | `1` | номер заказа |
| `order_date` | `2025-03-14` | дата заказа |
| `customer_id` | `1843` | покупатель |
| `category` | `books` | категория товара |
| `amount` | `512.37` | сумма заказа |

Размер можно поменять: `ROWS=200000 bash scripts/10-prepare-dataset.sh`. Можно загрузить свой файл того же формата: `bash scripts/10-prepare-dataset.sh /tmp/my.csv` (файл должен быть читаем пользователем `hadoop`, поэтому лучше класть его в `/tmp`).

### Таблицы

`11-create-tables.sh` выполняет `sql/11-create-tables.sql` и создает в базе `hw3`:

| Таблица | Тип | Где данные | Зачем |
|---|---|---|---|
| `hw3.sales_raw` | EXTERNAL, TEXTFILE | `/data/hw3/sales_raw` | staging: читает CSV как есть, заголовок пропускается |
| `hw3.sales` | EXTERNAL, PARQUET, `PARTITIONED BY (sale_year INT, sale_month INT)` | `/user/hive/warehouse/hw3.db/sales` | целевая партиционированная таблица |

`sales` объявлена как EXTERNAL с явным `LOCATION` и `external.table.purge=true`: так Hive 4 не делает ее транзакционной (ACID), данные лежат в общем warehouse, а при `DROP TABLE` удаляются.

### Загрузка

`12-load-data.sh` выполняет `sql/12-load-partitioned.sql`:

```sql
INSERT OVERWRITE TABLE sales PARTITION (sale_year, sale_month)
SELECT order_id, order_date, customer_id, category, amount,
       year(order_date), month(order_date)
FROM sales_raw
WHERE order_date IS NOT NULL;
```

Партиции динамические: Hive сам раскладывает строки по каталогам `sale_year=YYYY/sale_month=M` по значениям последних колонок `SELECT`. Для этого нужен `hive.exec.dynamic.partition.mode=nonstrict` (включено в конфиге HiveServer2, в SQL продублировано через `SET`). Запрос выполняется как MapReduce-задача на YARN, ее видно в ResourceManager UI.

`INSERT OVERWRITE` перезаписывает только партиции, попавшие в выборку, поэтому повторная загрузка не создает дубликатов. Чтобы догрузить новые данные, достаточно положить файл в `/data/hw3/sales_raw` (`10-prepare-dataset.sh /tmp/new.csv`) и запустить `12-load-data.sh`.

После загрузки скрипт сверяет число строк в `sales_raw` и `sales`.

### Проверка

`13-check-partitions.sh`:
- выводит `SHOW PARTITIONS hw3.sales` и статистику по партициям;
- выполняет запрос с фильтром по ключу партиции (`WHERE sale_year = 2025 AND sale_month = 3`);
- показывает каталоги партиций в HDFS;
- проверяет, что число партиций в Metastore = числу каталогов в HDFS = числу различных месяцев в исходных данных, и что каждая строка лежит в своей партиции.

Пример успешного вывода:

```
=== 3. Consistency checks ===
Partitions in Metastore:   24
Partition dirs in HDFS:    24
Expected from raw data:    24
Rows in wrong partition:   0
OK: 24 partitions, Metastore and HDFS are consistent
=== Partitioned table checks passed ===
```

### Вручную

```bash
sudo -iu hadoop
beeline -u jdbc:hive2://team-31-nn:10000/default -n hadoop
```

```sql
USE hw3;
SHOW PARTITIONS sales;
SELECT count(*) FROM sales WHERE sale_year = 2024 AND sale_month = 12;
```
