#!/usr/bin/env bash
set -euo pipefail
NODES=("team-31-nn" "team-31-00" "team-31-01")
SSH_KEY="$HOME/.ssh/team_internal"
REMOTE_USER="team"
HADOOP_USER="hadoop"
HADOOP_HOME="/home/hadoop/hadoop"
JAVA_HOME="/home/hadoop/java"

echo "=== 1. JPS processes on all nodes ==="
for host in "${NODES[@]}"; do
  echo "--- $host ---"
  ssh -i "$SSH_KEY" -o BatchMode=yes "${REMOTE_USER}@${host}" \
    "sudo -H -u ${HADOOP_USER} ${JAVA_HOME}/bin/jps -l" || true
done

echo "=== 2. dfsadmin -report ==="
ssh -i "$SSH_KEY" -o BatchMode=yes "${REMOTE_USER}@team-31-nn" \
  "sudo -H -u ${HADOOP_USER} bash -c 'export JAVA_HOME=${JAVA_HOME}; export HADOOP_HOME=${HADOOP_HOME}; ${HADOOP_HOME}/bin/hdfs dfsadmin -report'"

echo "=== 3. Test write/read ==="
ssh -i "$SSH_KEY" -o BatchMode=yes "${REMOTE_USER}@team-31-nn" \
  "sudo -H -u ${HADOOP_USER} bash -c '
    export JAVA_HOME=${JAVA_HOME};
    export HADOOP_HOME=${HADOOP_HOME};
    ${HADOOP_HOME}/bin/hdfs dfs -mkdir -p /test_dir;
    echo \"Hello HDFS\" > /tmp/test_file.txt;
    ${HADOOP_HOME}/bin/hdfs dfs -put /tmp/test_file.txt /test_dir/;
    ${HADOOP_HOME}/bin/hdfs dfs -cat /test_dir/test_file.txt;
    ${HADOOP_HOME}/bin/hdfs dfs -rm -r /test_dir;
    rm /tmp/test_file.txt
  '"

echo "=== 4. Check NameNode logs for critical errors ==="
ssh -i "$SSH_KEY" -o BatchMode=yes "${REMOTE_USER}@team-31-nn" \
  "sudo -H -u ${HADOOP_USER} bash -c '
    grep -i \"fatal\" ${HADOOP_HOME}/logs/hadoop-hadoop-namenode-*.log || echo \"No FATAL errors found\"
  '"
