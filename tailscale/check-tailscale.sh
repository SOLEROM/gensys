#!/usr/bin/env bash
set -euo pipefail

# check-tailscale.sh — verify Tailscale is installed and configured on THIS host
# so it can join the tailnet and be reached from / reach your other devices
# (station, VPS, Android). See README.md in this directory.
#
# Usage:
#   ./check-tailscale.sh            # station mode: also require Tailscale SSH server ON
#   ./check-tailscale.sh --client   # client mode (VPS/laptop): SSH server is optional
#   ./check-tailscale.sh --help
#
# Exit code: 0 if no failures, 1 if any check FAILED.

# ── args ─────────────────────────────────────────────────────────────────────
MODE="station"
for arg in "$@"; do
  case "$arg" in
    --client)      MODE="client" ;;
    --station)     MODE="station" ;;
    -h|--help)
      sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "Unknown option: $arg (use --help)" >&2
      exit 2 ;;
  esac
done

# ── colours (respect NO_COLOR and non-tty) ───────────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; DIM=$'\e[2m'; RST=$'\e[0m'
else
  R=""; G=""; Y=""; B=""; DIM=""; RST=""
fi

PASS_N=0; WARN_N=0; FAIL_N=0
pass() { PASS_N=$((PASS_N+1)); printf '  %sPASS%s %s\n' "$G" "$RST" "$1"; }
warn() { WARN_N=$((WARN_N+1)); printf '  %sWARN%s %s\n' "$Y" "$RST" "$1"; [[ -n "${2:-}" ]] && printf '       %s%s%s\n' "$DIM" "$2" "$RST"; }
fail() { FAIL_N=$((FAIL_N+1)); printf '  %sFAIL%s %s\n' "$R" "$RST" "$1"; [[ -n "${2:-}" ]] && printf '       %s→ %s%s\n' "$DIM" "$2" "$RST"; }
info() { printf '  %s•%s   %s\n' "$B" "$RST" "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ── minimal JSON reader (dotted path). Prefers jq, falls back to python3 ──────
JSON_TOOL=""
have jq && JSON_TOOL="jq"
[[ -z "$JSON_TOOL" ]] && have python3 && JSON_TOOL="python3"

jget() {  # usage: printf '%s' "$json" | jget <dotted.path>
  local path="$1"
  case "$JSON_TOOL" in
    jq)      jq -r ".${path} // empty" 2>/dev/null ;;
    python3) python3 -c '
import sys, json
try:
    cur = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for k in sys.argv[1].split("."):
    cur = cur.get(k) if isinstance(cur, dict) else None
    if cur is None:
        break
if cur is None:
    print("")
elif isinstance(cur, bool):
    print("true" if cur else "false")
else:
    print(cur)' "$path" 2>/dev/null ;;
    *)       printf '' ;;
  esac
}

printf '%s┌─ Tailscale check ── host: %s ── mode: %s ─%s\n' "$B" "$(hostname)" "$MODE" "$RST"

# ── 1. binary installed ──────────────────────────────────────────────────────
if ! have tailscale; then
  fail "tailscale CLI is not installed" \
       "Install: curl -fsSL https://tailscale.com/install.sh | sh"
  printf '\n%s✗ Cannot continue — Tailscale is not installed.%s\n' "$R" "$RST"
  exit 1
fi
pass "tailscale CLI installed ($(tailscale version 2>/dev/null | head -1))"

if [[ -z "$JSON_TOOL" ]]; then
  warn "neither 'jq' nor 'python3' found — some config checks will be skipped" \
       "Install jq for full checks:  sudo apt-get install -y jq"
fi

# ── 2. daemon running ────────────────────────────────────────────────────────
DAEMON_OK=0
if have systemctl && systemctl list-unit-files 2>/dev/null | grep -q '^tailscaled\.service'; then
  if systemctl is-active --quiet tailscaled; then
    pass "tailscaled service is active"; DAEMON_OK=1
  else
    fail "tailscaled service is not running" "sudo systemctl enable --now tailscaled"
  fi
elif pgrep -x tailscaled >/dev/null 2>&1; then
  pass "tailscaled process is running"; DAEMON_OK=1
else
  warn "could not confirm tailscaled is running (no systemd unit / process found)"
fi

# ── 3. backend state (are we logged in and up?) ──────────────────────────────
STATUS_JSON="$(tailscale status --json 2>/dev/null || true)"
if [[ -z "$STATUS_JSON" ]]; then
  fail "cannot talk to tailscaled (\`tailscale status\` failed)" \
       "Start it: sudo systemctl enable --now tailscaled  — or run 'sudo tailscale up'"
  printf '\n'; # summary at end
