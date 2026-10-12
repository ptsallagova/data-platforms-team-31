# data-platforms-team-31

HSE data platforms course — team 31

## HW1. Развёртывание HDFS кластера

Кластер состоит из 3 DataNode, 1 NameNode и 1 Secondary NameNode.

### Требования
- 4 ВМ: edge + namenode + 2 datanode (MWS Ubuntu 24.04)
- Java 11 (Temurin 11.0.32.1+1)
- Hadoop 3.4.0
- SSH-ключ ~/.ssh/team_internal для доступа edge → внутренние узлы

### Узлы

| Роль | Hostname | IP |
|---|---|---|
| edge | team-31-en | 10.31.0.10 |
| namenode + secondary | team-31-nn | 10.31.0.11 |
| datanode-0 | team-31-00 | 10.31.0.12 |
| datanode-1 | team-31-01 | 10.31.0.13 |

### Автоматическое развёртывание

С edge-ноды (пользователь team), из корня репозитория:

    cd hw1-hdfs/scripts
    ./deploy.sh

Скрипт идемпотентен — его можно запускать повторно на той же среде: старые данные HDFS будут очищены, кластер развёрнут заново.

Шаги, выполняемые deploy.sh:
1. 01-prepare-nodes.sh — установка Java 11 и Hadoop 3.4.0 на все ноды, создание пользователя hadoop, фикс /etc/hosts (убирает строку 127.0.1.1 <hostname>)
2. 02-setup-ssh.sh — беспарольный SSH для пользователя hadoop между нодами
3. 03-configure-hdfs.sh — раскладка конфигов core-site.xml, hdfs-site.xml, workers и создание директорий HDFS
4. Очистка старых данных HDFS и пересоздание директорий
5. 04-format-namenode.sh — форматирование NameNode
6. 05-start-hdfs.sh — запуск кластера
7. 06-check-hdfs.sh — проверка

### Проверка работоспособности
- Web UI NameNode: http://team-31-nn:9870 → 3 Live DataNodes, 0 Dead
- ./06-check-hdfs.sh — выводит jps, dfsadmin -report, тест записи/чтения, поиск FATAL в логах
- Ожидаемо в отчёте: Live datanodes (3):

### Остановка

    ./stop-hdfs.sh

### Структура репозитория
- hw1-hdfs/config/ — конфигурация Hadoop (core-site.xml, hdfs-site.xml, workers)
- hw1-hdfs/scripts/ — скрипты развёртывания (01–06 + deploy.sh)
- hw1-hdfs/docs/ — документация
