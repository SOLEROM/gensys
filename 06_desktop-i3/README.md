---
noteId: "5005e3105fd211f199201d56734786d8"
tags: []

---

# 06_desktop-i3 — Regolith 3 (i3) desktop

## Purpose

Reproduce the Regolith 3 desktop environment with the author's customizations:

- **Custom keybindings** (`config.d/myConfs`): `F1`–`F10` jump straight to
  workspaces 1–10; `Win+Insert` opens the next-numbered workspace; `Alt+Tab`
  focuses right; a `disable-Fx-modes` mode toggled with `Ctrl+Escape`.
- **NVIDIA-tuned picom** compositor (GLX, vsync, flicker fixes for a rotated
  monitor).
- **Status-bar tweaks** (i3xrocks): connected Wi-Fi SSID shown next to the
  net icon; clicking the clock pops a zenity calendar. Mined from the old
  station's `ubu20/00RegolithI3/barChanges/` notes, re-implemented as
  user-side overrides — no packaged file is edited (see below).
- **Wallpaper** + lockscreen image.
- **X session env** (`.xprofile`): NVIDIA GL tuning, HSL-mouse accel profile,
  cursor theme/size.

This layer reproduces **Regolith**, not vanilla i3 — the custom config is a thin
`config.d/` overlay on top of Regolith's shipped i3 config.

---

## Prerequisites

> **Verified on Ubuntu 24.04 (noble)** — this is exactly how the rebuilt
> ubu24 host runs Regolith today (checked live 2026-07-24: `regolith-desktop
> 4.8.0-1regolith-noble` from `archive.regolith-desktop.com stable noble
> v3.2`). The old `ppa:regolith-linux/release` path was the focal-era
> Regolith 2 install — do not use it on noble.

```bash
# Regolith 3 — official apt archive (also added by 01_base; repeated here
# in case this layer is applied standalone). Key fingerprint:
# C91ECAB862037F9474087DBC7107DED133505B88. Bump "v3.2" to the current
# release line when a newer one ships.
curl -fsSL https://archive.regolith-desktop.com/regolith.key | gpg --dearmor | sudo tee /usr/share/keyrings/regolith-archive-keyring.gpg >/dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/regolith-archive-keyring.gpg] https://archive.regolith-desktop.com/ubuntu/stable noble v3.2" \
  | sudo tee /etc/apt/sources.list.d/regolith.list >/dev/null
sudo apt update

# Regolith desktop + session + look + i3 status blocks + compositor
# (regolith-look-lascaille matches the live host — regolith-look-default
# comes in as a dependency)
sudo apt install -y \
  regolith-desktop regolith-session-flashback regolith-look-lascaille \
  i3xrocks i3xrocks-battery i3xrocks-cpu-usage i3xrocks-net-traffic i3xrocks-time \
  picom jq unclutter zenity
#   zenity → calendar popup on clock click (i3xrocks.action.time, see below)

# Optional: this second station's fuller i3xrocks status-bar set (beyond
# the battery/cpu-usage/net-traffic/time set above) — add if the richer
# status bar is wanted:
sudo apt install -y \
  i3xrocks-focused-window-name i3xrocks-keyboard-layout \
  i3xrocks-key-indicator i3xrocks-media-player i3xrocks-memory i3xrocks-volume

# NVIDIA (this machine: driver 550). Pick the right driver for the target GPU.
sudo apt install -y nvidia-driver-550

# log out, then at the GDM gear menu choose the "Regolith on Xorg" session
```

