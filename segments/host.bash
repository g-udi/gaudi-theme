#!/usr/bin/env bash
#
# Hostname
#

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_HOST_SHOW="${GAUDI_HOST_SHOW=always}"
GAUDI_HOST_PREFIX="${GAUDI_HOST_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_HOST_SUFFIX="${GAUDI_HOST_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_HOST_COLOR="${GAUDI_HOST_COLOR="$GAUDI_WHITE$BACKGROUND_GAUDI_BLUE"}"
GAUDI_HOST_COLOR_SSH="${GAUDI_HOST_COLOR_SSH="$GAUDI_BLACK$BACKGROUND_GAUDI_YELLOW"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# If there is an ssh connections, current machine name. Leaves the section in
# GAUDI_THEME_REPLY; the name comes from bash's own HOSTNAME variable, so
# `hostname` is only run if that is empty.
gaudi::segment_host () {
  GAUDI_THEME_REPLY=""
  [[ $GAUDI_HOST_SHOW == false ]] && return

  if [[ $GAUDI_HOST_SHOW == 'always' ]] || [[ -n $SSH_CONNECTION ]]; then
    local host_color

    # Determination of what color should be used
    if [[ -n $SSH_CONNECTION ]] || [[ -n "${SSH_CLIENT-}${SSH2_CLIENT-}${SSH_TTY-}" ]]; then
      host_color=$GAUDI_HOST_COLOR_SSH
    else
      host_color=$GAUDI_HOST_COLOR
    fi

    gaudi::set_section \
      "$host_color" \
      "$GAUDI_HOST_PREFIX" \
      "" \
      "${HOSTNAME:-$(hostname)}" \
      "$GAUDI_HOST_SUFFIX"
  fi
}

gaudi_host () {
  gaudi::segment_host
  printf '%s' "$GAUDI_THEME_REPLY"
}
