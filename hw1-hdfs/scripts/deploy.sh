#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Stopping any running HDFS ==="
ssh -i "$HOME/.ssh/team_internal" -o BatchMode=yes team@team-31-nn \
  "sudo -H -u hadoop bash -c 'export JAVA_HOME=/home/hadoop/java; export HADOOP_HOME=/home/hadoop/hadoop; \$HADOOP_HOME/sbin/stop-dfs.sh' || true" 2>/dev/null || true
for h in team-31-nn team-31-00 team-31-01; do
  ssh -i "$HOME/.ssh/team_internal" -o BatchMode=yes team@$h \
    "sudo pkill -f 'org.apache.hadoop' || true" 2>/dev/null || true
done
sleep 3


echo "=== Deploying HDFS cluster ==="
bash "$SCRIPT_DIR/01-prepare-nodes.sh"
bash "$SCRIPT_DIR/02-setup-ssh.sh"
bash "$SCRIPT_DIR/03-configure-hdfs.sh"

echo "=== Cleaning old HDFS data (if any) ==="
for h in team-31-nn team-31-00 team-31-01; do
  ssh -i "$HOME/.ssh/team_internal" -o BatchMode=yes team@$h \
    "sudo find /data/hdfs -mindepth 1 -delete" || true
done

echo "=== Recreating HDFS directories ==="
ssh -i "$HOME/.ssh/team_internal" -o BatchMode=yes team@team-31-nn \
  "sudo mkdir -p /data/hdfs/namenode /data/hdfs/namesecondary /data/hdfs/datanode && \
   sudo chown hadoop:hadoop /data/hdfs/namenode /data/hdfs/namesecondary /data/hdfs/datanode"
for h in team-31-00 team-31-01; do
  ssh -i "$HOME/.ssh/team_internal" -o BatchMode=yes team@$h \
    "sudo mkdir -p /data/hdfs/datanode && sudo chown hadoop:hadoop /data/hdfs/datanode"
done

echo "=== Formatting NameNode ==="
echo "FORMAT" | bash "$SCRIPT_DIR/04-format-namenode.sh"

bash "$SCRIPT_DIR/05-start-hdfs.sh"
bash "$SCRIPT_DIR/06-check-hdfs.sh"
echo "=== Deployment complete ==="
