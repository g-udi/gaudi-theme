#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034

GAUDI_ROOT="${GAUDI_BASH}/components/themes/gaudi"

source "$GAUDI_ROOT/gaudi.configs.bash"
source "$GAUDI_ROOT/lib/utils.bash"
source "$GAUDI_ROOT/lib/colors.bash"
source "$GAUDI_ROOT/lib/scm.bash"

# Do not load if not an interactive shell
# Reference: https://github.com/nojhan/liquidprompt/issues/161
test -z "$TERM" -o "x$TERM" = xdumb && return

# # Check for recent enough version of bash.
# if test -n "${BASH_VERSION-}" -a -n "$PS1" ; then
#   bash=${BASH_VERSION%.*}; bmajor=${bash%.*}; bminor=${bash#*.}
#   if (( bmajor < 4 || ( bmajor == 4 && bminor < 0 ) )); then
#     echo "The current bash version ${bash} is not supported by Gaudi Theme [[ 4.0+ ]]"
#     unset bash bmajor bminor
#     return
#   fi
# fi

gaudi::prompt () {

  # Must be the very first line in all entry prompt functions, or the value
  # will be overridden by a different command execution - do not move this line!
  RETVAL=$?

  local PROMPT_CHAR
  local COMPENSATE
  local LEFT_PROMPT
  local RIGHT_PROMPT

  PROMPT_CHAR="${GREEN}>>${NC} "
  COMPENSATE=58

  LEFT_PROMPT="$(gaudi::render_prompt GAUDI_PROMPT_LEFT[@])"
  RIGHT_PROMPT="$(gaudi::render_prompt GAUDI_PROMPT_RIGHT[@])"
  ASYNC_PROMPT="$(gaudi::render_prompt GAUDI_PROMPT_ASYNC[@])"

  # Check if we need to activate the two side theme split (LEFT_PROMPT ------ RIGHT RIGHT)
  # Or we need to have the whole prompt in one line where (RIGHT_PROMPT LEFT_PROMPT)
  if [[ $GAUDI_SPLIT_PROMPT == false ]]; then
    PS1=$(printf "\n%b%b%b\n\n%b" "$RIGHT_PROMPT" "$LEFT_PROMPT" "$ASYNC_PROMPT" "$PROMPT_CHAR")
  else
    if [[ "$TERM" =~ "screen".* ]]; then
      tmux set-option -g default-command bash
      COMPENSATE=45
    fi
    [[ $GAUDI_SPLIT_PROMPT_TWO_LINES == true ]] && line_separator="\n" || line_separator="\r"
    PS1=$(printf "\n%*b%s%b%b\n\n%b" "$(($(tput cols) + "$COMPENSATE"))" "$RIGHT_PROMPT" "$line_separator" "$LEFT_PROMPT" "$ASYNC_PROMPT" "$PROMPT_CHAR")
  fi;

  # Load the PS2 continuation bash configuration
  source "$GAUDI_ROOT/segments/continuation.bash"
  # PS2 – Continuation interactive prompt
  PS2=$(gaudi_continuation)

  # The PS4 defined below in the ps4.sh has the following two codes:
  #   $0 – indicates the name of script
  #   $LINENO – displays the current line number within the script
  PS4='$0.$LINENO+ '

  ## cleanup
  unset LEFT_PROMPT RIGHT_PROMPT ASYNC_PROMPT
}

PROMPT_COMMAND=gaudi::prompt
