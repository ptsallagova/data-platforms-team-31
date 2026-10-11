#!/usr/bin/env bash
# stop JobHistory Server, NodeManagers and ResourceManager
# run on edge as team

set -euo pipefail

NN_HOST="team-31-nn"
SSH_KEY="$HOME/.ssh/team_internal"
REMOTE_USER="team"

ssh -i "$SSH_KEY" -o BatchMode=yes "${REMOTE_USER}@${NN_HOST}" "
  sudo -iu hadoop mapred --daemon stop historyserver
  sudo -iu hadoop stop-yarn.sh
"

echo "YARN stopped"
