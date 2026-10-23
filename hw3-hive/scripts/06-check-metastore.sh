#!/usr/bin/env bash
set -euo pipefail


DB_NAME="hive_metastore"
SERVICE_NAME="hive-metastore"

echo "=== Checking Hive Metastore ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

echo "=== 1. PostgreSQL ==="

if ! systemctl is-active --quiet postgresql; then
    echo "FAIL: PostgreSQL is not running"
    exit 1
fi

echo "OK: PostgreSQL is running"

echo "=== 2. Hive Metastore database ==="

table_count=$(sudo -u postgres psql -d "$DB_NAME" -Atqc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';")

if [[ "$table_count" -eq 0 ]]; then
    echo "FAIL: Metastore schema is empty"
    exit 1
fi

echo "OK: Metastore contains $table_count tables"

echo "=== 3. Schema version ==="

schema_version=$(sudo -u postgres psql -d "$DB_NAME" -Atqc 'SELECT "SCHEMA_VERSION" FROM "VERSION" LIMIT 1;')

if [[ "$schema_version" != "4.0.0-alpha-2" ]]; then
    echo "FAIL: Unexpected schema version: $schema_version"
    exit 1
fi

echo "OK: Schema version $schema_version"

echo "=== 4. systemd service ==="

if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "FAIL: Hive Metastore is not running"
    exit 1
fi

echo "OK: Hive Metastore is running"

if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then
    echo "FAIL: Metastore autostart is disabled"
    exit 1
fi

echo "OK: Autostart enabled"

echo "=== 5. Metastore port ==="

if ! sudo ss -ltnH '( sport = :9083 )' | grep -q LISTEN; then
    echo "FAIL: Metastore port 9083 is not listening"
    exit 1
fi

echo "OK: Port 9083 is listening"
echo "=== Hive Metastore checks passed ==="
