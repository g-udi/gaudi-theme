#!/usr/bin/env bash
#
# Amazon Web Services (AWS)
#
# The AWS Command Line Interface (CLI) is a unified tool to manage AWS services.
# Link: https://aws.amazon.com/cli/
#
# The segment is read from the environment of the current shell on every prompt
# (it is never cached on disk), so two shells with different profiles each show
# their own. The first non-empty value wins:
#
#   AWS_VAULT             set by `aws-vault exec <profile>`
#   AWS_PROFILE           profile used by the AWS CLI and the SDKs
#   AWS_DEFAULT_PROFILE   older name, still honoured by the AWS CLI
#   CURRENT_AWS_PROFILE   legacy variable of this theme

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_AWS_SHOW="${GAUDI_AWS_SHOW=true}"
GAUDI_AWS_PREFIX="${GAUDI_AWS_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_AWS_SUFFIX="${GAUDI_AWS_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_AWS_SYMBOL="${GAUDI_AWS_SYMBOL="\\ue7ad"}"
GAUDI_AWS_COLOR="${GAUDI_AWS_COLOR="$GAUDI_YELLOW"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Shows selected AWS-cli profile. Leaves the section in GAUDI_THEME_REPLY
# without forking.
gaudi::segment_aws () {
  local profile=""

  GAUDI_THEME_REPLY=""
  [[ $GAUDI_AWS_SHOW == false ]] && return

  if [[ -n "${AWS_VAULT:-}" ]]; then
    profile="$AWS_VAULT"
  else
    # Check if the AWS-cli is installed
    gaudi::exists aws || return 0
    profile="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-${CURRENT_AWS_PROFILE:-}}}"
  fi

  # Is the current profile not the default profile
  [[ -z "$profile" || "$profile" == "default" ]] && return

  # The prompt layout is printed with `printf %b`: keep backslashes literal.
  profile="${profile//\\/\\\\}"

  # Show prompt section
  gaudi::set_section \
    "$GAUDI_AWS_COLOR" \
    "$GAUDI_AWS_PREFIX" \
    "$GAUDI_AWS_SYMBOL" \
    "$profile" \
    "$GAUDI_AWS_SUFFIX"
}

gaudi_aws () {
  gaudi::segment_aws
  printf '%s' "$GAUDI_THEME_REPLY"
}
