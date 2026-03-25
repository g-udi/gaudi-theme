#!/usr/bin/env bash
#
# Shell Level
#
# Shows the current shell nesting level (SHLVL).
# Useful for detecting nested shells (e.g., from vim :shell, nix-shell, etc.)

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_SHLVL_SHOW="${GAUDI_SHLVL_SHOW=true}"
GAUDI_SHLVL_PREFIX="${GAUDI_SHLVL_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_SHLVL_SUFFIX="${GAUDI_SHLVL_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_SHLVL_SYMBOL="${GAUDI_SHLVL_SYMBOL="\\uf120"}"
GAUDI_SHLVL_COLOR="${GAUDI_SHLVL_COLOR="$GAUDI_YELLOW"}"
GAUDI_SHLVL_THRESHOLD="${GAUDI_SHLVL_THRESHOLD=2}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Show shell nesting level when above threshold
gaudi_shlvl () {
  [[ "$GAUDI_SHLVL_SHOW" == false ]] && return

  # Only show when shell level exceeds threshold (i.e., in a nested shell)
  [[ "${SHLVL:-1}" -lt "$GAUDI_SHLVL_THRESHOLD" ]] && return

  gaudi::section \
    "$GAUDI_SHLVL_COLOR" \
    "$GAUDI_SHLVL_PREFIX" \
    "$GAUDI_SHLVL_SYMBOL" \
    "L${SHLVL}" \
    "$GAUDI_SHLVL_SUFFIX"
}
