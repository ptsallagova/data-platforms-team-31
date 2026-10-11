#!/usr/bin/env bash
# check YARN daemons, registered NodeManagers and run test MapReduce job
# run on edge as team

set -euo pipefail

NODES=(
  "team-31-nn"
  "team-31-00"
  "team-31-01"
)

NN_HOST="team-31-nn"
SSH_KEY="$HOME/.ssh/team_internal"
REMOTE_USER="team"

SSH_OPTIONS=(
  -i "$SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
)

failed=0

check_process() {
  local host="$1"
  local name="$2"
  local procs
  procs=$(ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" "sudo -iu hadoop jps" || true)
  if grep -qw "$name" <<< "$procs"; then
    echo "OK   ${host}: ${name}"
  else
    echo "FAIL ${host}: ${name} is not running"
    failed=1
  fi
}

echo "=== Daemons ==="
check_process "$NN_HOST" ResourceManager
check_process "$NN_HOST" JobHistoryServer
for host in "${NODES[@]}"; do
  check_process "$host" NodeManager
done

echo "=== NodeManagers registered in ResourceManager ==="
nodes_list=$(ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${NN_HOST}" "sudo -iu hadoop yarn node -list 2>/dev/null" || true)
echo "$nodes_list"

running=$(grep -c RUNNING <<< "$nodes_list" || true)
if [[ "$running" -ne ${#NODES[@]} ]]; then
  echo "FAIL: expected ${#NODES[@]} running NodeManagers, got ${running}"
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then
  echo "YARN check failed, see logs in /home/hadoop/hadoop/logs on the nodes"
  exit 1
fi

echo "=== Test job: pi ==="
job_rc=0
job_output=$(ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${NN_HOST}" \
  'sudo -iu hadoop bash -c "yarn jar \$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar pi 3 100"' 2>&1) || job_rc=$?

if [[ "$job_rc" -ne 0 ]]; then
  echo "$job_output" | tail -n 30
  echo "FAIL: test job exited with code ${job_rc}"
  exit 1
fi

grep -E "Job job_.* completed successfully|Estimated value of Pi" <<< "$job_output"

echo "YARN is OK"