else
  STATE="$(printf '%s' "$STATUS_JSON" | jget BackendState)"
  case "$STATE" in
    Running)
      pass "backend state: Running (logged in and up)" ;;
    NeedsLogin)
      fail "backend state: NeedsLogin (not authenticated)" \
           "sudo tailscale up --ssh --hostname=$( [[ $MODE == station ]] && echo station || echo "$(hostname)" )" ;;
    Stopped)
      fail "backend state: Stopped (logged in but tailscale is down)" "sudo tailscale up" ;;
    NoState|"")
      warn "backend state unknown — daemon may be starting" "Re-run in a few seconds" ;;
    *)
      warn "backend state: $STATE" ;;
  esac

  # ── 4. identity / addressing ───────────────────────────────────────────────
  TS_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
  DNS_NAME="$(printf '%s' "$STATUS_JSON" | jget Self.DNSName)"
  DNS_NAME="${DNS_NAME%.}"   # strip trailing dot
  ONLINE="$(printf '%s' "$STATUS_JSON" | jget Self.Online)"

  if [[ -n "$TS_IP" ]]; then
    info "tailnet IPv4 : $TS_IP"
  else
    warn "no tailnet IPv4 assigned yet"
  fi
  [[ -n "$DNS_NAME" ]] && info "MagicDNS name: $DNS_NAME"

  if [[ "$ONLINE" == "true" ]]; then
    pass "this host reports Online on the tailnet"
  elif [[ "$STATE" == "Running" ]]; then
    warn "this host is not reporting Online yet"
  fi

  # ── 5. MagicDNS enabled on the tailnet ─────────────────────────────────────
  MDNS="$(printf '%s' "$STATUS_JSON" | jget CurrentTailnet.MagicDNSEnabled)"
  case "$MDNS" in
    true)  pass "MagicDNS is enabled (reach devices by name)" ;;
    false) warn "MagicDNS is disabled for this tailnet" \
                "Enable it: admin console → DNS → MagicDNS (then names like 'station' resolve)" ;;
    *)     [[ -n "$JSON_TOOL" ]] && warn "could not determine MagicDNS state" ;;
  esac

  # ── 6. Tailscale SSH server (station mode wants this ON) ────────────────────
  PREFS_JSON="$(tailscale debug prefs 2>/dev/null || true)"
  RUNSSH=""
  [[ -n "$PREFS_JSON" ]] && RUNSSH="$(printf '%s' "$PREFS_JSON" | jget RunSSH)"

  if [[ -z "$PREFS_JSON" ]]; then
    warn "could not read prefs to check Tailscale SSH" \
         "Try: sudo tailscale debug prefs   (or check 'tailscale status' shows this host)"
  elif [[ "$RUNSSH" == "true" ]]; then
    pass "Tailscale SSH server is ENABLED (other devices can SSH into this host)"
  else
    if [[ "$MODE" == "station" ]]; then
      fail "Tailscale SSH server is OFF — the station can't be SSH'd into" \
           "Enable it: sudo tailscale up --ssh --hostname=station"
    else
      info "Tailscale SSH server is off (fine for a client-only host)"
    fi
  fi

  # ── 7. peers overview (informational) ──────────────────────────────────────
  if [[ "$JSON_TOOL" == "jq" ]]; then
    PEERS_ONLINE="$(printf '%s' "$STATUS_JSON" | jq -r '[.Peer[]? | select(.Online)] | length' 2>/dev/null || echo "?")"
    PEERS_TOTAL="$(printf '%s' "$STATUS_JSON" | jq -r '(.Peer // {}) | length' 2>/dev/null || echo "?")"
    info "tailnet peers: ${PEERS_ONLINE} online / ${PEERS_TOTAL} total"
  fi
fi

# ── summary ──────────────────────────────────────────────────────────────────
printf '%s└─ summary: %s%d passed%s, %s%d warn%s, %s%d failed%s\n' \
  "$B" "$G" "$PASS_N" "$RST" "$Y" "$WARN_N" "$RST" "$R" "$FAIL_N" "$B$RST"

if [[ "$FAIL_N" -gt 0 ]]; then
  printf '%s✗ Not fully configured — address the FAIL items above.%s\n' "$R" "$RST"
  exit 1
fi
if [[ "$WARN_N" -gt 0 ]]; then
  printf '%s✓ Usable, with warnings above.%s\n' "$Y" "$RST"
  exit 0
fi
printf '%s✓ Tailscale is installed and configured on this host.%s\n' "$G" "$RST"
exit 0
