# shellcheck shell=bash
#
# Duration
#
# Shows the execution time of the last command.
# Requires GAUDI_BASH_COMMAND_DURATION=true in your profile.
# Uses _command_duration from lib/command_duration.bash (loaded automatically).

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_DURATION_SHOW="${GAUDI_DURATION_SHOW=true}"
GAUDI_DURATION_PREFIX="${GAUDI_DURATION_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_DURATION_SYMBOL="\uf253"
GAUDI_DURATION_SUFFIX="${GAUDI_DURATION_SUFFIX=$GAUDI_PROMPT_DEFAULT_SUFFIX}"
GAUDI_DURATION_COLOR="${GAUDI_DURATION_COLOR="$GAUDI_YELLOW"}"
GAUDI_DURATION_MIN_SECONDS="${GAUDI_DURATION_MIN_SECONDS=1}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

gaudi_duration() {

	[[ $GAUDI_DURATION_SHOW == false ]] && return

	export COMMAND_DURATION_MIN_SECONDS="$GAUDI_DURATION_MIN_SECONDS"

	local duration_str
	duration_str="$(_command_duration)"

	[[ -z "$duration_str" ]] && return

	gaudi::section \
		"$GAUDI_DURATION_COLOR" \
		"$GAUDI_DURATION_PREFIX" \
		"$GAUDI_DURATION_SYMBOL" \
		"$duration_str" \
		"$GAUDI_DURATION_SUFFIX"
}
