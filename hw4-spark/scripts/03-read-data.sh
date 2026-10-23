#!/usr/bin/env bash
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/read_data.py"
WORK_DIR="/home/hadoop/hw4"
LOG_FILE="/tmp/hw4-read-data.log"

echo "=== Reading dataset with Spark on YARN ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

sudo install -d -o hadoop -g hadoop -m 755 "$WORK_DIR"
sudo install -o hadoop -g hadoop -m 644 "$SCRIPT" "$WORK_DIR/read_data.py"

status=0
output=$(
    cd /tmp
    sudo -H -u hadoop bash -c "source /home/hadoop/spark-env.sh && spark-submit --master yarn --deploy-mode client $WORK_DIR/read_data.py" 2> "$LOG_FILE"
) || status=$?

echo "$output"

if [[ "$status" -ne 0 ]] || ! grep -q "^Rows: [1-9]" <<< "$output"; then
    tail -n 40 "$LOG_FILE"
    echo "ERROR: Spark job failed, full log: $LOG_FILE"
    exit 1
fi

echo "=== Dataset read successfully ==="
