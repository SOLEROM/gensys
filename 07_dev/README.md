# 07_dev — dev runtimes: `uv`+`pyenv`, nvm, rustup, RVM, JDKs, editor extensions

## Purpose

Reproduce the dev-runtime layer, with one deliberate change from what this
host actually runs today: **conda/miniconda/mambaforge/micromamba are
dropped entirely.** This host's live `.zshrc` currently inits both a
`mambaforge` conda hook *and* a `micromamba` hook (leftover from switching
tools at some point) — neither carries forward. Decision locked in:

- **Python**: `uv` is the primary tool/venv manager going forward (already
  used here via `uv tool` for `claude-monitor`). `pyenv` stays supported as
  a secondary version manager, for pulling a specific old interpreter on
  demand — not pre-loaded with any version by default.
- **Node**: nvm, with one default version pinned (`nvm alias default`)
  instead of drifting.
- **Ruby**: RVM with `ruby-3.0.0` — this host's live `.zshrc` sources RVM,
  backing `jekyll`/`gitbook-cli`. Confirm still needed before porting;
  otherwise drop (it's the one item in this layer not confirmed in-use for
  an active project as of this capture).
- **Rust**: rustup + toolchain (clippy, rustfmt, rust-analyzer).
- **Java**: openjdk-17/21 (installed in `01_base`) — settle on the default
  via `update-alternatives`. `openjdk-8` (focal-era) is **not** carried
  forward per `01_base`'s "no focal-only baseline" rule unless a specific
  project needs it.
- **Editor extensions**: VS Code + Cursor lists, captured as plain text,
  applied with `xargs`.

**Not this layer's job** (lives in `13_misc` instead, already scoped there):
git identity (`.gitconfig`), GPG (restored from the owner's own backup, out
of band — keys are never snapshotted here).

---

## Prerequisites

`01_base` applied (build-essential, JDKs, and the `code` snap). For the
editor-extension step: `code` comes from `01_base`'s snaps; **Cursor is
deliberately unscripted** (see `01_base`'s README, "AI coding tools") — if it
isn't installed yet, `apply.sh` warns and skips its extension list.

---

## Files in this layer

| repo path | target on fresh box |
|---|---|
| `files/vscode-extensions.txt` | applied via `code --install-extension` (not copied anywhere) |
| `files/cursor-extensions.txt` | applied via `cursor --install-extension` (not copied anywhere) |

---

## Apply

### Node (nvm)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"; . "$NVM_DIR/nvm.sh"
nvm install --lts
nvm alias default 'lts/*'   # quoted — zsh hard-errors on the bare glob
```

### Python (`uv` primary, `pyenv` secondary — no conda family)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# uv tool install claude-monitor   # example — install CLI apps as needed, not upfront

curl -fsSL https://pyenv.run | bash
# PATH/init: 05_shell's zshrc snapshot carries a guarded pyenv block (right
# after the nvm lines) that activates once ~/.pyenv exists — nothing to add
# by hand. Do NOT pyenv-install any specific version by default — only on
# demand, per-project.
```

### Ruby (RVM) — confirm still needed before running

```bash
gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm
rvm install ruby-3.0.0
rvm use ruby-3.0.0 --default
```

### Rust (rustup)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup component add clippy rustfmt rust-analyzer
```

### Java

```bash
sudo update-alternatives --config java   # pick 17 or 21 as default
```

### Editor extensions

```bash
# || true: xargs exits 123 if any single extension fails (renamed,
# marketplace-restricted, WSL-only) — don't let one entry abort the step
xargs -r -n1 code   --install-extension < files/vscode-extensions.txt || true
xargs -r -n1 cursor --install-extension < files/cursor-extensions.txt || true
```

---

## Verify

```bash
node --version && nvm current
uv --version; pyenv --version
rustc --version; cargo --version; rustup component list --installed
java -version
code --list-extensions | wc -l
cursor --list-extensions | wc -l
```

---

## Machine-specific values

- **RVM** (`dev.rvm_install` in the active station's `00_configs` yaml, env var
  `RVM_INSTALL`) — only apply if a project under `/proj` actually still
  needs `ruby-3.0.0` (jekyll/gitbook-cli). Skip otherwise.
- **Node default version** — `nvm alias default` picks whichever LTS is
  current at install time; pin a specific version instead if a project
  needs it.
- **Android SDK/Gradle** (`ANDROID_HOME`, seen in this host's live `.zshrc`)
  — intentionally **not** part of this layer. That's `10_embedded-hw`
  territory (optional/on-demand only) — its own PATH exports only get added
  to `.zshrc` if that layer is explicitly requested later.

---

## Origin

`files/vscode-extensions.txt` ← `code --list-extensions`,
`files/cursor-extensions.txt` ← `cursor --list-extensions`, both captured
2026-07-23. RVM/nvm/rustup/pyenv choices cross-referenced against this
host's live `~/.zshrc` init blocks (conda/mamba blocks intentionally
excluded — see Purpose above).
