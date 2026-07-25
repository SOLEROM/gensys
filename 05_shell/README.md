# 05_shell — zsh + oh-my-zsh + personal aliases & helpers

## Purpose

Reproduce the interactive shell environment:

- **zsh** as the login shell, with **oh-my-zsh** (theme `risto`, plugins
  `git sudo dirhistory safe-paste thefuck zsh-autosuggestions`).
- The personal alias/function set sourced from `alias.bashrc`.
- The two flagship helpers:
  - **`tit <text>`** — set the terminal window/tab title.
  - **`name <text>`** — rename the *current i3 workspace* to `"<num>: <num>.<text>"`.

The shell config is shared between bash and zsh: `alias.bashrc` takes a shell
argument (`bash`/`zsh`) and branches where the two differ (prompt, `tit`).

---

## Prerequisites

Run on the fresh box before placing files:

```bash
# packages the shell layer needs
sudo apt update
sudo apt install -y zsh git jq xclip vim
#   jq      → required by name/wrsp_name.sh (parses i3 workspace JSON)
#   xclip   → required by the c2f / clip2file helper
#   i3-msg  → NOT here; comes from layer 06_desktop-i3 (name needs it)

# oh-my-zsh (unattended; RUNZSH=no keeps it from launching a subshell)
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# make zsh the login shell — via sudo: plain chsh prompts for the login
# password, which an unattended run can't answer
sudo chsh -s "$(command -v zsh)" "$(id -un)"

# extra plugins this host actually uses beyond stock oh-my-zsh (git, sudo,
# dirhistory, safe-paste ship with oh-my-zsh; these two don't):
git clone https://github.com/zsh-users/zsh-autosuggestions \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
sudo apt install -y thefuck
```

The `risto` theme and the `git`/`sudo`/`dirhistory`/`safe-paste` plugins ship
with oh-my-zsh — no extra install for those four.

---

## Files in this layer

**Alias/scripts source moved to top-level `02_aliases/`** (one combined,
repo-owned source — see `../02_aliases/`). This layer now only owns the zsh
entrypoint itself.

`<sysadmin_dir>` below is **`station.sysadmin_dir` from the station config**
(`../00_configs/<name>.yaml`), default `/data/sysadmin` — one knob per
station; every target path, the rendered `alias.bashrc` (`$sys`) and the
rendered `.zshrc` source line all follow it. The default lives on the
persistent `/data` partition (survives reinstalls), so **`04_storage` must
be applied before this layer** — already the `Makefile`/`CLAUDE_CONSUMER.md`
order.

| repo path | target on fresh box |
|---|---|
| `files/zshrc` | `~/.zshrc` (rendered — `{{SYSADMIN_DIR}}`) |
| `../02_aliases/alias.bashrc` | `<sysadmin_dir>/00_bashrc/alias.bashrc` (rendered — `{{GENSYS_REPO_ROOT}}`, `{{SYSADMIN_DIR}}`) |
| `../02_aliases/bashrc_colors` | `<sysadmin_dir>/00_bashrc/bashrc_colors` |
| `../00_configs/<station>_aliases` (next to the active station yaml, if the station has one) | `<sysadmin_dir>/00_bashrc/station_aliases` (rendered — same tokens as `alias.bashrc`; **removed** when the active station has no companion) |
| `../02_aliases/scripts/titZSH.sh` | `<sysadmin_dir>/01_scripts/shell/titZSH.sh` |
| `../02_aliases/scripts/tit.sh` | `<sysadmin_dir>/01_scripts/shell/tit.sh` |
| `../02_aliases/scripts/wrsp_name.sh` | `<sysadmin_dir>/01_scripts/shell/wrsp_name.sh` |
| `../02_aliases/scripts/wrsp_addNewNamed.sh` | `<sysadmin_dir>/01_scripts/shell/wrsp_addNewNamed.sh` |
| `../02_aliases/scripts/gitScripts/*` | `<sysadmin_dir>/01_scripts/gitScripts/*` |
| `../02_aliases/scripts/tmux/lisTree.sh` | `<sysadmin_dir>/01_scripts/tmux/lisTree.sh` |
| `../02_aliases/scripts/maps/mapls.sh` | `<sysadmin_dir>/01_scripts/maps/mapls.sh` |
| `../02_aliases/scripts/shell/setStaticIPbyUUID.sh` | `<sysadmin_dir>/01_scripts/shell/setStaticIPbyUUID.sh` |
| `../02_aliases/scripts/multiScreen/*` | `<sysadmin_dir>/01_scripts/multiScreen/*` (rendered — `{{MON_*}}` from `desktop.monitors.*`) |
| `../03_help/welcome`, `../03_help/h_*` | `<sysadmin_dir>/help/*` (the `h`/`hh`/`h.*` pages) |

