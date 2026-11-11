#!/usr/bin/env bash
#
# Time
#
# Current time

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_TIME_SHOW="${GAUDI_TIME_SHOW=true}"
GAUDI_TIME_PREFIX="${GAUDI_TIME_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_TIME_SYMBOL="\\ue384"
GAUDI_TIME_SUFFIX="${GAUDI_TIME_SUFFIX=$GAUDI_PROMPT_DEFAULT_SUFFIX}"
GAUDI_TIME_FORMAT="${GAUDI_TIME_FORMAT="+%H:%M"}"
GAUDI_TIME_COLOR="${GAUDI_TIME_COLOR="$GAUDI_GREEN"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Leaves the section in GAUDI_THEME_REPLY. GAUDI_TIME_FORMAT is a `date`
# format ("+%H:%M"); on bash 4.2 and later it is rendered by the printf builtin
# instead of forking `date`.
gaudi::segment_time () {
  local time_str=""
  local format="${GAUDI_TIME_FORMAT#+}"

  GAUDI_THEME_REPLY=""
  [[ $GAUDI_TIME_SHOW == false ]] && return

  if [[ $GAUDI_TIME_FORMAT != false ]]; then
    if [[ "$format" != *")"* ]] &&
      [[ ${BASH_VERSINFO[0]} -gt 4 || ( ${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -ge 2 ) ]]; then
      printf -v time_str "%(${format})T" -1
    else
      time_str=$(date "+${format}")
    fi
  fi

  gaudi::set_section \
    "$GAUDI_TIME_COLOR" \
    "$GAUDI_TIME_PREFIX" \
    "$GAUDI_TIME_SYMBOL" \
    "$time_str" \
    "$GAUDI_TIME_SUFFIX"
}

gaudi_time () {
  gaudi::segment_time
  printf '%s' "$GAUDI_THEME_REPLY"
}
