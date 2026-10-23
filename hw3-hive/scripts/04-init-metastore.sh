#!/usr/bin/env bash
set -euo pipefail

DB_NAME="hive_metastore"
HIVE_HOME="/home/hadoop/hive"
CONF_DIR="/home/hadoop/hive-metastore-conf"
JAVA_HOME="/home/hadoop/java"
HADOOP_HOME="/home/hadoop/hadoop"

echo "=== Initializing Hive Metastore schema ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

# Проверяем конфигурацию
if ! sudo -u hadoop test -s "$CONF_DIR/hive-site.xml"; then
    echo "ERROR: hive-site.xml not found"
    exit 1
fi

# Проверяем доступность PostgreSQL
if ! sudo -u postgres psql -d "$DB_NAME" -Atqc "SELECT 1" | grep -qx 1; then
    echo "ERROR: PostgreSQL database is unavailable"
    exit 1
fi

# Функция запуска schemaTool
run_schema_tool() {
    (
        cd /tmp
        sudo -H -u hadoop env \
            JAVA_HOME="$JAVA_HOME" \
            HADOOP_HOME="$HADOOP_HOME" \
            HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop" \
            HIVE_CONF_DIR="$CONF_DIR" \
            "$HIVE_HOME/bin/hive" --service schemaTool \
            -dbType postgres "$@"
    )
}

# Проверяем существующие таблицы
table_count=$(sudo -u postgres psql -d "$DB_NAME" -Atqc \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';")

echo "Existing tables: $table_count"

if [[ "$table_count" -eq 0 ]]; then
    echo "Database is empty, initializing schema..."
    run_schema_tool -initSchema
else
    echo "Database is not empty, checking existing schema..."
fi

# Проверяем версию схемы
run_schema_tool -info

echo "=== Hive Metastore schema is ready ==="
