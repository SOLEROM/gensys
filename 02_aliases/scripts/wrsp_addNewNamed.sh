#!/bin/bash

newName=$1
nextWrkNum=$(i3-msg -t get_workspaces | jq 'map(.num) | max | .+1')
i3-msg workspace $nextWrkNum "$nextWrkNum.$newName"