> **The layout *inside* `<sysadmin_dir>` is mandatory, not cosmetic.**
> `alias.bashrc`'s `$sys` (rendered from `{{SYSADMIN_DIR}}`) derives
> `bashScripts="$sys/01_scripts"`, `bashColor`, `bashAlias`, `helpRoot` from
> it, and the helpers resolve their scripts through `$bashScripts` — so the
> `00_bashrc/01_scripts/help` sub-structure is fixed. The *root* is the
> per-station knob: edit `station.sysadmin_dir` and re-run this layer.
> Where the source lives in *this repo* (`02_aliases/` instead of
> `05_shell/files/`) is the one intentional exception to "each layer is
> self-contained" — aliases are cross-cutting by nature, and the owner
> wants one canonical copy, not N near-duplicates.

---

## Apply

```bash
# 0. per-station parameters (00_configs/load.sh + the station yaml)
SYSADMIN_DIR="$(cfg station.sysadmin_dir /data/sysadmin)"
MON_LAPTOP="$(cfg desktop.monitors.laptop eDP-1)"
MON_WIDE="$(cfg desktop.monitors.wide DP-1)"
MON_TOP="$(cfg desktop.monitors.top HDMI-1)"

# 1. directory scaffold the configs expect. The default root is on /data,
# whose mount root is root-owned on a fresh box — take ownership of the
# base dir once, then plain mkdirs work (apply.sh does the same):
if [ ! -d "$SYSADMIN_DIR" ] && ! mkdir -p "$SYSADMIN_DIR" 2>/dev/null; then
  sudo mkdir -p "$SYSADMIN_DIR"
  sudo chown "$(id -un):$(id -gn)" "$SYSADMIN_DIR"
fi
mkdir -p "$SYSADMIN_DIR/00_bashrc" \
         "$SYSADMIN_DIR/01_scripts/shell" \
         "$SYSADMIN_DIR/01_scripts/gitScripts" \
         "$SYSADMIN_DIR/01_scripts/tmux" \
         "$SYSADMIN_DIR/01_scripts/maps" \
         "$SYSADMIN_DIR/01_scripts/multiScreen" \
         "$SYSADMIN_DIR/help"

# 2. drop the zsh entrypoint (run from this layer's files/ dir) — its
# alias.bashrc source line carries {{SYSADMIN_DIR}}. Back up any existing
# ~/.zshrc first (installers like nvm append to it), then render:
[ -f ~/.zshrc ] && cp ~/.zshrc ~/.zshrc.bak.$(date +%Y%m%d%H%M%S)
render_template zshrc ~/.zshrc "SYSADMIN_DIR=$SYSADMIN_DIR"

# 2a. bash entrypoint — bash shares the same alias.bashrc (it branches on
# its shell argument); append the source line once, idempotently:
grep -qF "00_bashrc/alias.bashrc" ~/.bashrc 2>/dev/null || printf '\n%s\n' \
  "[ -f \"$SYSADMIN_DIR/00_bashrc/alias.bashrc\" ] && source \"$SYSADMIN_DIR/00_bashrc/alias.bashrc\" bash" >> ~/.bashrc

# 3. drop the shared alias/scripts source (run from ../02_aliases/)
# alias.bashrc hardcodes {{GENSYS_REPO_ROOT}} (secrets/ssh-key paths) and
# {{SYSADMIN_DIR}} ($sys) — render_template (00_configs/load.sh) substitutes
# this repo's real location and this station's configured dir.
render_template alias.bashrc "$SYSADMIN_DIR/00_bashrc/alias.bashrc" \
  "GENSYS_REPO_ROOT=$GENSYS_REPO_ROOT" "SYSADMIN_DIR=$SYSADMIN_DIR"
cp bashrc_colors             "$SYSADMIN_DIR/00_bashrc/bashrc_colors"

# 3a. the station's OWN aliases, if it has any: <station>_aliases next to
# the active yaml (00_configs/README.md "Separation contract";
# ${CONFIG_FILE%.yaml}_aliases covers flat and per-station-subfolder
# layouts alike). Installed under the FIXED name station_aliases —
# alias.bashrc's last line sources $bashRoot/station_aliases if present,
# so it needs no station knowledge. Removed when the station has no
# companion, so re-runs converge instead of keeping another station's
# aliases around.
STATION_ALIASES="${CONFIG_FILE%.yaml}_aliases"
if [ -f "$STATION_ALIASES" ]; then
  render_template "$STATION_ALIASES" "$SYSADMIN_DIR/00_bashrc/station_aliases" \
    "GENSYS_REPO_ROOT=$GENSYS_REPO_ROOT" "SYSADMIN_DIR=$SYSADMIN_DIR"
else
  rm -f "$SYSADMIN_DIR/00_bashrc/station_aliases"
fi
cp scripts/titZSH.sh         "$SYSADMIN_DIR/01_scripts/shell/titZSH.sh"
cp scripts/tit.sh            "$SYSADMIN_DIR/01_scripts/shell/tit.sh"
cp scripts/wrsp_name.sh      "$SYSADMIN_DIR/01_scripts/shell/wrsp_name.sh"
cp scripts/wrsp_addNewNamed.sh "$SYSADMIN_DIR/01_scripts/shell/wrsp_addNewNamed.sh"
cp scripts/shell/setStaticIPbyUUID.sh "$SYSADMIN_DIR/01_scripts/shell/setStaticIPbyUUID.sh"
cp scripts/gitScripts/*.sh   "$SYSADMIN_DIR/01_scripts/gitScripts/"
cp scripts/tmux/lisTree.sh   "$SYSADMIN_DIR/01_scripts/tmux/lisTree.sh"
cp scripts/maps/mapls.sh     "$SYSADMIN_DIR/01_scripts/maps/mapls.sh"
# multiScreen scripts carry {{MON_*}} tokens — rendered per station
# (thisName.sh has none; render_template passes it through unchanged)
for f in scripts/multiScreen/*.sh; do
  render_template "$f" "$SYSADMIN_DIR/01_scripts/multiScreen/$(basename "$f")" \
    "MON_LAPTOP=$MON_LAPTOP" "MON_WIDE=$MON_WIDE" "MON_TOP=$MON_TOP"
done

# 3b. drop the help pages (run from ../03_help/) — backs h / hh / h.*
cp welcome h_*               "$SYSADMIN_DIR/help/"

# 4. make the invoked (not sourced) scripts executable
chmod +x "$SYSADMIN_DIR/01_scripts/shell/wrsp_name.sh" \
         "$SYSADMIN_DIR/01_scripts/shell/wrsp_addNewNamed.sh" \
         "$SYSADMIN_DIR/01_scripts/shell/setStaticIPbyUUID.sh" \
         "$SYSADMIN_DIR/01_scripts/gitScripts/"*.sh \
         "$SYSADMIN_DIR/01_scripts/tmux/lisTree.sh" \
         "$SYSADMIN_DIR/01_scripts/maps/mapls.sh" \
         "$SYSADMIN_DIR/01_scripts/multiScreen/"*.sh

# 5. load it
exec zsh   # or: source ~/.zshrc
```

