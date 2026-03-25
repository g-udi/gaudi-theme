#!/usr/bin/env bash
#
# Google Cloud Platform
#
# The Google Cloud CLI is a set of tools to create and manage Google Cloud resources.
# Link: https://cloud.google.com/sdk/gcloud

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_GCLOUD_SHOW="${GAUDI_GCLOUD_SHOW=true}"
GAUDI_GCLOUD_PREFIX="${GAUDI_GCLOUD_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_GCLOUD_SUFFIX="${GAUDI_GCLOUD_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_GCLOUD_SYMBOL="${GAUDI_GCLOUD_SYMBOL="\\ue7b2"}"
GAUDI_GCLOUD_COLOR="${GAUDI_GCLOUD_COLOR="$GAUDI_BLUE"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Show current Google Cloud account and project
gaudi_gcloud () {
  [[ "$GAUDI_GCLOUD_SHOW" == false ]] && return

  gaudi::exists gcloud || return

  local gcloud_account gcloud_project gcloud_info

  # Read from gcloud config files directly for speed (avoid gcloud CLI overhead)
  local config_dir="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}"
  local active_config="default"

  if [[ -f "$config_dir/active_config" ]]; then
    active_config=$(cat "$config_dir/active_config")
  fi

  local config_file="$config_dir/configurations/config_$active_config"

  if [[ -f "$config_file" ]]; then
    gcloud_account=$(grep '^account' "$config_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
    gcloud_project=$(grep '^project' "$config_file" 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
  fi

  [[ -z "$gcloud_account" && -z "$gcloud_project" ]] && return

  if [[ -n "$gcloud_project" ]]; then
    gcloud_info="$gcloud_project"
  fi

  if [[ -n "$gcloud_account" ]]; then
    # Show shortened account (just the username part)
    local short_account="${gcloud_account%%@*}"
    [[ -n "$gcloud_info" ]] && gcloud_info="$short_account:$gcloud_info" || gcloud_info="$short_account"
  fi

  gaudi::section \
    "$GAUDI_GCLOUD_COLOR" \
    "$GAUDI_GCLOUD_PREFIX" \
    "$GAUDI_GCLOUD_SYMBOL" \
    "$gcloud_info" \
    "$GAUDI_GCLOUD_SUFFIX"
}
