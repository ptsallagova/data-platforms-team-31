#!/usr/bin/env bash
# Полное развертывание HW3: Hive -> PostgreSQL + Metastore -> HiveServer2 -> таблица и загрузка.
# Запуск на team-31-nn от пользователя team: bash scripts/deploy.sh
# Скрипты 02 и 03 один раз спросят пароль для пользователя hive в PostgreSQL.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

echo "##### 1. Hive installation #####"
# 01 работает в /home/hadoop, поэтому запускается от hadoop.
# Домашний каталог team недоступен hadoop — копируем скрипт во /tmp.
tmp="$(mktemp -d)"
chmod 755 "$tmp"
install -m 755 "$DIR/01-install-hive.sh" "$tmp/"
sudo -iu hadoop bash "$tmp/01-install-hive.sh"
rm -rf "$tmp"

echo "##### 2. PostgreSQL + Metastore #####"
bash "$DIR/02-setup-postgres.sh"
bash "$DIR/03-configure-metastore.sh"
bash "$DIR/04-init-metastore.sh"
bash "$DIR/05-start-metastore.sh"
bash "$DIR/06-check-metastore.sh"

echo "##### 3. HiveServer2 #####"
bash "$DIR/07-configure-hiveserver2.sh"
bash "$DIR/08-start-hiveserver2.sh"
bash "$DIR/09-check-hiveserver2.sh"

echo "##### 4. Partitioned table #####"
bash "$DIR/10-prepare-dataset.sh"
bash "$DIR/11-create-tables.sh"
bash "$DIR/12-load-data.sh"
bash "$DIR/13-check-partitions.sh"

echo "##### HW3 deployed #####"
