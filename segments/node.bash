#!/usr/bin/env bash
#
# Node.js
#
# Node.js is a JavaScript runtime built on Chrome's V8 JavaScript engine.
# Link: https://nodejs.org/

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_NODE_SHOW="${GAUDI_NODE_SHOW=true}"
GAUDI_NODE_PREFIX="${GAUDI_NODE_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_NODE_SUFFIX="${GAUDI_NODE_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_NODE_SYMBOL="${GAUDI_NODE_SYMBOL="\\ue74e"}"
GAUDI_NODE_DEFAULT_VERSION="${GAUDI_NODE_DEFAULT_VERSION=""}"
GAUDI_NODE_COLOR="${GAUDI_NODE_COLOR="$GAUDI_YELLOW"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Show current version of node, exception system.
#
# A version manager that is loaded on first use (the nvm plugin) leaves stub
# functions named nvm and node behind until then. They are never called from
# here: calling one would load nvm inside the prompt. nvm is only asked once
# the real one is loaded (it defines nvm_ls_current), and node only when it is
# a program on PATH.
gaudi_node () {

  [[ $GAUDI_NODE_SHOW == false ]] && return

  # Show NODE status only for JS-specific folders
  [[ -f package.json || -d node_modules ]] || gaudi::has_files '*.js' || return

  local 'node_version'

  if gaudi::defined nvm_ls_current; then
    node_version=$(nvm current 2>/dev/null)
    [[ $node_version == "system" || $node_version == "node" || $node_version == "none" ]] && return
  elif type -P nodenv > /dev/null 2>&1; then
    node_version=$(nodenv version-name)
    [[ $node_version == "system" || $node_version == "node" ]] && return
  elif type -P node > /dev/null 2>&1; then
    node_version=$(command node -v 2>/dev/null)
  else
    return
  fi

  [[ -n $node_version ]] || return

  [[ $node_version == "$GAUDI_NODE_DEFAULT_VERSION" ]] && return

  gaudi::section \
    "$GAUDI_NODE_COLOR" \
    "$GAUDI_NODE_PREFIX" \
    "$GAUDI_NODE_SYMBOL" \
    "$node_version"\
    "$GAUDI_NODE_SUFFIX"
}
