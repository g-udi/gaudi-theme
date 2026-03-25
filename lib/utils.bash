#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2128,SC1090,SC2154

# Check if command exists in $PATH
# USAGE:
#   gaudi::exists <command>
gaudi::exists () {
  command -v "$1" > /dev/null 2>&1
}

# Check if function is defined
# USAGE:
#   gaudi::defined <function>
gaudi::defined () {
  type -t "$1" &> /dev/null
}

# Draw prompt section
# USAGE:
#   gaudi::section <color> [prefix] [symbol] <content> [suffix]
gaudi::section () {

    local color prefix symbol content suffix

    [[ -n $1 ]] && color="$1"    || color=""
    [[ -n $2 ]] && prefix="$2"   || prefix=""
    [[ -n $3 ]] && symbol="$3"   || symbol=""
    [[ -n $4 ]] && content="$4"  || content=""
    [[ -n $5 ]] && suffix="$5"   || suffix=""

    # gaudi::escape "$color$prefix$symbol $content$suffix${NC}"
    # printf "%b%b%b %b%b%b" "$color" "$prefix" "$symbol" "$content" "$suffix" "${NC}"

    if [[ $GAUDI_ENABLE_SYMBOLS == false ]]; then
      symbol="$GAUDI_SYMBOL_ALT"
    fi
    [[ -n $symbol ]] && symbol="$symbol "
    # Why are wrapping the cariables with "" you say ?
    # To pass a whole string containing GAUDI_WHITEspaces as a single argument, enclose it in double quotes
    # Like every other program, echo or printf interprets strings separated by GAUDI_WHITEspace as different arguments
    echo -n "$color"    # Print out any coloring needed for the section with order of <font_color><background_color>
    echo -n "$prefix"   # Print the prefix before the content .. default prefix is a space
    echo -n "$symbol"   # Print the symbol if exists which is the icon to show before the segment
    echo -n "$content"  # Print the actual content to display in the prompt
    echo -n "$suffix"   # Print the suffix before the content .. default prefix is a space
    echo -n "$NC"       # Reset the coloring set in the $color
}

# Load a segment definition once per shell session.
# USAGE:
#   gaudi::load_segment <segment>
gaudi::load_segment () {
  local segment="$1"
  local loaded_var="GAUDI_SEGMENT_LOADED_${segment//[^a-zA-Z0-9_]/_}"

  [[ ${!loaded_var:-0} == 1 ]] && return 0

  source "$GAUDI_ROOT/segments/$segment.bash" || return 1
  printf -v "$loaded_var" '%s' '1'
}

# Render a single segment by name.
# USAGE:
#   gaudi::render_segment <segment>
gaudi::render_segment () {
  local segment="$1"
  local segment_function="gaudi_${segment}"
  local info=""
  local GAUDI_SYMBOL_ALT="$segment"

  gaudi::load_segment "$segment" || return 1
  gaudi::defined "$segment_function" || return 1

  info="$("$segment_function")"
  [[ -n $info ]] && printf "%s" "$info"
}

# Render a prompt section by getting the segments from the segments definitions array
# USAGE:
#   gaudi::render_prompt segments <array>
gaudi::render_prompt () {
  local _prompt=""
  declare -a _segments=("${!1}")
  if [[ -n "${_segments}" ]]; then
    for segment in "${_segments[@]}"; do
      local info
      info="$(gaudi::render_segment "$segment")"
      [[ -n "${info}" ]] && _prompt+="$info"
    done
    printf "%s" "$_prompt"
  fi;
}

# Check usage of bash-preexec
# USAGE:
#   gaudi::check_precmd_conflict <command>
gaudi::check_precmd_conflict () {
    local f
    for f in "${precmd_functions[@]}"; do
        if [[ "${f}" == "${1}" ]]; then
            return 0
        fi
    done
    return 1
}

# Display seconds in human readable fromat
# Based on http://stackoverflow.com/a/32164707/3859566
# USAGE:
#   gaudi::displaytime <seconds>
gaudi::displaytime () {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  [[ $D -gt 0 ]] && printf '%dd ' $D
  [[ $H -gt 0 ]] && printf '%dh ' $H
  [[ $M -gt 0 ]] && printf '%dm ' $M
  printf '%ds' $S
}
