---
noteId: "7d5f3b405fd211f199201d56734786d8"
tags: []

---

# CLAUDE_CONSUMER.md — build-agent instructions

**You are the build agent.** Your job: take a freshly installed Ubuntu 24.04
machine and reproduce the owner's preferred environment using the layered
instructions in this repo. Each layer folder (`NN_name/`) has its own `README.md`
that is the source of truth for that layer — you apply layers in order, but you
**adapt to the target machine's hardware** and **ask the owner** for the few
choices that can't be inferred.

> Read this whole file first, then `./README.md` (the layer index/conventions),
> then walk the layers.

---

## Operating principles

1. **Probe before you install.** Detect the hardware first (Step 1). Don't
   install hardware-specific packages the box can't use (e.g. no NVIDIA driver on
   an Intel/AMD machine).
2. **Ask, don't guess, for owner choices.** There is one mandatory question
   (background image) and a short confirmation of the detected hardware plan.
   Ask up front, then run unattended.
3. **Layers are the unit of work.** For each layer you decide to apply, open its
   `README.md` and follow its **Prerequisites → Apply → Verify** sections. This
   file only adds the *gating* (what to skip) and *parameters* (what to fill in).
4. **Idempotence / safety.** Back up any pre-existing target file before
   overwriting (`cp x x.bak.$(timestamp)`). Re-running a layer should be safe.
5. **Report.** After each layer, run its Verify block and report pass/fail. Stop
   and ask if a prerequisite (PPA, network, sudo) fails.

---

## Step 0 — Preflight

**Session mode.** This build is meant to run unattended: install.sh's hand-off
starts you as `claude --dangerously-skip-permissions`, and `make deps` already
seeded `~/.claude/settings.json` with `Bash(sudo:*)` allowed. If permission
prompts still interrupt you (the owner started `claude` bare), ask the owner to
restart the session with that flag before you walk the layers.

```bash
. /etc/os-release; echo "$PRETTY_NAME"     # expect Ubuntu 24.04 (noble)
whoami; echo "$HOME"                         # the target user (shell configs resolve via $HOME — no assumed username)
sudo -v                                      # confirm sudo works
ping -c1 8.8.8.8 >/dev/null && echo net-ok   # need network for apt/PPAs/oh-my-zsh
```

If the OS is not 24.04, warn the owner — snapshots are authored against noble.

**Station config.** Check whether this box already has a `00_configs/<name>.yaml`
(see `00_configs/README.md`) — e.g. this is a re-run, or the owner already
prepared one. If not, this is a genuinely new station: copy
`00_configs/TEMPLATE.yaml` to `00_configs/<name>.yaml` now (ask the owner for a
name, or default to the next `myDevX<N>`), and fill in what you can from the
hardware probe below (Step 1) plus `whoami`/`$HOME` above — leave the rest
for Step 2. Every layer's `apply.sh` reads this file via `00_configs/load.sh`;
set `GENSYS_CONFIG=00_configs/<name>.yaml` for the rest of this run so `make`/
`apply.sh` invocations pick it up without re-asking.

A station may also have an end-state companion doc, `host_<name>.md`, next
to its yaml (`00_configs/myDevX1/host_devX1.md` for myDevX1 — that whole
per-station folder is git-ignored, so it's only present in a working-tree
copy). If it exists, read
it: it describes what the finished box should look like, layer by layer —
the reference to check the Step 5 report against.

---

## Step 1 — Hardware probe

Run these and record the answers; they drive the **decision matrix** below.

```bash
# GPU vendor(s)
lspci | grep -Ei 'vga|3d|display'
HAS_NVIDIA=$(lspci | grep -iq nvidia && echo yes || echo no)
HAS_AMD=$(lspci    | grep -Eiq 'amd/ati|radeon' && echo yes || echo no)
HAS_INTEL_GPU=$(lspci | grep -Eiq 'intel.*(graphics|vga|display)' && echo yes || echo no)

# Laptop vs desktop (battery present?)
HAS_BATTERY=$([ -d /sys/class/power_supply ] && ls /sys/class/power_supply | grep -qi bat && echo yes || echo no)

# Displays / rotation (only meaningful inside an X session)
xrandr --query 2>/dev/null | grep ' connected'

# Pointing devices (the .xprofile HSL-mouse tweak only matters if this exists)
xinput list --name-only 2>/dev/null | grep -i HSL && echo "HSL mouse present"
```

---

## Step 2 — Ask the owner

If the station config (Step 0) already has an answer for one of these
(non-empty, non-placeholder), treat it as the default and only confirm it
rather than asking cold — that's the point of filling in `00_configs/<name>.yaml`
once. Ask these before applying anything:

