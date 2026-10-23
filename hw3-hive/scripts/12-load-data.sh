#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/hive-common.sh"

echo "=== Loading data into partitioned table ==="

check_host
require_hiveserver2

raw_count="$(beeline_value "SELECT count(*) FROM ${DB_NAME}.${TABLE_NAME}_raw WHERE order_date IS NOT NULL")"

if ! [[ "$raw_count" =~ ^[0-9]+$ ]] || [[ "$raw_count" -eq 0 ]]; then
    echo "ERROR: Staging table is empty or missing (run 10 and 11 first)"
    exit 1
fi
echo "Rows in staging: $raw_count"

echo "Running INSERT OVERWRITE ... PARTITION (sale_year, sale_month)"
echo "The query runs as MapReduce on YARN, it takes 1-3 minutes"
start=$(date +%s)

beeline_file 12-load-partitioned.sql

echo "Load finished in $(( $(date +%s) - start )) s"

table_count="$(beeline_value "SELECT count(*) FROM ${DB_NAME}.${TABLE_NAME}")"
echo "Rows in ${DB_NAME}.${TABLE_NAME}: $table_count"

if [[ "$table_count" != "$raw_count" ]]; then
    echo "FAIL: Row count mismatch: staging=$raw_count, table=$table_count"
    exit 1
fi

echo "OK: Row counts match"
echo "=== Data loaded ==="
