#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="hive-server2"
PORT=10000
JDBC_URL="jdbc:hive2://team-31-nn:${PORT}/default"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

echo "=== Checking HiveServer2 ==="

if [[ "$(hostname -s)" != "team-31-nn" ]]; then
    echo "ERROR: Run on team-31-nn"
    exit 1
fi

sudo -n true

beeline() {
    local user="$1"
    shift
    (
        cd /tmp
        sudo -H -u hadoop env \
            JAVA_HOME=/home/hadoop/java \
            HADOOP_HOME=/home/hadoop/hadoop \
            /home/hadoop/hive/bin/beeline -u "$JDBC_URL" -n "$user" \
            --silent=true --showHeader=false --outputformat=tsv2 "$@" 2>/dev/null
    )
}

echo "=== 1. Service ==="

if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "FAIL: HiveServer2 is not running"
    exit 1
fi
echo "OK: HiveServer2 is running"

if ! sudo ss -ltnH "( sport = :$PORT )" | grep -q LISTEN; then
    echo "FAIL: Port $PORT is not listening"
    exit 1
fi
echo "OK: Port $PORT is listening"

code=$(curl -s -o /dev/null -w "%{http_code}" "http://team-31-nn:10002/" || true)
if [[ "$code" == "200" ]]; then
    echo "OK: Web UI http://team-31-nn:10002 responds"
else
    echo "WARN: Web UI returned $code"
fi

echo "=== 2. Connection through Beeline ==="

if ! beeline check -e "SHOW DATABASES;"; then
    echo "FAIL: Beeline cannot connect to $JDBC_URL"
    exit 1
fi
echo "OK: Beeline connected"

echo "=== 3. Two clients at the same time ==="

pids=()
for client in client1 client2; do
    beeline "$client" -e "
        SELECT '$client started', current_user(), current_timestamp();
        SELECT reflect('java.lang.Thread', 'sleep', cast(10000 AS bigint));
        SELECT '$client finished', current_timestamp();
    " > "$LOG_DIR/$client.log" &
    pids+=($!)
done

sessions=0
for ((i = 0; i < 15; i++)); do
    current=$(sudo ss -tnH state established "( sport = :$PORT )" | wc -l)
    if [[ "$current" -gt "$sessions" ]]; then
        sessions=$current
    fi
    sleep 1
done
echo "Max simultaneous connections to HiveServer2: $sessions"

failed=0
for i in 0 1; do
    if ! wait "${pids[$i]}"; then
        failed=1
    fi
done

cat "$LOG_DIR/client1.log" "$LOG_DIR/client2.log" | grep -vix 'null' || true

if [[ "$failed" -ne 0 ]]; then
    echo "FAIL: One of the clients finished with error"
    exit 1
fi

if [[ "$sessions" -lt 2 ]]; then
    echo "FAIL: Expected at least 2 simultaneous connections, got $sessions"
    exit 1
fi
echo "OK: Two clients worked with HiveServer2 at the same time"

echo "=== 4. Shared metastore ==="

beeline client1 -e "CREATE DATABASE IF NOT EXISTS hs2_check;" >/dev/null

if beeline client2 -e "SHOW DATABASES LIKE 'hs2_check';" | grep -qx hs2_check; then
    echo "OK: Database created by client1 is visible to client2"
else
    echo "FAIL: client2 does not see database created by client1"
    exit 1
fi

beeline client1 -e "DROP DATABASE IF EXISTS hs2_check;" >/dev/null

echo "=== HiveServer2 checks passed ==="
