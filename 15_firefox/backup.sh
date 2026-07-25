#!/usr/bin/env bash
# 15_firefox/backup.sh — snapshot this station's Firefox bookmarks (all
# profiles) into 15_firefox/bookmarks/, so they can be carried to and restored
# on the next station. Safe to re-run any time (e.g. via cron) — always
# takes the freshest available snapshot.
#
# For each profile under ~/.mozilla/firefox/ that has a places.sqlite:
#   1. prefer Firefox's own latest bookmarkbackups/*.jsonlz4 auto-backup
#      (a static, already-consistent snapshot — safe even while Firefox is
#      running, no lock issues)
#   2. if none exists yet, fall back to reading places.sqlite directly
#      (read-only) — only works if that profile isn't the one currently
#      locked open by a running Firefox instance
# and writes a portable bookmarks.html next to it via export_bookmarks.py.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/bookmarks"
FF_DIR="$HOME/.mozilla/firefox"
PY="$HERE/export_bookmarks.py"

if [ ! -d "$FF_DIR" ]; then
  echo "no $FF_DIR — Firefox not installed/used on this box, nothing to back up" >&2
  exit 0
fi

mkdir -p "$OUT"

found_any=0
shopt -s nullglob
for profile in "$FF_DIR"/*/; do
  name="$(basename "$profile")"
  places="$profile/places.sqlite"
  [ -f "$places" ] || continue

  dest="$OUT/$name"
  mkdir -p "$dest"

  latest_backup=""
  for f in "$profile"/bookmarkbackups/bookmarks-*.jsonlz4; do
    [ -e "$f" ] || continue
    if [ -z "$latest_backup" ] || [ "$f" -nt "$latest_backup" ]; then
      latest_backup="$f"
    fi
  done

  if [ -n "$latest_backup" ]; then
    cp -f "$latest_backup" "$dest/latest.jsonlz4"
    if python3 "$PY" --jsonlz4 "$dest/latest.jsonlz4" -o "$dest/latest.html"; then
      echo "[$name] backed up from $(basename "$latest_backup")"
      found_any=1
    else
      echo "[$name] WARNING: export_bookmarks.py failed on $(basename "$latest_backup") — any older latest.html left as-is" >&2
    fi
  elif python3 "$PY" --sqlite "$places" -o "$dest/latest.html" 2>/dev/null; then
    echo "[$name] backed up directly from places.sqlite (no jsonlz4 auto-backup existed yet)"
    found_any=1
  else
    echo "[$name] SKIPPED — no bookmarkbackups/*.jsonlz4 and places.sqlite is locked (profile currently in use); re-run later" >&2
    rmdir "$dest" 2>/dev/null || true
  fi
done

if [ "$found_any" -ne 1 ]; then
  echo "no bookmarks exported" >&2
  exit 1
fi
echo "done -> $OUT"
