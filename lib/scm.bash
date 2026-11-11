#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2034,SC1091,SC2053

source "$GAUDI_ROOT/lib/helpers/git.helpers.bash"
source "$GAUDI_ROOT/lib/helpers/hg.helpers.bash"
source "$GAUDI_ROOT/lib/helpers/p4.helpers.bash"
source "$GAUDI_ROOT/lib/helpers/svn.helpers.bash"

SCM_CHECK=${SCM_CHECK:=true}

GAUDI_SCM_THEME_PROMPT_DIRTY=' !'
GAUDI_SCM_THEME_PROMPT_CLEAN=''
GAUDI_SCM_THEME_BRANCH_PREFIX=''
GAUDI_SCM_THEME_TAG_PREFIX='tag:'
GAUDI_SCM_THEME_DETACHED_PREFIX='detached:'
GAUDI_SCM_THEME_BRANCH_TRACK_PREFIX=' → '
GAUDI_SCM_THEME_BRANCH_GONE_PREFIX=' ⇢ '
GAUDI_SCM_NONE='NONE'
GAUDI_SCM_NONE_CHAR='○'

scm () {
  if [[ "$SCM_CHECK" = false ]]; then SCM=$GAUDI_SCM_NONE
  elif [[ -f .git/HEAD ]] && command -v git &> /dev/null; then SCM=$GAUDI_SCM_GIT
  elif command -v git &> /dev/null && [[ -n "$(git rev-parse --is-inside-work-tree 2> /dev/null)" ]]; then SCM=$GAUDI_SCM_GIT
  elif command -v p4 &> /dev/null && [[ -n "$(p4 set P4CLIENT 2> /dev/null)" ]]; then SCM=$GAUDI_SCM_P4
  elif [[ -d .hg ]] && command -v hg &> /dev/null; then SCM=$GAUDI_SCM_HG
  elif command -v hg &> /dev/null && [[ -n "$(hg root 2> /dev/null)" ]]; then SCM=$GAUDI_SCM_HG
  elif [[ -d .svn ]] && command -v svn &> /dev/null; then SCM=$GAUDI_SCM_SVN
  else SCM=$GAUDI_SCM_NONE
  fi
}

scm_prompt_char () {
  if [[ -z $SCM ]]; then scm; fi
  if [[ $SCM == $GAUDI_SCM_GIT ]]; then GAUDI_SCM_CHAR=$GAUDI_SCM_GIT_CHAR
  elif [[ $SCM == $GAUDI_SCM_P4 ]]; then GAUDI_SCM_CHAR=$GAUDI_SCM_P4_CHAR
  elif [[ $SCM == $GAUDI_SCM_HG ]]; then GAUDI_SCM_CHAR=$GAUDI_SCM_HG_CHAR
  elif [[ $SCM == $GAUDI_SCM_SVN ]]; then GAUDI_SCM_CHAR=$GAUDI_SCM_SVN_CHAR
  else GAUDI_SCM_CHAR=$GAUDI_SCM_NONE_CHAR
  fi
}

scm_prompt_vars () {
  scm
  scm_prompt_char
  GAUDI_SCM_DIRTY=0
  GAUDI_SCM_STATE=''
  [[ $SCM == $GAUDI_SCM_GIT ]] && git_prompt_vars && return
  [[ $SCM == $GAUDI_SCM_P4 ]] && p4_prompt_vars && return
  [[ $SCM == $GAUDI_SCM_HG ]] && hg_prompt_vars && return
  [[ $SCM == $GAUDI_SCM_SVN ]] && svn_prompt_vars && return
}
