# 01_base — apt/PPA/snap bill of materials (noble-only)

## Purpose

Base OS package set for a fresh Ubuntu 24.04 (noble) install. This is a
**curated bill of materials**, not a raw `apt-mark showmanual` dump — this
host's actual manually-installed package list runs to ~384 entries, most of
it focal/OEM-image cruft with no place on a fresh noble box. Everything
focal-only is called out explicitly below and excluded, not silently
dropped.

Apply this layer **first** — before `04_storage`/`05_shell`/`06_desktop-i3`
(everything later assumes `git`, `curl`, etc. already exist). This matches
`CLAUDE_CONSUMER.md`'s Step 4 and the root `Makefile`'s `LAYERS` order,
which both put `01_base` at the front.

---

## Prerequisites

None beyond a working `apt` and network — this layer *is* the prerequisite
step for most others.

---

## Files in this layer

None — this layer is entirely `apt`/PPA/snap commands, no config files to
place.

---

## Apply

### 1. Third-party APT sources

Verify each against noble before trusting it blindly — PPA availability for
a new Ubuntu release isn't guaranteed day one.

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg software-properties-common

# Docker CE (see 09_docker for the rest of that layer)
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# Tailscale (see 11_tailscale)
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

# Regolith 3 (see 06_desktop-i3) — official apt archive, NOT the old
# ppa:regolith-linux/release (that PPA backed the focal-era Regolith 2
# install; the archive below is what the rebuilt ubu24 host actually runs —
# verified live 2026-07-24: regolith-desktop 4.8.0-1regolith-noble from
# "stable noble v3.2"). Bump "v3.2" to the current release line per
# https://regolith-desktop.com's install docs when a newer one ships.
curl -fsSL https://archive.regolith-desktop.com/regolith.key | gpg --dearmor | sudo tee /usr/share/keyrings/regolith-archive-keyring.gpg >/dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/ubuntu/stable noble v3.2" \
  | sudo tee /etc/apt/sources.list.d/regolith.list >/dev/null

# deadsnakes (extra python versions, on-demand only — pyenv is the primary way, see 07_dev)
sudo add-apt-repository -y ppa:deadsnakes/ppa

# Cursor, Windsurf — verify current install method against noble; both ship
# their own .deb/AppImage + apt-repo installers that change occasionally,
# check https://cursor.com / https://windsurf.com for the current one-liner
# rather than trusting a stale PPA snippet here.

# Syncthing
curl -fsSL https://syncthing.net/release-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/syncthing-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net syncthing stable" \
  | sudo tee /etc/apt/sources.list.d/syncthing.list >/dev/null

# Notion (fury.io) — verify current repo; notion-app's unofficial packaging changes hands occasionally.

sudo apt-get update
```

**Drop, don't carry forward**: `nilarimogard/webupd8` PPA (source blog
defunct), the Lenovo OEM PPA (`oem-sutton.newell-aekerley-meta`, hardware-
image specific), `ethereum`/`ng-hong-quan`/`gezakovacs` PPAs
(blockchain-adjacent/niche, dropped per owner decision),
`phosphobot` (only relevant if `10_embedded-hw` is ever built out).

### 2. Core CLI/shell baseline

```bash
sudo apt-get install -y \
  git vim tmux htop jq fzf thefuck tree silversearcher-ag \
  plocate ripgrep fd-find \
  curl wget rsync build-essential gnupg ca-certificates \
  software-properties-common net-tools nmap sqlite3 \
  pandoc ffmpeg imagemagick graphviz gh yamllint yt-dlp
sudo updatedb   # prime plocate's index so `locate` works right away
```

File-locating tools, per owner request (`plocate` replaces the focal-era
`mlocate` — noble's `mlocate` package is just a transitional shim):
`locate`/`updatedb` (plocate), `rg` (ripgrep), `fdfind` (fd-find, Debian
renames the binary), plus `ag` (silversearcher-ag) and `fzf` already above.

Debug/monitoring and extra CLI tools (absorbed from the former `15-toolset`
layer on 2026-07-24 — originally derived by diffing the
`query/snapshots/edge_2026-07-24` freeze map against the layer set; merged
here so there is exactly **one** "packages every station gets" list — new
always-on CLI tools go in this section from now on):

```bash
sudo apt-get install -y \
  bat ncdu nvtop iotop \
  gdb strace ltrace \
  tcpdump socat sshpass dnsutils \
  shellcheck ninja-build \
  p7zip-full screen tmuxp wmctrl \
  gparted unison-gtk \
  mkcert libnss3-tools
