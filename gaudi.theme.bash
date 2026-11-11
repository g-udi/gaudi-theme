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

# Build PS2 from the continuation segment: its text is rendered once with
# `printf %b` (so "" and "\t" become the glyph and a tab instead of being
# read by bash as the prompt escapes \u and \t) and its colours are wrapped in
# \[ \] so readline does not count them as visible characters.
gaudi::set_continuation_prompt () {
  local color="${GAUDI_CHAR_COLOR:-}"
  local reset="${NC:-}"
  local body=""

  body="$(gaudi_continuation)"
  body="${body#"$color"}"
  body="${body%"$reset"}"
  printf -v body "%b" "$body"

  gaudi::set_prompt_escaped "$body"
  body="$GAUDI_THEME_REPLY"

  [[ -n "$color" && "$color" != *'\['* ]] && color="\[${color}\]"
  [[ -n "$reset" ]] && reset="\[${reset}\]"

  PS2="${color}${body}${reset}"
}

gaudi::init () {
  gaudi::ensure_async_dirs
  gaudi::load_segment continuation

  gaudi::set_continuation_prompt
  PS4='$0.$LINENO+ '

  [[ $- == *i* ]] && gaudi::register_exit_cleanup

  gaudi::register_prompt_hook
}

gaudi::prompt () {

  # Must be the very first line in all entry prompt functions, or the value
  # will be overridden by a different command execution - do not move this line!
  RETVAL=$?

  local left_prompt=""
  local right_prompt=""
  local async_prompt=""
  local prompt_layout=""
  local prompt_rows=""

  gaudi::ensure_async_dirs
  gaudi::advance_generation || return 1

  gaudi::set_rendered_prompt GAUDI_PROMPT_LEFT[@]
  left_prompt="$GAUDI_THEME_REPLY"
  gaudi::set_rendered_prompt GAUDI_PROMPT_RIGHT[@]
  right_prompt="$GAUDI_THEME_REPLY"

  gaudi::prime_global_async_segments GAUDI_PROMPT_ASYNC[@]
  gaudi::set_cached_async_prompt GAUDI_PROMPT_ASYNC[@]
  async_prompt="$GAUDI_THEME_REPLY"
  gaudi::set_prompt_layout "$left_prompt" "$right_prompt" "$async_prompt"
  prompt_layout="$GAUDI_THEME_REPLY"
  gaudi::set_prompt_cursor_rows "$right_prompt"
  prompt_rows="$GAUDI_THEME_REPLY"
  gaudi::store_prompt_state "$left_prompt" "$right_prompt" "$prompt_rows"

  # The layout holds segment content (directory and branch names), so it is
  # escaped: bash must print it, never expand it. Only the last line is edited
  # by readline, so that is where non-printing colours need their \[ \] guards.
  gaudi::set_prompt_escaped "$prompt_layout"
  PS1=$'\n'"${GAUDI_THEME_REPLY}"$'\n\n'"\[${GAUDI_GREEN}\]>>\[${NC}\] "

  gaudi::launch_async_segment_jobs "$GAUDI_THEME_GENERATION" GAUDI_PROMPT_ASYNC[@]
}

gaudi::init
