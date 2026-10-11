#!/usr/bin/env bash
# copy yarn-site.xml and mapred-site.xml to all nodes
# run on edge as team

set -euo pipefail

NODES=(
  "team-31-nn"
  "team-31-00"
  "team-31-01"
)

SSH_KEY="$HOME/.ssh/team_internal"
REMOTE_USER="team"
HADOOP_CONF="/home/hadoop/hadoop/etc/hadoop"
CONFIG_DIR="$(cd "$(dirname "$0")/../config" && pwd)"

SSH_OPTIONS=(
  -i "$SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
)

for host in "${NODES[@]}"; do
  echo "=== Copying configs to ${host} ==="

  scp "${SSH_OPTIONS[@]}" \
    "$CONFIG_DIR/yarn-site.xml" "$CONFIG_DIR/mapred-site.xml" \
    "${REMOTE_USER}@${host}:/tmp/"

  ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" "
    sudo install -o hadoop -g hadoop -m 644 /tmp/yarn-site.xml /tmp/mapred-site.xml ${HADOOP_CONF}/
    rm -f /tmp/yarn-site.xml /tmp/mapred-site.xml
  "

  if ! ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" \
    "grep -q '^ *export JAVA_HOME=' ${HADOOP_CONF}/hadoop-env.sh"; then
    echo "WARNING: JAVA_HOME is not set in hadoop-env.sh on ${host} (HW1 step 3)"
  fi
done

echo "=== Checking workers file on team-31-nn ==="

workers=$(ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@team-31-nn" "cat ${HADOOP_CONF}/workers")
echo "$workers"

for host in "${NODES[@]}"; do
  if ! grep -qx "$host" <<< "$workers"; then
    echo "WARNING: ${host} is not in workers, NodeManager will not start there"
  fi
done

echo "Done"
