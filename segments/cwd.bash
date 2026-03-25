#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2010

#
# Working directory
#
# Current directory. Return only three last items of path

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_CWD_SHOW="${GAUDI_CWD_SHOW=true}"
GAUDI_CWD_SHORTEN="${GAUDI_CWD_SHORTEN=true}"
GAUDI_CWD_SUMMARY="${GAUDI_CWD_SUMMARY=false}"
GAUDI_CWD_PREFIX="${GAUDI_CWD_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_CWD_SUFFIX="${GAUDI_CWD_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_CWD_COLOR="${GAUDI_CWD_COLOR="$BACKGROUND_GAUDI_BLUE"}"
GAUDI_CWD_COLOR_LOCKED="${GAUDI_CWD_COLOR_LOCKED="$GAUDI_WHITE$BACKGROUND_GAUDI_RED"}"
GAUDI_CWD_SEPARATOR="${GAUDI_CWD_SEPARATOR=""}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Shows selected AWS-cli profile.
gaudi_cwd () {
  [[ $GAUDI_CWD_SHOW == false ]] && return

  [[ -w $PWD ]] && color=$GAUDI_CWD_COLOR || color=$GAUDI_CWD_COLOR_LOCKED

  gaudi_reduce_path () {
    local path=${1-$PWD} target=${2-33} IFS=/ order
    [[ $path == "/" ]] && echo "⚠ ROOT" && return
    [[ "$path" =~ ^$HOME(/|$) ]] && path="~${path#"$HOME"}"
    [[ ${#path} -le $target ]] && echo "$path" && return
    order=$( (i=0; for e in $path; do echo ${#e} $i; ((i++)); done ) |
        tail -n 1 | sort -rn | cut -d " " -f 2)
    local elements=("$path")
    IFS=$'\n'
    for i in $order; do
        elements[i]=${elements[i]:0:1}
        IFS=/
        path="${elements[*]}"
        [[ ${#path} -le $target ]] && echo "$path" && return
    done
    echo "${path:0:target/2}~${path: -target/2}"
  }

  [[ $GAUDI_CWD_SHORTEN == true ]] && GAUDI_CWD=$(gaudi_reduce_path "$PWD") || GAUDI_CWD=$(pwd | sed "s|^${HOME}|~|")
  # shellcheck disable=SC2012
  [[ $GAUDI_CWD_SUMMARY == true ]] && GAUDI_CWD+=" [$(ls -1 | wc -l | sed 's: ::g') Files, $(ls -lah | grep -m 1 total | sed 's/total //')]"

  gaudi::section \
    "$color" \
    "$GAUDI_CWD_PREFIX" \
    "$GAUDI_CWD_SEPARATOR" \
    "$GAUDI_CWD" \
    "$GAUDI_CWD_SUFFIX"
}
