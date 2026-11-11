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

# Leaves the section in GAUDI_THEME_REPLY. Runs in the current shell, so the
# only fork left is the call to _command_duration itself.
gaudi::segment_duration() {
	local duration_str=""

	GAUDI_THEME_REPLY=""
	[[ $GAUDI_DURATION_SHOW == false ]] && return
	gaudi::defined _command_duration || return 0

	duration_str="$(COMMAND_DURATION_MIN_SECONDS="$GAUDI_DURATION_MIN_SECONDS" _command_duration)"

	[[ -z "$duration_str" ]] && return

	gaudi::set_section \
		"$GAUDI_DURATION_COLOR" \
		"$GAUDI_DURATION_PREFIX" \
		"$GAUDI_DURATION_SYMBOL" \
		"$duration_str" \
		"$GAUDI_DURATION_SUFFIX"
}

gaudi_duration() {
	gaudi::segment_duration
	printf '%s' "$GAUDI_THEME_REPLY"
}
