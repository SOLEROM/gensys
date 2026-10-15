#!/usr/bin/env bash
# 05_shell/apply.sh — mirrors this layer's README.md Prerequisites + Apply.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../00_configs/load.sh"

# Where the vendored 02_aliases/scripts/help pages land ($sys in alias.bashrc).
# One knob per station (00_configs/<name>.yaml station.sysadmin_dir); every
# path below and the rendered alias.bashrc/zshrc follow it. Default lives on
# the persistent /data partition (04_storage) — survives reinstalls.
SYSADMIN_DIR="${SYSADMIN_DIR:-$(cfg station.sysadmin_dir /data/sysadmin)}"

# Monitor output names for the multiScreen scrLay* helpers — per-station,
# from 00_configs/<name>.yaml desktop.monitors (xrandr --listmonitors).
MON_LAPTOP="${MON_LAPTOP:-$(cfg desktop.monitors.laptop eDP-1)}"
MON_WIDE="${MON_WIDE:-$(cfg desktop.monitors.wide DP-1)}"
MON_TOP="${MON_TOP:-$(cfg desktop.monitors.top HDMI-1)}"

echo "==> packages"
sudo apt-get update
sudo apt-get install -y zsh git jq xclip vim thefuck

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "==> oh-my-zsh"
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi
# chsh prompts for the login password — useless in an unattended run. sudo
# is already pre-authorized (make deps), so change the shell through it and
# only fall back to the interactive form if that path is unavailable.
sudo chsh -s "$(command -v zsh)" "$(id -un)" || chsh -s "$(command -v zsh)" || \
  echo "WARNING: could not set zsh as login shell — run: chsh -s $(command -v zsh)" >&2

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

echo "==> scaffold ($SYSADMIN_DIR)"
# The default sysadmin dir sits on /data, whose mount root is root-owned on
# a fresh box — create the base dir with sudo once and hand it to the
# invoking user, so the plain mkdir/cp below (and future re-runs) just work.
if ! mkdir -p "$SYSADMIN_DIR" 2>/dev/null || [ ! -w "$SYSADMIN_DIR" ]; then
  sudo mkdir -p "$SYSADMIN_DIR"
  sudo chown -R "$(id -un):$(id -gn)" "$SYSADMIN_DIR"
fi
mkdir -p "$SYSADMIN_DIR/00_bashrc" \
         "$SYSADMIN_DIR/01_scripts/shell" \
         "$SYSADMIN_DIR/01_scripts/gitScripts" \
         "$SYSADMIN_DIR/01_scripts/tmux" \
         "$SYSADMIN_DIR/01_scripts/maps" \
         "$SYSADMIN_DIR/01_scripts/multiScreen" \
         "$SYSADMIN_DIR/help"

echo "==> zsh entrypoint"
# zshrc sources alias.bashrc from {{SYSADMIN_DIR}} — rendered, not copied.
# Back up any existing ~/.zshrc first: installers (nvm, Claude Code's PATH
# line) append to it, and a re-run of this layer would silently discard that.
[ -f ~/.zshrc ] && cp ~/.zshrc ~/.zshrc.bak."$(date +%Y%m%d%H%M%S)"
render_template "$HERE/files/zshrc" ~/.zshrc "SYSADMIN_DIR=$SYSADMIN_DIR"

echo "==> bash entrypoint"
# bash gets the same shared aliases (alias.bashrc branches on its shell
# argument) — without this line, bash logins have no aliases at all.
BASH_HOOK="[ -f \"$SYSADMIN_DIR/00_bashrc/alias.bashrc\" ] && source \"$SYSADMIN_DIR/00_bashrc/alias.bashrc\" bash"
touch ~/.bashrc
grep -qF "00_bashrc/alias.bashrc" ~/.bashrc || printf '\n%s\n' "$BASH_HOOK" >> ~/.bashrc

echo "==> shared alias/scripts source (../02_aliases/)"
ALIASES="$HERE/../02_aliases"
# alias.bashrc hardcodes {{GENSYS_REPO_ROOT}} (secrets sourcing, ssh-add
# paths) and {{SYSADMIN_DIR}} ($sys) — rendered here with this repo clone's
# actual location (computed live by 00_configs/load.sh) and this station's
# configured sysadmin dir, not hand-edited.
render_template "$ALIASES/alias.bashrc" "$SYSADMIN_DIR/00_bashrc/alias.bashrc" \
  "GENSYS_REPO_ROOT=$GENSYS_REPO_ROOT" "SYSADMIN_DIR=$SYSADMIN_DIR"
