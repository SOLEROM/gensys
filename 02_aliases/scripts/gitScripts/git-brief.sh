#!/bin/bash
# git-brief.sh [dir] — print a commit message (subject + up to 4 bullets of
# the other big changes, 5 lines max) for the uncommitted
# changes under dir (default ./), written by a headless Claude Code call
# using the prompt in git-brief.prompt.md next to this script.
#   usage:  git.brief           -> prints the message
#           gitup "$(git.brief)" -> commit + push with it
# env: GIT_BRIEF_MODEL (default haiku), GIT_BRIEF_MAX_BYTES (default 150000)

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
prompt="$here/git-brief.prompt.md"
model="${GIT_BRIEF_MODEL:-haiku}"
max_bytes="${GIT_BRIEF_MAX_BYTES:-150000}"

cd "${1:-.}" || exit 1

if ! git rev-parse --is-inside-work-tree &> /dev/null; then
  echo "Error: Not inside a Git repository." >&2
  exit 1
fi
[ -f "$prompt" ] || { echo "Error: prompt not found: $prompt" >&2; exit 1; }
command -v claude &> /dev/null || { echo "Error: claude CLI not on PATH." >&2; exit 1; }

# changes scoped to this folder: tracked (staged + unstaged) vs HEAD, plus
# untracked files. A repo with no commits yet diffs against the empty tree.
base=HEAD
git rev-parse --verify -q HEAD > /dev/null || base=$(git hash-object -t tree /dev/null)
status=$(git status -s -- .)
if [ -z "$status" ]; then
  echo "Nothing to commit under $(pwd)." >&2
  exit 1
fi

changes() {
  echo "Folder: $(git rev-parse --show-prefix)"
  echo
  echo "### git status -s"
  echo "$status"
  echo
  echo "### recent log (style reference)"
  git log --oneline -n 10 2> /dev/null
  echo
  echo "### diff"
  git diff "$base" -- .
  git ls-files --others --exclude-standard -z -- . |
    while IFS= read -r -d '' f; do
      git diff --no-index -- /dev/null "$f"
    done
}

body=$(changes | head -c "$max_bytes")
[ "${#body}" -ge "$max_bytes" ] && body+=$'\n\n[diff truncated]'

msg=$(printf '%s\n\n%s\n' "$(cat "$prompt")" "$body" |
  claude -p --model "$model" --tools "" --no-session-persistence)
rc=$?
[ $rc -eq 0 ] || { echo "Error: claude exited $rc." >&2; exit $rc; }

# drop blank/fence lines and stray quotes, keep at most 5 lines, and put
# git's blank line between the subject and the bullets
printf '%s\n' "$msg" |
  sed -e '/^[[:space:]]*$/d' -e '/^[[:space:]]*```/d' \
      -e 's/^[[:space:]]*//; s/[[:space:]]*$//' -e 's/^`\(.*\)`$/\1/; s/^"\(.*\)"$/\1/' |
  head -n 5 | sed '1{$!a\

}'
