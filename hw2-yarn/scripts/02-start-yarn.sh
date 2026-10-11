#!/usr/bin/env bash
# start ResourceManager, NodeManagers and JobHistory Server
# run on edge as team, HDFS must be already running

set -euo pipefail

NN_HOST="team-31-nn"
SSH_KEY="$HOME/.ssh/team_internal"
REMOTE_USER="team"

SSH_OPTIONS=(
  -i "$SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
)

on_nn() {
  ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${NN_HOST}" "sudo -iu hadoop $*"
}

safemode=$(on_nn "hdfs dfsadmin -safemode get" 2>/dev/null || true)
if ! grep -q "Safe mode is OFF" <<< "$safemode"; then
  echo "ERROR: HDFS is not running or is in safe mode, start it first (HW1)"
  exit 1
fi

echo "=== Starting YARN ==="
if ! on_nn "start-yarn.sh"; then
  echo "WARNING: start-yarn.sh returned an error (maybe YARN is already running)"
fi

echo "=== Starting JobHistory Server ==="
if ! on_nn "mapred --daemon start historyserver"; then
  echo "WARNING: historyserver did not start (maybe it is already running)"
fi

sleep 10
bash "$(dirname "$0")/03-check-yarn.sh"