cp "$ALIASES/bashrc_colors"              "$SYSADMIN_DIR/00_bashrc/bashrc_colors"

# Station-specific aliases companion (00_configs/README.md "Separation
# contract"): <station>_aliases sits next to the active station yaml —
# 00_configs/myClean_aliases flat, 00_configs/myDevX1/myDevX1_aliases in a
# per-station subfolder; ${CONFIG_FILE%.yaml}_aliases covers both. Installed
# under the FIXED name station_aliases so alias.bashrc's tail source line
# needs no station knowledge, rendered with the same tokens as alias.bashrc
# (pass-through when the file carries none). Removed when the active station
# has no companion — a re-run converges instead of keeping another station's
# aliases around.
STATION_ALIASES=""
[ -n "${CONFIG_FILE:-}" ] && STATION_ALIASES="${CONFIG_FILE%.yaml}_aliases"
if [ -n "$STATION_ALIASES" ] && [ -f "$STATION_ALIASES" ]; then
  echo "==> station aliases (${STATION_ALIASES#"$GENSYS_REPO_ROOT"/} → 00_bashrc/station_aliases)"
  render_template "$STATION_ALIASES" "$SYSADMIN_DIR/00_bashrc/station_aliases" \
    "GENSYS_REPO_ROOT=$GENSYS_REPO_ROOT" "SYSADMIN_DIR=$SYSADMIN_DIR"
else
  rm -f "$SYSADMIN_DIR/00_bashrc/station_aliases"
fi
cp "$ALIASES/scripts/titZSH.sh"          "$SYSADMIN_DIR/01_scripts/shell/titZSH.sh"
cp "$ALIASES/scripts/tit.sh"             "$SYSADMIN_DIR/01_scripts/shell/tit.sh"
cp "$ALIASES/scripts/wrsp_name.sh"       "$SYSADMIN_DIR/01_scripts/shell/wrsp_name.sh"
cp "$ALIASES/scripts/wrsp_addNewNamed.sh" "$SYSADMIN_DIR/01_scripts/shell/wrsp_addNewNamed.sh"
# multiScreen scripts carry {{MON_*}} tokens — rendered per station
# (thisName.sh has no tokens; render_template passes it through unchanged)
for f in "$ALIASES/scripts/multiScreen/"*.sh; do
  render_template "$f" "$SYSADMIN_DIR/01_scripts/multiScreen/$(basename "$f")" \
    "MON_LAPTOP=$MON_LAPTOP" "MON_WIDE=$MON_WIDE" "MON_TOP=$MON_TOP"
done
cp "$ALIASES/scripts/shell/setStaticIPbyUUID.sh" "$SYSADMIN_DIR/01_scripts/shell/setStaticIPbyUUID.sh"
cp "$ALIASES/scripts/gitScripts/"*.sh    "$SYSADMIN_DIR/01_scripts/gitScripts/"
cp "$ALIASES/scripts/gitScripts/"*.prompt.md "$SYSADMIN_DIR/01_scripts/gitScripts/"  # git-brief.sh reads its prompt from beside itself
cp "$ALIASES/scripts/tmux/lisTree.sh"    "$SYSADMIN_DIR/01_scripts/tmux/lisTree.sh"
cp "$ALIASES/scripts/maps/mapls.sh"      "$SYSADMIN_DIR/01_scripts/maps/mapls.sh"

chmod +x "$SYSADMIN_DIR/01_scripts/shell/wrsp_name.sh" \
         "$SYSADMIN_DIR/01_scripts/shell/wrsp_addNewNamed.sh" \
         "$SYSADMIN_DIR/01_scripts/shell/setStaticIPbyUUID.sh" \
         "$SYSADMIN_DIR/01_scripts/gitScripts/"*.sh \
         "$SYSADMIN_DIR/01_scripts/tmux/lisTree.sh" \
         "$SYSADMIN_DIR/01_scripts/maps/mapls.sh" \
         "$SYSADMIN_DIR/01_scripts/multiScreen/"*.sh

echo "==> help pages (../03_help/ → $SYSADMIN_DIR/help/, behind h/hh/h.*)"
cp "$HERE/../03_help/welcome" "$HERE/../03_help/"h_* "$SYSADMIN_DIR/help/"

echo "==> done. Run 'exec zsh' (or open a new terminal) to load it."
