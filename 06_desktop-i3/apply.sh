#!/usr/bin/env bash
# 06_desktop-i3/apply.sh — mirrors this layer's README.md Prerequisites +
# Apply sections. Params: N (wallpaper number, default 1), HAS_NVIDIA
# (yes/no, default: autodetect via lspci).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../00_configs/load.sh"
cd "$HERE/files"

N="${N:-$(cfg desktop.wallpaper_n 1)}"
if [ -z "${HAS_NVIDIA:-}" ]; then
  HAS_NVIDIA="$(cfg desktop.has_nvidia)"
fi
case "${HAS_NVIDIA:-}" in
  yes|no) ;;
  "")
    HAS_NVIDIA=$(lspci | grep -iq nvidia && echo yes || echo no)
    echo "==> desktop.has_nvidia unset — autodetected via lspci: $HAS_NVIDIA" >&2 ;;
  *)
    echo "ERROR: desktop.has_nvidia must be yes|no, got '$HAS_NVIDIA' — fix the station config." >&2
    exit 1 ;;
esac
NVIDIA_DRIVER_VERSION="${NVIDIA_DRIVER_VERSION:-$(cfg desktop.nvidia_driver 550)}"
CURSOR_THEME="$(cfg desktop.cursor_theme Adwaita)"
CURSOR_SIZE="$(cfg desktop.cursor_size 24)"
MOUSE_ACCEL_DEVICE="$(cfg desktop.mouse_accel_device)"

echo "==> Regolith 3 apt archive + packages"
# Official archive, verified on the rebuilt ubu24 host 2026-07-24 (also
# added by 01_base — guarded here for standalone runs). Bump "v3.2" when a
# newer Regolith release line ships.
if [ ! -f /etc/apt/sources.list.d/regolith.list ]; then
  curl -fsSL https://archive.regolith-desktop.com/regolith.key | gpg --dearmor | sudo tee /usr/share/keyrings/regolith-archive-keyring.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/ubuntu/stable noble v3.2" \
    | sudo tee /etc/apt/sources.list.d/regolith.list >/dev/null
fi
sudo apt-get update
# xinput: the .xprofile mouse-accel loop; bc: net-traffic-ssid's rate math —
# neither arrives transitively, and both fail silently/blank when absent.
sudo apt-get install -y \
  regolith-desktop regolith-session-flashback regolith-look-lascaille \
  i3xrocks i3xrocks-battery i3xrocks-cpu-usage i3xrocks-net-traffic i3xrocks-time \
  picom jq unclutter zenity xinput bc

if [ "$HAS_NVIDIA" = yes ]; then
  echo "==> NVIDIA driver $NVIDIA_DRIVER_VERSION (this repo's picom tuning assumes 550/580)"
  # Non-fatal: a retired driver version must not discard the whole desktop
  # layer — everything below works without it, and the README says how to
  # pick the current recommended driver.
  sudo apt-get install -y "nvidia-driver-${NVIDIA_DRIVER_VERSION}" || \
    echo "WARNING: nvidia-driver-${NVIDIA_DRIVER_VERSION} unavailable — run 'ubuntu-drivers devices' and install the recommended one, then re-run this layer." >&2
else
  echo "==> no NVIDIA detected — skipping driver install, will skip NVIDIA-tuned picom config too"
fi

echo "==> scaffold"
mkdir -p ~/.config/regolith3/i3/config.d \
         ~/.config/regolith3/picom \
         ~/.local/share/backgrounds

echo "==> files"
cp i3/config.d/myConfs   ~/.config/regolith3/i3/config.d/myConfs
# one-time backups: ~/.xprofile / ~/.Xresources often carry unrelated user
# settings — keep the pre-gensys copy around (cp -n: first run only)
for f in ~/.xprofile ~/.Xresources; do [ -f "$f" ] && cp -n "$f" "$f.pre-gensys"; done
render_template xprofile ~/.xprofile \
  "CURSOR_SIZE=$CURSOR_SIZE" "CURSOR_THEME=$CURSOR_THEME" "MOUSE_ACCEL_DEVICE=$MOUSE_ACCEL_DEVICE"
render_template Xresources-cursor ~/.Xresources \
  "CURSOR_SIZE=$CURSOR_SIZE" "CURSOR_THEME=$CURSOR_THEME"

if [ "$HAS_NVIDIA" = yes ]; then
  cp picom/config ~/.config/regolith3/picom/config
else
  echo "    (skipping NVIDIA-tuned picom/config — leaving Regolith's default compositor config in place)"
fi

echo "==> i3xrocks status-bar tweaks (SSID next to wifi icon; calendar on clock click)"
# Once the user conf.d exists, i3xrocks (-u) uses it INSTEAD of the packaged
# /usr/share/i3xrocks/conf.d — so seed it with every packaged blocklet first
# (cp -n keeps any existing user copies), then drop our override on top.
# Re-run this block after installing any new i3xrocks-* package so its
# blocklet gets picked up into the user dir too.
mkdir -p ~/.config/regolith3/i3xrocks/conf.d ~/.config/regolith3/i3xrocks/scripts
cp -n /usr/share/i3xrocks/conf.d/* ~/.config/regolith3/i3xrocks/conf.d/ || true
cp i3xrocks/conf.d/30_net-traffic    ~/.config/regolith3/i3xrocks/conf.d/30_net-traffic
cp i3xrocks/scripts/net-traffic-ssid ~/.config/regolith3/i3xrocks/scripts/net-traffic-ssid
chmod +x ~/.config/regolith3/i3xrocks/scripts/net-traffic-ssid
# calendar-on-click needs no script change: files/Xresources sets
# i3xrocks.action.time (rendered below with the wallpaper), zenity installed above.

echo "==> wallpaper (N=$N)"
cp backgrounds/imgBg_*.jpg ~/.local/share/backgrounds/
WALLPAPER="$HOME/.local/share/backgrounds/imgBg_${N}.jpg"
if [ ! -f "$WALLPAPER" ]; then
  echo "ERROR: no such background: $WALLPAPER" >&2
  echo "Available: $(ls backgrounds/)" >&2
  exit 1
fi
render_template Xresources ~/.config/regolith3/Xresources "WALLPAPER=$WALLPAPER"

echo "==> input sources (English + Hebrew, Alt+Z toggle)"
# gsd-keyboard (Regolith's Flashback session runs it) applies these live —
# no re-login needed. No-op over a bare SSH shell with no session dbus.
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'il')]" || true
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Alt>z']" || true

echo "==> apply"
regolith-look refresh || true
# regolith-look only rereads ~/.config/regolith3/Xresources — merge the
# cursor settings written to ~/.Xresources too (no-op outside an X session)
xrdb -merge ~/.Xresources 2>/dev/null || true

cat <<'EOF'

Done. Remaining manual step: log out, then at the GDM gear menu choose the
"Regolith on Xorg" session (can't be scripted — it's a login-screen choice).
EOF