```

`bat` installs its binary as `batcat` (Debian rename). Per-user manual step
(optional): `mkcert -install` to create and trust the local CA — writes into
`$HOME` and the NSS store, so it is not scripted.

### 3. Desktop apps

```bash
# gpaste-2 is noble's package name for GPaste; eog backs the ee/img aliases
# in 02_aliases; nnn/cscope (core CLI tier) back the nn/vv aliases there too.
sudo apt-get install -y \
  firefox thunderbird gimp vlc kdenlive obs-studio handbrake calibre \
  gthumb gwenview eog meld mkvtoolnix \
  gpaste-2 guake terminator flameshot transmission-gtk

# discord, zoom, draw.io have NO apt package on noble — vendor .debs, same
# pattern as Chrome/Obsidian below (apply.sh guards each with command -v):
curl -fL "https://discord.com/api/download?platform=linux&format=deb" -o /tmp/discord.deb
sudo apt-get install -y /tmp/discord.deb
curl -fL https://zoom.us/client/latest/zoom_amd64.deb -o /tmp/zoom.deb
sudo apt-get install -y /tmp/zoom.deb
DRAWIO_TAG=$(curl -fsSL https://api.github.com/repos/jgraph/drawio-desktop/releases/latest | jq -r .tag_name)
curl -fL "https://github.com/jgraph/drawio-desktop/releases/download/${DRAWIO_TAG}/drawio-amd64-${DRAWIO_TAG#v}.deb" -o /tmp/drawio.deb
sudo apt-get install -y /tmp/drawio.deb

# google-chrome-stable ships its own .deb, not a plain apt-get name:
curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb
sudo apt-get install -y /tmp/chrome.deb

# guake on every host (owner decision): autostart on login + close-button fix
sudo apt-get install -y libutempter0
sudo cp /usr/share/applications/guake.desktop /etc/xdg/autostart/

# Obsidian — official .deb from GitHub releases (no apt/snap channel).
# Installs /usr/bin/obsidian, which backs the `oo` alias in
# 02_aliases/alias.bashrc (the old alias pointed at an AppImage under
# /data/sysadmin/local/brainStorm that only existed on the old host).
OBS_TAG=$(curl -fsSL https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest | jq -r .tag_name)
curl -fL "https://github.com/obsidianmd/obsidian-releases/releases/download/${OBS_TAG}/obsidian_${OBS_TAG#v}_amd64.deb" -o /tmp/obsidian.deb
sudo apt-get install -y /tmp/obsidian.deb

# slack-desktop, notion-app, koodo-reader: verify current install method
# (some ship as snaps now instead of .deb/apt) before scripting a specific
# path here — check each app's current install docs.

# bcompare (Beyond Compare), master-pdf-editor-5: proprietary, licensed —
# download from the vendor, not scripted here.
```

### 4. Sync/backup

```bash
sudo apt-get install -y syncthing rclone duplicity clonezilla grsync
```

Remote-access daemons intentionally **not** here — see `11_tailscale` (kept;
TeamViewer/AnyDesk/VNC-stack dropped per owner decision).

### 5. Dev runtime prerequisites

```bash
sudo apt-get install -y \
  cmake autoconf automake libtool \
  openjdk-17-jdk openjdk-21-jdk \
  nodejs npm \
  qemu-kvm libvirt-daemon-system virtinst virt-manager vagrant virtualbox
```
(`lxd` has no apt package on noble — the snap in step 7 is the one install.)
The full `docker-ce` stack is `09_docker`'s job (data-root relocation needs
its own careful ordering — see that layer). `lib*-dev` set: add specific
`-dev` packages as projects under `/proj` actually need them rather than
guessing a full list upfront.

Jupyter — the apt family the station actually runs (not pip; absorbed from
the former `15-toolset` layer):

```bash
sudo apt-get install -y jupyter-notebook jupyter-server python3-ipykernel
```

### 6. AI coding tools

```bash
# claude-desktop, cursor, windsurf, antigravity, auto-claude-ui: see
# 08_ai-agent-tools for the fuller picture (CLI census, systemd services).
# Claude Code itself is bootstrapped by `make deps` (root Makefile), not this layer.
```

### 7. Snaps

```bash
# code and ttyd are classic-confinement — snap refuses them mixed into a
# strict multi-snap line, so they get their own --classic installs:
sudo snap install spotify telegram-desktop czkawka rpi-imager sleek lxd mountain-tapir yq
sudo snap install --classic code
sudo snap install --classic ttyd
```
No flatpak in use — don't add flatpak/flathub unless a specific app needs
it. `yq` (mikefarah) is the parser `00_configs/load.sh` uses to read
`00_configs/*.yaml` — every later layer's `apply.sh` depends on it being
present; `00_configs/load.sh` also installs it lazily if a layer is ever run
standalone before `01_base`.

---

## Explicitly excluded — focal/OEM/installer artifacts

Has no place on a fresh noble install; **do not** install these even though
they showed up in this host's `apt-mark showmanual`:

- `linux-oem-20.04`, `linux-tools-5.14.0-1056-oem`,
  `oem-sutton.newell-aekerley-meta` — this exact Lenovo unit's OEM install
  image + its PPA. Noble's own kernel/installer supplies the equivalent.
- `grub-pc`, `grub-efi-amd64-signed`, `os-prober`, `mokutil`,
  `secureboot-db` — boot-stack artifacts the Ubuntu 24 installer supplies
  fresh. Reinstalling over these is how you break the bootloader, not fix
  it.
- `python3.8`, `python3.8-venv`, `libncurses5`, `libncurses5-dev` — focal-era
  compat shims. Noble ships python3.12 and libncurses6 by default;
  reintroduce a specific old Python only via `pyenv` on demand (`07_dev`),
  never as baseline.
- `zfsutils-linux` — no ZFS pool actually exists on this host (confirmed:
  it's only in `/etc/cron.d` as a stock timer, no pool). Vestigial, drop.
- `ravkavonline` (Israeli transit-card reader) — confirm still wanted before
  including; not installed by default here.

---

## Verify

```bash
. /etc/os-release; echo "$PRETTY_NAME"     # Ubuntu 24.04.x LTS (noble)
dpkg -l | grep -c '^ii'                    # sanity count, not a precise target
which git curl jq fzf gh  # spot-check a few from each tier
# (docker/tailscale binaries come from 09_docker/11_tailscale — this layer
# only adds their apt sources: test -f /etc/apt/sources.list.d/docker.list)
which locate rg fdfind ag obsidian         # file-locating tools + obsidian
which yt-dlp flameshot transmission-gtk    # absorbed from zenbook snapshot diff
locate --version | head -1                 # plocate, index primed by updatedb
for c in batcat ncdu nvtop iotop gdb strace ltrace tcpdump socat sshpass dig \
         shellcheck ninja 7z screen tmuxp wmctrl gparted unison-gtk mkcert; do
  command -v "$c" >/dev/null || echo "MISSING: $c"
done                                       # no output = all debug/CLI tools present
jupyter notebook --version
test -f /etc/xdg/autostart/guake.desktop && echo "guake autostarts"
snap list
```

---

## Machine-specific values

None — this layer has no per-machine substitution. Hardware gating (GPU
driver choice) lives in `06_desktop-i3` / `CLAUDE_CONSUMER.md` Step 3, not
here.

---

## Origin

`apt-mark showmanual` + `snap list` + `/etc/apt/sources.list.d/*` on this
host, 2026-07-23, filtered per the exclusion rules above. Re-derive by
re-running those commands and diffing against this README rather than
trusting a stale package-count number.

The debug/monitoring tools and apt-Jupyter blocks were the former
`15-toolset` layer (merged in 2026-07-24): derived from the
`query/snapshots/edge_2026-07-24` freeze map by diffing it against every
layer's install list (its network-services third went to `12_services`).
One substitution kept from that derivation: `mkcert` on the station was a
hand-dropped `~/.local/bin` binary; this layer installs the
identical-version apt package (`mkcert` 1.4.4, noble universe) instead.
Re-sync by re-running `query/mapCurrentHost.sh` and re-diffing — one list
to diff against now, not two.

`yt-dlp`, `flameshot`, `transmission-gtk` added 2026-07-24 from diffing
`query/snapshots/zenbook_2026-07-24` against this layer's install lists —
all three were present on that host and generic enough to belong here.
