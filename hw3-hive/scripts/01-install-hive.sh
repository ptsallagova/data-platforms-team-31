#!/usr/bin/env bash
set -euo pipefail

HIVE_VERSION="4.0.0-alpha-2"
HIVE_HOME="/home/hadoop/hive"
HIVE_DIR="/home/hadoop/apache-hive-${HIVE_VERSION}-bin"
HIVE_URL="https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz"

JAVA_HOME="/home/hadoop/java"
HADOOP_HOME="/home/hadoop/hadoop"

echo "=== Installing Apache Hive ${HIVE_VERSION} ==="

#проверяем зависимости
test -x "$JAVA_HOME/bin/java" || {
    echo "ERROR: Java not found"
    exit 1
}

test -x "$HADOOP_HOME/bin/hadoop" || {
    echo "ERROR: Hadoop not found"
    exit 1
}

#скачиваем и распаковываем Hive
if [ ! -d "$HIVE_DIR" ]; then
    ARCHIVE="/tmp/apache-hive-${HIVE_VERSION}-bin.tar.gz"

    curl -fL --retry 3 "$HIVE_URL" -o "$ARCHIVE"
    tar -tzf "$ARCHIVE" >/dev/null
    tar -xzf "$ARCHIVE" -C /home/hadoop
fi

#создаём ссылку на установленную версию
ln -sfnT "$HIVE_DIR" "$HIVE_HOME"

#настраиваем переменные окружения
cat > /home/hadoop/hive-env.sh <<EOF
export JAVA_HOME="$JAVA_HOME"
export HADOOP_HOME="$HADOOP_HOME"
export HIVE_HOME="$HIVE_HOME"
export PATH="\$HIVE_HOME/bin:\$HADOOP_HOME/bin:\$JAVA_HOME/bin:\$PATH"
EOF

#автоматически загружаем переменные при входе пользователя hadoop
BASHRC="/home/hadoop/.bashrc"
SOURCE_LINE="source /home/hadoop/hive-env.sh"

touch "$BASHRC"
grep -qxF "$SOURCE_LINE" "$BASHRC" || echo "$SOURCE_LINE" >> "$BASHRC"

#проверяем установку
export JAVA_HOME HADOOP_HOME HIVE_HOME
export PATH="$HIVE_HOME/bin:$HADOOP_HOME/bin:$JAVA_HOME/bin:$PATH"

"$HIVE_HOME/bin/hive" --version

echo "=== Hive installation completed ==="
