#!/usr/bin/env bash
# 08_ai-agent-tools/apply.sh — mirrors this layer's README.md Apply section.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../00_configs/load.sh"

# node/npm live in nvm (07_dev), which puts nothing on a non-interactive
# PATH — source it here or this whole layer no-ops on a fresh box.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  set +u; . "$NVM_DIR/nvm.sh"; set -u
fi

echo "==> sibling CLIs"
if command -v npm >/dev/null 2>&1; then
  npm install -g openclaw || echo "WARNING: 'npm install -g openclaw' failed (see above) — openclaw-gateway will be skipped" >&2
else
  echo "npm not found — run 07_dev first" >&2
fi
command -v uv  >/dev/null 2>&1 && uv tool install claude-monitor || true

echo "==> claude config + skill"
mkdir -p ~/.claude/skills/taskList
# The live settings.json may have grown hooks/plugins/env since deps seeded
# it — keep a one-time backup before refreshing it with the snapshot.
[ -f ~/.claude/settings.json ] && cp -n ~/.claude/settings.json ~/.claude/settings.json.pre-gensys
cp "$HERE/files/claude/settings.json" ~/.claude/settings.json
cp "$HERE/files/claude/skills/taskList/"* ~/.claude/skills/taskList/

echo "==> systemd user services"
mkdir -p ~/.config/systemd/user

# Working dirs / ports come from the active station yaml's agents: block
# (see 00_configs/README.md and TEMPLATE.yaml's commented skeleton) — only
# relevant if you're carrying these personal agent servers forward onto the
# new station in the first place. A unit whose agents.dirs.* is unset is
# SKIPPED (and a stale copy removed), never installed with an empty
# WorkingDirectory — systemd rejects those with a confusing 200/CHDIR.
USER_UNITS=()
maybe_user_unit() {  # <name> <dir> [KEY=value ...]
  local name="$1" dir="$2"; shift 2
  if [ -z "$dir" ]; then
    echo "    (skipping $name.service — agents.dirs.* unset in ${CONFIG_FILE:-the station config})"
    rm -f ~/.config/systemd/user/"$name.service"
    return 0
  fi
  render_template "$HERE/files/systemd/user/$name.service" ~/.config/systemd/user/"$name.service" "$@"
  USER_UNITS+=("$name.service")
}

ANVILON_DIR="$(cfg agents.dirs.anvilon)"
CLDLAB_DIR="$(cfg agents.dirs.cldlab)"
REMDEV_DIR="$(cfg agents.dirs.remdev)"
RESMAN_DIR="$(cfg agents.dirs.resman)"
SOLSEED_DIR="$(cfg agents.dirs.solseed)"
maybe_user_unit anvilon "$ANVILON_DIR" "ANVILON_DIR=$ANVILON_DIR"
maybe_user_unit cldlab  "$CLDLAB_DIR"  "CLDLAB_DIR=$CLDLAB_DIR" "CLDLAB_PORT=$(cfg agents.ports.cldlab 6002)"
maybe_user_unit remdev  "$REMDEV_DIR"  "REMDEV_DIR=$REMDEV_DIR"
maybe_user_unit resman  "$RESMAN_DIR"  "RESMAN_DIR=$RESMAN_DIR"
maybe_user_unit solseed "$SOLSEED_DIR" "SOLSEED_DIR=$SOLSEED_DIR"

# Node binary/openclaw path resolved live (not config-driven) so it never
# goes stale after an nvm upgrade — was previously pinned to v22.16.0.
NODE_BIN="$(command -v node || true)"
if [ -z "$NODE_BIN" ] && [ -f "$HOME/.nvm/alias/default" ]; then
  # nvm lays node at versions/node/<v>/bin — there is no ~/.nvm/current
  NODE_BIN="$HOME/.nvm/versions/node/$(cat "$HOME/.nvm/alias/default")/bin/node"
fi
OPENCLAW_JS="$(npm root -g 2>/dev/null || echo "$HOME/.npm-global/lib/node_modules")/openclaw/dist/index.js"
if [ -n "$NODE_BIN" ] && [ -f "$OPENCLAW_JS" ]; then
  maybe_user_unit openclaw-gateway "$HOME" \
    "HOME=$HOME" "NODE_BIN=$NODE_BIN" "OPENCLAW_JS=$OPENCLAW_JS" \
    "OPENCLAW_PORT=$(cfg agents.ports.openclaw_gateway 18789)"
else
  echo "    (skipping openclaw-gateway.service — node/openclaw not installed; run 07_dev, then re-run this layer)"
  rm -f ~/.config/systemd/user/openclaw-gateway.service
fi

systemctl --user daemon-reload
if [ "${#USER_UNITS[@]}" -gt 0 ]; then
  # linger: user services must survive logout and start at boot — without
  # this they die with the login session, defeating "always-on" servers.
  sudo loginctl enable-linger "$(id -un)" || true
  systemctl --user enable --now "${USER_UNITS[@]}" || \
    echo "one or more user services failed to start — check the agents.dirs.* paths in ${CONFIG_FILE:-the station config} exist"
else
  echo "==> no user agent services configured for this station (agents: block absent) — none installed"
fi

echo "==> mdplanner (system service)"
MDPLANNER_DIR="$(cfg agents.dirs.mdplanner)"
if [ -n "$MDPLANNER_DIR" ]; then
  MDP_TMP="$(mktemp)"   # mktemp, not a fixed /tmp name — this file is sudo-copied into /etc
  render_template "$HERE/files/systemd/system/mdplanner.service" "$MDP_TMP" \
    "USERNAME=$(cfg station.username "$USER")" "MDPLANNER_DIR=$MDPLANNER_DIR"
  sudo install -m 0644 -o root -g root "$MDP_TMP" /etc/systemd/system/mdplanner.service
  rm -f "$MDP_TMP"
  sudo systemctl daemon-reload
  sudo systemctl enable --now mdplanner.service || \
    echo "mdplanner failed to start — check its WorkingDirectory (agents.dirs.mdplanner in the station config) exists"
else
  echo "    (skipping mdplanner.service — agents.dirs.mdplanner unset in ${CONFIG_FILE:-the station config})"
fi

echo "==> usage-monitoring scripts (files/clds/ — run in place from the repo)"
chmod +x "$HERE/files/clds/usage.sh" "$HERE/files/clds/wakeup.sh"

echo "==> done."