`i3-msg` (used by the shell layer's `name` helper) is provided by the Regolith
i3 packages installed here.

---

## Files in this layer

| repo path | target on fresh box |
|---|---|
| `files/i3/config.d/myConfs` | `~/.config/regolith3/i3/config.d/myConfs` |
| `files/Xresources` | `~/.config/regolith3/Xresources` |
| `files/picom/config` | `~/.config/regolith3/picom/config` (**NVIDIA boxes only** — see Apply) |
| `files/xprofile` | `~/.xprofile` |
| `files/Xresources-cursor` | `~/.Xresources` |
| `files/backgrounds/imgBg_<N>.jpg` | `~/.local/share/backgrounds/imgBg_<N>.jpg` |
| `files/i3xrocks/conf.d/30_net-traffic` | `~/.config/regolith3/i3xrocks/conf.d/30_net-traffic` |
| `files/i3xrocks/scripts/net-traffic-ssid` | `~/.config/regolith3/i3xrocks/scripts/net-traffic-ssid` |

> User config under `~/.config/regolith3/` *overlays* the system defaults in
> `/etc/regolith/` and `/usr/share/regolith/`. We only ship the deltas; Regolith
> supplies the base config via its `include` directives.

### Background images (`imgBg_<N>`)

Wallpapers live in `files/backgrounds/`, named `imgBg_<N>.jpg` — a numbered
set (currently just `imgBg_1.jpg`). Add more by dropping `imgBg_<next>.jpg`
into that folder (keep the `.jpg` extension — the copy glob and the
`WALLPAPER` path in apply.sh both assume it).

`files/Xresources` does **not** hardcode a wallpaper. Its wallpaper lines use a
`{{WALLPAPER}}` placeholder:

```
regolith.wallpaper.file: {{WALLPAPER}}
regolith.lockscreen.wallpaper.file: {{WALLPAPER}}
```

The build agent (see top-level `CLAUDE_CONSUMER.md`) **asks which `<N>` to use**,
then substitutes `{{WALLPAPER}}` with the absolute path
`$HOME/.local/share/backgrounds/imgBg_<N>.jpg`. This file is therefore an
intentional *template*, not a verbatim snapshot.

---

## Apply

```bash
# 1. scaffold
mkdir -p ~/.config/regolith3/i3/config.d \
         ~/.config/regolith3/picom \
         ~/.local/share/backgrounds

# 2. drop snapshots (run from this layer's files/ dir).
# xprofile / Xresources-cursor are templates ({{CURSOR_*}}, {{MOUSE_ACCEL_DEVICE}})
# — render them, don't cp, or the tokens land verbatim in $HOME and .xprofile
# fails at login. picom/config is NVIDIA-only: on other GPUs skip it and let
# Regolith use its default compositor config.
cp i3/config.d/myConfs   ~/.config/regolith3/i3/config.d/myConfs
[ "$HAS_NVIDIA" = yes ] && cp picom/config ~/.config/regolith3/picom/config
render_template xprofile ~/.xprofile \
  "CURSOR_SIZE=$(cfg desktop.cursor_size 24)" "CURSOR_THEME=$(cfg desktop.cursor_theme Adwaita)" \
  "MOUSE_ACCEL_DEVICE=$(cfg desktop.mouse_accel_device)"
render_template Xresources-cursor ~/.Xresources \
  "CURSOR_SIZE=$(cfg desktop.cursor_size 24)" "CURSOR_THEME=$(cfg desktop.cursor_theme Adwaita)"

# 2b. i3xrocks status-bar tweaks — seed user conf.d with ALL packaged
# blocklets first (the user dir replaces the system one wholesale), then
# override net-traffic with the SSID variant (see "Status-bar tweaks" below)
mkdir -p ~/.config/regolith3/i3xrocks/conf.d ~/.config/regolith3/i3xrocks/scripts
cp -n /usr/share/i3xrocks/conf.d/* ~/.config/regolith3/i3xrocks/conf.d/ || true
cp i3xrocks/conf.d/30_net-traffic    ~/.config/regolith3/i3xrocks/conf.d/
cp i3xrocks/scripts/net-traffic-ssid ~/.config/regolith3/i3xrocks/scripts/
chmod +x ~/.config/regolith3/i3xrocks/scripts/net-traffic-ssid

# 3. background: copy all available images, then pick one (N) for the wallpaper
cp backgrounds/imgBg_*.jpg ~/.local/share/backgrounds/
N=1                                                    # <- chosen by build agent (CLAUDE_CONSUMER.md)
WALLPAPER="$HOME/.local/share/backgrounds/imgBg_${N}.jpg"
sed "s|{{WALLPAPER}}|$WALLPAPER|g" Xresources > ~/.config/regolith3/Xresources

# 4. apply
regolith-look refresh         # reload Xresources (wallpaper, cursor)
# reload i3 in-session: Win+Shift+c   (or log out/in to re-run .xprofile)
```

### What `myConfs` does

```
bindsym $mod+Insert exec --no-startup-id i3-msg workspace \
        $(i3-msg -t get_workspaces | jq 'map(.num) | max | .+1')   # new workspace
bindsym $alt+Tab focus right                                       # cycle windows
bindsym F1 workspace number $ws1 ... bindsym F10 workspace number $ws10
mode "disable-Fx-modes" { bindsym Ctrl+Escape mode "default" }     # suspend F-keys
bindsym Ctrl+Escape mode "disable-Fx-modes"
```

The `disable-Fx-modes` mode exists so the `F1`–`F10` workspace bindings can be
temporarily suspended (e.g. when an app needs the function keys); `Ctrl+Escape`
enters it, `Ctrl+Escape` again returns to default.

### Status-bar tweaks (i3xrocks)

Two behaviors from the old station, both applied **user-side** — unlike the
old `barChanges/` notes, which patched `/usr/share/i3xrocks/*` directly and
were wiped on every package upgrade:

1. **Wi-Fi SSID on the bar** — `scripts/net-traffic-ssid` is a copy of the
   packaged noble `net-traffic` blocklet script with one delta: on a
   wireless interface it appends `(SSID)` (via `nmcli`) to the wifi icon.
   The `conf.d/30_net-traffic` override points the blocklet at it.
2. **Calendar on clock click** — needs *no* script copy on Regolith 3: the
   stock `time` blocklet already reads its click action from the
   `i3xrocks.action.time` Xresource. `files/Xresources` sets it to
   `zenity --calendar`.

**Seeding caveat**: once `~/.config/regolith3/i3xrocks/conf.d/` exists,
i3xrocks (`-u`) uses it *instead of* `/usr/share/i3xrocks/conf.d` — so
`apply.sh` first seeds the user dir with every packaged blocklet (`cp -n`),
then overwrites `30_net-traffic`. If you later install more `i3xrocks-*`
packages (e.g. the richer optional set above), copy their new conf files
into the user dir too (or re-run `apply.sh`) or they won't appear on the bar.

### picom tuning (NVIDIA + rotated monitor)

`picom/config` overrides `/etc/regolith/picom/config`. Key choices, all tuned for
**NVIDIA 550/580 + dual monitor with one portrait-rotated panel**:

- `backend = "glx"`, `vsync = true`
- `xrender-sync-fence = false` — on NVIDIA 470+ the fence *adds* latency.
- `unredir-if-possible = false` — prevents a flicker on fullscreen focus changes.
- `use-damage = false` — full-frame redraws are cheaper than damage tracking when
  a monitor is rotated.

---

## Verify

```bash
# in a Regolith session:
i3-msg -t get_version            # confirms i3/Regolith is running
pgrep -a picom                   # NVIDIA boxes: picom with the user config
                                 # (non-NVIDIA: no user picom config by design)
xrdb -query | grep -i wallpaper  # wallpaper path resolved
xrdb -query | grep action.time   # → zenity --calendar
ls ~/.config/regolith3/i3xrocks/conf.d/   # all packaged blocklets + our 30_net-traffic
```

Functionally: press `F1`–`F10` (workspaces switch), `Win+Insert` (new workspace
appears), `Alt+Tab` (focus moves right), and confirm no flicker when toggling a
fullscreen window.

---

## Machine-specific values

All of the below live in the active station's `00_configs/<name>.yaml` under
`desktop:` (read via `00_configs/load.sh`'s `cfg`; see `../00_configs/README.md`)
— edit there rather than hand-editing `apply.sh`. `N`/`HAS_NVIDIA` env vars still override the config, same as
before this existed.

- **Wallpaper** (`desktop.wallpaper_n`, env var `N`). `Xresources` itself
  still doesn't hardcode a path — it uses the `{{WALLPAPER}}` placeholder
  (see *Background images* above); `apply.sh` substitutes the absolute
  `$HOME`-relative path via `render_template`.
- **GPU** (`desktop.has_nvidia`, `desktop.nvidia_driver`, env vars
  `HAS_NVIDIA`/`NVIDIA_DRIVER_VERSION`). picom is tuned for NVIDIA 550/580.
  On Intel/AMD boxes `apply.sh` does **not** install `files/picom/config` at
  all — Regolith's default compositor config is used. If you nevertheless
  want the user config on such a box, strip the NVIDIA-only lines
  (`xrender-sync-fence`, and revisit `backend`/`vsync`/`unredir-if-possible`/
  `use-damage`) before copying it by hand.
- **`.xprofile` / `Xresources-cursor`** — `{{MOUSE_ACCEL_DEVICE}}`
  (`desktop.mouse_accel_device`, this host: `HSL`) and `{{CURSOR_THEME}}`/
  `{{CURSOR_SIZE}}` (`desktop.cursor_theme`/`desktop.cursor_size`, this
  host: `Adwaita`/`24`) are rendered by `apply.sh` at copy time. An empty
  `mouse_accel_device` makes the `xinput` loop a no-op — safe default for a
  box with no such mouse.
- **Display layout** (reference, not scripted here): HDMI-0 primary, portrait
  1440×2560 right-rotated, at +1920+0; DP-4 1920×1080 at +0+827. Set via `Win+d`
  (Regolith display settings) or `xrandr` after first login.
- **`../02_aliases/scripts/multiScreen/*.sh`** (installed by `05_shell`, not this
  layer) take their monitor output names from the station config
  (`desktop.monitors.laptop/wide/top`, rendered via `{{MON_*}}` tokens at
  install time) — fill those in from `xrandr --listmonitors` on the target
  box; no script editing needed.
- **Regolith install method — RESOLVED 2026-07-24.** Prerequisites now use
  `archive.regolith-desktop.com`'s own apt repo (`stable noble v3.2`) +
  `regolith-look-lascaille`, verified against the rebuilt ubu24 host's live
  state (`regolith-desktop 4.8.0-1regolith-noble`, key fingerprint matches
  the archive's published `regolith.key`). The old
  `ppa:regolith-linux/release` (focal-era Regolith 2, from the 2026-06-02
  source machine) is dropped everywhere — `01_base` adds the archive repo
  too. The one value to revisit over time is the `v3.2` release-line
  component in the sources line.

---

## Origin

Snapshots captured from:

- `~/.config/regolith3/i3/config.d/myConfs`
- `~/.config/regolith3/Xresources`
- `~/.config/regolith3/picom/config`
- `~/.xprofile`
- `~/.Xresources`
- `~/.local/share/backgrounds/2025-12-23-00-35-24-01.jpg` → stored here as `imgBg_1.jpg`

> Note: `files/Xresources` diverges from its origin **by design** — the live
> wallpaper path was replaced with the `{{WALLPAPER}}` placeholder so the build
> agent can select an image, and the `i3xrocks.action.time` line was added
> (status-bar tweaks). Don't "re-sync" that one verbatim.

`files/i3xrocks/scripts/net-traffic-ssid` ← `/usr/share/i3xrocks/scripts/net-traffic`
(i3xrocks `1.3.5-1-1regolith-noble`, captured 2026-07-24) + the SSID delta
from `/data/sysadmin/ubu20/00RegolithI3/barChanges/wifiName.md`. If a
Regolith upgrade reworks the packaged script, re-base the copy on the new
version and re-apply the one marked delta.

Re-sync the others by re-copying from those paths.
