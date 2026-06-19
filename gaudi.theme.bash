#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034

GAUDI_ROOT="${GAUDI_BASH}/components/themes/gaudi"

# Do not load if not an interactive shell.
# Reference: https://github.com/nojhan/liquidprompt/issues/161
test -z "$TERM" -o "x$TERM" = xdumb && return

source "$GAUDI_ROOT/gaudi.configs.bash"
source "$GAUDI_ROOT/lib/utils.bash"
source "$GAUDI_ROOT/lib/colors.bash"
source "$GAUDI_ROOT/lib/scm.bash"
source "$GAUDI_ROOT/lib/async.bash"

gaudi::register_prompt_hook () {
  if gaudi::defined __bp_precmd_invoke_cmd; then
    gaudi::check_precmd_conflict "gaudi::prompt" || precmd_functions+=(gaudi::prompt)
    return 0
  fi

  [[ "${PROMPT_COMMAND:-}" == *"gaudi::prompt"* ]] && return 0

  if [[ -n "${PROMPT_COMMAND:-}" ]]; then
    PROMPT_COMMAND=$'gaudi::prompt\n'"$PROMPT_COMMAND"
  else
    PROMPT_COMMAND="gaudi::prompt"
  fi
}

gaudi::init () {
  gaudi::ensure_async_dirs
  gaudi::load_segment continuation

  PS2="$(gaudi_continuation)"
  PS4='$0.$LINENO+ '

  gaudi::register_prompt_hook
}

gaudi::prompt () {

  # Must be the very first line in all entry prompt functions, or the value
  # will be overridden by a different command execution - do not move this line!
  RETVAL=$?

  local generation=""
  local prompt_char=""
  local left_prompt=""
  local right_prompt=""
  local async_prompt=""
  local prompt_layout=""
  local prompt_rows=""

  prompt_char="${GAUDI_GREEN}>>${NC} "

  gaudi::ensure_async_dirs
  generation="$(gaudi::next_generation)" || return 1

  left_prompt="$(gaudi::render_prompt GAUDI_PROMPT_LEFT[@])"
  right_prompt="$(gaudi::render_prompt GAUDI_PROMPT_RIGHT[@])"

  gaudi::prime_global_async_segments GAUDI_PROMPT_ASYNC[@]
  async_prompt="$(gaudi::render_cached_async_prompt GAUDI_PROMPT_ASYNC[@])"
  prompt_layout="$(gaudi::render_prompt_layout "$left_prompt" "$right_prompt" "$async_prompt")"
  prompt_rows="$(gaudi::prompt_cursor_rows "$right_prompt")"
  gaudi::store_prompt_state "$left_prompt" "$right_prompt" "$prompt_rows"

  PS1=$(printf "\n%b\n\n%b" "$prompt_layout" "$prompt_char")

  set +m
  gaudi::launch_async_segment_jobs "$generation" GAUDI_PROMPT_ASYNC[@]
}

gaudi::init
