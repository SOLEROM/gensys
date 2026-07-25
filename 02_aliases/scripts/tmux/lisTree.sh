#!/bin/bash
for s in /tmp/tmux-"$UID"/*; do
  name="$(basename "$s")"
  echo "=== socket: $name ==="
  tmux -L "$name" list-sessions 2>/dev/null || echo "(no server / not accessible)"
done
