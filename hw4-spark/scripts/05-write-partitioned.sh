
#!/usr/bin/env bash
set -euo pipefail

SPARK_HOME="/home/hadoop/spark"
WORK_DIR="/home/hadoop/hw4"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/tmp/hw4-write-partitioned.log"

echo "=== Writing partitioned COVID data ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

# Проверяем зависимости
if ! sudo -u hadoop test -x "$SPARK_HOME/bin/spark-submit"; then
    echo "ERROR: Spark is not installed"
    exit 1
fi

if ! systemctl is-active --quiet hive-metastore; then
    echo "ERROR: Hive Metastore is not running"
    exit 1
fi

# Копируем файл в каталог hadoop
sudo install -d -o hadoop -g hadoop -m 755 "$WORK_DIR"
sudo install -o hadoop -g hadoop -m 644 \
    "$SCRIPT_DIR/05-write-partitioned.py" \
    "$WORK_DIR/05-write-partitioned.py"

# Проверяем, работает ли NodeManager на NameNode
NM_WAS_RUNNING=0

restore_nodemanager() {
    status=$?
    trap - EXIT

    if [[ "$NM_WAS_RUNNING" -eq 1 ]]; then
        echo "=== Restoring NodeManager ==="
        if ! sudo -iu hadoop yarn --daemon start nodemanager; then
            echo "WARNING: Could not restart NodeManager"
            status=1
        fi
    fi

    exit "$status"
}

trap restore_nodemanager EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Освобождаем память на NameNode
if sudo -u hadoop /home/hadoop/java/bin/jps -l | grep -q 'org.apache.hadoop.yarn.server.nodemanager.NodeManager'; then
    echo "Stopping NodeManager on NameNode..."
    NM_WAS_RUNNING=1
    sudo -iu hadoop yarn --daemon stop nodemanager
else
    echo "NodeManager is already stopped on NameNode"
fi

# Проверяем доступную память
avail_mb=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
echo "Available memory: ${avail_mb} MB"

if [[ "$avail_mb" -lt 1000 ]]; then
    echo "ERROR: Not enough memory for Spark"
    exit 1
fi

echo "=== Starting Spark on YARN ==="

(
    cd /tmp

    sudo -H -u hadoop bash -c '
        source /home/hadoop/spark-env.sh
        exec /home/hadoop/spark/bin/spark-submit \
            --master yarn \
            --deploy-mode client \
            --driver-memory 512m \
            --num-executors 2 \
            --executor-cores 1 \
            --executor-memory 512m \
            --conf spark.dynamicAllocation.enabled=false \
            --conf spark.sql.shuffle.partitions=8 \
            /home/hadoop/hw4/05-write-partitioned.py
    '
) 2>&1 | tee "$LOG_FILE"

echo "=== Partitioned data written successfully ==="
echo "Log: $LOG_FILE"
