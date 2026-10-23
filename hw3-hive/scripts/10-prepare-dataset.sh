#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/hive-common.sh"

# Датасет: продажи интернет-магазина за 2024–2025 годы.
# Генерируется детерминированно (seed 42), поэтому результат всегда одинаковый.
# Можно передать свой CSV того же формата: bash scripts/10-prepare-dataset.sh /path/file.csv
ROWS="${ROWS:-50000}"
LOCAL_DIR="/tmp/hw3-data"
LOCAL_FILE="${1:-$LOCAL_DIR/sales_2024_2025.csv}"

echo "=== Preparing dataset in HDFS ==="

check_host

if [[ $# -eq 0 ]]; then
    echo "Generating $ROWS rows -> $LOCAL_FILE"
    mkdir -p "$LOCAL_DIR"
    chmod 755 "$LOCAL_DIR"
    awk -v rows="$ROWS" 'BEGIN {
        srand(42)
        split("electronics,books,clothing,home,sports,toys", cat, ",")
        print "order_id,order_date,customer_id,category,amount"
        for (i = 1; i <= rows; i++) {
            y = 2024 + int(rand() * 2)
            m = 1 + int(rand() * 12)
            d = 1 + int(rand() * 28)
            printf "%d,%04d-%02d-%02d,%d,%s,%.2f\n",
                i, y, m, d, 1 + int(rand() * 5000), cat[1 + int(rand() * 6)], 1 + rand() * 999
        }
    }' > "$LOCAL_FILE"
    chmod 644 "$LOCAL_FILE"
fi

if [[ ! -s "$LOCAL_FILE" ]]; then
    echo "ERROR: File not found: $LOCAL_FILE"
    exit 1
fi

header="$(head -1 "$LOCAL_FILE" | tr -d '\r')"
if [[ "$header" != "order_id,order_date,customer_id,category,amount" ]]; then
    echo "ERROR: Unexpected header: $header"
    exit 1
fi

if ! sudo -u hadoop test -r "$LOCAL_FILE"; then
    echo "ERROR: User hadoop cannot read $LOCAL_FILE (put it into /tmp)"
    exit 1
fi

echo "Rows in file: $(( $(wc -l < "$LOCAL_FILE") - 1 ))"
head -4 "$LOCAL_FILE"

if ! hdfs_cmd -test -d /; then
    echo "ERROR: HDFS is not available"
    exit 1
fi

hdfs_cmd -mkdir -p "$HDFS_RAW_DIR"
hdfs_cmd -put -f "$LOCAL_FILE" "$HDFS_RAW_DIR/"

if ! hdfs_cmd -test -e "$HDFS_RAW_DIR/$(basename "$LOCAL_FILE")"; then
    echo "ERROR: File was not uploaded to HDFS"
    exit 1
fi

hdfs_cmd -ls -h "$HDFS_RAW_DIR"
echo "=== Dataset is in HDFS: $HDFS_RAW_DIR ==="
