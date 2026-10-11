# ДЗ 2. YARN и веб-интерфейсы

Разворачиваем YARN поверх HDFS из ДЗ 1 и открываем веб-интерфейсы демонов кластера снаружи через nginx на edge-ноде.

## Что где работает

| Нода | Демоны |
|---|---|
| team-31-nn | ResourceManager, NodeManager, JobHistory Server (+ NameNode, Secondary NameNode, DataNode из ДЗ 1) |
| team-31-00 | NodeManager (+ DataNode) |
| team-31-01 | NodeManager (+ DataNode) |
| team-31-en (edge) | nginx, через который открыты веб-интерфейсы |

## Что должно быть готово заранее

- ДЗ 1 выполнено: Hadoop стоит на всех нодах, у `hadoop` есть беспарольный SSH с `team-31-nn`, HDFS запущена.
- В `hadoop-env.sh` прописан `JAVA_HOME`, в `workers` есть все три ноды: `team-31-nn`, `team-31-00`, `team-31-01`. По этому файлу `start-yarn.sh` решает, где запускать NodeManager.

## Запуск

Все скрипты запускаются на edge-ноде от пользователя `team` из корня репозитория.

```bash
bash hw2-yarn/scripts/01-configure-yarn.sh   # разложить yarn-site.xml и mapred-site.xml по нодам
bash hw2-yarn/scripts/02-start-yarn.sh       # запустить YARN и JobHistory Server, в конце проверка
bash hw2-yarn/scripts/04-publish-ui.sh       # поставить nginx и открыть веб-интерфейсы
```

Остановить YARN: `bash hw2-yarn/scripts/stop-yarn.sh`.

### 1. Конфигурация

`config/yarn-site.xml`:
- ResourceManager работает на `team-31-nn`;
- включен `mapreduce_shuffle`, без него не работают MapReduce-задачи;
- память и ядра для NodeManager определяются автоматически по железу ноды;
- отключена проверка виртуальной памяти (иначе Java 11 часто убивают зря);
- логи задач собираются в HDFS и открываются через JobHistory.

`config/mapred-site.xml`:
- MapReduce запускается через YARN;
- указан `HADOOP_MAPRED_HOME`, без него задача падает с ошибкой `Could not find or load main class ...MRAppMaster`;
- по 1 ГБ памяти на мастер задачи, map и reduce;
- JobHistory Server на `team-31-nn` (порт 19888).

Скрипт `01-configure-yarn.sh` копирует оба файла в `/home/hadoop/hadoop/etc/hadoop` на все три ноды и предупреждает, если в `workers` не хватает нод или не задан `JAVA_HOME`.

Если YARN уже запущен, после изменения конфигов его нужно перезапустить: `stop-yarn.sh`, затем `02-start-yarn.sh`.

### 2. Запуск и проверка

`02-start-yarn.sh` проверяет, что HDFS работает, запускает на `team-31-nn` от `hadoop` команды `start-yarn.sh` и `mapred --daemon start historyserver`, затем вызывает `03-check-yarn.sh`.

`03-check-yarn.sh` проверяет:
- через `jps`, что запущены ResourceManager, JobHistoryServer и NodeManager на каждой ноде;
- через `yarn node -list`, что в ResourceManager зарегистрированы 3 NodeManager в состоянии RUNNING;
- что проходит тестовая задача MapReduce (вычисление числа пи).

Пример успешного вывода:

```
=== Daemons ===
OK   team-31-nn: ResourceManager
OK   team-31-nn: JobHistoryServer
OK   team-31-nn: NodeManager
OK   team-31-00: NodeManager
OK   team-31-01: NodeManager
=== NodeManagers registered in ResourceManager ===
Total Nodes:3
...
=== Test job: pi ===
Job job_..._0001 completed successfully
Estimated value of Pi is 3.14...
YARN is OK
```

### 3. Веб-интерфейсы снаружи

Внешний IP есть только у edge-ноды, поэтому на ней стоит nginx: он принимает запросы на нужных портах и пересылает их на внутренние ноды. Конфиг лежит в `config/nginx/hadoop-ui.conf`, общие настройки — в `config/nginx/hadoop-proxy.conf`.

Интерфейсы закрыты логином и паролем (basic auth). Открывать ResourceManager в интернет без пароля опасно: через его API любой может запустить на кластере свой код. Логин по умолчанию `admin`, пароль скрипт спросит при первом запуске.

Ограничение: соединение идет по HTTP, без шифрования, поэтому пароль теоретически можно перехватить в сети. Для учебного стенда этого достаточно. Для настоящего кластера нужен HTTPS или доступ только через VPN / SSH-туннель.

`04-publish-ui.sh`:
- ставит nginx, если его нет;
- создает файл с паролем `/etc/nginx/hadoop.htpasswd`;
- копирует конфиги в `/etc/nginx`, проверяет их через `nginx -t` и перезапускает nginx;
- если включен `ufw`, открывает в нем нужные порты;
- в конце запускает `05-check-ui.sh`, который проверяет, что каждая страница отвечает с паролем и не открывается без него.

| Адрес | Что открывается |
|---|---|
| http://2.59.82.188:9870 | NameNode |
| http://2.59.82.188:9868 | Secondary NameNode |
| http://2.59.82.188:8088 | ResourceManager |
| http://2.59.82.188:19888 | JobHistory Server |
| http://2.59.82.188:9864 | DataNode на team-31-nn |
| http://2.59.82.188:9865 | DataNode на team-31-00 |
| http://2.59.82.188:9866 | DataNode на team-31-01 |
| http://2.59.82.188:8042 | NodeManager на team-31-nn |
| http://2.59.82.188:8043 | NodeManager на team-31-00 |
| http://2.59.82.188:8044 | NodeManager на team-31-01 |

Ссылки внутри интерфейсов (например, на конкретную ноду в ResourceManager) ведут на внутренние имена вида `team-31-00:8042` и снаружи не открываются. Для них нужно пользоваться адресами из таблицы.

Если страницы не открываются снаружи, хотя `05-check-ui.sh` на edge показывает OK, значит порты закрыты на стороне облака. В этом случае можно открыть интерфейс через SSH-туннель со своего компьютера:

```bash
ssh -L 8088:localhost:8088 team@2.59.82.188
```

и зайти на http://localhost:8088.
