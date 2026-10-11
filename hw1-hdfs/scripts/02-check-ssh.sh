#!/usr/bin/env bash
# check that hadoop on NN can ssh to all nodes without password
# run on edge as team

set -euo pipefail

NODES=(
  "team-31-nn"
  "team-31-00"
  "team-31-01"
  "localhost"
)

NN_HOST="team-31-nn"
SSH_KEY="$HOME/.ssh/team_internal"
REMOTE_USER="team"
HADOOP_USER="hadoop"

echo "=== Checking ssh for ${HADOOP_USER} from ${NN_HOST} ==="

ssh -i "$SSH_KEY" -o BatchMode=yes "${REMOTE_USER}@${NN_HOST}" \
  "sudo -H -u ${HADOOP_USER} bash -s -- ${NODES[*]}" <<'EOF'
failed=0
for h in "$@"; do
  # BatchMode: fail instead of asking password
  # StrictHostKeyChecking=yes: fail if host not in known_hosts
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5 "$h" true; then
    echo "OK   $h"
  else
    echo "FAIL $h"
    failed=1
  fi
done
exit $failed
EOF

echo "All nodes OK"
