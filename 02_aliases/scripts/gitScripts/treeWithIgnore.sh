#!/bin/bash

# Path to your Git repository
REPO_PATH=$1

# Level to display
LEVEL=5

# Get the list of ignored files
IGNORED_FILES=$(git -C "$REPO_PATH" ls-files --others --ignored --exclude-standard)

# Convert the ignored files list into a pattern for grep
IGNORED_PATTERN=$(echo "$IGNORED_FILES" | sed 's/^/|/' | tr '\n' ' ' | sed 's/|//')

# Use tree with the level option and exclude ignored files
if [ -n "$IGNORED_PATTERN" ]; then
  tree -h --du -L $LEVEL "$REPO_PATH" | grep -vE "$IGNORED_PATTERN"
else
  tree -h --du -L $LEVEL "$REPO_PATH"
fi

