#!/usr/bin/env bash
#
# Vagrant
#
# Vagrant enables users to create and configure lightweight, reproducible, and portable development environments.
# Link: https://www.vagrantup.com

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_VAGRANT_SHOW="${GAUDI_VAGRANT_SHOW=true}"
GAUDI_VAGRANT_PREFIX="${GAUDI_VAGRANT_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_VAGRANT_SUFFIX="${GAUDI_VAGRANT_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_VAGRANT_SYMBOL="${GAUDI_VAGRANT_SYMBOL="\\ue62b"}"
GAUDI_VAGRANT_COLOR="${GAUDI_VAGRANT_COLOR="$GAUDI_CYAN"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Show current Vagrant status
gaudi_vagrant () {
  [[ $GAUDI_VAGRANT_SHOW == false ]] && return

  gaudi::exists vagrant || return

  # Show Vagrant status only for Vagrant-specific folders
  [[ -f Vagrantfile || ( -n "${VAGRANT_VAGRANTFILE:-}" && -f "$VAGRANT_VAGRANTFILE" ) ]] || return

  local machine_index="$HOME/.vagrant.d/data/machine-index/index"
  local python_cmd="" vagrant_status=""
  [[ -r "$machine_index" ]] || return

  if gaudi::exists jq; then
    vagrant_status="$(jq -r --arg dir "$PWD" '.machines[] | select(.vagrantfile_path == $dir).state' "$machine_index" 2>/dev/null)"
  else
    if gaudi::exists python3; then
      python_cmd="python3"
    elif gaudi::exists python; then
      python_cmd="python"
    else
      return
    fi

    vagrant_status="$("$python_cmd" -c 'import json, os, sys
machines = json.load(sys.stdin).get("machines", {})
for machine in machines.values():
    if machine.get("vagrantfile_path") == os.getcwd():
        print(machine.get("state", ""))
        break
' < "$machine_index" 2>/dev/null)"
  fi

  [[ -n "$vagrant_status" && "$vagrant_status" != null ]] || return

  gaudi::section \
    "$GAUDI_VAGRANT_COLOR" \
    "$GAUDI_VAGRANT_PREFIX" \
    "$GAUDI_VAGRANT_SYMBOL" \
    "$vagrant_status" \
    "$GAUDI_VAGRANT_SUFFIX"
}
