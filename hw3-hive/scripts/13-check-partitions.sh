#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/hive-common.sh"

echo "=== Checking partitioned table ==="

check_host
require_hiveserver2

echo "=== 1. SHOW PARTITIONS and SQL queries ==="
beeline_file 13-check-partitions.sql

echo "=== 2. Partition directories in HDFS ==="
hdfs_cmd -ls "$TABLE_DIR/sale_year=2025" | grep -o 'sale_year=.*' || true

echo "=== 3. Consistency checks ==="

parts_hive="$(beeline_value "SHOW PARTITIONS ${DB_NAME}.${TABLE_NAME}" | wc -l)"
parts_hdfs="$(hdfs_cmd -ls -R "$TABLE_DIR" | grep -c '/sale_month=[0-9]*$' || true)"
parts_expected="$(beeline_value "SELECT count(DISTINCT year(order_date) * 100 + month(order_date)) FROM ${DB_NAME}.${TABLE_NAME}_raw WHERE order_date IS NOT NULL")"
mismatch="$(beeline_value "SELECT count(*) FROM ${DB_NAME}.${TABLE_NAME} WHERE year(order_date) <> sale_year OR month(order_date) <> sale_month")"

echo "Partitions in Metastore:   $parts_hive"
echo "Partition dirs in HDFS:    $parts_hdfs"
echo "Expected from raw data:    $parts_expected"
echo "Rows in wrong partition:   $mismatch"

if [[ "$parts_hive" -eq 0 ]]; then
    echo "FAIL: Table has no partitions"
    exit 1
fi

if [[ "$parts_hive" != "$parts_expected" ]]; then
    echo "FAIL: Metastore has $parts_hive partitions, expected $parts_expected"
    exit 1
fi

if [[ "$parts_hive" != "$parts_hdfs" ]]; then
    echo "FAIL: Metastore has $parts_hive partitions, HDFS has $parts_hdfs directories"
    exit 1
fi

if [[ "$mismatch" != "0" ]]; then
    echo "FAIL: Some rows are stored in a wrong partition"
    exit 1
fi

echo "OK: $parts_hive partitions, Metastore and HDFS are consistent"
echo "=== Partitioned table checks passed ==="
