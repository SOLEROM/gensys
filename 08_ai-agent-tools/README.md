# 08_ai-agent-tools — Claude Code + sibling AI CLIs + personal agent services

## Purpose

The single biggest uncaptured theme on this machine: the AI coding tool
census, Claude Code's own config, seven personal "agent server" systemd
services that live on this box (six user units + the mdplanner system
unit), and the custom Claude Code usage-monitoring
scripts (`files/clds/` — folded in from the former top-level `clds/` folder
on 2026-07-24, so every AI tool lives in this one layer).

---

## Prerequisites

```bash
# Claude Code itself is bootstrapped by `make deps` at the repo root
# (native installer, no Node dependency) — not repeated here.

# sibling CLIs/apps
npm install -g @openai/codex           # OpenAI Codex CLI
npm install -g openclaw                # OpenClaw gateway (see service table below)
# cursor, windsurf, antigravity, claude-desktop, auto-claude-ui: each ships
# its own installer — verify current download link per app, not scripted
# generically here.
# gemini CLI, GitHub Copilot CLI: npm install -g @google/gemini-cli ;
# gh extension install github/gh-copilot

uv tool install claude-monitor

# bun — required by files/clds/usage.sh (its claude.ai fetch and the bunx
# ccusage stats); installed by NO layer, so grab it once per box:
curl -fsSL https://bun.sh/install | bash
```

---

## Files in this layer

| repo path | target on fresh box |
|---|---|
| `files/claude/settings.json` | `~/.claude/settings.json` |
| `files/claude/skills/taskList/*` | `~/.claude/skills/taskList/*` |
| `files/systemd/user/anvilon.service` | `~/.config/systemd/user/anvilon.service` |
| `files/systemd/user/cldlab.service` | `~/.config/systemd/user/cldlab.service` |
| `files/systemd/user/remdev.service` | `~/.config/systemd/user/remdev.service` |
| `files/systemd/user/resman.service` | `~/.config/systemd/user/resman.service` |
| `files/systemd/user/solseed.service` | `~/.config/systemd/user/solseed.service` |
| `files/systemd/user/openclaw-gateway.service` | `~/.config/systemd/user/openclaw-gateway.service` |
| `files/systemd/system/mdplanner.service` | `/etc/systemd/system/mdplanner.service` |
| `files/clds/usage.sh` | run from the repo (not copied anywhere) — `chmod +x` by `apply.sh` |
| `files/clds/wakeup.sh` | run from the repo (not copied anywhere) — `chmod +x` by `apply.sh` |

`settings.json` is already sanitized — no API keys (Claude Code auth is
OAuth, not a static key stored in this file). It deliberately carries **no
plugin/marketplace entries** (owner decision, 2026-07-24): this repo's job
ends at a working Claude Code with base settings; plugins are added later
by other tooling, outside this repo's responsibility. Don't re-add
`enabledPlugins`/`extraKnownMarketplaces` blocks when re-syncing from the
live station's (much larger) `~/.claude/settings.json`.

It also carries a `permissions.allow` block with `Bash(sudo:*)` (owner
decision, 2026-07-25) so a Claude session on the new box can run sudo
commands without a permission prompt. `make deps` at the repo root seeds
this same file into `~/.claude/settings.json` (only if none exists yet) so
the **build agent** — which starts right after deps, long before this
layer runs — already has sudo allowed; this layer's `cp` then refreshes it
(after a one-time `settings.json.pre-gensys` backup, since the live file
may have grown hooks/plugins by then). Keep the block when re-syncing from
the live station.

The remaining keys are deliberate owner defaults, carried as-is:
`model`/`effortLevel`/`tui` (session look-and-feel),
`agentPushNotifEnabled`, and `skipDangerousModePermissionPrompt: true` —
that last one, together with `Bash(sudo:*)`, is what lets the
`--dangerously-skip-permissions` provisioning run go fully unattended
(owner decision, 2026-07-25). On a multi-user or shared box, re-decide it.

---

## Apply

