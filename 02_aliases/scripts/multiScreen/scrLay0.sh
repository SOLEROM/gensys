#!/bin/bash
## move all open workspace to desired screen
############################################
## use:	xrandr --listmonitors	to get list;
############################################

# Define screen names — {{MON_*}} rendered by 05_shell/apply.sh from the
# station config (desktop.monitors.*, per-box xrandr --listmonitors output)
leptop="{{MON_LAPTOP}}"
screen1="{{MON_WIDE}}"
screen2="{{MON_TOP}}"

# Choose target screen based on input parameter
case "$1" in
    lpt)
        target="$leptop"
        ;;
    wide)
        target="$screen1"
        ;;
    top)
        target="$screen2"
        ;;
    *)
        echo "Usage: $0 [1|2|3]"
        echo "  lpt = leptop "
        echo "  wide = screen - WIDE "
        echo "  top = screen - TOP"
        exit 1
        ;;
esac

# Get the currently focused workspace
curName=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true).name')

# Move all active workspaces by name to the selected output
i3-msg -t get_workspaces | jq -r '.[].name' | while read -r ws_name; do
    i3-msg "workspace \"$ws_name\", move workspace to output $target"
done

# Restore focus to the previously focused workspace
i3-msg "workspace \"$curName\""

