# Общие функции для шагов 10–13 (таблица и загрузка данных).
# Подключается через source, отдельно не запускается.

JAVA_HOME="/home/hadoop/java"
HADOOP_HOME="/home/hadoop/hadoop"
HIVE_HOME="/home/hadoop/hive"
JDBC_URL="jdbc:hive2://team-31-nn:10000/default"

DB_NAME="hw3"
TABLE_NAME="sales"
HDFS_RAW_DIR="/data/hw3/sales_raw"
TABLE_DIR="/user/hive/warehouse/${DB_NAME}.db/${TABLE_NAME}"

SQL_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../sql" && pwd)"

check_host() {
    if [[ "$(hostname -s)" != "team-31-nn" ]]; then
        echo "ERROR: Run on team-31-nn"
        exit 1
    fi
    sudo -n true
}

hdfs_cmd() {
    (
        cd /tmp
        sudo -H -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" dfs "$@"
    )
}

# beeline от пользователя hadoop; переменные для SQL передаются через --hivevar
beeline_cmd() {
    (
        cd /tmp
        sudo -H -u hadoop env \
            JAVA_HOME="$JAVA_HOME" \
            HADOOP_HOME="$HADOOP_HOME" \
            "$HIVE_HOME/bin/beeline" -u "$JDBC_URL" -n hadoop --silent=true \
            --hivevar db="$DB_NAME" \
            --hivevar tbl="$TABLE_NAME" \
            --hivevar raw_dir="$HDFS_RAW_DIR" \
            --hivevar table_dir="$TABLE_DIR" \
            "$@"
    )
}

# Одно значение из запроса (без заголовка и логов)
beeline_value() {
    beeline_cmd --showHeader=false --outputformat=tsv2 -e "$1" 2>/dev/null | grep -v '^[[:space:]]*$'
}

# Запуск SQL-файла из репозитория. Домашний каталог team закрыт для hadoop
# (750 в Ubuntu 24.04), поэтому файл сначала копируется во временный каталог.
beeline_file() {
    local tmp
    tmp="$(mktemp -d)"
    chmod 755 "$tmp"
    install -m 644 "$SQL_SRC_DIR/$1" "$tmp/$1"
    local rc=0
    beeline_cmd -f "$tmp/$1" || rc=$?
    rm -rf "$tmp"
    return $rc
}

require_hiveserver2() {
    if ! systemctl is-active --quiet hive-server2; then
        echo "ERROR: HiveServer2 is not running (run 08-start-hiveserver2.sh)"
        exit 1
    fi
}
