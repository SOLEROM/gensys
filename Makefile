# Makefile — scripted install path, alternative to the agent-driven
# CLAUDE_CONSUMER.md path. Each layer target just runs that layer's apply.sh
# (the literal execution of that layer's README.md Apply section — the
# README stays the human-readable explanation, apply.sh is its script).
#
# `deps` is the bootstrap rule (absorbed from the old deps.sh, 2026-07-24):
# base apt tooling + Claude Code itself + a seeded ~/.claude/settings.json
# (sudo pre-allowed, so the build agent runs unattended), idempotent. install.sh runs it
# first thing; `all` depends on it too, so a bare `make all` is also
# self-sufficient. The one thing this rule can't install is `make` itself —
# install.sh apt-installs that single package if missing before calling in.
#
# Every apply.sh sources 00_configs/load.sh, which reads its per-machine
# defaults from a station config file:
#   GENSYS_CONFIG=00_configs/myDevX2.yaml   which station's config to build (see 00_configs/README.md)
# With GENSYS_CONFIG unset, load.sh auto-selects the single station yaml under
# 00_configs/ — flat or in a per-station subfolder like 00_configs/myDevX1/ —
# if there's exactly one (TEMPLATE.yaml aside) and hard-errors if there are
# several — it never guesses between stations.
#
# The station config's `layers:` block picks WHICH layers `all` applies
# ("no" = skip; omitted/"yes" = apply). Explicit rules (`make 08_ai-agent-tools`)
# bypass the toggle — naming a layer is the opt-in.
#
# The env vars below still override the config file for a one-off run, same
# defaults as the READMEs / CLAUDE_CONSUMER.md document:
#   N=1                        wallpaper number (06_desktop-i3)
#   HAS_NVIDIA=yes|no          default: autodetected via lspci (06_desktop-i3)
#   NVIDIA_DRIVER_VERSION=550   (06_desktop-i3)
#   DOCKER_DATA_ROOT=/data/dockerDATA   (09_docker)
#   DATA_ENCRYPTED=yes|no      is /data LUKS-encrypted (04_storage)
#   SWAP_SIZE=16G SWAP_ENCRYPTED=yes    (04_storage)
#   SYSADMIN_DIR=/data/sysadmin         where 05_shell/11_tailscale vendor scripts
#   RVM_INSTALL=no             set yes only if a project still needs ruby-3.0.0 (07_dev)
#
# Usage:
#   ./install.sh          # make deps, then print the hand-off options + rule list
#   make deps             # bootstrap only: base apt tooling + Claude Code
#   make list             # print every rule (same list install.sh shows)
#   make all              # deps + every layer, in order (10_embedded-hw/14_udev/17_gdrive excluded)
#   make 04_storage       # one layer at a time
#   DOCKER_DATA_ROOT=/mnt/bkData/docker make 09_docker
#   GENSYS_CONFIG=00_configs/myDevX2.yaml make all   # build a different station

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.ONESHELL:

# dependency order: 04_storage before anything storing under /data (docker
# data-root, agent dirs, the default sysadmin_dir /data/sysadmin that
# 05_shell/11_tailscale install into); 05_shell before 06_desktop-i3 (per 05_shell/
# README.md's ordering note); everything else has no hard ordering
# constraint beyond "01_base first" for packages. Bind mounts (the old
# /data/proj→/proj) are NOT applied by any layer — on-demand per station,
# see 04_storage/README.md.
LAYERS := 01_base 04_storage 05_shell 06_desktop-i3 07_dev 08_ai-agent-tools \
          09_docker 11_tailscale 12_services 13_misc

.PHONY: all deps list $(LAYERS) 14_udev 10_embedded-hw 17_gdrive

# `all` walks LAYERS in order, honoring the station config's layers.<name>
# toggles (default "yes"). Not prerequisites anymore — a skip decision needs
# the config, which make can't read at parse time.
all: deps
	@source 00_configs/load.sh
	export GENSYS_CONFIG="$$CONFIG_FILE"   # pin the resolved config for every child apply.sh
	for l in $(LAYERS); do
	  if [ "$$(cfg "layers.\"$$l\"" yes)" = "yes" ]; then
	    echo "=== $$l ==="
	    ./$$l/apply.sh
	  else
	    echo "=== skipping $$l (layers.$$l: \"no\" in $$CONFIG_FILE) ==="
	  fi
	done
	echo "=== make all done (10_embedded-hw + 14_udev + 17_gdrive excluded by design — run them explicitly if ever wanted) ==="

# every layer rule is the same shape: run that layer's apply.sh.
# 14_udev shares the shape but is intentionally NOT in LAYERS/`all` —
# device-specific udev rules, optional/on-demand only (see 14_udev/README.md).
$(LAYERS) 14_udev:
	./$@/apply.sh

