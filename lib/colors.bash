#!/usr/bin/env bash
# shellcheck shell=bash

# Literal ANSI escape codes: the same sequences `tput` prints for these colours
# on a 256-colour terminal, without forking `tput` 19 times at every shell start
# (and again in every async worker).

# Reset
export NC=$'\e[0m'                              # Text Reset

# Regular Colors
export GAUDI_BLACK=$'\e[30m'                    # GAUDI_BLACK
export GAUDI_RED=$'\e[31m'                      # GAUDI_RED
export GAUDI_GREEN=$'\e[32m'                    # GAUDI_GREEN
export GAUDI_YELLOW=$'\e[33m'                   # GAUDI_YELLOW
export GAUDI_BLUE=$'\e[34m'                     # GAUDI_BLUE
export GAUDI_MAGENTA=$'\e[38;5;165m'            # GAUDI_MAGENTA
export GAUDI_CYAN=$'\e[36m'                     # GAUDI_CYAN
export GAUDI_WHITE=$'\e[97m'                    # GAUDI_WHITE
export GAUDI_ORANGE=$'\e[38;5;202m'             # GAUDI_ORANGE

# Background
export BACKGROUND_GAUDI_BLACK=$'\e[40m'         # GAUDI_BLACK
export BACKGROUND_GAUDI_RED=$'\e[41m'           # GAUDI_RED
export BACKGROUND_GAUDI_GREEN=$'\e[42m'         # GAUDI_GREEN
export BACKGROUND_GAUDI_YELLOW=$'\e[43m'        # GAUDI_YELLOW
export BACKGROUND_GAUDI_BLUE=$'\e[44m'          # GAUDI_BLUE
export BACKGROUND_GAUDI_MAGENTA=$'\e[45m'       # GAUDI_MAGENTA
export BACKGROUND_GAUDI_CYAN=$'\e[46m'          # GAUDI_CYAN
export BACKGROUND_GAUDI_WHITE=$'\e[107m'        # GAUDI_WHITE
export BACKGROUND_GAUDI_ORANGE=$'\e[48;5;202m'  # GAUDI_ORANGE
