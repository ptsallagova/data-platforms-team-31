#!/usr/bin/env bash
set -euo pipefail

SPARK_VERSION="3.5.7"
SPARK_DIR="/home/hadoop/spark-${SPARK_VERSION}-bin-hadoop3"
SPARK_HOME="/home/hadoop/spark"
SPARK_URL="https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz"

JAVA_HOME="/home/hadoop/java"
HADOOP_HOME="/home/hadoop/hadoop"

echo "=== Installing Apache Spark ${SPARK_VERSION} ==="

#проверяем зависимости
test -x "$JAVA_HOME/bin/java" || {
    echo "ERROR: Java not found"
    exit 1
}

test -x "$HADOOP_HOME/bin/hadoop" || {
    echo "ERROR: Hadoop not found"
    exit 1
}

#скачиваем и распаковываем Spark
if [ ! -d "$SPARK_DIR" ]; then
    ARCHIVE="/tmp/spark-${SPARK_VERSION}-bin-hadoop3.tgz"

    curl -fL --retry 3 "$SPARK_URL" -o "$ARCHIVE"
    tar -tzf "$ARCHIVE" >/dev/null
    tar -xzf "$ARCHIVE" -C /home/hadoop
fi

#создаём символическую ссылку
ln -sfnT "$SPARK_DIR" "$SPARK_HOME"

#настраиваем переменные окружения
cat > /home/hadoop/spark-env.sh <<EOF
export JAVA_HOME="$JAVA_HOME"
export HADOOP_HOME="$HADOOP_HOME"
export SPARK_HOME="$SPARK_HOME"
export HADOOP_CONF_DIR="\$HADOOP_HOME/etc/hadoop"
export YARN_CONF_DIR="\$HADOOP_CONF_DIR"
export PATH="\$SPARK_HOME/bin:\$HADOOP_HOME/bin:\$JAVA_HOME/bin:\$PATH"
EOF

#подключаем переменные при входе пользователя hadoop
BASHRC="/home/hadoop/.bashrc"
SOURCE_LINE="source /home/hadoop/spark-env.sh"

touch "$BASHRC"
grep -qxF "$SOURCE_LINE" "$BASHRC" || echo "$SOURCE_LINE" >> "$BASHRC"

#проверяем установку
export JAVA_HOME HADOOP_HOME SPARK_HOME
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export YARN_CONF_DIR="$HADOOP_CONF_DIR"
export PATH="$SPARK_HOME/bin:$HADOOP_HOME/bin:$JAVA_HOME/bin:$PATH"

"$SPARK_HOME/bin/spark-submit" --version

echo "=== Spark installation completed ==="
