#!/usr/bin/env bash
set -euo pipefail

# list-online.sh — list devices on the configured tailnet.
# By default shows only ONLINE devices; the current host is marked with '*'.
# See README.md in this directory.
#
# Usage:
#   ./list-online.sh              # online devices only (pretty table)
#   ./list-online.sh --all        # include offline devices (adds STATUS + LAST SEEN)
#   ./list-online.sh --ips-only   # just the tailnet IPv4s of online devices (for scripts)
#   ./list-online.sh --help
#
# Exit code: 0 on success, 1 if Tailscale isn't reachable/configured.

MODE="online"      # online | all
IPS_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --all)       MODE="all" ;;
    --online)    MODE="online" ;;
    --ips-only|--ips) IPS_ONLY=1 ;;
    -h|--help)   sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           echo "Unknown option: $arg (use --help)" >&2; exit 2 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }
err()  { printf '\e[31m✗ %s\e[0m\n' "$1" >&2; }

# ── preflight ────────────────────────────────────────────────────────────────
if ! have tailscale; then
  err "tailscale CLI is not installed."
  echo "  Install: curl -fsSL https://tailscale.com/install.sh | sh" >&2
  exit 1
fi

STATUS_JSON="$(tailscale status --json 2>/dev/null || true)"
if [[ -z "$STATUS_JSON" ]]; then
  err "cannot talk to tailscaled (is it running and are you logged in?)."
  echo "  Try: sudo systemctl enable --now tailscaled  &&  sudo tailscale up" >&2
  exit 1
fi

# ── aligned-table renderer (falls back to raw TSV if 'column' is missing) ─────
render() { if have column; then column -t -s "$(printf '\t')"; else cat; fi; }

# ── path with jq: rich, reliable table ───────────────────────────────────────
if have jq; then
  STATE="$(printf '%s' "$STATUS_JSON" | jq -r '.BackendState // "unknown"')"
  if [[ "$STATE" != "Running" ]]; then
    err "Tailscale backend is '$STATE' (not Running) — connect first with 'sudo tailscale up'."
    exit 1
  fi

  # --ips-only: plain list, script-friendly
  if [[ "$IPS_ONLY" -eq 1 ]]; then
    printf '%s' "$STATUS_JSON" | jq -r '
      ([.Self] + ((.Peer // {}) | to_entries | map(.value)))
      | map(select(.Online == true))
      | .[] | .TailscaleIPs[0] // empty'
    exit 0
  fi

  # Build the table rows as TSV, then align.
  ROWS="$(printf '%s' "$STATUS_JSON" | jq -r --arg mode "$MODE" '
    .User as $users
    | ([ (.Self + {_self:true}) ] + ((.Peer // {}) | to_entries | map(.value)))
    | map({
        online: (.Online == true),
        self:   (._self == true),
        name:   ((.HostName // (.DNSName // "" | split(".")[0])) + (if ._self then " *" else "" end)),
        ip:     (.TailscaleIPs[0] // "-"),
        os:     (.OS // "-"),
        conn:   (if ._self then "this host"
                 elif (.Relay // "") != "" then "relay:" + .Relay
                 elif (.CurAddr // "") != "" then "direct"
                 else "-" end),
        owner:  ($users[(.UserID|tostring)].LoginName // "-"),
        seen:   (.LastSeen // "-")
      })
    | (if $mode == "online" then map(select(.online)) else . end)
    | sort_by((if .self then 0 else 1 end), (.name | ascii_downcase))
    | .[]
    | if $mode == "all"
      then [ (if .online then "online" else "offline" end), .name, .ip, .os, .conn, .owner, .seen ]
      else [ .name, .ip, .os, .conn, .owner ]
      end
    | @tsv')"

  if [[ -z "$ROWS" ]]; then
    echo "No online devices found on the tailnet."
    exit 0
  fi

  if [[ "$MODE" == "all" ]]; then
    { printf 'STATUS\tNAME\tTAILSCALE_IP\tOS\tCONN\tOWNER\tLAST_SEEN\n'; printf '%s\n' "$ROWS"; } | render
  else
    { printf 'NAME\tTAILSCALE_IP\tOS\tCONN\tOWNER\n'; printf '%s\n' "$ROWS"; } | render
  fi

  COUNT="$(printf '%s\n' "$ROWS" | grep -c '.' || true)"
  printf '\n\e[2m%s device(s) listed (%s).\e[0m\n' "$COUNT" "$MODE"
  exit 0
fi

# ── fallback without jq: use plain `tailscale status` text ────────────────────
echo "(install 'jq' for a richer table:  sudo apt-get install -y jq)" >&2
if [[ "$IPS_ONLY" -eq 1 ]]; then
  # first column is the tailnet IP; drop offline peers
  tailscale status | awk 'tolower($NF) != "offline" { print $1 }'
  exit 0
fi
if [[ "$MODE" == "all" ]]; then
  tailscale status
else
  # `tailscale status` marks offline peers with a trailing "offline"
  tailscale status | awk 'tolower($NF) != "offline"'
fi
