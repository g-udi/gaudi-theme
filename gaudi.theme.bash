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

# Cache for async prompt content — persists between prompt renders so the
# prompt always shows the last known async result instead of going blank.
_GAUDI_ASYNC_CACHE=""

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

  # Use cached async content for the initial PS1 draw — the background
  # job will overwrite this with fresh content once it finishes.
  local ASYNC_PROMPT="${_GAUDI_ASYNC_CACHE}"

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

  # Render async segments in background and overwrite the prompt
  gaudi::render_async () {
    local FRESH_ASYNC
    FRESH_ASYNC="$(gaudi::render_prompt GAUDI_PROMPT_ASYNC[@])"

    # Update the cache for next prompt render
    _GAUDI_ASYNC_CACHE="$FRESH_ASYNC"

    tput sc && tput cuu1 && tput cuu1
    if [[ $GAUDI_SPLIT_PROMPT == false ]]; then
      printf "\r%b%b%b" "$RIGHT_PROMPT" "$LEFT_PROMPT" "$FRESH_ASYNC"
    else
      printf "\r%b%b" "$LEFT_PROMPT" "$FRESH_ASYNC"
    fi;
    tput rc
  }

  # Load the PS2 continuation bash configuration
  source "$GAUDI_ROOT/segments/continuation.bash"
  PS2=$(gaudi_continuation)

  PS4='$0.$LINENO+ '

  set +m
  gaudi::render_async &

  ## cleanup
  unset LEFT_PROMPT RIGHT_PROMPT
}

PROMPT_COMMAND=gaudi::prompt
