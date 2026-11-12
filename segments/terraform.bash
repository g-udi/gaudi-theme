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
  # (the *.tf files are walked by value: the first index of an array is 0 in
  # bash and 1 in zsh)
  local _tf_file="" _tf_found=""
  for _tf_file in *.tf; do
    if [[ -e "$_tf_file" ]]; then
      _tf_found=true
      break
    fi
  done
  [[ -d .terraform || -f main.tf || -f terraform.tfvars || -n "$_tf_found" ]] || return

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
