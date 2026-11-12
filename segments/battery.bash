#!/usr/bin/env bash
# shellcheck disable=SC1091
#
# Battery
#

source "$GAUDI_ROOT/lib/battstat.bash"

# GAUDI_BATTERY_SHOW:
#   always   show the battery on every prompt (default)
#   true     show it only when the charge is below GAUDI_BATTERY_THRESHOLD
#            percent, or when the battery is fully charged
#   false    never show it
# Below GAUDI_BATTERY_THRESHOLD the segment turns red in every mode.
GAUDI_BATTERY_SHOW="${GAUDI_BATTERY_SHOW=always}"
GAUDI_BATTERY_THRESHOLD="${GAUDI_BATTERY_THRESHOLD=10}"
GAUDI_BATTERY_PREFIX="${GAUDI_BATTERY_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_BATTERY_SUFFIX="${GAUDI_BATTERY_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_BATTERY_SYMBOL_CHARGING="${GAUDI_BATTERY_SYMBOL_CHARGING="\\uf240"}"
GAUDI_BATTERY_SYMBOL_DISCHARGING="${GAUDI_BATTERY_SYMBOL_DISCHARGING="\\uf241"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Nothing is shown on a machine without a battery.
gaudi_battery () {

  [[ $GAUDI_BATTERY_SHOW == false ]] && return

  local battery=""

  if [[ $GAUDI_BATTERY_SHOW == always ]]; then
    battery="$(battstat -t "$GAUDI_BATTERY_THRESHOLD" -d "$GAUDI_BATTERY_SYMBOL_DISCHARGING" -c "$GAUDI_BATTERY_SYMBOL_CHARGING" '{b}' '{i}' '{p}')"
  else
    battery="$(battstat -t "$GAUDI_BATTERY_THRESHOLD" --hide-above "$GAUDI_BATTERY_THRESHOLD" -d "$GAUDI_BATTERY_SYMBOL_DISCHARGING" -c "$GAUDI_BATTERY_SYMBOL_CHARGING" '{b}' '{i}' '{p}')"
  fi

  [[ -n "$battery" ]] || return

  gaudi::section \
    "" \
    "$GAUDI_BATTERY_PREFIX" \
    "" \
    "$battery" \
    "$GAUDI_BATTERY_SUFFIX"
}
