#!/usr/bin/env bash
set -euo pipefail

CONF_DIR="/home/hadoop/hive-server2-conf"
SRC_CONF="$(cd "$(dirname "$0")/../config/hiveserver2" && pwd)/hive-site.xml"
HADOOP_HOME="/home/hadoop/hadoop"
JAVA_HOME="/home/hadoop/java"

echo "=== Configuring HiveServer2 ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

if ! sudo -u hadoop test -x /home/hadoop/hive/bin/hive; then
    echo "ERROR: Hive is not installed"
    exit 1
fi

if ! systemctl is-active --quiet hive-metastore; then
    echo "ERROR: Hive Metastore is not running"
    exit 1
fi

hdfs_cmd() {
    (
        cd /tmp
        sudo -H -u hadoop env JAVA_HOME="$JAVA_HOME" "$HADOOP_HOME/bin/hdfs" dfs "$@"
    )
}

sudo install -d -o hadoop -g hadoop -m 755 "$CONF_DIR"
sudo install -o hadoop -g hadoop -m 644 "$SRC_CONF" "$CONF_DIR/hive-site.xml"
echo "hive-site.xml copied to $CONF_DIR"

if ! hdfs_cmd -test -d /; then
    echo "ERROR: HDFS is not available"
    exit 1
fi

hdfs_cmd -mkdir -p /user/hive/warehouse /tmp/hive
hdfs_cmd -chmod 775 /user/hive/warehouse
hdfs_cmd -chmod 1777 /tmp/hive
hdfs_cmd -ls -d /user/hive/warehouse /tmp/hive

echo "=== HiveServer2 configuration completed ==="
