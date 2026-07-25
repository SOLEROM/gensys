#!/usr/bin/env bash
# 07_dev/apply.sh — mirrors this layer's README.md Apply section.
# RVM is opt-in (RVM_INSTALL=yes) — confirm still needed before running.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../00_configs/load.sh"

RVM_INSTALL="${RVM_INSTALL:-$(cfg dev.rvm_install no)}"

echo "==> nvm + node LTS"
if [ ! -d "$HOME/.nvm" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
# nvm.sh is not set -u clean — relax around the source
set +u
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
set -u
nvm install --lts
nvm alias default 'lts/*'

echo "==> uv"
command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh

echo "==> pyenv"
# -fsSL matters: pyenv.run redirects (-L) and an HTTP error page must fail
# (-f) instead of being piped into bash. PATH/init lives in 05_shell's zshrc
# (guarded pyenv block — active once ~/.pyenv exists).
[ -d "$HOME/.pyenv" ] || curl -fsSL https://pyenv.run | bash

if [ "$RVM_INSTALL" = yes ]; then
  echo "==> RVM + ruby-3.0.0"
  gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 || true
  curl -sSL https://get.rvm.io | bash -s stable
  # RVM's scripts are notoriously not set -u clean
  set +u
  # shellcheck disable=SC1090
  source "$HOME/.rvm/scripts/rvm"
  set -u
  rvm install ruby-3.0.0
  rvm use ruby-3.0.0 --default
else
  echo "==> RVM skipped (RVM_INSTALL != yes — confirm a project still needs ruby-3.0.0 first)"
fi

echo "==> rustup"
if ! command -v rustup >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
# guarded: rustup may exist via a non-rustup route with no ~/.cargo/env
# shellcheck disable=SC1091
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
rustup component add clippy rustfmt rust-analyzer

echo "==> editor extensions"
# `|| true`: xargs exits 123 if ANY extension fails (renamed, marketplace-
# restricted, WSL-only) — one bad entry must not abort the layer.
if command -v code >/dev/null 2>&1; then
  xargs -r -n1 code --install-extension < "$HERE/files/vscode-extensions.txt" || \
    echo "WARNING: some VS Code extensions failed to install (see above) — continuing" >&2
else
  echo "WARNING: 'code' not on PATH — VS Code extension list skipped (install VS Code first, see 01_base snaps)" >&2
fi
if command -v cursor >/dev/null 2>&1; then
  xargs -r -n1 cursor --install-extension < "$HERE/files/cursor-extensions.txt" || \
    echo "WARNING: some Cursor extensions failed to install (see above) — continuing" >&2
else
  echo "WARNING: 'cursor' not on PATH — Cursor extension list skipped (Cursor is unscripted, see 01_base README)" >&2
fi

echo "==> done. Pick a default Java with: sudo update-alternatives --config java"