### How `tit` works

Defined in `alias.bashrc`:

```sh
function tit() { source $bashScripts/shell/titZSH.sh $1 ; }   # zsh branch
alias    tit='source $bashScripts/shell/tit.sh $1'            # bash branch
```

`titZSH.sh` emits the OSC title escape directly:

```sh
echo -n -e "\033]0;$tit\007"
```

`tit.sh` (bash) installs a `precmd`/`PROMPT_COMMAND` hook so the title persists
across prompts. **`DISABLE_AUTO_TITLE="true"` in `.zshrc` is required** — without
it oh-my-zsh overwrites the title on every command.

### How `name` works

Defined in `alias.bashrc`:

```sh
function i3-name() { $bashScripts/shell/wrsp_name.sh  $1 ; }
alias name="i3-name"
```

`wrsp_name.sh` queries i3 for the focused workspace number and renames it:

```sh
curNum=$(i3-msg -t get_workspaces | jq '.[] | select(.focused==true).num')
i3-msg "rename workspace to \"$curNum: $curNum.$1\""
```

So inside workspace 3, `name web` → workspace becomes `3: 3.web`. **Requires
`i3-msg` (layer `06_desktop-i3`) and `jq`.** Outside an i3 session it simply fails — harmless.

### How `newname` works

Same pattern, but opens a **new** workspace instead of renaming the current
one:

