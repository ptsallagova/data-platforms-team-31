# HW3. Apache Hive 4.0.0-alpha-2 (не embedded) + загрузка в партиционированную таблицу

Hive разворачивается на `team-31-nn` в многоклиентской схеме:

```
Beeline / JDBC клиенты ──► HiveServer2 :10000 ──► Hive Metastore :9083 ──► PostgreSQL 16 (hive_metastore)
                                │
                                └──► MapReduce на YARN, данные в HDFS (/user/hive/warehouse)
```

Metastore — отдельный сервис с базой в PostgreSQL (не embedded Derby), поэтому к HiveServer2 одновременно подключаются несколько клиентов.

## Требования

- Работающие HDFS (HW1) и YARN (HW2)
- Java 11 и Hadoop 3.4.0 в `/home/hadoop/java` и `/home/hadoop/hadoop`
- Пользователь `team` с sudo на `team-31-nn`

## Автоматическое развертывание

На `team-31-nn` от пользователя `team`, из папки `hw3-hive`:

```bash
bash scripts/deploy.sh
```

Скрипты 02 и 03 один раз спросят пароль пользователя `hive` для PostgreSQL (одинаковый в обоих местах). Все шаги идемпотентны.

## Шаги

| # | Скрипт | Что делает |
|---|---|---|
| 1 | `01-install-hive.sh` | скачивает Hive 4.0.0-alpha-2 в `/home/hadoop`, ссылка `/home/hadoop/hive`, `HIVE_HOME`/`PATH` в `~/.bashrc`, проверка `hive --version`. Запускается от `hadoop`: `sudo -iu hadoop bash /tmp/01-install-hive.sh` (deploy.sh делает это сам) |
| 2 | `02-setup-postgres.sh` | ставит PostgreSQL, создает пользователя `hive` и базу `hive_metastore` |
| 2 | `03-configure-metastore.sh` | `hive-site.xml` Metastore в `/home/hadoop/hive-metastore-conf/` (подключение к PostgreSQL) |
| 2 | `04-init-metastore.sh` | `schemaTool -initSchema` (если база пустая) и `-info` |
| 2 | `05-start-metastore.sh` | systemd-сервис `hive-metastore` (`config/hive-metastore.service`), порт 9083 |
| 2 | `06-check-metastore.sh` | проверка: PostgreSQL, схема 4.0.0-alpha-2, сервис, порт |
| 3 | `07–09-*.sh` | HiveServer2, два одновременных клиента — см. [docs/03-hiveserver2.md](docs/03-hiveserver2.md) |
| 4 | `10–13-*.sh` | датасет в HDFS, таблица `PARTITIONED BY`, загрузка, `SHOW PARTITIONS` — см. [docs/04-partitioned-table.md](docs/04-partitioned-table.md) |

## Проверка

```bash
bash scripts/06-check-metastore.sh      # Metastore
bash scripts/09-check-hiveserver2.sh    # два клиента одновременно
bash scripts/13-check-partitions.sh     # партиции
```

Вручную:

```bash
sudo -iu hadoop
beeline -u jdbc:hive2://team-31-nn:10000/default -n hadoop
```

Web UI HiveServer2: http://team-31-nn:10002

## Структура

- `config/` — systemd-юниты и `hiveserver2/hive-site.xml`
- `scripts/` — скрипты 01–13, `deploy.sh`, `hive-common.sh` (общие функции для 10–13)
- `sql/` — SQL для создания таблиц, загрузки и проверки
- `docs/` — подробности по шагам 3 и 4
