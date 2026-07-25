#!/usr/bin/env bash
# 00_configs/load.sh — shared station-config loader, sourced by every layer's
# apply.sh. Provides:
#
#   cfg <dotted.path> [default]
#       Reads one scalar from $CONFIG_FILE via yq, printing [default] if the
#       key is absent/null/empty.
#
#   render_template <src> <dst> KEY=value [KEY=value ...]
#       Copies <src> to <dst>, replacing every {{KEY}} token with its value
#       (sed, all occurrences). Same mechanism 06_desktop-i3/apply.sh already
#       uses for {{WALLPAPER}} in Xresources — this just gives every layer
#       one shared helper instead of a hand-rolled sed pipeline each.
#
# Config file resolution (see 00_configs/README.md):
#   1. $GENSYS_CONFIG if set — must exist, a typo'd path is a hard error
#      (silently building another station's values is exactly the failure
#      mode this guards against).
#   2. Unset + exactly ONE station yaml in 00_configs/ or one level down in a
#      per-station subfolder like 00_configs/myDevX1/ (TEMPLATE.yaml aside)
#      → that one is auto-selected.
#   3. Unset + several station yamls → hard error, refuse to guess.
#   4. Unset + none → warn, every cfg() falls back to built-in defaults.
# Per-var env overrides in each apply.sh still take precedence over anything
# read from the file.
#
# Not sourced standalone — always via: source ".../00_configs/load.sh"

GENSYS_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENSYS_REPO_ROOT="$(cd "$GENSYS_CONFIG_DIR/.." && pwd)"

if ! command -v yq >/dev/null 2>&1; then
  echo "==> yq not found — installing (snap)" >&2
  sudo snap install yq >/dev/null
fi

if [ -n "${GENSYS_CONFIG:-}" ]; then
  CONFIG_FILE="$GENSYS_CONFIG"
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: GENSYS_CONFIG points at a missing file: $CONFIG_FILE" >&2
    echo "Fix the path (available: $(ls "$GENSYS_CONFIG_DIR"/*.yaml "$GENSYS_CONFIG_DIR"/*/*.yaml 2>/dev/null | grep -v TEMPLATE.yaml | sed "s|^$GENSYS_REPO_ROOT/||" | tr '\n' ' '))" >&2
    return 1 2>/dev/null || exit 1
  fi
  # Absolutize — several layers' apply.sh `cd` into a files/ subdir before
  # later cfg() calls; a relative GENSYS_CONFIG (the documented usage, e.g.
  # `GENSYS_CONFIG=00_configs/myDevX2.yaml make all`) would silently break
  # cfg()'s `< "$CONFIG_FILE"` redirection after that cd — every cfg() call
  # would then fall back to its default instead of erroring loudly, with no
  # visible symptom whenever a real value happens to equal the default.
  # Confirmed 2026-07-25: this actually happened (06_desktop-i3, 13_misc).
  CONFIG_FILE="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"
else
  # Station yamls live either flat (00_configs/<station>.yaml, tracked) or in
  # a per-station subfolder (00_configs/<station>/<station>.yaml, git-ignored
  # personal layout — myDevX1/) — scan both, one level deep.
  _gensys_candidates=()
  for _f in "$GENSYS_CONFIG_DIR"/*.yaml "$GENSYS_CONFIG_DIR"/*/*.yaml; do
    [ -f "$_f" ] || continue
    [ "$(basename "$_f")" = "TEMPLATE.yaml" ] && continue
    _gensys_candidates+=("$_f")
  done
  if [ "${#_gensys_candidates[@]}" -eq 1 ]; then
    CONFIG_FILE="${_gensys_candidates[0]}"
  elif [ "${#_gensys_candidates[@]}" -eq 0 ]; then
    CONFIG_FILE=""
    echo "WARNING: no station config in $GENSYS_CONFIG_DIR — falling back to each script's built-in defaults. Copy TEMPLATE.yaml first (see 00_configs/README.md)." >&2
  else
    echo "ERROR: several station configs exist and GENSYS_CONFIG is not set — refusing to guess which station to build:" >&2
    printf '  %s\n' "${_gensys_candidates[@]}" >&2
    echo "Pick one, e.g.: export GENSYS_CONFIG=${_gensys_candidates[0]#"$GENSYS_REPO_ROOT"/}" >&2
    return 1 2>/dev/null || exit 1
  fi
fi

# announce once per run which station is being built (children inherit the flag)
if [ -n "$CONFIG_FILE" ] && [ -z "${GENSYS_CONFIG_ANNOUNCED:-}" ]; then
  echo "==> station config: ${CONFIG_FILE#"$GENSYS_REPO_ROOT"/}" >&2
  export GENSYS_CONFIG_ANNOUNCED=1
fi

cfg() {
  local path="$1" default="${2:-}" val
  if [ -f "$CONFIG_FILE" ]; then
    # Feed the file on stdin, never as a filename arg: the snap-confined yq
    # cannot open paths outside its sandbox (a repo clone on /data included —
    # found the hard way: every cfg silently returned defaults). The shell
    # opens the file; confinement doesn't apply to inherited stdin.
    val="$(yq e ".${path} // \"\"" - < "$CONFIG_FILE" 2>/dev/null)"
  else
    val=""
  fi
  case "$val" in
    ""|null) printf '%s' "$default" ;;
    # An unfilled template placeholder ("<run: blkid ...>", "<TODO yes|no>")
    # is NOT a value — fall back to the default, same as an absent key.
    # Otherwise placeholders flow into scripts as real data (e.g. has_nvidia
    # never matching "yes" and silently skipping the NVIDIA driver).
    "<"*">") printf '%s' "$default" ;;
    *) printf '%s' "$val" ;;
  esac
}

render_template() {
  local src="$1" dst="$2"
  shift 2
  local sed_args=()
  local kv key val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    # escape sed-replacement metacharacters so a value containing \ | &
    # (paths, device names) can't corrupt the rendered file
    val="${val//\\/\\\\}"
    val="${val//|/\\|}"
    val="${val//&/\\&}"
    sed_args+=(-e "s|{{${key}}}|${val}|g")
  done
  sed "${sed_args[@]}" "$src" > "$dst"
}
