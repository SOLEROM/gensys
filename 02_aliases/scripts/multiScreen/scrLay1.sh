#!/bin/bash
## {{MON_*}} rendered by 05_shell/apply.sh from desktop.monitors.* in the
## station config (per-box xrandr --listmonitors output)
lpt="{{MON_LAPTOP}}"
wide="{{MON_WIDE}}"
top="{{MON_TOP}}"
curName=$(i3-msg -t get_workspaces   | jq -r '.[] | select(.focused==true).name')
curDir="$(cd "$(dirname "$0")" && pwd)"

$curDir/scrLay0.sh lpt

i3-msg workspace number 1, move workspace to output $top
i3-msg workspace number 2, move workspace to output $wide

i3-msg "workspace \"$curName\""
