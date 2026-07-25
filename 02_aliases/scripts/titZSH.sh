# shellcheck shell=bash
# (sourced, not executed — no shebang on purpose; see 05_shell/apply.sh)
#this file will be source by the alias with input param for title shell
tit="$1"
#output:
echo -n -e "\033]0;$tit\007"
