#!/usr/bin/env bash
# 14_udev/apply.sh — mirrors this layer's README.md Apply section.
# OPTIONAL/ON-DEMAND layer: not in `make all`, run explicitly per station.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../00_configs/load.sh"
cd "$HERE/files"

echo "==> udev rules (device-specific — see README.md before applying)"
sudo install -m 0644 -o root -g root udev/69-mtp.rules /etc/udev/rules.d/69-mtp.rules
# 99-usb.rules carries {{HOME}} — render to a mktemp file (never a fixed
# /tmp name: it gets sudo-installed into /etc) and install root-owned.
TMP="$(mktemp)"
render_template udev/99-usb.rules "$TMP" "HOME=$HOME"
sudo install -m 0644 -o root -g root "$TMP" /etc/udev/rules.d/99-usb.rules
rm -f "$TMP"
# 69-mtp.rules grants the device to group plugdev — membership is the other
# half of that (takes effect after re-login).
id -nG | grep -qw plugdev || sudo usermod -aG plugdev "$(id -un)"
sudo udevadm control --reload-rules
# reload alone doesn't re-evaluate already-plugged devices:
sudo udevadm trigger --subsystem-match=usb

echo "==> done. (plugdev membership needs a log out/in if it was just added.)"
