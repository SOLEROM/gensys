#!/usr/bin/env bash
set -euo pipefail

CREDS="$HOME/.claude/.credentials.json"
BAR_WIDTH=40
WAKEUP=0
JSON_MODE=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for arg in "$@"; do
  [[ "$arg" == "--wakeup" ]] && WAKEUP=1
  [[ "$arg" == "--json"   ]] && JSON_MODE=1
done

if [[ $WAKEUP -eq 1 ]]; then
  [[ $JSON_MODE -eq 0 ]] && echo "Waking up Claude window..."
  bash "$SCRIPT_DIR/wakeup.sh"
  [[ $JSON_MODE -eq 0 ]] && echo "Window ready."
fi

bar() {
  local pct=$1
  local filled=$(( pct * BAR_WIDTH / 100 ))
  local empty=$(( BAR_WIDTH - filled ))
  printf '['
  printf '%0.s#' $(seq 1 $filled) 2>/dev/null || true
  printf '%0.s-' $(seq 1 $empty) 2>/dev/null || true
  printf '] %d%%' "$pct"
}

# ── 1. Fetch real utilization percentages from claude.ai ────────────────────
USAGE_JSON=$(bun -e "
const fs = require('fs');
const creds = JSON.parse(fs.readFileSync('$CREDS'));
const token = creds.claudeAiOauth.accessToken;
const r = await fetch('https://claude.ai/api/oauth/usage', {
  headers: {
    'Authorization': 'Bearer ' + token,
    'Content-Type': 'application/json',
    'anthropic-client-name': 'claude-code',
    'anthropic-client-version': '2.1.161',
  }
});
const d = await r.json();
console.log(JSON.stringify(d));
" 2>&1)

# ── 2. Parse utilization + ccusage local stats ───────────────────────────────
python3 - "$USAGE_JSON" "$JSON_MODE" <<'EOF'
import sys, json, datetime, subprocess

raw      = sys.argv[1]
json_mode = sys.argv[2] == "1"
usage    = json.loads(raw)

def run_ccusage(args):
    r = subprocess.run(["bunx", "--bun", "ccusage"] + args,
                       capture_output=True, text=True)
    return json.loads(r.stdout) if r.returncode == 0 else {}

blocks_data = run_ccusage(["blocks", "--json"])
weekly_data = run_ccusage(["weekly", "--json"])

active = next((b for b in blocks_data.get("blocks", []) if b.get("isActive")), None)
weeks = weekly_data.get("weekly", [])
claude_weeks = [w for w in weeks if "claude" in w.get("metadata", {}).get("agents", [])]
current_week = claude_weeks[-1] if claude_weeks else (weeks[-1] if weeks else None)

def fmt_tokens(n):
    if n >= 1_000_000: return f"{n/1_000_000:.1f}M"
    if n >= 1_000:     return f"{n/1_000:.0f}k"
    return str(n)

def time_until(iso):
    dt = datetime.datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone()
    diff = dt - datetime.datetime.now(datetime.timezone.utc).astimezone()
    total = max(0, int(diff.total_seconds()))
    h, rem = divmod(total, 3600)
    m = rem // 60
    if total >= 86400:
        d, h = divmod(h, 24)
        remaining = f"{d}d {h}h"
    else:
        remaining = f"{h}h {m}m"
    short_time = dt.strftime("%H:%M %Z")
    full_time  = dt.strftime("%a %b %d at %H:%M %Z")
    return short_time, full_time, remaining

BAR = 40

def bar(pct):
    pct = int(round(pct))
    filled = int(pct * BAR / 100)
    empty  = BAR - filled
    return f"[{'#' * filled}{'-' * empty}] {pct}%"

fh = usage.get("five_hour") or {}
pct_session = fh.get("utilization", 0)
reset_iso   = fh.get("resets_at", "")

sd = usage.get("seven_day") or {}
pct_weekly  = sd.get("utilization", 0)
wreset_iso  = sd.get("resets_at", "")

if json_mode:
    out = {"session": {}, "weekly": {}}

    if reset_iso:
        reset_time, _, remaining = time_until(reset_iso)
        out["session"]["utilization_pct"] = pct_session
        out["session"]["resets_at"]       = reset_iso
        out["session"]["resets_at_local"] = reset_time
        out["session"]["remaining"]       = remaining
    if active:
        out["session"]["tokens_used"]     = active["totalTokens"]
        br = (active.get("burnRate") or {}).get("tokensPerMinute", 0)
        if br:
            out["session"]["burn_rate_per_min"] = br

    if wreset_iso:
        _, wreset_full, wremaining = time_until(wreset_iso)
        out["weekly"]["utilization_pct"] = pct_weekly
        out["weekly"]["resets_at"]       = wreset_iso
        out["weekly"]["resets_at_local"] = wreset_full
        out["weekly"]["remaining"]       = wremaining
    if current_week:
        out["weekly"]["tokens_used"] = current_week["totalTokens"]
        models = current_week.get("modelsUsed", [])
        if models:
            out["weekly"]["models"] = models

    print(json.dumps(out, indent=2))

else:
    print()
    print("=== Claude Code Usage ===")

    print()
    print("── Session (5-hour block) ──")
    if reset_iso:
        reset_time, _, remaining = time_until(reset_iso)
        print(f"  {bar(pct_session)}")
        print(f"  Resets at {reset_time}  ({remaining} remaining)")
    if active:
        tok = active["totalTokens"]
        br  = (active.get("burnRate") or {}).get("tokensPerMinute", 0)
        print(f"  Tokens used:  {fmt_tokens(tok)}", end="")
        if br:
            print(f"  |  burn {fmt_tokens(br)}/min", end="")
        print()

    print()
    print("── Weekly limit ──")
    if wreset_iso:
        _, wreset_full, wremaining = time_until(wreset_iso)
        print(f"  {bar(pct_weekly)}")
        print(f"  Resets at {wreset_full}  ({wremaining} remaining)")
    if current_week:
        tok = current_week["totalTokens"]
        models = ", ".join(current_week.get("modelsUsed", []))
        print(f"  Tokens used:  {fmt_tokens(tok)}", end="")
        if models:
            print(f"  |  {models}", end="")
        print()

    print()
EOF
