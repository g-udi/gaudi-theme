#!/usr/bin/env bash
#
# Nix Shell
#
# Shows when inside a Nix shell environment.
# Link: https://nixos.org/

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_NIX_SHOW="${GAUDI_NIX_SHOW=true}"
GAUDI_NIX_PREFIX="${GAUDI_NIX_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_NIX_SUFFIX="${GAUDI_NIX_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_NIX_SYMBOL="${GAUDI_NIX_SYMBOL="\\uf313"}"
GAUDI_NIX_COLOR="${GAUDI_NIX_COLOR="$GAUDI_CYAN"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Show Nix shell indicator
gaudi_nix () {
  [[ "$GAUDI_NIX_SHOW" == false ]] && return

  # Check if we're inside a nix-shell or nix develop
  [[ -n "$IN_NIX_SHELL" || -n "$IN_NIX_DEVELOP" ]] || return

  local nix_info="nix-shell"
  [[ -n "$IN_NIX_DEVELOP" ]] && nix_info="nix develop"

  # Show the name if available
  [[ -n "$name" ]] && nix_info="$name"

  gaudi::section \
    "$GAUDI_NIX_COLOR" \
    "$GAUDI_NIX_PREFIX" \
    "$GAUDI_NIX_SYMBOL" \
    "$nix_info" \
    "$GAUDI_NIX_SUFFIX"
}
