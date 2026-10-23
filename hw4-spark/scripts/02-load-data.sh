#!/usr/bin/env bash
set -euo pipefail

FILE_NAME="countries-aggregated.csv"
URLS=(
    "https://raw.githubusercontent.com/datasets/covid-19/main/data/${FILE_NAME}"
    "https://datahub.io/core/covid-19/_r/-/data/${FILE_NAME}"
)
LOCAL_FILE="/tmp/${FILE_NAME}"
HDFS_DIR="/data/covid"
HADOOP_HOME="/home/hadoop/hadoop"
JAVA_HOME="/home/hadoop/java"

echo "=== Loading dataset to HDFS ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

hdfs_cmd() {
    (
        cd /tmp
        sudo -H -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" dfs "$@"
    )
}

if [[ ! -s "$LOCAL_FILE" ]]; then
    for url in "${URLS[@]}"; do
        echo "Downloading $url"
        if curl -fL --retry 3 "$url" -o "$LOCAL_FILE.part"; then
            mv "$LOCAL_FILE.part" "$LOCAL_FILE"
            break
        fi
        rm -f "$LOCAL_FILE.part"
    done
fi

if [[ ! -s "$LOCAL_FILE" ]]; then
    echo "ERROR: Could not download $FILE_NAME"
    exit 1
fi

header=$(head -n 1 "$LOCAL_FILE" | tr -d '\r')
if [[ "$header" != "Date,Country,Confirmed,Recovered,Deaths" ]]; then
    echo "ERROR: Unexpected header: $header"
    rm -f "$LOCAL_FILE"
    exit 1
fi

lines=$(wc -l < "$LOCAL_FILE")
echo "Local file: $lines lines"

if [[ "$lines" -lt 1000 ]]; then
    echo "ERROR: File is too small, download may be incomplete"
    rm -f "$LOCAL_FILE"
    exit 1
fi

chmod 644 "$LOCAL_FILE"
hdfs_cmd -mkdir -p "$HDFS_DIR"
hdfs_cmd -put -f "$LOCAL_FILE" "$HDFS_DIR/$FILE_NAME"
hdfs_cmd -ls "$HDFS_DIR"

echo "=== Dataset loaded to hdfs://team-31-nn:9000${HDFS_DIR}/${FILE_NAME} ==="
