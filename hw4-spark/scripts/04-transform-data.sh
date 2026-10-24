#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/transform_data.py"
WORK_DIR="/home/hadoop/hw4"
LOG_FILE="/tmp/hw4-transform-data.log"
INPUT_PATH="hdfs://team-31-nn:9000/data/covid/countries-aggregated.csv"
OUTPUT_PATH="hdfs://team-31-nn:9000/data/covid/processed/country_monthly"

# На team-31-nn одновременно работают NameNode, ResourceManager, Hive и PostgreSQL,
# поэтому ресурсы Spark ограничены: датасет маленький (~160 тыс. строк), этого хватает
SPARK_OPTS=(
    --master yarn
    --deploy-mode client
    --driver-memory 512m
    --num-executors 2
    --executor-cores 1
    --executor-memory 512m
    --conf spark.dynamicAllocation.enabled=false
    --conf spark.sql.shuffle.partitions=8
)

# Драйвер (client mode) работает на team-31-nn и занимает ~700 МБ
avail_mb="$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)"
if [[ "$avail_mb" -lt 900 ]]; then
    echo "ERROR: Only ${avail_mb} MB of free memory on $(hostname -s), Spark driver needs ~900 MB"
    echo "Stop the NodeManager on this node for the run (see docs/03-transform.md):"
    echo "  sudo -iu hadoop yarn --daemon stop nodemanager"
    free -h
    exit 1
fi

echo "=== Transforming dataset with Spark on YARN ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

if ! sudo -H -u hadoop bash -c "source /home/hadoop/spark-env.sh && cd /tmp && hdfs dfs -test -e ${INPUT_PATH}"; then
    echo "ERROR: Input not found: ${INPUT_PATH} (run 02-load-data.sh)"
    exit 1
fi

sudo install -d -o hadoop -g hadoop -m 755 "$WORK_DIR"
sudo install -o hadoop -g hadoop -m 644 "$SCRIPT" "$WORK_DIR/transform_data.py"

status=0
output=$(
    cd /tmp
    sudo -H -u hadoop bash -c "source /home/hadoop/spark-env.sh && spark-submit ${SPARK_OPTS[*]} $WORK_DIR/transform_data.py $INPUT_PATH $OUTPUT_PATH" 2> "$LOG_FILE"
) || status=$?

echo "$output"

if [[ "$status" -ne 0 ]] || grep -q '^\[FAIL\]' <<< "$output" || ! grep -q "^Result rows: [1-9]" <<< "$output"; then
    tail -n 40 "$LOG_FILE"
    echo "ERROR: Spark job failed, full log: $LOG_FILE"
    exit 1
fi

echo "=== Result in HDFS ==="
sudo -H -u hadoop bash -c "source /home/hadoop/spark-env.sh && cd /tmp && hdfs dfs -ls -h ${OUTPUT_PATH}"

echo "=== Dataset transformed successfully ==="
