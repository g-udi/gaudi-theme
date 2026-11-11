#!/usr/bin/env bash
#
# Prompt character
#
# The character(s) in front of the cursor, on the last line of PS1. It is drawn
# on every prompt from the exit status of the last command: one colour when the
# command succeeded, another when it failed.

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

# Colours are plain escape sequences such as "$GAUDI_GREEN"; the theme wraps
# them in \[ \] itself. A value that already holds \[ \] is used as it is.
GAUDI_CHAR_PREFIX="${GAUDI_CHAR_PREFIX=""}"
GAUDI_CHAR_SUFFIX="${GAUDI_CHAR_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_CHAR_SYMBOL="${GAUDI_CHAR_SYMBOL=">>"}"
GAUDI_CHAR_COLOR_SUCCESS="${GAUDI_CHAR_COLOR_SUCCESS="$GAUDI_GREEN"}"
GAUDI_CHAR_COLOR_FAILURE="${GAUDI_CHAR_COLOR_FAILURE="$GAUDI_RED"}"
GAUDI_CHAR_COLOR_CLEAR="${GAUDI_CHAR_COLOR_CLEAR="$NC"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Paint the prompt character in GAUDI_CHAR_COLOR_FAILURE if the previous command
# failed and in GAUDI_CHAR_COLOR_SUCCESS if everything was OK. The result, left
# in GAUDI_THEME_REPLY, is ready to be appended to PS1: colours are wrapped in
# \[ \] and the text is escaped so bash prints it instead of expanding it.
# Nothing is forked.
# USAGE:
#   gaudi::segment_char [exit status]
gaudi::segment_char () {
  local status="${1:-${RETVAL:-0}}"
  local color="$GAUDI_CHAR_COLOR_SUCCESS"
  local clear="$GAUDI_CHAR_COLOR_CLEAR"
  local prefix="" symbol="" suffix=""

  [[ "$status" == 0 ]] || color="$GAUDI_CHAR_COLOR_FAILURE"

  # Empty values are skipped: `printf -v` with an empty result leaves stale
  # data in the variable on bash 3.2.
  [[ -n "$GAUDI_CHAR_PREFIX" ]] && printf -v prefix '%b' "$GAUDI_CHAR_PREFIX"
  [[ -n "$GAUDI_CHAR_SYMBOL" ]] && printf -v symbol '%b' "$GAUDI_CHAR_SYMBOL"
  [[ -n "$GAUDI_CHAR_SUFFIX" ]] && printf -v suffix '%b' "$GAUDI_CHAR_SUFFIX"

  gaudi::set_prompt_escaped "$prefix"
  prefix="$GAUDI_THEME_REPLY"
  gaudi::set_prompt_escaped "$symbol"
  symbol="$GAUDI_THEME_REPLY"
  gaudi::set_prompt_escaped "$suffix"
  suffix="$GAUDI_THEME_REPLY"

  [[ -n "$color" && "$color" != *'\['* ]] && color="\[${color}\]"
  [[ -n "$clear" && "$clear" != *'\['* ]] && clear="\[${clear}\]"

  GAUDI_THEME_REPLY="${prefix}${color}${symbol}${clear}${suffix}"
}

gaudi_char () {
  gaudi::segment_char "$@"
  printf '%s' "$GAUDI_THEME_REPLY"
}