```sh
function i3-newname() { $bashScripts/shell/wrsp_addNewNamed.sh  $1 ; }
alias newname="i3-newname"
```

```sh
nextWrkNum=$(i3-msg -t get_workspaces | jq 'map(.num) | max | .+1')
i3-msg workspace $nextWrkNum "$nextWrkNum.$1"
```

`newname web` opens workspace `<max+1>` pre-labeled `<n>.web`. Same
`i3-msg`/`jq` requirement as `name`.

`multiScreen/scrLay0.sh`/`scrLay1.sh`/`scrLay2.sh`/`thisName.sh` (moves i3
workspaces to a specific physical monitor by output name) are installed
here too but **not** aliased. Their monitor names are per-station config
(`desktop.monitors.laptop/wide/top` in `../00_configs/<name>.yaml`, rendered
into the scripts at install time via `{{MON_*}}` tokens) — fill them in
from `xrandr --listmonitors` on the target box.

---

## Verify

```bash
# paths below assume the default sysadmin_dir (/data/sysadmin) — swap in
# your station's station.sysadmin_dir if you changed it
zsh -n  ~/.zshrc                                     # parses clean
bash -n /data/sysadmin/00_bashrc/alias.bashrc        # parses clean
bash -n /data/sysadmin/01_scripts/shell/wrsp_name.sh
bash -n /data/sysadmin/01_scripts/shell/wrsp_addNewNamed.sh
echo $ZSH_THEME            # → risto   (after sourcing)
type tit name newname       # all defined
# stations WITH a <station>_aliases companion only (e.g. myDevX1):
bash -n /data/sysadmin/00_bashrc/station_aliases     # installed + parses clean
alias mini0                # (or any alias from the companion) → resolves
# stations WITHOUT one: the file must be absent, sourcing still exits 0
[ ! -f /data/sysadmin/00_bashrc/station_aliases ] && echo no-companion-ok
h                          # prints the help index (03_help/welcome)
tit hello                  # terminal title becomes "hello"
# inside an i3 session:
name foo                   # focused workspace label gains ".foo"
newname bar                 # new workspace opens, pre-labeled ".bar"
```

---

## Machine-specific values

- **Sysadmin folder location** — `station.sysadmin_dir` in
  `../00_configs/<name>.yaml` (default `/data/sysadmin` — on the persistent
  `/data` partition, so the vendored copies survive a reinstall; needs
  `04_storage` applied first). One knob: the scaffold, every copy target,
  `alias.bashrc`'s `$sys` and `.zshrc`'s source line are all rendered from
  it. A station that keeps the folder elsewhere just edits that one config
  value and re-runs this layer.
