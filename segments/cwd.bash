#!/usr/bin/env bash
# shellcheck shell=bash

#
# Working directory
#
# Current directory, with $HOME shown as "~". Long paths are shortened: parent
# directories are abbreviated to their first character, longest first, until
# the path fits GAUDI_CWD_MAX_LENGTH; the current directory name is kept whole.

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_CWD_SHOW="${GAUDI_CWD_SHOW=true}"
GAUDI_CWD_SHORTEN="${GAUDI_CWD_SHORTEN=true}"
GAUDI_CWD_MAX_LENGTH="${GAUDI_CWD_MAX_LENGTH=33}"
GAUDI_CWD_SUMMARY="${GAUDI_CWD_SUMMARY=false}"
GAUDI_CWD_PREFIX="${GAUDI_CWD_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_CWD_SUFFIX="${GAUDI_CWD_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_CWD_COLOR="${GAUDI_CWD_COLOR="$BACKGROUND_GAUDI_BLUE"}"
GAUDI_CWD_COLOR_LOCKED="${GAUDI_CWD_COLOR_LOCKED="$GAUDI_WHITE$BACKGROUND_GAUDI_RED"}"
GAUDI_CWD_SEPARATOR="${GAUDI_CWD_SEPARATOR=""}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Replace a leading $HOME with "~". The result is left in GAUDI_THEME_REPLY.
# USAGE:
#   gaudi::set_tilde_path <path>
gaudi::set_tilde_path () {
  local path="$1"

  if [[ -n "${HOME:-}" && "$HOME" != "/" ]]; then
    if [[ "$path" == "$HOME" ]]; then
      path="~"
    elif [[ "$path" == "$HOME"/* ]]; then
      path="~${path#"$HOME"}"
    fi
  fi

  GAUDI_THEME_REPLY="$path"
}

# Shorten a path to at most <max length> characters and leave the result in
# GAUDI_THEME_REPLY. Nothing is forked.
#
#   1. "/" is shown as "⚠ ROOT" and $HOME as "~".
#   2. A path that already fits is returned unchanged.
#   3. Otherwise the parent directories are abbreviated one at a time, longest
#      first (leftmost first when equally long), to their first character
#      (hidden directories keep the dot: ".config" becomes ".c"). The last
#      element, the current directory, is never abbreviated.
#   4. If the path is still too long once every parent is abbreviated, its
#      middle is replaced with "…".
#
# USAGE:
#   gaudi::set_reduced_path [path] [max length]
gaudi::set_reduced_path () {
  local path="${1-$PWD}"
  local target="${2-${GAUDI_CWD_MAX_LENGTH:-33}}"
  local rest="" joined="" short=""
  local i=0 last=0 longest=0 longest_index=0 head=0 tail=0
  local -a elements=()

  [[ "$target" =~ ^[0-9]+$ && "$target" -gt 0 ]] || target=33

  if [[ "$path" == "/" ]]; then
    GAUDI_THEME_REPLY="⚠ ROOT"
    return
  fi

  gaudi::set_tilde_path "$path"
  path="$GAUDI_THEME_REPLY"
  [[ ${#path} -le $target ]] && return

  # Split on "/" by hand: no IFS change, no globbing, no word splitting.
  rest="$path"
  while [[ "$rest" == */* ]]; do
    elements+=("${rest%%/*}")
    rest="${rest#*/}"
  done
  elements+=("$rest")
  last=$((${#elements[@]} - 1))

  while :; do
    longest=0
    longest_index=-1

    for ((i = 0; i < last; i++)); do
      short="${elements[i]:0:1}"
      [[ "$short" == "." ]] && short="${elements[i]:0:2}"

      if [[ ${#elements[i]} -gt ${#short} && ${#elements[i]} -gt $longest ]]; then
        longest=${#elements[i]}
        longest_index=$i
      fi
    done

    # Every parent directory is already abbreviated.
    [[ $longest_index -ge 0 ]] || break

    short="${elements[longest_index]:0:1}"
    [[ "$short" == "." ]] && short="${elements[longest_index]:0:2}"
    elements[longest_index]="$short"

    joined="${elements[0]}"
    for ((i = 1; i <= last; i++)); do
      joined+="/${elements[i]}"
    done
    path="$joined"

    if [[ ${#path} -le $target ]]; then
      GAUDI_THEME_REPLY="$path"
      return
    fi
  done

  head=$(((target - 1) / 2))
  tail=$((target - 1 - head))
  GAUDI_THEME_REPLY="${path:0:head}…${path:${#path}-tail}"
}

# Printing variant of gaudi::set_reduced_path.
# USAGE:
#   gaudi_reduce_path [path] [max length]
gaudi_reduce_path () {
  gaudi::set_reduced_path "$@"
  printf '%s\n' "$GAUDI_THEME_REPLY"
}

# Shows the current working directory. Leaves the section in GAUDI_THEME_REPLY.
gaudi::segment_cwd () {
  local color="" cwd="" entry="" size=""
  local count=0

  GAUDI_THEME_REPLY=""
  [[ $GAUDI_CWD_SHOW == false ]] && return

  if [[ -w $PWD ]]; then
    color=$GAUDI_CWD_COLOR
  else
    color=$GAUDI_CWD_COLOR_LOCKED
  fi

  if [[ $GAUDI_CWD_SHORTEN == true ]]; then
    gaudi::set_reduced_path "$PWD"
  else
    gaudi::set_tilde_path "$PWD"
  fi

  # The prompt layout is printed with `printf %b` later on: double the
  # backslashes of the path so a directory name is never read as an escape
  # sequence.
  cwd="${GAUDI_THEME_REPLY//\\/\\\\}"

  if [[ $GAUDI_CWD_SUMMARY == true ]]; then
    for entry in *; do
      [[ -e "$entry" || -L "$entry" ]] && count=$((count + 1))
    done
    # First line of `ls -lah` is "total <size>".
    { read -r _ size; } < <(command ls -lah 2> /dev/null)
    cwd+=" [${count} Files, ${size}]"
  fi

  gaudi::set_section \
    "$color" \
    "$GAUDI_CWD_PREFIX" \
    "$GAUDI_CWD_SEPARATOR" \
    "$cwd" \
    "$GAUDI_CWD_SUFFIX"
}

gaudi_cwd () {
  gaudi::segment_cwd
  printf '%s' "$GAUDI_THEME_REPLY"
}
