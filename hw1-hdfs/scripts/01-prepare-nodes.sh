#!/usr/bin/env bash

set -euo pipefail



NODES=(
  "team-31-nn"
  "team-31-00"
  "team-31-01"
)

SSH_KEY="$HOME/.ssh/team_internal"
REMOTE_USER="team"
HADOOP_USER="hadoop"

HADOOP_VERSION="3.4.0"
HADOOP_ARCHIVE="hadoop-${HADOOP_VERSION}.tar.gz"
HADOOP_URL="https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_ARCHIVE}"
HADOOP_FALLBACK_URL="https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_ARCHIVE}"

HADOOP_SHA512="6f653c0109f97430047bd3677c50da7c8a2809d153b231794cf980b3208a6b4beff8ff1a03a01094299d459a3a37a3fe16731629987165d71f328657dbf2f24c"

JDK_ARCHIVE="OpenJDK11U-jdk_x64_linux_hotspot_11.0.32.1_1.tar.gz"
JDK_DIR="jdk-11.0.32.1+1"
JDK_URL="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.32.1%2B1/${JDK_ARCHIVE}"

ARTIFACT_DIR="$HOME/hdfs-bootstrap/artifacts"

SSH_OPTIONS=(
  -i "$SSH_KEY"
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
)

echo "=== Preparing local artifacts on edge ==="

if [[ ! -f "$SSH_KEY" ]]; then
  echo "ERROR: SSH key not found: $SSH_KEY"
  exit 1
fi

mkdir -p "$ARTIFACT_DIR"
cd "$ARTIFACT_DIR"

if [[ ! -f "$HADOOP_ARCHIVE" ]]; then
  echo "Downloading Hadoop ${HADOOP_VERSION}..."

  wget -c -O "$HADOOP_ARCHIVE" "$HADOOP_URL" || \
  wget -c -O "$HADOOP_ARCHIVE" "$HADOOP_FALLBACK_URL"
fi

echo "Checking Hadoop SHA-512..."

echo "${HADOOP_SHA512}  ${HADOOP_ARCHIVE}" | sha512sum -c -

if [[ ! -f "$JDK_ARCHIVE" ]]; then
  echo "Downloading JDK 11..."

  wget -c -O "$JDK_ARCHIVE" "$JDK_URL"
fi

echo "Checking JDK archive..."

tar -tzf "$JDK_ARCHIVE" >/dev/null

echo "JDK archive OK"


for host in "${NODES[@]}"; do
  echo
  echo "======================================"
  echo "Preparing ${host}"
  echo "======================================"

  ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" \
    "id ${HADOOP_USER} >/dev/null 2>&1 || sudo adduser --disabled-password --gecos '' ${HADOOP_USER}"

  ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" \
    'mkdir -p ~/hdfs-bootstrap/artifacts'

  if ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" \
    "cd ~/hdfs-bootstrap/artifacts 2>/dev/null &&
     test -f '${HADOOP_ARCHIVE}' &&
     echo '${HADOOP_SHA512}  ${HADOOP_ARCHIVE}' | sha512sum -c - >/dev/null 2>&1"
  then
    echo "Hadoop archive already exists on ${host}"
  else
    echo "Copying Hadoop archive to ${host}..."

    scp "${SSH_OPTIONS[@]}" \
      "$HADOOP_ARCHIVE" \
      "${REMOTE_USER}@${host}:/home/team/hdfs-bootstrap/artifacts/"
  fi

  if ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" \
    "test -f ~/hdfs-bootstrap/artifacts/${JDK_ARCHIVE} &&
     tar -tzf ~/hdfs-bootstrap/artifacts/${JDK_ARCHIVE} >/dev/null 2>&1"
  then
    echo "JDK archive already exists on ${host}"
  else
    echo "Copying JDK archive to ${host}..."

    scp "${SSH_OPTIONS[@]}" \
      "$JDK_ARCHIVE" \
      "${REMOTE_USER}@${host}:/home/team/hdfs-bootstrap/artifacts/"
  fi

  ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" 'bash -s' <<'REMOTE_SCRIPT'
set -euo pipefail

JDK_DIR="/home/hadoop/jdk-11.0.32.1+1"
HADOOP_DIR="/home/hadoop/hadoop-3.4.0"

JDK_ARCHIVE="/home/team/hdfs-bootstrap/artifacts/OpenJDK11U-jdk_x64_linux_hotspot_11.0.32.1_1.tar.gz"
HADOOP_ARCHIVE="/home/team/hdfs-bootstrap/artifacts/hadoop-3.4.0.tar.gz"

if ! sudo test -d "$JDK_DIR"; then
  echo "Extracting JDK..."
  sudo tar -xzf "$JDK_ARCHIVE" -C /home/hadoop
fi

if ! sudo test -d "$HADOOP_DIR"; then
  echo "Extracting Hadoop..."
  sudo tar -xzf "$HADOOP_ARCHIVE" -C /home/hadoop
fi


sudo chown -R hadoop:hadoop "$JDK_DIR" "$HADOOP_DIR"


sudo -u hadoop ln -sfnT "$JDK_DIR" /home/hadoop/java
sudo -u hadoop ln -sfnT "$HADOOP_DIR" /home/hadoop/hadoop



if ! sudo grep -q '^# HADOOP_ENV$' /home/hadoop/.profile; then
  sudo tee -a /home/hadoop/.profile >/dev/null <<'EOF'
# HADOOP_ENV
export JAVA_HOME=/home/hadoop/java
export HADOOP_HOME=/home/hadoop/hadoop
export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
EOF

  sudo chown hadoop:hadoop /home/hadoop/.profile
fi
REMOTE_SCRIPT

done


echo
echo "======================================"
echo "Verification"
echo "======================================"

for host in "${NODES[@]}"; do
  echo
  echo "=== ${host} ==="

  ssh "${SSH_OPTIONS[@]}" "${REMOTE_USER}@${host}" '
    id hadoop

    sudo -u hadoop /home/hadoop/java/bin/java -version

    sudo -u hadoop env JAVA_HOME=/home/hadoop/java \
      /home/hadoop/hadoop/bin/hadoop version | head -1

    sudo grep -E "^(export JAVA_HOME|export HADOOP_HOME|export PATH=)" \
      /home/hadoop/.profile
  '
done

echo
echo "All nodes prepared successfully."
