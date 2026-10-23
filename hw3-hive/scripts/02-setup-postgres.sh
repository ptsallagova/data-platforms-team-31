#!/usr/bin/env bash
set -euo pipefail

DB_USER="hive"
DB_NAME="hive_metastore"

echo "=== Setting up PostgreSQL ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run this script on team-31-nn"
    exit 1
fi

if ! sudo -n true; then
    echo "ERROR: sudo access is required"
    exit 1
fi

# Установка PostgreSQL, если он отсутствует
if ! dpkg-query -W -f='${Status}' postgresql 2>/dev/null | grep -qx "install ok installed" ||
   ! dpkg-query -W -f='${Status}' postgresql-client 2>/dev/null | grep -qx "install ok installed"; then
    echo "Installing PostgreSQL..."
    sudo apt-get update
    sudo apt-get install -y postgresql postgresql-client
else
    echo "PostgreSQL already installed"
fi

# Запускаем PostgreSQL
sudo systemctl enable --now postgresql

# Проверяем доступность базы
sudo -u postgres psql -Atqc "SELECT 1" | grep -qx 1

if sudo -u postgres psql -Atqc \
    "SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}'" | grep -qx 1; then
    echo "Role ${DB_USER} already exists"
else
    echo "Creating role ${DB_USER}..."
    sudo -u postgres createuser --login --pwprompt "$DB_USER"
fi

# Создаём базу только при  отсутствии
if sudo -u postgres psql -Atqc \
    "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -qx 1; then
    echo "Database ${DB_NAME} already exists"
else
    echo "Creating database ${DB_NAME}..."
    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
fi


# Проверяем владельца базы
owner=$(sudo -u postgres psql -Atqc \
    "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = '${DB_NAME}'")

if [[ "$owner" != "$DB_USER" ]]; then
    echo "ERROR: Unexpected database owner: $owner"
    exit 1
fi


echo "=== PostgreSQL setup completed ==="
sudo pg_lsclusters
echo "Database: ${DB_NAME}"
echo "Owner: ${DB_USER}"
