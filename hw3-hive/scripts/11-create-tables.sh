#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/hive-common.sh"

echo "=== Creating Hive tables ==="

check_host
require_hiveserver2

if ! hdfs_cmd -test -d "$HDFS_RAW_DIR"; then
    echo "ERROR: $HDFS_RAW_DIR not found (run 10-prepare-dataset.sh)"
    exit 1
fi

beeline_file 11-create-tables.sql

if [[ "$(beeline_value "SHOW TABLES IN ${DB_NAME} LIKE '${TABLE_NAME}'")" != "$TABLE_NAME" ]]; then
    echo "FAIL: Table ${DB_NAME}.${TABLE_NAME} was not created"
    exit 1
fi

partition_cols="$(beeline_value "DESCRIBE FORMATTED ${DB_NAME}.${TABLE_NAME}" | grep -c '^sale_\(year\|month\)' || true)"
if [[ "$partition_cols" -lt 2 ]]; then
    echo "FAIL: Partition columns not found"
    exit 1
fi

echo "OK: ${DB_NAME}.${TABLE_NAME}_raw (staging) and ${DB_NAME}.${TABLE_NAME} (PARTITIONED BY sale_year, sale_month)"
echo "=== Tables created ==="
