#!/usr/bin/env bash
# passwordless ssh for hadoop user: key on NN -> authorized_keys on all nodes
# run on edge as team

set -euo pipefail

NODES=(
  "team-31-nn"
  "team-31-00"
  "team-31-01"
)

NN_HOST="team-31-nn"
SSH_KEY="$HOME/.ssh/team_internal"
REMOTE_USER="team"
HADOOP_USER="hadoop"

SSH_OPTIONS=(
  -i "$SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
)

# run script from stdin on host as hadoop
run_as_hadoop() {
  local host="$1"
  shift
  ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" \
    "sudo -H -u ${HADOOP_USER} bash -s -- $*"
}

for host in "${NODES[@]}"; do
  if ! ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" "id ${HADOOP_USER} >/dev/null"; then
    echo "ERROR: no ${HADOOP_USER} user on ${host}, run 01-prepare-nodes.sh first"
    exit 1
  fi
done

echo "=== Generating ssh key for ${HADOOP_USER} on ${NN_HOST} ==="

PUBKEY=$(run_as_hadoop "$NN_HOST" <<'EOF' | tail -n 1
mkdir -p ~/.ssh
chmod 700 ~/.ssh
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519
fi
cat ~/.ssh/id_ed25519.pub
EOF
)

if [[ "$PUBKEY" != ssh-ed25519* ]]; then
  echo "ERROR: could not get public key from ${NN_HOST}"
  exit 1
fi

for host in "${NODES[@]}"; do
  echo "=== Adding key to authorized_keys on ${host} ==="

  run_as_hadoop "$host" "'$PUBKEY'" <<'EOF'
chmod go-w ~
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
grep -qxF "$1" ~/.ssh/authorized_keys || echo "$1" >> ~/.ssh/authorized_keys
EOF
done

echo "=== Filling known_hosts on ${NN_HOST} ==="

run_as_hadoop "$NN_HOST" "${NODES[@]}" <<'EOF'
hosts=(localhost 127.0.0.1 "$@")
for h in "$@"; do
  hosts+=("$(getent hosts "$h" | awk '{print $1; exit}')")
done

touch ~/.ssh/known_hosts
for h in "${hosts[@]}"; do
  [[ -z "$h" ]] && continue
  ssh-keygen -R "$h" -f ~/.ssh/known_hosts >/dev/null 2>&1 || true
  ssh-keyscan -T 5 "$h" >> ~/.ssh/known_hosts 2>/dev/null
  echo "added $h"
done
chmod 600 ~/.ssh/known_hosts
rm -f ~/.ssh/known_hosts.old
EOF

bash "$(dirname "$0")/02-check-ssh.sh"
