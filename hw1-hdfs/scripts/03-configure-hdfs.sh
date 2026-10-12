#!/usr/bin/env bash
set -euo pipefail

#узлы HDFS
NODES=(
  "team-31-nn"
  "team-31-00"
  "team-31-01"
)

NN_HOST="team-31-nn"
SSH_KEY="$HOME/.ssh/team_internal"
REMOTE_USER="team"

HADOOP_HOME="/home/hadoop/hadoop"
JAVA_HOME="/home/hadoop/java"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"

SSH_OPTIONS=(
  -i "$SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
)

#проверка конфигурационных файлов
for file in core-site.xml hdfs-site.xml workers; do
  if [[ ! -f "$CONFIG_DIR/$file" ]]; then
    echo "ERROR: missing $CONFIG_DIR/$file"
    exit 1
  fi
done

#настройка каждого узла
for host in "${NODES[@]}"; do
  echo "=== Configuring $host ==="

#создание директорий HDFS
  ssh "${SSH_OPTIONS[@]}" "$REMOTE_USER@$host" \
    "sudo mkdir -p /data/hdfs/datanode &&
     sudo chown hadoop:hadoop /data/hdfs/datanode"

#директории NameNode и Secondary NameNode
  if [[ "$host" == "$NN_HOST" ]]; then
    ssh "${SSH_OPTIONS[@]}" "$REMOTE_USER@$host" \
      "sudo mkdir -p /data/hdfs/namenode /data/hdfs/namesecondary &&
       sudo chown hadoop:hadoop /data/hdfs/namenode /data/hdfs/namesecondary"
  fi

#копирование конфигураций во временную папку
  for file in core-site.xml hdfs-site.xml workers; do
    scp "${SSH_OPTIONS[@]}" "$CONFIG_DIR/$file" \
      "$REMOTE_USER@$host:/tmp/hdfs-$file"

    ssh "${SSH_OPTIONS[@]}" "$REMOTE_USER@$host" \
      "sudo install -o hadoop -g hadoop -m 644 \
       /tmp/hdfs-$file $HADOOP_HOME/etc/hadoop/$file &&
       rm /tmp/hdfs-$file"
  done
#настройка JAVA_HOME
  ssh "${SSH_OPTIONS[@]}" "$REMOTE_USER@$host" \
    "sudo sed -i '/^[[:space:]]*export JAVA_HOME=/d' \
     $HADOOP_HOME/etc/hadoop/hadoop-env.sh &&
     echo 'export JAVA_HOME=$JAVA_HOME' |
     sudo tee -a $HADOOP_HOME/etc/hadoop/hadoop-env.sh >/dev/null"
  echo "$host configured successfully"
done

echo "All HDFS nodes configured successfully."
