#!/usr/bin/env bash
# 09_docker/apply.sh — thin wrapper so `make 09_docker` matches every other
# layer's convention; the real work is in files/installAndConf.sh.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../00_configs/load.sh"
DOCKER_DATA_ROOT="${DOCKER_DATA_ROOT:-$(cfg docker.data_root /data/dockerDATA)}" "$HERE/files/installAndConf.sh"
