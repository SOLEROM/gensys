# shellcheck shell=bash
# (sourced, not executed — no shebang on purpose; see 05_shell/apply.sh)
# Usage:
#   source tit.sh "aaa"
# Purpose:
#   Set terminal title without touching your existing PS1 / PROMPT.

tit="${1:-}"
[ -z "$tit" ] && return 0

# Bash
if [ -n "${BASH_VERSION-}" ]; then
  __tit_set_title() { printf '\e]0;%s\a' "$tit"; }

  # Prepend to existing PROMPT_COMMAND safely
  case ";${PROMPT_COMMAND-};" in
    *";__tit_set_title;"*) : ;;
    *)
      if [ -n "${PROMPT_COMMAND-}" ]; then
        PROMPT_COMMAND="__tit_set_title; $PROMPT_COMMAND"
      else
        PROMPT_COMMAND="__tit_set_title"
      fi
      ;;
  esac

  return 0
fi

# zsh
if [ -n "${ZSH_VERSION-}" ]; then
  autoload -Uz add-zsh-hook 2>/dev/null || true
  __tit_set_title() { print -n -- $'\e]0;'"${tit}"$'\a'; }
  add-zsh-hook precmd __tit_set_title
  return 0
fi

