#!/usr/bin/env bash
# publish web UIs of cluster daemons through nginx on edge node
# run on edge as team

set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")/../config/nginx" && pwd)"
UI_USER="${UI_USER:-admin}"
HTPASSWD="/etc/nginx/hadoop.htpasswd"
PORTS=(9870 9868 8088 19888 9864 9865 9866 8042 8043 8044)

echo "=== Installing nginx ==="
if ! command -v nginx >/dev/null; then
  sudo apt-get update -q
  sudo apt-get install -y -q nginx
fi

echo "=== Setting password for web UI ==="
if [[ -f "$HTPASSWD" && -z "${UI_PASSWORD:-}" ]]; then
  echo "Password file already exists, keeping it (set UI_PASSWORD to change)"
else
  if [[ -z "${UI_PASSWORD:-}" ]]; then
    read -r -s -p "New password for user ${UI_USER}: " UI_PASSWORD
    echo
  fi
  hash=$(printf '%s' "$UI_PASSWORD" | openssl passwd -apr1 -stdin)
  echo "${UI_USER}:${hash}" | sudo tee "$HTPASSWD" >/dev/null
  sudo chown root:www-data "$HTPASSWD"
  sudo chmod 640 "$HTPASSWD"
fi

echo "=== Copying nginx config ==="
sudo install -m 644 "$CONFIG_DIR/hadoop-proxy.conf" /etc/nginx/snippets/hadoop-proxy.conf
sudo install -m 644 "$CONFIG_DIR/hadoop-ui.conf" /etc/nginx/sites-available/hadoop-ui.conf
sudo ln -sfn /etc/nginx/sites-available/hadoop-ui.conf /etc/nginx/sites-enabled/hadoop-ui.conf

sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx

if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
  echo "=== Opening ports in ufw ==="
  for port in "${PORTS[@]}"; do
    sudo ufw allow "${port}/tcp"
  done
fi

if [[ -n "${UI_PASSWORD:-}" ]]; then
  UI_USER="$UI_USER" UI_PASSWORD="$UI_PASSWORD" bash "$(dirname "$0")/05-check-ui.sh"
else
  echo "Run 05-check-ui.sh to check that all pages respond"
fi
