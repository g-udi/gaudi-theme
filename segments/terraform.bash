#!/usr/bin/env bash
#
# Terraform
#
# Terraform is an infrastructure as code tool for building, changing,
# and versioning infrastructure safely and efficiently.
# Link: https://www.terraform.io/

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_TERRAFORM_SHOW="${GAUDI_TERRAFORM_SHOW=true}"
GAUDI_TERRAFORM_PREFIX="${GAUDI_TERRAFORM_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_TERRAFORM_SUFFIX="${GAUDI_TERRAFORM_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_TERRAFORM_SYMBOL="${GAUDI_TERRAFORM_SYMBOL="\\uf9fd"}"
GAUDI_TERRAFORM_COLOR="${GAUDI_TERRAFORM_COLOR="$GAUDI_MAGENTA"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Show current Terraform workspace
gaudi_terraform () {
  [[ "$GAUDI_TERRAFORM_SHOW" == false ]] && return

  # Only show in directories with Terraform files
  local _tf_files=(*.tf)
  [[ -d .terraform || -f main.tf || -f terraform.tfvars ||
     -e "${_tf_files[0]}"
  ]] || return

  gaudi::exists terraform || return

  local terraform_workspace
  terraform_workspace=$(terraform workspace show 2>/dev/null)

  [[ -z "$terraform_workspace" ]] && return

  gaudi::section \
    "$GAUDI_TERRAFORM_COLOR" \
    "$GAUDI_TERRAFORM_PREFIX" \
    "$GAUDI_TERRAFORM_SYMBOL" \
    "$terraform_workspace" \
    "$GAUDI_TERRAFORM_SUFFIX"
}
