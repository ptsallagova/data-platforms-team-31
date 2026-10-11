#!/usr/bin/env bash
# check that every published web UI responds through nginx
# run on edge as team

set -euo pipefail

EXTERNAL_IP="${EXTERNAL_IP:-2.59.82.188}"
UI_USER="${UI_USER:-admin}"

if [[ -z "${UI_PASSWORD:-}" ]]; then
  read -r -s -p "Password for ${UI_USER}: " UI_PASSWORD
  echo
fi

PAGES=(
  "9870  NameNode"
  "9868  Secondary NameNode"
  "8088  ResourceManager"
  "19888 JobHistory Server"
  "9864  DataNode team-31-nn"
  "9865  DataNode team-31-00"
  "9866  DataNode team-31-01"
  "8042  NodeManager team-31-nn"
  "8043  NodeManager team-31-00"
  "8044  NodeManager team-31-01"
)

failed=0

for page in "${PAGES[@]}"; do
  read -r port name <<< "$page"
  code=$(curl -s -L -o /dev/null -w "%{http_code}" -u "${UI_USER}:${UI_PASSWORD}" "http://localhost:${port}/" || true)
  no_auth=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/" || true)

  if [[ "$code" == "200" && "$no_auth" == "401" ]]; then
    echo "OK   http://${EXTERNAL_IP}:${port}  ${name}"
  else
    echo "FAIL http://${EXTERNAL_IP}:${port}  ${name} (with password: ${code}, without: ${no_auth})"
    failed=1
  fi
done

exit $failed
