#!/usr/bin/env bash
# 13_misc/apply.sh — mirrors this layer's README.md Apply section.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../00_configs/load.sh"
cd "$HERE/files"

echo "==> fonts"
mkdir -p ~/.local/share/fonts/JetBrainsMono
cp fonts/JetBrainsMono/*.ttf ~/.local/share/fonts/JetBrainsMono/
fc-cache -f

echo "==> git identity"
GIT_NAME="$(cfg git.name)"
GIT_EMAIL="$(cfg git.email)"
if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
  echo "WARNING: git.name/git.email unset (or still placeholders) in ${CONFIG_FILE:-the station config} — skipping ~/.gitconfig (git would refuse to commit with an empty ident)." >&2
else
  # one-time backup — the live file may have grown [alias]/[credential] blocks
  [ -f ~/.gitconfig ] && cp -n ~/.gitconfig ~/.gitconfig.pre-gensys
  render_template gitconfig ~/.gitconfig \
    "GIT_NAME=$GIT_NAME" "GIT_EMAIL=$GIT_EMAIL"
fi

echo "==> ssh config pattern"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
touch ~/.ssh/config
grep -qF "Session Manager" ~/.ssh/config || cat ssh_config_pattern >> ~/.ssh/config

# udev rules moved to the optional/on-demand 14_udev layer (2026-07-24) —
# device-specific, not applied on new stations by default.

echo "==> timezone"
# owner default; non-fatal so a bad/placeholder value can't abort the layer
sudo timedatectl set-timezone "$(cfg station.timezone Asia/Jerusalem)" || \
  echo "WARNING: timedatectl rejected '$(cfg station.timezone Asia/Jerusalem)' — set station.timezone to a valid zone (timedatectl list-timezones)" >&2

echo "==> Hebrew font coverage (culmus)"
sudo apt-get install -y culmus

echo "==> done. Wi-Fi re-join and input-source (English/Hebrew) toggle are manual GUI steps — see README.md."
