#!/usr/bin/env bash
#
# Continuation character
#
# PS2, shown while a command continues on the next line.

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

# This segment used to share the GAUDI_CHAR_* names with the `char` segment. It
# now has its own; a GAUDI_CHAR_* value set before the theme loads is still
# used as the fallback so existing configurations keep working. The theme loads
# this file before segments/char.bash, so only values set by the user (never the
# defaults of the `char` segment) are picked up here.
GAUDI_CONTINUATION_PREFIX="${GAUDI_CONTINUATION_PREFIX=${GAUDI_CHAR_PREFIX-}}"
GAUDI_CONTINUATION_SUFFIX="${GAUDI_CONTINUATION_SUFFIX=${GAUDI_CHAR_SUFFIX-\\t}}"
GAUDI_CONTINUATION_SYMBOL="${GAUDI_CONTINUATION_SYMBOL=${GAUDI_CHAR_SYMBOL-\\uf6d7}}"
GAUDI_CONTINUATION_COLOR="${GAUDI_CONTINUATION_COLOR=${GAUDI_CHAR_COLOR_SUCCESS-$GAUDI_YELLOW}}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Paint PS2 – Continuation interactive prompt
gaudi_continuation () {

  gaudi::section \
    "$GAUDI_CONTINUATION_COLOR" \
    "$GAUDI_CONTINUATION_PREFIX" \
    "$GAUDI_CONTINUATION_SYMBOL" \
    "" \
    "$GAUDI_CONTINUATION_SUFFIX"
}
