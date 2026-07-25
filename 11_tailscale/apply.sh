#!/usr/bin/env bash
# 11_tailscale/apply.sh — mirrors this layer's README.md Apply section.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../00_configs/load.sh"
STATION_HOSTNAME="${STATION_HOSTNAME:-$(cfg station.tailscale_hostname "$(hostname)")}"
SYSADMIN_DIR="${SYSADMIN_DIR:-$(cfg station.sysadmin_dir /data/sysadmin)}"

if [ ! -f /etc/apt/sources.list.d/tailscale.list ]; then
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
  sudo apt-get update
fi
sudo apt-get install -y tailscale

# Default sysadmin dir is on /data (root-owned mount root on a fresh box) —
# same ownership guard as 05_shell/apply.sh, in case this layer runs first.
if ! mkdir -p "$SYSADMIN_DIR" 2>/dev/null || [ ! -w "$SYSADMIN_DIR" ]; then
  sudo mkdir -p "$SYSADMIN_DIR"
  sudo chown -R "$(id -un):$(id -gn)" "$SYSADMIN_DIR"
fi
mkdir -p "$SYSADMIN_DIR/01_scripts/tailscale"
cp "$HERE/files/check-tailscale.sh" "$HERE/files/list-online.sh" \
  "$SYSADMIN_DIR/01_scripts/tailscale/"
chmod +x "$SYSADMIN_DIR/01_scripts/tailscale/"*.sh

sudo systemctl enable --now tailscaled

echo
echo "Interactive step (can't be scripted): run"
echo "  sudo tailscale up --ssh --hostname=$STATION_HOSTNAME"
echo "(from ${CONFIG_FILE:-the station config}'s station.tailscale_hostname — change there, or override via STATION_HOSTNAME=, before running)"
echo "and complete the browser/QR login. Then verify with:"
echo "  $SYSADMIN_DIR/01_scripts/tailscale/check-tailscale.sh"
echo "  $SYSADMIN_DIR/01_scripts/tailscale/list-online.sh"
