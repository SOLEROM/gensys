#!/usr/bin/env bash
# 01_base/apply.sh — mirrors this layer's README.md Apply section.
# Idempotent (apt-get install is naturally so). Third-party repos are
# added only if their list file doesn't already exist.
set -euo pipefail

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg software-properties-common

echo "==> third-party APT sources"
sudo install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

if [ ! -f /etc/apt/sources.list.d/tailscale.list ]; then
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
fi

if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
fi

# Regolith 3 — official apt archive (verified on the rebuilt ubu24 host
# 2026-07-24; key fingerprint C91ECAB862037F9474087DBC7107DED133505B88).
# Bump "v3.2" when a newer Regolith release line ships.
if [ ! -f /etc/apt/sources.list.d/regolith.list ]; then
  curl -fsSL https://archive.regolith-desktop.com/regolith.key | gpg --dearmor | sudo tee /usr/share/keyrings/regolith-archive-keyring.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/ubuntu/stable noble v3.2" \
    | sudo tee /etc/apt/sources.list.d/regolith.list >/dev/null
fi

sudo add-apt-repository -y ppa:deadsnakes/ppa

if [ ! -f /etc/apt/sources.list.d/syncthing.list ]; then
  curl -fsSL https://syncthing.net/release-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/syncthing-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net syncthing stable" \
    | sudo tee /etc/apt/sources.list.d/syncthing.list >/dev/null
fi

sudo apt-get update

echo "==> core CLI/shell baseline"
sudo apt-get install -y \
  git vim tmux htop jq fzf thefuck tree silversearcher-ag \
  plocate ripgrep fd-find nnn cscope \
  curl wget rsync build-essential gnupg ca-certificates \
  software-properties-common net-tools nmap sqlite3 \
  pandoc ffmpeg imagemagick graphviz gh yamllint yt-dlp
sudo updatedb   # prime plocate's index so `locate` works right away

echo "==> debug/monitoring + extra CLI tools (absorbed from the former 15-toolset)"
sudo apt-get install -y \
  bat ncdu nvtop iotop \
  gdb strace ltrace \
  tcpdump socat sshpass dnsutils \
  shellcheck ninja-build \
  p7zip-full screen tmuxp wmctrl \
  gparted unison-gtk \
  mkcert libnss3-tools

echo "==> desktop apps"
# gpaste-2 is noble's package name for GPaste; eog backs the ee/img aliases
# in 02_aliases. discord/zoom/draw.io have NO apt package on noble — they
# get vendor .debs below, same pattern as Chrome/Obsidian.
sudo apt-get install -y \
  firefox thunderbird gimp vlc kdenlive obs-studio handbrake calibre \
  gthumb gwenview eog meld mkvtoolnix \
  gpaste-2 guake terminator flameshot transmission-gtk

if ! command -v discord >/dev/null 2>&1; then
  curl -fL "https://discord.com/api/download?platform=linux&format=deb" -o /tmp/discord.deb
  sudo apt-get install -y /tmp/discord.deb
  rm -f /tmp/discord.deb
fi

if ! command -v zoom >/dev/null 2>&1; then
  curl -fL https://zoom.us/client/latest/zoom_amd64.deb -o /tmp/zoom.deb
  sudo apt-get install -y /tmp/zoom.deb
  rm -f /tmp/zoom.deb
fi

if ! command -v drawio >/dev/null 2>&1; then
  DRAWIO_TAG=$(curl -fsSL https://api.github.com/repos/jgraph/drawio-desktop/releases/latest | jq -r .tag_name)
  curl -fL "https://github.com/jgraph/drawio-desktop/releases/download/${DRAWIO_TAG}/drawio-amd64-${DRAWIO_TAG#v}.deb" -o /tmp/drawio.deb
  sudo apt-get install -y /tmp/drawio.deb
  rm -f /tmp/drawio.deb
fi

if ! command -v google-chrome >/dev/null 2>&1; then
  curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
  sudo apt-get install -y /tmp/chrome.deb
  rm -f /tmp/chrome.deb
fi

# guake on every host: autostart on login + the close-button fix
sudo apt-get install -y libutempter0
if [ ! -f /etc/xdg/autostart/guake.desktop ]; then
  sudo cp /usr/share/applications/guake.desktop /etc/xdg/autostart/
fi

# Obsidian — official .deb from GitHub releases (no apt/snap channel);
# backs the `oo` alias in 02_aliases/alias.bashrc (/usr/bin/obsidian).
if ! command -v obsidian >/dev/null 2>&1; then
  OBS_TAG=$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | jq -r .tag_name)
  curl -fL "https://github.com/obsidianmd/obsidian-releases/releases/download/${OBS_TAG}/obsidian_${OBS_TAG#v}_amd64.deb" -o /tmp/obsidian.deb
  sudo apt-get install -y /tmp/obsidian.deb
  rm -f /tmp/obsidian.deb
fi

echo "==> sync/backup"
sudo apt-get install -y syncthing rclone duplicity clonezilla grsync

echo "==> dev runtime prerequisites"
sudo apt-get install -y \
  cmake autoconf automake libtool \
  openjdk-17-jdk openjdk-21-jdk \
  nodejs npm \
  qemu-kvm libvirt-daemon-system virtinst virt-manager vagrant virtualbox
# (lxd has no apt package on noble — the snap below is the one install)

echo "==> jupyter (apt family — same channel as the source station)"
sudo apt-get install -y jupyter-notebook jupyter-server python3-ipykernel

echo "==> snaps"
# code and ttyd are classic-confinement — snap refuses them mixed into a
# strict multi-snap install, so they get their own --classic lines.
sudo snap install spotify telegram-desktop czkawka rpi-imager sleek lxd mountain-tapir yq
sudo snap install --classic code
sudo snap install --classic ttyd

echo "==> done. Verify with README.md's Verify block."
echo "    Per-user manual step if you want locally-trusted TLS certs: mkcert -install"
