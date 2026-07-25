#!/usr/bin/env bash
# 09_docker/files/installAndConf.sh — Docker CE install + data-root
# relocation. Adapted from /data/sysadmin/ubu24/04_dockers/installAndConf.sh
# (already tested on this host) — the one change: DOCKER_DATA_ROOT is a
# parameter, not a hardcoded ~/proj/docker (which didn't even exist on this
# host — confirmed; the live setup actually uses /data/dockerDATA).
set -euo pipefail

DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-/data/dockerDATA}"
# $USER is unreliable under sudo/non-login shells — derive the real user
TARGET_USER="${SUDO_USER:-$(id -un)}"

# ---- Docker CE install (official repo) ----
sudo apt-get remove -y docker.io docker-doc docker-compose podman-docker containerd runc || true
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg jq rsync

sudo install -m 0755 -d /etc/apt/keyrings
# --yes: gpg refuses to overwrite an existing keyring, which would abort a re-run
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# UBUNTU_CODENAME survives derivatives; VERSION_CODENAME is the fallback
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ---- Enable Docker ----
sudo systemctl enable --now docker

# ---- Docker group (no sudo) ----
sudo groupadd -f docker
sudo usermod -aG docker "$TARGET_USER"

# ---- Move Docker data-root to $DOCKER_DATA_ROOT ----
sudo mkdir -p "$DOCKER_DATA_ROOT"
NEW_DOCKER_DIR="$(realpath "$DOCKER_DATA_ROOT")"

# Warn if the target isn't on a separate mount — a missing /data mount means
# mkdir -p just created it on the root filesystem, and every image will
# land on / (usually not what the 04_storage prerequisite intended).
if [ "$(findmnt -n -o TARGET -T "$NEW_DOCKER_DIR")" = "/" ] && [ "$NEW_DOCKER_DIR" != "${NEW_DOCKER_DIR#/data}" ]; then
  echo "WARNING: $NEW_DOCKER_DIR resolves to the root filesystem — is /data mounted (04_storage applied)?" >&2
fi

CURRENT_ROOT="$(sudo docker info --format '{{.DockerRootDir}}' 2>/dev/null || true)"
if [ "$CURRENT_ROOT" = "$NEW_DOCKER_DIR" ]; then
  echo "data-root already $NEW_DOCKER_DIR — skipping the one-time /var/lib/docker copy"
else
  sudo systemctl stop docker docker.socket
  # one-time relocation of whatever the fresh install put in /var/lib/docker;
  # guarded above so a re-run can never rsync a stale snapshot over live data
  sudo rsync -aHAX --numeric-ids /var/lib/docker/ "$NEW_DOCKER_DIR/"
fi

# Merge data-root into daemon.json instead of overwriting it — an existing
# file may carry log-opts, registry mirrors, or the nvidia runtime block.
sudo mkdir -p /etc/docker
EXISTING="$(sudo cat /etc/docker/daemon.json 2>/dev/null || echo '{}')"
echo "$EXISTING" | jq --arg r "$NEW_DOCKER_DIR" '. + {"data-root": $r}' | sudo tee /etc/docker/daemon.json >/dev/null

sudo systemctl start docker.socket docker

# ---- Verify ----
# via sudo: the invoking user's docker-group membership only lands after a
# re-login, and the verify must not fail (and hide the message below) for that
sudo docker info | grep "Docker Root Dir"
sudo docker buildx version
sudo docker run --rm hello-world

cat <<EOF

Docker data-root: $NEW_DOCKER_DIR
Log out/in (or 'newgrp docker') for the docker group membership to take
effect without sudo.
EOF