```bash
# node/npm live in nvm — source it first or npm/openclaw resolution no-ops
# in a non-interactive run:
export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

mkdir -p ~/.claude/skills/taskList ~/.config/systemd/user
[ -f ~/.claude/settings.json ] && cp -n ~/.claude/settings.json ~/.claude/settings.json.pre-gensys
cp files/claude/settings.json          ~/.claude/settings.json
cp files/claude/skills/taskList/*      ~/.claude/skills/taskList/

# each unit is a {{PLACEHOLDER}} template — render_template (00_configs/load.sh)
# substitutes working dirs/ports from the station yaml's agents: block.
# A unit whose agents.dirs.* is UNSET is skipped entirely (not installed
# broken) — apply.sh's maybe_user_unit() does the guard + render, e.g.:
render_template files/systemd/user/cldlab.service ~/.config/systemd/user/cldlab.service \
  "CLDLAB_DIR=$(cfg agents.dirs.cldlab)" "CLDLAB_PORT=$(cfg agents.ports.cldlab 6002)"
# ... same pattern for anvilon/remdev/resman/solseed — see apply.sh

# openclaw-gateway additionally needs the node binary and the installed
# openclaw entry point, resolved live (skipped if either is missing):
NODE_BIN="$(command -v node)"
OPENCLAW_JS="$(npm root -g)/openclaw/dist/index.js"
render_template files/systemd/user/openclaw-gateway.service ~/.config/systemd/user/openclaw-gateway.service \
  "HOME=$HOME" "NODE_BIN=$NODE_BIN" "OPENCLAW_JS=$OPENCLAW_JS" \
  "OPENCLAW_PORT=$(cfg agents.ports.openclaw_gateway 18789)"

# mdplanner (system unit) — render to a mktemp file, install root-owned:
MDP_TMP="$(mktemp)"
render_template files/systemd/system/mdplanner.service "$MDP_TMP" \
  "USERNAME=$(cfg station.username "$USER")" "MDPLANNER_DIR=$(cfg agents.dirs.mdplanner)"
sudo install -m 0644 -o root -g root "$MDP_TMP" /etc/systemd/system/mdplanner.service

# user services — code for each lives on persistent /data/proj (survives
# the reinstall via 04_storage); only the unit files themselves needed
# recreating. enable-linger keeps them alive across logouts / starts them
# at boot — without it a user service dies with the login session.
sudo loginctl enable-linger "$(id -un)"
systemctl --user daemon-reload
systemctl --user enable --now <the units that were rendered above>

# system service (root)
sudo systemctl daemon-reload
sudo systemctl enable --now mdplanner.service

# usage-monitoring scripts run in place from the repo — just make them executable
chmod +x files/clds/usage.sh files/clds/wakeup.sh
```

### Personal agent servers — what each one is

| Unit | Points at | Note |
|---|---|---|
| `anvilon.service` | `/data/proj/agents/anvilon/v2` | **`--public` baked into the snapshot's ExecStart** |
| `cldlab.service` | `/data/proj/agents/cldlab` | port 6002, **`--public` baked in** |
| `remdev.service` | `/data/proj/aproj/remdev` | `--public`; **"no authentication" — unit's own comments say so** |
| `resman.service` | `/proj/wikval/resman` | `--public` |
| `solseed.service` | `/data/proj/agents/solSeed` | `--public` |
| `openclaw-gateway.service` | npm global `openclaw` | port 18789, full env-var block in the unit file |
| `mdplanner.service` (system) | `/data/proj/aproj/mdPlanner/app` | runs as `{{USERNAME}}`, **not** root; a system unit only so it starts at boot without linger. `--open-any` deliberately **relaxes** the hardening (`ProtectSystem=off`/`ProtectHome=off`) so it can write anywhere — the unit is *not* sandboxed |

**Re-decide consciously on the new station, especially on a possibly more-
open network**: five of the six user units (`anvilon`, `cldlab`, `remdev`,
`resman`, `solseed`) run with `--public` and/or explicitly **no auth
layer**, and `mdplanner` runs with `--open-any` (filesystem-wide writes) —
that was an accepted trade-off on this host's network; don't carry it
forward unreviewed onto a different network.

The `cld_mon`/`clw_start`/`clw_stop`/`oll_start`/`oll_stop` control aliases
live in `../02_aliases/alias.bashrc` (cross-referenced from there too).

### Usage monitoring (`files/clds/`)

A custom Claude Code usage-monitoring pair, distinct from the
`claude-monitor` tool behind `cld_mon` above:

- **`usage.sh`** — reports how much of the Claude Code session (5-hour
  block) and weekly quota is used, with a progress bar and burn rate — a
  quick answer to "how close am I to a rate limit right now" without
  opening a browser. Human output by default, `--json` for machine use,
  `--wakeup` to ping a session awake first.
- **`wakeup.sh`** — a tiny `claude -p "hi"` no-op ping `usage.sh --wakeup`
  calls before reading usage.

They run **from the repo** (nothing to install beyond `chmod +x` — done by
`apply.sh`); `usage.sh` reads the OAuth token straight from
`~/.claude/.credentials.json` (must exist — log into Claude Code once
first) and shells out to `bunx --bun ccusage` for local token/burn-rate
stats, so it needs `bun` and `python3` on the box. Add an alias in
`../02_aliases/alias.bashrc` if wanted, e.g.
`alias cldusage='<repo>/08_ai-agent-tools/files/clds/usage.sh'`.

---

## Verify

```bash
claude --version
systemctl --user status anvilon cldlab remdev resman solseed openclaw-gateway  # only the ones configured
sudo systemctl status mdplanner
loginctl show-user "$(id -un)" | grep Linger=yes   # user units survive logout/boot
curl -sf "localhost:$(cfg agents.ports.cldlab 6002)" >/dev/null && echo cldlab-ok
curl -sf "localhost:$(cfg agents.ports.openclaw_gateway 18789)" >/dev/null && echo openclaw-ok
./files/clds/usage.sh          # session + weekly usage bars (needs a prior claude login)
```

---

## Machine-specific values

All seven unit files are templates (`{{PLACEHOLDER}}` tokens), rendered by
`apply.sh` via `00_configs/load.sh`'s `render_template` — the tracked files in
`files/systemd/` never hold one station's literal paths/ports again.

- **Working directories** (`{{ANVILON_DIR}}`, `{{CLDLAB_DIR}}`,
  `{{REMDEV_DIR}}`, `{{RESMAN_DIR}}`, `{{SOLSEED_DIR}}`,
  `{{MDPLANNER_DIR}}`) — from the station yaml's `agents.dirs.*` (skeleton
  in `../00_configs/TEMPLATE.yaml`, commented out). Only relevant if you're
  carrying these specific personal agent servers forward onto the new
  station in the first place — most stations won't have any; `apply.sh`
  skips every unit whose dir key is unset.
- **Ports** (`{{CLDLAB_PORT}}`, `{{OPENCLAW_PORT}}`) — from
  `agents.ports.*` in the same file; change there if they collide with
  something else on the target box.
- **`openclaw-gateway.service`'s node path** — no longer pinned
  (`v22.16.0` used to hardcode both the username and an exact nvm-managed
  version, both of which drift). `apply.sh` now resolves `{{NODE_BIN}}`/
  `{{OPENCLAW_JS}}` live via `$(command -v node)` (falling back to nvm's
  `alias/default` version dir)/`$(npm root -g)` at render time, so an nvm
  upgrade doesn't leave a dangling `ExecStart`.
- **`mdplanner.service`'s `User=`/`Group=`** — `{{USERNAME}}`, from
  `station.username` (falls back to `$USER` if the config is missing).
- **`--public` flags** — see the re-decide-consciously note above; these
  stay hand-edited, not config-driven (a security-posture choice, not a
  station-identity value).
- **`files/clds/usage.sh`** — reads `$HOME/.claude/.credentials.json`
  ($HOME-relative, nothing to edit per box). Its Claude Code API version
  header (`anthropic-client-version: 2.1.161`) is hardcoded — cosmetic,
  harmless if stale, but bump it to match the installed `claude --version`
  if the usage endpoint ever starts rejecting old client versions.

---

## Origin

- `~/.claude/settings.json`, `~/.claude/skills/taskList/`
- `~/.config/systemd/user/{anvilon,cldlab,remdev,resman,solseed,openclaw-gateway}.service`
- `/etc/systemd/system/mdplanner.service`

Captured 2026-07-23. Re-sync by re-copying from those paths.

`files/clds/` was the top-level `clds/` folder until 2026-07-24 (folded in
here so all AI tooling lives in one layer); it was itself migrated
2026-07-24 from `/data/proj/myGits/syso/gensys/clds/` (an older, separate
repo predating the `gensys` layered convention), carried over verbatim.
