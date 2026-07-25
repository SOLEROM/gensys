#!/usr/bin/env bash
# 15_firefox/restore.sh — run on the NEW station, after Firefox has been
# launched at least once (so a default profile exists). Stages the saved
# bookmark backups where Firefox can find them; finishing the import is a
# one-time manual step because Firefox has no reliable non-interactive
# bookmarks-import path.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/bookmarks"
FF_DIR="$HOME/.mozilla/firefox"

if [ ! -d "$SRC" ] || [ -z "$(ls -A "$SRC" 2>/dev/null)" ]; then
  echo "no $SRC — run backup.sh on the old station first, and carry this repo's 15_firefox/bookmarks/ over" >&2
  exit 1
fi

if [ ! -d "$FF_DIR" ] || ! ls "$FF_DIR"/*/places.sqlite >/dev/null 2>&1; then
  cat >&2 <<'EOF'
No Firefox profile found yet on this box. Launch Firefox once (it creates
the default profile on first run), close it, then re-run restore.sh.
EOF
  exit 1
fi

staged=0
for saved in "$SRC"/*/; do
  name="$(basename "$saved")"
  target="$FF_DIR/$name"

  # exact profile-dir-name match first (e.g. kidt04f3.default-release won't
  # match on a fresh box with a new random profile id) — fall back to the
  # single *.default-release profile if there's exactly one.
  if [ ! -d "$target" ]; then
    candidates=("$FF_DIR"/*.default-release)
    if [ "${#candidates[@]}" -eq 1 ] && [ -d "${candidates[0]}" ]; then
      target="${candidates[0]}"
    else
      echo "[$name] no matching profile on this box — leaving saved copy at $saved untouched"
      continue
    fi
  fi

  mkdir -p "$target/bookmarkbackups"
  if [ -f "$saved/latest.jsonlz4" ]; then
    cp -n "$saved/latest.jsonlz4" "$target/bookmarkbackups/restored-$name.jsonlz4"
    echo "[$name] staged -> $(basename "$target")/bookmarkbackups/restored-$name.jsonlz4"
  fi
  if [ -f "$saved/latest.html" ]; then
    # per-profile filename: two saved profiles can fall back to the SAME
    # *.default-release target — a fixed name would let the second overwrite
    # the first (this repo ships exactly that pair).
    cp -f "$saved/latest.html" "$target/bookmarks-import-$name.html"
    echo "[$name] staged -> $(basename "$target")/bookmarks-import-$name.html"
  fi
  staged=1
done

[ "$staged" -eq 1 ] || { echo "nothing staged — no matching profiles found" >&2; exit 1; }

cat <<'EOF'

Files are staged. Finish in Firefox (per profile, one-time, manual):
  Library (Ctrl+Shift+O) -> Import and Backup -> Restore -> pick the
  "restored-<profile>" entry     [preferred — exact restore, incl. folders/tags]
  or: Import and Backup -> Import Bookmarks from HTML ->
      bookmarks-import-<profile>.html (sitting in the profile's own folder;
      one per saved profile)                               [fallback, flatter]

Firefox does not offer a scripted/non-interactive way to finish this step.
EOF
