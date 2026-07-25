#!/usr/bin/env bash
# mapCurrentHost.sh — freeze a snapshot of everything installed on this host.
#
# Creates <script_dir>/snapshots/<hostname>_<YYYY-MM-DD>/ with one file per
# install source (apt, snap, flatpak, pip, npm, cargo, docker, local bins, ...).
# Package managers that are not present on the host are skipped and noted
# in 00-summary.txt. Re-running on the same day refreshes the same folder.
# snapshots/ is git-ignored — these are per-host audit data, not repo content.

set -u

# Never let a captured command block on an interactive prompt, and stop
# Corepack shims (pnpm/yarn) from downloading anything on a plain "list".
exec < /dev/null
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="$(hostname -s 2>/dev/null || hostname)"
STAMP="$(date +%F)"
OUT_DIR="${SCRIPT_DIR}/snapshots/${HOST}_${STAMP}"
SUMMARY="${OUT_DIR}/00-summary.txt"
ERRLOG="${OUT_DIR}/99-errors.log"

# Give every child command a guaranteed-valid cwd, whatever dir we were
# launched from.
cd "$SCRIPT_DIR" || exit 1

mkdir -p "$OUT_DIR" || { printf 'ERROR: cannot create %s\n' "$OUT_DIR" >&2; exit 1; }
# Clear stale files from an earlier same-day run, but keep the directory
# inode alive — deleting the dir breaks getcwd() for any shell sitting in it.
rm -f "${OUT_DIR:?}"/*
: > "$SUMMARY"
: > "$ERRLOG"

note() { printf '%s\n' "$*" >> "$SUMMARY"; }

# capture <outfile> <label> <cmd...>
# Saves cmd stdout to outfile. SKIP when the binary is absent, WARN when the
# command exits nonzero but still produced output, FAIL otherwise.
capture() {
  local out="$1" label="$2" of
  shift 2
  of="${OUT_DIR}/${out}"
  if ! command -v "$1" >/dev/null 2>&1; then
    note "SKIP ${label} (${1} not installed)"
    return 0
  fi
  if "$@" > "$of" 2>> "$ERRLOG"; then
    note "OK   ${label} -> ${out} ($(grep -c '' "$of") lines)"
  elif [ -s "$of" ]; then
    note "WARN ${label} -> ${out} (nonzero exit, output captured; see 99-errors.log)"
  else
    note "FAIL ${label} -> ${out} (see 99-errors.log)"
  fi
}

# list_dirs <outfile> <label> <dir...> — one section per existing dir.
list_dirs() {
  local out="$1" label="$2" d
  shift 2
  {
    for d in "$@"; do
      [ -d "$d" ] || continue
      echo "### $d"
      ls -1 "$d" 2>> "$ERRLOG"
      echo
    done
  } > "${OUT_DIR}/${out}"
  note "OK   ${label} -> ${out} ($(grep -c '' "${OUT_DIR}/${out}") lines)"
}

note "freeze map of installed software"
note "host:      $HOST"
note "generated: $(date -Is)"
note "output:    $OUT_DIR"
note ""

# --- host identity ----------------------------------------------------------
{
  echo "hostname : $(timeout 2 hostname -f 2>/dev/null || hostname)"
  echo "kernel   : $(uname -srmo)"
  echo "uptime   : $(uptime -p 2>/dev/null || uptime)"
  echo
  [ -r /etc/os-release ] && cat /etc/os-release
} > "${OUT_DIR}/01-host-info.txt" 2>> "$ERRLOG"
note "OK   host info -> 01-host-info.txt"

# --- system package managers ------------------------------------------------
capture 10-apt-dpkg.tsv    "apt/dpkg packages"   dpkg-query -W -f='${binary:Package}\t${Version}\t${Architecture}\n'
capture 11-apt-manual.txt  "apt manual installs" apt-mark showmanual
capture 12-snap.txt        "snap packages"       snap list
capture 13-flatpak.txt     "flatpak apps"        flatpak list --columns=application,version,origin
capture 14-brew.txt        "homebrew packages"   brew list --versions
capture 15-nix.txt         "nix packages"        nix-env -q

# --- language package managers ----------------------------------------------
if command -v python3 >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; then
  capture 20-pip.txt      "pip (python3)" python3 -m pip list --format=freeze --disable-pip-version-check
  capture 21-pip-user.txt "pip --user"    python3 -m pip list --format=freeze --user --disable-pip-version-check
else
  note "SKIP pip (python3/pip not installed)"
fi
capture 22-pipx.txt        "pipx tools"      pipx list --short
capture 23-uv-tools.txt    "uv tools"        uv tool list
capture 24-conda-envs.txt  "conda envs"      conda env list
capture 25-npm-global.txt  "npm global"      npm ls -g --depth=0
capture 26-pnpm-global.txt "pnpm global"     pnpm ls -g --depth 0
capture 27-yarn-global.txt "yarn global"     yarn global list
capture 28-cargo.txt       "cargo installs"  cargo install --list
capture 29-rustup.txt      "rust toolchains" rustup toolchain list
capture 30-gem.txt         "ruby gems"       gem list --local

if command -v go >/dev/null 2>&1; then
  {
    go version
    echo
    echo "### binaries in $(go env GOPATH)/bin"
    ls -1 "$(go env GOPATH)/bin" 2>/dev/null || echo "(none)"
  } > "${OUT_DIR}/31-go.txt" 2>> "$ERRLOG"
  note "OK   go toolchain+bins -> 31-go.txt"
else
  note "SKIP go (not installed)"
fi

# --- containers & services --------------------------------------------------
capture 40-docker-images.txt     "docker images"     docker images --format '{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}'
capture 41-docker-containers.txt "docker containers" docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
capture 42-systemd-enabled.txt   "systemd enabled services" systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend

# --- desktop & editor -------------------------------------------------------
capture 50-vscode-extensions.txt "vscode extensions"      code --list-extensions --show-versions
capture 51-gnome-extensions.txt  "gnome shell extensions" gnome-extensions list

# --- local / hand-installed tools -------------------------------------------
list_dirs 60-local-bins.txt "local bin dirs" \
  /usr/local/bin /usr/local/sbin /opt \
  "$HOME/.local/bin" "$HOME/bin" "$HOME/.cargo/bin"

find "$HOME" -maxdepth 4 -type f -iname '*.AppImage' 2>/dev/null \
  > "${OUT_DIR}/61-appimages.txt"
note "OK   appimages (home, depth 4) -> 61-appimages.txt ($(grep -c '' "${OUT_DIR}/61-appimages.txt") found)"

IFS=':' read -r -a PATH_DIRS <<< "$PATH"
list_dirs 62-path-executables.txt "PATH executables" ${PATH_DIRS[@]+"${PATH_DIRS[@]}"}

# --- wrap up ----------------------------------------------------------------
note ""
note "files written: $(ls -1 "$OUT_DIR" | wc -l)"
if [ -s "$ERRLOG" ]; then
  note "errors: some commands wrote to 99-errors.log (non-fatal)"
else
  note "errors: none"
fi

cat "$SUMMARY"
