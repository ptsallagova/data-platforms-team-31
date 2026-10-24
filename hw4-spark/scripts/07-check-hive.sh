#!/usr/bin/env bash
set -euo pipefail

HIVE_HOME="/home/hadoop/hive"
HADOOP_HOME="/home/hadoop/hadoop"
JAVA_HOME="/home/hadoop/java"
HIVE_CONF_DIR="/home/hadoop/hive-server2-conf"

TABLE="hw4.covid_monthly"
TABLE_DIR="/user/hive/warehouse/hw4.db/covid_monthly"
LOG_FILE="/tmp/hw4-check-hive-errors.log"

echo "=== Checking Spark and Hive integration ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

echo "=== 1. Hive services ==="

for service in hive-metastore hive-server2; do
    if ! systemctl is-active --quiet "$service"; then
        echo "FAIL: $service is not running"
        exit 1
    fi
    echo "OK: $service is running"
done

echo "=== 2. HDFS partitions ==="

hdfs_cmd() {
    (
        cd /tmp
        sudo -H -u hadoop env JAVA_HOME="$JAVA_HOME" \
            "$HADOOP_HOME/bin/hdfs" dfs "$@"
    )
}

for year in 2020 2021 2022; do
    if ! hdfs_cmd -test -d "$TABLE_DIR/year=$year"; then
        echo "FAIL: HDFS partition year=$year missing"
        exit 1
    fi
    echo "OK: HDFS year=$year"
done

beeline_sql() {
    (
        cd /tmp
        sudo -H -u hadoop env \
            JAVA_HOME="$JAVA_HOME" \
            HADOOP_HOME="$HADOOP_HOME" \
            HIVE_CONF_DIR="$HIVE_CONF_DIR" \
            "$HIVE_HOME/bin/beeline" \
            -u jdbc:hive2://team-31-nn:10000/default \
            -n hadoop \
            --silent=true \
            --showHeader=false \
            --outputformat=tsv2 \
            -e "$1"
    ) 2>"$LOG_FILE" || {
        tail -n 25 "$LOG_FILE"
        return 1
    }
}

echo "=== 3. Hive partitions ==="

partitions=$(beeline_sql "SHOW PARTITIONS $TABLE" | tr -d '\r')

printf '%s\n' "$partitions"

for year in 2020 2021 2022; do
    if ! printf '%s\n' "$partitions" | grep -qx "year=$year"; then
        echo "FAIL: Hive partition year=$year missing"
        exit 1
    fi
done

partition_count=$(printf '%s\n' "$partitions" | grep -Ec '^year=[0-9]{4}$' || true)

if [[ "$partition_count" -ne 3 ]]; then
    echo "FAIL: Expected 3 partitions, got $partition_count"
    exit 1
fi

echo "OK: All 3 partitions registered in Hive"

echo "=== 4. SQL read via Beeline ==="

sample=$(beeline_sql "SELECT country, year, month, confirmed FROM $TABLE WHERE year = 2020 LIMIT 5")

printf '%s\n' "$sample"

if ! printf '%s\n' "$sample" | awk -F '\t' '
    NF == 4 && $2 == "2020" { found = 1 }
    END { exit !found }
'; then
    echo "FAIL: Could not read rows from Hive"
    exit 1
fi

echo "OK: Hive SQL read successful"
echo "=== All Spark/Hive checks passed ==="
