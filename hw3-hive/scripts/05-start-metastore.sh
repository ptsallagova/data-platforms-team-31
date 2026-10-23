#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="hive-metastore"
SERVICE_FILE="${1:-/tmp/hive-metastore.service}"
CONF_FILE="/home/hadoop/hive-metastore-conf/hive-site.xml"

echo "=== Setting up Hive Metastore service ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "ERROR: Service file not found: $SERVICE_FILE"
    exit 1
fi

if ! sudo -u hadoop test -r "$CONF_FILE"; then
    echo "ERROR: Metastore configuration not found"
    exit 1
fi

# Проверяем PostgreSQL
if ! systemctl is-active --quiet postgresql; then
    echo "ERROR: PostgreSQL is not running"
    exit 1
fi

# Устанавливаем systemd unit
sudo install -o root -g root -m 644 \
    "$SERVICE_FILE" "/etc/systemd/system/${SERVICE_NAME}.service"

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"

# Если systemd уже управляет Metastore, не перезапускаем его
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Metastore is already running via systemd"
else
    # Не завершаем чужие процессы автоматически
    if sudo ss -ltnH | awk '{print $4}' | grep -Eq '(^|:)9083$'; then
        echo "ERROR: Port 9083 is already occupied"
        echo "Stop the existing Metastore process safely first"
        exit 1
    fi

    echo "Starting Hive Metastore..."
    sudo systemctl start "$SERVICE_NAME"
fi

echo "=== Checking service ==="
sudo systemctl is-active "$SERVICE_NAME"

echo "=== Hive Metastore service configured ==="
