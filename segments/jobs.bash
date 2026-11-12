#!/usr/bin/env bash
#
# Background jobs
#

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_JOBS_SHOW="${GAUDI_JOBS_SHOW=true}"
GAUDI_JOBS_PREFIX="${GAUDI_JOBS_PREFIX=" "}"
GAUDI_JOBS_SUFFIX="${GAUDI_JOBS_SUFFIX=" "}"
GAUDI_JOBS_SYMBOL="${GAUDI_JOBS_SYMBOL="\\uf013"}"
GAUDI_JOBS_COLOR="${GAUDI_JOBS_COLOR="$GAUDI_WHITE"}"
GAUDI_JOBS_AMOUNT_PREFIX="${GAUDI_JOBS_AMOUNT_PREFIX=""}"
GAUDI_JOBS_AMOUNT_SUFFIX="${GAUDI_JOBS_AMOUNT_SUFFIX=""}"
GAUDI_JOBS_AMOUNT_THRESHOLD="${GAUDI_JOBS_AMOUNT_THRESHOLD=1}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Show an icon when jobs are running in the background. Their number is added,
# between GAUDI_JOBS_AMOUNT_PREFIX and GAUDI_JOBS_AMOUNT_SUFFIX, once there are
# more of them than GAUDI_JOBS_AMOUNT_THRESHOLD.
gaudi_jobs () {
  [[ $GAUDI_JOBS_SHOW == false ]] && return

  local jobs_amount=""
  jobs_amount="$(jobs -r | awk '!/wd/' | wc -l | tr -d " ")"

  [[ $jobs_amount -gt 0 ]] || return

  if [[ $jobs_amount -le $GAUDI_JOBS_AMOUNT_THRESHOLD ]]; then
    jobs_amount=''
  else
    jobs_amount="${GAUDI_JOBS_AMOUNT_PREFIX}${jobs_amount}${GAUDI_JOBS_AMOUNT_SUFFIX}"
  fi

  gaudi::section \
    "$GAUDI_JOBS_COLOR" \
    "$GAUDI_JOBS_PREFIX" \
    "$GAUDI_JOBS_SYMBOL" \
    "$jobs_amount" \
    "$GAUDI_JOBS_SUFFIX"
}
