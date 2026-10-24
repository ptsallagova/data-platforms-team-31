
#!/usr/bin/env bash
set -euo pipefail


HIVE_HOME="/home/hadoop/hive"
HADOOP_HOME="/home/hadoop/hadoop"
JAVA_HOME="/home/hadoop/java"
CONF_DIR="/home/hadoop/hive-server2-conf"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${1:-$SCRIPT_DIR/../sql/06-create-hive-table.sql}"

echo "=== Registering Hive table ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

if [[ ! -f "$SQL_FILE" ]]; then
    echo "ERROR: SQL file not found: $SQL_FILE"
    exit 1
fi

if ! systemctl is-active --quiet hive-metastore; then
    echo "ERROR: Hive Metastore is not running"
    exit 1
fi

if ! systemctl is-active --quiet hive-server2; then
    echo "ERROR: HiveServer2 is not running"
    exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

chmod 755 "$TMP_DIR"
install -m 644 "$SQL_FILE" "$TMP_DIR/create.sql"

echo "=== Running SQL through Beeline ==="

(
    cd /tmp
    sudo -H -u hadoop env \
        JAVA_HOME="$JAVA_HOME" \
        HADOOP_HOME="$HADOOP_HOME" \
        HIVE_CONF_DIR="$CONF_DIR" \
        "$HIVE_HOME/bin/beeline" \
        -u "jdbc:hive2://team-31-nn:10000/default" \
        -n hadoop \
        -f "$TMP_DIR/create.sql"
)

echo "=== Hive table registered successfully ==="