1. **Background image** (mandatory): list the available choices and ask which `N`.
   ```bash
   ls 06_desktop-i3/files/backgrounds/   # the imgBg_<N>.jpg set (may be just imgBg_1.jpg)
   ```
   Present them (filename, and a thumbnail/preview if you can) and ask:
   *"Which background number should I set? (1, 2, 3, …)"* Store as `$N`.
2. **Docker data-root**: *"Where should Docker's image/container storage
   live? (default: `/data/dockerDATA`)"* Store as `$DOCKER_DATA_ROOT` — see
   `09_docker/README.md`. Any mounted path is valid (root fs, `/data`, an
   external drive) — don't guess, ask.
3. **`/data` encryption + swap**: *"Is `/data` LUKS-encrypted on this box?
   (`storage.data_encrypted`, default yes — say no for a plain unencrypted
   partition)"*, *"Swap size? (default `16G`)"* and *"Encrypt swap?
   (default yes — swapfile inside `/data`; only actually encrypted when
   `/data` itself is LUKS)"* — store as
   `$DATA_ENCRYPTED`/`$SWAP_SIZE`/`$SWAP_ENCRYPTED`. See
   `04_storage/README.md` for why the swap defaults changed from the old
   10G-plaintext setup.
4. **Confirm the hardware plan**: show the decision matrix result (which layers /
   GPU driver you intend to install or skip) and ask for a go-ahead.

> **Before the OS install even happens**: if this is a same-disk reinstall
> reusing an existing LUKS `/data` partition, tell the owner **not** to let
> the Ubuntu installer format that partition — see `04_storage/README.md`.
> This is the one step in the whole process that isn't recoverable by
> re-running a script.

---

## Step 3 — Decision matrix (what to install vs skip)

| Condition | Action |
|---|---|
| `HAS_NVIDIA = yes` | Install `nvidia-driver-550` (or the recommended driver via `ubuntu-drivers devices`). Apply the **NVIDIA-tuned `picom/config`** from `06_desktop-i3` as-is. Keep the `__GL_*` env in `.xprofile`. |
| `HAS_NVIDIA = no` | **Skip** the NVIDIA driver install entirely. Do **not** ship `06_desktop-i3`'s NVIDIA-tuned `picom/config` verbatim — instead let Regolith use its default compositor config (omit the user `~/.config/regolith3/picom/config`), or strip the NVIDIA-only lines (`xrender-sync-fence`, `__GL_*`). The `__GL_*` env in `.xprofile` is harmless but pointless — may be left or removed. |
| `HAS_AMD` / `HAS_INTEL_GPU` only | As "no NVIDIA": default picom, no proprietary driver (Mesa is built in). |
| `HAS_BATTERY = no` (desktop) | The `i3xrocks-battery` block renders nothing; installing it is harmless. Optional to skip. |
| `HAS_BATTERY = yes` (laptop) | Keep `i3xrocks-battery`. |
| HSL mouse **absent** | The `xinput` accel loop in `.xprofile` finds nothing and no-ops. Leave it; it's self-guarding. |
| Single monitor / no rotation | picom's `use-damage=false` / `unredir-if-possible=false` were chosen for a rotated panel; on a simple single-monitor box you may re-enable them for efficiency. Non-blocking. |

The general rule: **a layer or package that targets hardware the box lacks is
skipped or replaced with the generic default — never force-installed.**

---

## Step 4 — Apply layers (in order)

Apply in this order. For each, follow that layer's `README.md`
(Prerequisites → Apply → Verify), with the gating from Step 3 and the
parameters from Step 2.

**Per-station layer selection**: before each layer, check the station
config's `layers.<layer-name>` key (via `00_configs/load.sh`'s `cfg`,
default `"yes"`). `"no"` means the owner opted this station out — skip the
layer and say so in the report; don't ask again. The "always apply" notes
below describe the default, not an override of an explicit `"no"`. Every layer below has a matching `apply.sh` you can
run directly (or via `make <layer-name>` — see the root `Makefile`) once you
and the owner agree on the parameters; the README stays the explanation, the
script is its literal execution.

### `01_base` — always apply, first
- No hardware gating. Follow `01_base/README.md` verbatim. Everything else
  assumes `git`/`curl`/etc. already exist.

### `04_storage` — always apply, before anything storing under `/data`
- Follow `04_storage/README.md`, using
  `$DATA_ENCRYPTED`/`$SWAP_SIZE`/`$SWAP_ENCRYPTED` from Step 2. LUKS is
  **per-station** now (`storage.data_encrypted`) — a new station with an
  unencrypted `/data` skips every cryptsetup/crypttab step.
- Confirm the LUKS/data UUIDs in the active `00_configs/<name>.yaml` still match
  this disk (`blkid`) before trusting them — `apply.sh` hard-refuses UUIDs
  that don't exist on the machine, but re-derive and update the config
  rather than leaning on that guard.
