#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="hive-server2"
SERVICE_FILE="$(cd "$(dirname "$0")/../config" && pwd)/hive-server2.service"
PORT=10000
WAIT_SECONDS=240

echo "=== Starting HiveServer2 ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

if ! sudo -u hadoop test -r /home/hadoop/hive-server2-conf/hive-site.xml; then
    echo "ERROR: Run 07-configure-hiveserver2.sh first"
    exit 1
fi

sudo install -o root -g root -m 644 "$SERVICE_FILE" "/etc/systemd/system/${SERVICE_NAME}.service"
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"

if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "HiveServer2 is already running, restarting to apply config"
    sudo systemctl restart "$SERVICE_NAME"
else
    if sudo ss -ltnH "( sport = :$PORT )" | grep -q LISTEN; then
        echo "ERROR: Port $PORT is already occupied"
        exit 1
    fi
    sudo systemctl start "$SERVICE_NAME"
fi

echo "Waiting for port $PORT..."
for ((i = 0; i < WAIT_SECONDS; i += 5)); do
    if sudo ss -ltnH "( sport = :$PORT )" | grep -q LISTEN; then
        echo "HiveServer2 is listening on port $PORT"
        echo "=== HiveServer2 started ==="
        exit 0
    fi
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "ERROR: HiveServer2 stopped"
        sudo journalctl -u "$SERVICE_NAME" -n 40 --no-pager
        exit 1
    fi
    sleep 5
done

echo "ERROR: HiveServer2 did not open port $PORT in $WAIT_SECONDS seconds"
sudo journalctl -u "$SERVICE_NAME" -n 40 --no-pager
exit 1