- **Station-specific aliases** — a station may keep a `<station>_aliases`
  companion next to its yaml in `../00_configs/` (myDevX1 does; see
  `00_configs/README.md`'s "Separation contract" and `../02_aliases/README.md`'s
  "General vs. host-specific"). `apply.sh` installs it (rendered, same
  tokens as `alias.bashrc`) to the fixed path
  `<sysadmin_dir>/00_bashrc/station_aliases`, which `alias.bashrc` sources
  **last** — after `$sys`/`$data`/`$proj`/`$tasks_script` are set — in both
  bash and zsh. No companion → no file installed (and a stale one from a
  previous station build is removed), sourcing skips silently.
- **Username / home path.** Not hardcoded — the home-relative pieces
  resolve through `$HOME` (`PROJROOT="$HOME/proj"`, `~/.zshrc`), and the
  default `sysadmin_dir` is the user-neutral `/data/sysadmin` (chowned to
  the invoking user by the scaffold step). It follows whichever account
  applies the layer, same as the wallpaper substitution in `06_desktop-i3`.
- **`home` alias.** `alias.bashrc` defines `alias home='cc ; tit projHOME ; cd
  $PROJROOT ; ls'` — a personal "jump to `$PROJROOT` and clear the screen"
  shortcut. The name is just a habit; rename it in your own copy if you'd
  prefer something else — it has no bearing on the OS username.
- **`DISABLE_AUTO_TITLE="true"`** must stay set (it appears twice in `.zshrc`) or
  `tit` is clobbered by oh-my-zsh.
- **No conda/miniconda/mambaforge/micromamba init in `.zshrc`** — dropped by
  owner decision; see `07_dev/README.md`. `.zshrc`'s nvm block is the one
  runtime-manager hook kept here; `07_dev` appends rustup/pyenv/uv/rvm init
  the same way.
- **Deferred-layer references (leave as-is; they no-op until those layers
  land):** `jupi`, `sshh`, `cld` work once `07_dev` (jupyter),
  `secrets/hosts.env` (`DEVBOARD_IP`/`DEVBOARD_PASS`), and `08_ai-agent-tools`
  (claude) respectively are in place. `oo` (Obsidian) works once `01_base`
  has run. `h`/`hh`/`h.*` are no longer dangling — the pages were mined
  into `../03_help/` and installed by this layer (see that folder's
  README).
- **`{{PLACEHOLDER}}` tokens** — three families, all substituted by
  `apply.sh` at copy time, never hand-edited: `{{GENSYS_REPO_ROOT}}`
  (`alias.bashrc`'s `secrets/hosts.env` sourcing and `git.solerom`/
  `git.trip` ssh-add paths; the repo clone's real location, computed live
  via `00_configs/load.sh`), `{{SYSADMIN_DIR}}` (`alias.bashrc`'s `$sys` and
  `.zshrc`'s source line, from `station.sysadmin_dir`), and `{{MON_*}}`
  (the multiScreen scripts' monitor output names, from
  `desktop.monitors.*`).
- **GitLab helper removed 2026-07-24** — the old
  `gitScripts/newGitlabRepoCreate.sh` (+ `lab.new` alias, `GITLAB_*` env
  vars) targeted the now-obsolete local LAN GitLab; deleted
  outright, nothing to configure.

---

## Origin

- `files/zshrc` ← `~/.zshrc` (this layer's own snapshot; conda block removed,
  plugin list updated — don't blind-resync this one, see the diffs above).
- Everything under `../02_aliases/` ← see `../02_aliases/README.md` for that
  folder's own origin (two merged lineages: this repo's prior `alias.bashrc`
  capture + `/data/sysadmin/00_bashrc/solov.bashrc`, plus mined scripts from
  `/data/sysadmin/ubu20`/`ubu24`).
