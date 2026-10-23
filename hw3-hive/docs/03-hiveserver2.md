## 3. HiveServer2

HiveServer2 принимает подключения клиентов (Beeline, JDBC). Метаданные он берёт из Hive Metastore (`thrift://team-31-nn:9083`, шаг 2), а тот хранит их в PostgreSQL. Embedded-режим не используется, поэтому к серверу могут одновременно подключаться несколько клиентов.

Перед этим должны быть выполнены шаги 1 и 2, а HDFS и YARN запущены.

### Запуск

На `team-31-nn` от пользователя `team`, из папки `hw3-hive`:

```bash
bash scripts/07-configure-hiveserver2.sh
bash scripts/08-start-hiveserver2.sh
bash scripts/09-check-hiveserver2.sh
```

`07-configure-hiveserver2.sh` копирует `config/hiveserver2/hive-site.xml` в `/home/hadoop/hive-server2-conf/` и создает в HDFS каталоги `/user/hive/warehouse` и `/tmp/hive`.

`08-start-hiveserver2.sh` устанавливает systemd-сервис `hive-server2`, запускает его и ждет, пока откроется порт 10000. Обычно это занимает 1–2 минуты.

`09-check-hiveserver2.sh` проверяет:
- сервис работает, порт 10000 открыт;
- Beeline подключается;
- два клиента работают с сервером одновременно;
- база, созданная одним клиентом, видна другому.

Пример успешного вывода:

```
=== 3. Two clients at the same time ===
Max simultaneous connections to HiveServer2: 2
client1 started hadoop 2026-10-23 17:16:34.001195
client1 finished 2026-10-23 17:16:50.397074
client2 started hadoop 2026-10-23 17:16:39.200562
client2 finished 2026-10-23 17:16:50.720975
OK: Two clients worked with HiveServer2 at the same time
=== 4. Shared metastore ===
OK: Database created by client1 is visible to client2
=== HiveServer2 checks passed ===
```

Оба клиента были подключены одновременно с 17:16:39 до 17:16:50.

### Настройки

| Параметр | Значение |
|---|---|
| `hive.metastore.uris` | `thrift://team-31-nn:9083` |
| `hive.server2.thrift.port` | `10000` |
| `hive.server2.webui.port` | `10002` |
| `hive.server2.enable.doAs` | `false`, запросы выполняются от `hadoop` |
| `hive.execution.engine` | `mr`, запросы идут через MapReduce на YARN |
| `hive.exec.dynamic.partition.mode` | `nonstrict`, нужно для загрузки в партиции |
| `hive.notification.event.poll.interval` | `0s`, без этого HiveServer2 не стартует: Metastore отклоняет запрос `get_current_notificationEventId` |

### Подключение вручную

```bash
sudo -iu hadoop
beeline -u jdbc:hive2://team-31-nn:10000/default -n hadoop
```

Если открыть так два терминала и в одном создать таблицу, во втором она сразу будет видна. Выход: `!quit`.

Управление сервисом:

```bash
sudo systemctl status hive-server2
sudo systemctl restart hive-server2
sudo journalctl -u hive-server2 -f
```