- **No bind mounts here** — the old `/data/proj`→`/proj` bind is a
  per-station on-demand step (recipe in that README); don't apply it
  unasked, and remember `/proj/...` config paths only resolve once the
  owner applies it.

### `05_shell` — always apply
- No hardware gating. Follow `05_shell/README.md` verbatim (sources aliases
  from `../02_aliases/`, not its own copy). The default `sysadmin_dir` is
  `/data/sysadmin` — on the persistent `/data` partition, so `04_storage`
  must already be applied (it is, in this order).
- Note: its `name` helper needs `i3-msg`, installed by `06_desktop-i3`. Apply that
  layer too (or accept `name` is inert until a Regolith session exists).

### `06_desktop-i3` — apply (with GPU gating + background param)
- Follow `06_desktop-i3/README.md`.
- **GPU:** per the matrix — install `nvidia-driver-550` **only if** `HAS_NVIDIA`;
  otherwise skip it and skip/replace the user picom config.
- **Background:** copy `06_desktop-i3/files/backgrounds/imgBg_*.jpg` into
  `~/.local/share/backgrounds/`, then substitute the wallpaper using `$N`:
  ```bash
  WALLPAPER="$HOME/.local/share/backgrounds/imgBg_${N}.jpg"
  sed "s|{{WALLPAPER}}|$WALLPAPER|g" 06_desktop-i3/files/Xresources \
      > ~/.config/regolith3/Xresources
  ```
- Then `regolith-look refresh` and reload i3.

### `07_dev` — always apply
- Follow `07_dev/README.md`. `uv` + `pyenv` only — never install conda/
  miniconda/mambaforge/micromamba, even if asked; that's a deliberate,
  already-made decision, not an open question. Ask the owner before running
  the RVM step (`RVM_INSTALL=yes`) — confirm a project still needs it first.

### `08_ai-agent-tools` — always apply
- Follow `08_ai-agent-tools/README.md`. Before enabling the personal-agent
  systemd services, flag the "no auth / `--public`" pattern documented there
  and get an explicit go-ahead — don't silently carry forward a
  loopback-only assumption onto a possibly more-open network.

### `09_docker` — apply with `$DOCKER_DATA_ROOT` from Step 2
- Follow `09_docker/README.md`. Apply after `04_storage` (the default data
  root lives under `/data`).

### `10_embedded-hw` — **never apply by default, never ask about it**
- Reference-only (see its `README.md`). Only touch this layer if the owner
  explicitly names it by asking for it later — not part of this pass, not a
  Step 2 question, not in `make all`.

### `11_tailscale` — always apply
- Follow `11_tailscale/README.md`. `tailscale up` is an interactive login —
  hand off to the owner for that one step, don't attempt to script it.

### `12_services` — always apply
- Follow `12_services/README.md`. Confirm `secrets/cameras/soil.env` was
  restored (see `secrets/README.md`) before enabling the soil cron line —
  it'll fail loudly at 12:15 otherwise.
- Network services (absorbed from the former `15-toolset`): `dnsmasq`/`sssd`
  end up *enabled but not running* and `hostapd` stays *masked* — that is
  correct (they need host-specific/secret config first; see that README's
  Machine-specific values). Do not invent configs to make them start.

### `13_misc` — always apply
- Follow `13_misc/README.md`. Wi-Fi re-join and the English/Hebrew input-
  source toggle are manual GUI steps by design — don't try to script those.

### `14_udev` — **never apply by default, never ask about it**
- Device-specific udev rules (same treatment as `10_embedded-hw`): only
  touch this layer if the owner explicitly asks for it — not part of this
  pass, not a Step 2 question, not in `make all`.

### `15_firefox` — manual, after Firefox has run once
- Not in `make all` (no apply.sh — it has `backup.sh`/`restore.sh` instead)
  and only meaningful when the repo arrived as a **working-tree copy**: the
  `bookmarks/` snapshots are git-ignored, so a bare clone has nothing to
  restore. If `15_firefox/bookmarks/` is present, remind the owner at the
  end of the build: launch Firefox once, close it, run
  `15_firefox/restore.sh`, then finish the one-time import inside Firefox
  (the script prints the exact clicks — there is no non-interactive path).

---

## Step 5 — Verify & report

- Run each applied layer's **Verify** block; collect pass/fail.
- Confirm the chosen wallpaper resolved: `xrdb -query | grep -i wallpaper` shows
  `.../imgBg_${N}.jpg`.
- Confirm `docker info | grep "Docker Root Dir"` matches `$DOCKER_DATA_ROOT`.
- Confirm `secrets/` was actually restored onto this box (not just present
  in the repo clone) before reporting `12_services`/`aliases` as fully
  working — `ssh-add -l`, and check the soil cron job isn't about to fail
  for a missing `secrets/cameras/soil.env`.
- Summarize for the owner: layers applied, layers/packages skipped and why
  (cite the hardware condition), and any Verify failures with the raw output.
