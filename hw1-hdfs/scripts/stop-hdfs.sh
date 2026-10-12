#!/usr/bin/env bash
set -euo pipefail
SSH_KEY="$HOME/.ssh/team_internal"
NN_HOST="team-31-nn"
REMOTE_USER="team"
HADOOP_USER="hadoop"
HADOOP_HOME="/home/hadoop/hadoop"
JAVA_HOME="/home/hadoop/java"

echo "=== Stopping HDFS cluster ==="
ssh -i "$SSH_KEY" -o BatchMode=yes "${REMOTE_USER}@${NN_HOST}" \
  "sudo -H -u ${HADOOP_USER} bash -c 'export JAVA_HOME=${JAVA_HOME}; export HADOOP_HOME=${HADOOP_HOME}; ${HADOOP_HOME}/sbin/stop-dfs.sh'"
echo "=== HDFS stopped ==="
