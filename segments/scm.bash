#!/usr/bin/env bash
#
# Git
#

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------


GAUDI_SCM_SHOW="${GAUDI_SCM_SHOW=true}"
GAUDI_SCM_FETCH="${GAUDI_SCM_FETCH=false}"
GAUDI_SCM_PREFIX="${GAUDI_SCM_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_SCM_SUFFIX="${GAUDI_SCM_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_THEME_PROMPT_CLEAN_COLOR="${GAUDI_WHITE}${BACKGROUND_GAUDI_GREEN}"
GAUDI_THEME_PROMPT_DIRTY_COLOR="${GAUDI_WHITE}${BACKGROUND_GAUDI_RED}"
GAUDI_THEME_PROMPT_STAGED_COLOR="${GAUDI_BLACK}${BACKGROUND_GAUDI_ORANGE}"
GAUDI_THEME_PROMPT_UNSTAGED_COLOR="${GAUDI_BLACK}${BACKGROUND_GAUDI_YELLOW}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

gaudi_scm () {

  [[ $GAUDI_SCM_SHOW == false ]] && return

  local color scm_prompt

  scm_prompt_vars
  
  if [[ "${GAUDI_SCM_NONE_CHAR}" != "${GAUDI_SCM_CHAR}" ]]; then
    if [[ "${GAUDI_SCM_DIRTY}" -ge 4 ]]; then
      color=${GAUDI_THEME_PROMPT_DIRTY_COLOR}
    elif [[ "${GAUDI_SCM_DIRTY}" -eq 3 ]]; then
      color=${GAUDI_THEME_PROMPT_STAGED_COLOR}
    elif [[ "${GAUDI_SCM_DIRTY}" -eq 2 ]]; then
      color=${GAUDI_THEME_PROMPT_UNSTAGED_COLOR}
    else
      color=${GAUDI_THEME_PROMPT_CLEAN_COLOR}
    fi

    scm_prompt+="${GAUDI_SCM_BRANCH}${GAUDI_SCM_STATE}"

    gaudi::section \
      "$color" \
      "$GAUDI_SCM_PREFIX" \
      "" \
      "$scm_prompt" \
      "$GAUDI_SCM_SUFFIX"
  fi

}
