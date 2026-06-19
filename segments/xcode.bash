#!/usr/bin/env bash
#
# Xcode
#
# Xcode is an integrated development environment for macOS.
# Link: https://developer.apple.com/xcode/

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_XCODE_SHOW_LOCAL="${GAUDI_XCODE_SHOW_LOCAL=true}"
GAUDI_XCODE_SHOW_GLOBAL="${GAUDI_XCODE_SHOW_GLOBAL=false}"
GAUDI_XCODE_PREFIX="${GAUDI_XCODE_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_XCODE_SUFFIX="${GAUDI_XCODE_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_XCODE_SYMBOL="${GAUDI_XCODE_SYMBOL="\\ufb32"}"
GAUDI_XCODE_COLOR="${GAUDI_XCODE_COLOR=""}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Show current version of Xcode
gaudi_xcode () {
  gaudi::exists xcenv || return
  gaudi::exists defaults || return

  [[ $GAUDI_XCODE_SHOW_GLOBAL == false && $GAUDI_XCODE_SHOW_LOCAL == false ]] && return

  local xcode_path="" xcode_version_path="" xcode_version="" xcenv_version=""

  xcenv_version="$(xcenv version 2>/dev/null)" || return

  if [[ $GAUDI_XCODE_SHOW_GLOBAL == true ]] ; then
    xcode_path="$(printf "%s" "$xcenv_version" | sed 's/ .*//')"
  elif [[ $GAUDI_XCODE_SHOW_LOCAL == true ]] ; then
    if printf "%s" "$xcenv_version" | grep -q "\.xcode-version"; then
      xcode_path="$(printf "%s" "$xcenv_version" | sed 's/ .*//')"
    fi
  fi

  [[ -n "$xcode_path" ]] || return

  xcode_version_path="${xcode_path}/Contents/version.plist"
  [[ -f "$xcode_version_path" ]] || return

  xcode_version="$(defaults read "$xcode_version_path" CFBundleShortVersionString 2>/dev/null)" || return
  [[ -n "$xcode_version" ]] || return

  gaudi::section \
    "$GAUDI_XCODE_COLOR" \
    "$GAUDI_XCODE_PREFIX" \
    "$GAUDI_XCODE_SYMBOL" \
    "$xcode_version" \
    "$GAUDI_XCODE_SUFFIX"
}