# ---- deps — bootstrap (was deps.sh; folded in here 2026-07-24) ----------
# Installs the minimum needed to (a) operate this repo at all (git, curl,
# gnupg) and (b) install Claude Code itself, since the rest of the setup
# (CLAUDE_CONSUMER.md, or `make all`) is driven by/through it. Idempotent —
# safe to re-run; skips apt entirely when the tooling is already present.
# Does not touch anything layer-specific (that's 01_base and friends); this
# only exists to get `claude` running on a bare box. First-run auth is an
# interactive browser OAuth flow — this rule stops at "claude is installed
# and runnable", it cannot log in for you.
deps:
	@log() { printf '\n==> %s\n' "$$1"; }
	if [[ "$$(uname -s)" != "Linux" ]]; then
	  echo "make deps only supports Linux (Ubuntu 24.04 target)." >&2
	  exit 1
	fi
	# ---- 1. base apt tooling ----
	# curl            -> fetches the Claude Code installer
	# ca-certificates -> TLS for that fetch and every apt repo added later
	# git             -> this repo, plus the multi-repo git helpers in 02_aliases/
	# gnupg           -> dearmoring apt keyrings in later layers (docker, tailscale, ...)
	# (make           -> already running this rule; kept in the install list anyway)
	if command -v curl >/dev/null && command -v git >/dev/null \
	   && command -v gpg >/dev/null && dpkg -s ca-certificates >/dev/null 2>&1; then
	  log "base tooling already present (curl, ca-certificates, git, gnupg) — apt skipped"
	else
	  log "apt update + base tooling (curl, ca-certificates, git, make, gnupg)"
	  sudo apt-get update
	  sudo apt-get install -y --no-install-recommends \
	    curl \
	    ca-certificates \
	    git \
	    make \
	    gnupg
	fi
	# ---- 2. Claude Code (native installer — self-contained, no Node required) ----
	if command -v claude >/dev/null 2>&1; then
	  log "claude already on PATH: $$(command -v claude) ($$(claude --version 2>/dev/null || echo unknown))"
	else
	  log "installing Claude Code (native installer)"
	  curl -fsSL https://claude.ai/install.sh | bash
	fi
	# ---- 3. make sure ~/.local/bin is on PATH, now and in future shells ----
	# The native installer places the binary at ~/.local/share/claude/versions/<v>/
	# and symlinks it from ~/.local/bin/claude, but does NOT edit shell rc files.
	LOCAL_BIN="$$HOME/.local/bin"
	case ":$$PATH:" in
	  *":$$LOCAL_BIN:"*) : ;;
	  *)
	    export PATH="$$LOCAL_BIN:$$PATH"
	    for rc in "$$HOME/.bashrc" "$$HOME/.zshrc"; do
	      [ -f "$$rc" ] || continue
	      grep -qF "$$LOCAL_BIN" "$$rc" 2>/dev/null || \
	        printf '\nexport PATH="%s:$$PATH"\n' "$$LOCAL_BIN" >> "$$rc"
	    done
	    log "added $$LOCAL_BIN to PATH (this shell, and appended to .bashrc/.zshrc if present)"
	    ;;
	esac
	# ---- 4. seed Claude Code settings (sudo pre-allowed) ----
	# The build-agent session starts right after deps — long before layer 08
	# copies the same snapshot — so seed ~/.claude/settings.json here or the
	# agent hits a permission prompt on its first sudo. Never overwrites an
	# existing settings.json (re-runs, or the author's own machine).
	if [ ! -f "$$HOME/.claude/settings.json" ]; then
	  mkdir -p "$$HOME/.claude"
	  cp 08_ai-agent-tools/files/claude/settings.json "$$HOME/.claude/settings.json"
	  log "seeded ~/.claude/settings.json (Bash sudo pre-allowed for the build agent)"
	else
	  log "~/.claude/settings.json already exists — left untouched"
	fi
	# ---- 5. verify ----
	if claude --version >/dev/null 2>&1; then
	  log "claude installed OK: $$(claude --version)"
	else
	  echo "claude did not install correctly — see https://code.claude.com/docs/en/troubleshoot-install" >&2
	  exit 1
	fi
	log "make deps done."

# `make list` — the rule menu; install.sh prints this after deps. Generated
# from $(LAYERS), so it can't drift from what `all` actually runs.
list:
	@echo "rules ('make <rule>' or './install.sh <rule>'):"
	echo "  deps             bootstrap: base apt tooling + Claude Code (idempotent; 'all' runs it first)"
	echo "  all              deps + every layer below, in order (minus any the station config's layers: block sets to \"no\")"
	for l in $(LAYERS); do echo "  $$l"; done
	echo "  14_udev          optional, excluded from 'all' — device-specific udev rules (see its README)"
	echo "  10_embedded-hw   optional, excluded from 'all' — reference-only, no apply.sh yet (see its README)"
	echo "  17_gdrive        optional, excluded from 'all' — reference-only, no apply.sh yet (see its README)"

# Intentionally NOT a dependency of `all` — optional, on-demand only.
# No apply.sh exists yet either (documentation-only layer, see its README);
# this target just points at that doc until someone actually builds it out.
10_embedded-hw:
	@cat 10_embedded-hw/README.md
	@echo
	@echo "=== 10_embedded-hw is reference-only — no apply.sh exists yet. ==="

# Same treatment as 10_embedded-hw — optional, on-demand only, no apply.sh
# yet (rclone + Google Drive OAuth remote, see its README).
17_gdrive:
	@cat 17_gdrive/README.md
	@echo
	@echo "=== 17_gdrive is reference-only — no apply.sh exists yet. ==="
