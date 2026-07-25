#!/bin/bash
newName=$1
curNum=$(i3-msg -t get_workspaces   | jq '.[] | select(.focused==true).num')
i3-msg "rename workspace to \"$curNum: $curNum.$newName\""

