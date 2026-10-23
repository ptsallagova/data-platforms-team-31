#!/usr/bin/env bash
set -euo pipefail

CONF_DIR="/home/hadoop/hive-metastore-conf"
CONF_FILE="$CONF_DIR/hive-site.xml"

echo "=== Configuring Hive Metastore ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

if ! sudo -u hadoop test -x /home/hadoop/hive/bin/hive; then
    echo "ERROR: Hive is not installed"
    exit 1
fi

sudo install -d -o hadoop -g hadoop -m 700 "$CONF_DIR"

# Не перезаписываем существующую конфигурацию
if sudo test -f "$CONF_FILE"; then
    echo "Existing configuration found"
else
    echo "Creating hive-site.xml..."

    sudo -u hadoop python3 - <<'PY'
import os
import getpass
import xml.etree.ElementTree as ET

path = "/home/hadoop/hive-metastore-conf/hive-site.xml"

password = getpass.getpass("PostgreSQL hive password: ")
if not password:
    raise SystemExit("ERROR: Empty password")

properties = {
    "javax.jdo.option.ConnectionURL":
        "jdbc:postgresql://127.0.0.1:5432/hive_metastore",
    "javax.jdo.option.ConnectionDriverName":
        "org.postgresql.Driver",
    "javax.jdo.option.ConnectionUserName":
        "hive",
    "javax.jdo.option.ConnectionPassword":
        password,
    "hive.metastore.warehouse.dir":
        "/user/hive/warehouse",
    "hive.metastore.schema.verification":
        "true",
}

root = ET.Element("configuration")

for name, value in properties.items():
    prop = ET.SubElement(root, "property")
    ET.SubElement(prop, "name").text = name
    ET.SubElement(prop, "value").text = value

old_umask = os.umask(0o077)
try:
    with open(path, "xb") as f:
        ET.ElementTree(root).write(
            f, encoding="UTF-8", xml_declaration=True
        )
finally:
    os.umask(old_umask)

print("Configuration created")
PY
fi

sudo -u hadoop python3 -c "import xml.etree.ElementTree as ET; ET.parse('$CONF_FILE')"

sudo chown hadoop:hadoop "$CONF_FILE"
sudo chmod 600 "$CONF_FILE"

echo "XML syntax OK"
echo "=== Metastore configuration completed ==="
