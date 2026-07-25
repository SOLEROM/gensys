#!/usr/bin/env bash
# install.sh — the one thing you type by hand on a fresh Ubuntu 24.04 box.
#
# Job: make sure `make` itself exists (the only package this script installs
# directly — a Makefile rule can't bootstrap make), run `make deps` (base
# apt tooling + Claude Code, the old deps.sh folded into the Makefile), then
# hand off:
#   - no args: print the two paths for the actual layers — agent-driven
#     (CLAUDE_CONSUMER.md) or scripted — plus the full rule list.
#   - with args: pass them straight to make ('./install.sh all',
#     './install.sh 05_shell 09_docker', ... — same names `make list` shows).
#
# Usage: ./install.sh                  # deps, then print the options below
#        ./install.sh all              # deps, then every layer (= make all)
#        ./install.sh 05_shell         # deps, then just that rule (= make 05_shell)
#        ./install.sh --make           # legacy alias for './install.sh all'

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

echo "=== gensys install.sh ==="
echo "repo: $HERE"

# `make` is the one dependency the deps rule can't provide for itself.
if ! command -v make >/dev/null 2>&1; then
  echo "==> installing make (needed for everything below)"
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends make
fi

make deps

echo
if [[ $# -gt 0 ]]; then
  [[ "$1" == "--make" ]] && set -- all "${@:2}"
  echo "=== handing off to 'make $*' ==="
  exec make "$@"
fi

cat <<EOF
deps done — claude is installed (first run still needs an interactive
browser login: just run 'claude' once, anywhere, to do that). If 'claude'
isn't found in THIS terminal, open a new one (or 'source ~/.bashrc') —
deps adds ~/.local/bin to PATH for future shells, not this one.

Two ways to apply the actual layers from here — pick one:

  1. Agent-driven (adapts to this box's hardware, asks the few required
     questions like wallpaper/DOCKER_DATA_ROOT):
       claude --dangerously-skip-permissions
       > read CLAUDE_CONSUMER.md and start the build
     (deps already seeded ~/.claude/settings.json with sudo allowed; the
      skip-permissions flag keeps the long build from stopping at every
      other prompt — use it only for this provisioning run)

  2. Scripted, no agent in the loop (fixed defaults):
       make all              # or: ./install.sh all
     or one rule at a time — './install.sh <rule>' or 'make <rule>':

EOF
make list
