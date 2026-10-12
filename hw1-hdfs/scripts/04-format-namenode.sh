#!/usr/bin/env bash
set -euo pipefail

SSH_KEY="$HOME/.ssh/team_internal"
NN_HOST="team-31-nn"
NN_DIR="/data/hdfs/namenode"
HADOOP_HOME="/home/hadoop/hadoop"

echo "Checking NameNode on $NN_HOST..."

#проверяем, что директория существует и пуста
ssh -n -i "$SSH_KEY" -o BatchMode=yes "team@$NN_HOST" \
  "sudo test -d '$NN_DIR' &&
   sudo test -z \"\$(sudo ls -A '$NN_DIR')\""

#проверяем, что NameNode не запущен
ssh -n -i "$SSH_KEY" -o BatchMode=yes "team@$NN_HOST" \
  "if sudo -u hadoop /home/hadoop/java/bin/jps -l | grep -q 'org.apache.hadoop.hdfs.server.namenode.NameNode'; then
     echo 'ERROR: NameNode is running'
     exit 1
   fi"

echo "NameNode directory is empty and NameNode is not running."
echo "WARNING: Formatting initializes a new HDFS filesystem."
read -r -p "Type FORMAT to continue: " confirmation

if [[ "$confirmation" != "FORMAT" ]]; then
  echo "Cancelled."
  exit 1
fi

#форматируем NameNode
ssh -n -i "$SSH_KEY" -o BatchMode=yes "team@$NN_HOST" \
  "sudo -H -u hadoop bash -c \
   'export JAVA_HOME=/home/hadoop/java;
    export HADOOP_HOME=$HADOOP_HOME;
    $HADOOP_HOME/bin/hdfs namenode -format -nonInteractive'"

echo "NameNode formatting command completed."
