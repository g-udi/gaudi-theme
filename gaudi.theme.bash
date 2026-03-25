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

GAUDI_THEME_SHELL_ID="${GAUDI_THEME_SHELL_ID:-$$}"
GAUDI_THEME_CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/gaudi-bash/theme/gaudi"
GAUDI_THEME_ASYNC_CACHE_DIR="${GAUDI_THEME_CACHE_ROOT}/async"
GAUDI_THEME_STATE_DIR="${GAUDI_THEME_CACHE_ROOT}/state/${GAUDI_THEME_SHELL_ID}"
GAUDI_THEME_GENERATION_FILE="${GAUDI_THEME_STATE_DIR}/generation"
GAUDI_THEME_LEFT_PROMPT_FILE="${GAUDI_THEME_STATE_DIR}/left_prompt"
GAUDI_THEME_RIGHT_PROMPT_FILE="${GAUDI_THEME_STATE_DIR}/right_prompt"

gaudi::ensure_async_dirs () {
  mkdir -p "$GAUDI_THEME_ASYNC_CACHE_DIR" "$GAUDI_THEME_STATE_DIR"
}

gaudi::write_atomic () {
  local file="$1"
  local content="$2"
  local dir="${file%/*}"
  local tmp_file=""

  mkdir -p "$dir" || return 1
  tmp_file="$(mktemp "${dir}/.gaudi.XXXXXX")" || return 1
  printf "%s" "$content" > "$tmp_file" || {
    rm -f "$tmp_file"
    return 1
  }

  mv "$tmp_file" "$file"
}

gaudi::read_file () {
  local file="$1"
  local content=""

  [[ -e "$file" ]] || return 1

  content="$(<"$file")"
  printf "%s" "$content"
}

gaudi::hash_string () {
  local checksum=""
  local remainder=""

  IFS=' ' read -r checksum remainder < <(printf "%s" "$1" | cksum)
  printf "%s" "$checksum"
}

gaudi::async_segment_scope () {
  case "$1" in
    aws|kubecontext)
      printf "%s" "global"
      ;;
    *)
      printf "%s" "directory"
      ;;
  esac
}

gaudi::async_segment_cache_file () {
  local segment="$1"
  local segment_scope=""
  local scope_key=""
  local scope_target="${2:-$PWD}"

  segment_scope="$(gaudi::async_segment_scope "$segment")"
  if [[ "$segment_scope" == "global" ]]; then
    scope_key="global"
  else
    scope_key="$(gaudi::hash_string "$scope_target")"
  fi

  printf "%s/%s--%s.cache" "$GAUDI_THEME_ASYNC_CACHE_DIR" "$segment" "$scope_key"
}

gaudi::render_cached_async_prompt () {
  local prompt=""
  local segment=""
  local cache_file=""
  declare -a segments=("${!1}")

  for segment in "${segments[@]}"; do
    cache_file="$(gaudi::async_segment_cache_file "$segment")"
    [[ -e "$cache_file" ]] || continue
    prompt+="$(gaudi::read_file "$cache_file")"
  done

  printf "%s" "$prompt"
}

gaudi::prime_global_async_segments () {
  local segment=""
  local cache_file=""
  local output=""
  declare -a segments=("${!1}")

  for segment in "${segments[@]}"; do
    [[ "$(gaudi::async_segment_scope "$segment")" == "global" ]] || continue

    cache_file="$(gaudi::async_segment_cache_file "$segment")"
    [[ -e "$cache_file" ]] && continue

    output="$(gaudi::render_segment "$segment")"
    gaudi::write_atomic "$cache_file" "$output"
  done
}

gaudi::current_generation () {
  local current_generation="0"

  if [[ -e "$GAUDI_THEME_GENERATION_FILE" ]]; then
    current_generation="$(<"$GAUDI_THEME_GENERATION_FILE")"
  fi

  printf "%s" "${current_generation:-0}"
}

gaudi::generation_matches () {
  [[ "$(gaudi::current_generation)" == "$1" ]]
}

gaudi::next_generation () {
  local current_generation="0"
  local next_generation="1"

  current_generation="$(gaudi::current_generation)"
  next_generation=$((current_generation + 1))
  gaudi::write_atomic "$GAUDI_THEME_GENERATION_FILE" "$next_generation" || return 1

  printf "%s" "$next_generation"
}

gaudi::store_prompt_state () {
  gaudi::write_atomic "$GAUDI_THEME_LEFT_PROMPT_FILE" "$1" || return 1
  gaudi::write_atomic "$GAUDI_THEME_RIGHT_PROMPT_FILE" "$2"
}

gaudi::redraw_prompt () {
  local async_prompt=""
  local left_prompt=""
  local right_prompt=""

  left_prompt="$(gaudi::read_file "$GAUDI_THEME_LEFT_PROMPT_FILE")" || return 0
  right_prompt="$(gaudi::read_file "$GAUDI_THEME_RIGHT_PROMPT_FILE")" || return 0
  async_prompt="$(gaudi::render_cached_async_prompt GAUDI_PROMPT_ASYNC[@])"

  tput sc
  tput cuu1
  tput cuu1
  if [[ $GAUDI_SPLIT_PROMPT == false ]]; then
    printf "\r%b%b%b" "$right_prompt" "$left_prompt" "$async_prompt"
  else
    printf "\r%b%b" "$left_prompt" "$async_prompt"
  fi
  tput rc
}

gaudi::refresh_async_segment () {
  local segment="$1"
  local generation="$2"
  local cache_file=""
  local temp_file=""
  local fresh_output=""
  local had_cache=false

  cache_file="$(gaudi::async_segment_cache_file "$segment")"
  fresh_output="$(gaudi::render_segment "$segment")"

  gaudi::generation_matches "$generation" || return 0
  [[ -e "$cache_file" ]] && had_cache=true

  temp_file="$(mktemp "${GAUDI_THEME_STATE_DIR}/${segment}.XXXXXX")" || return 1
  printf "%s" "$fresh_output" > "$temp_file" || {
    rm -f "$temp_file"
    return 1
  }

  if [[ -e "$cache_file" ]] && cmp -s "$temp_file" "$cache_file"; then
    rm -f "$temp_file"
    return 0
  fi

  gaudi::generation_matches "$generation" || {
    rm -f "$temp_file"
    return 0
  }

  mv "$temp_file" "$cache_file"

  gaudi::generation_matches "$generation" || return 0
  if [[ -n "$fresh_output" || "$had_cache" == true ]]; then
    gaudi::redraw_prompt
  fi
}

gaudi::launch_async_segment_jobs () {
  local generation="$1"
  local segment=""
  declare -a segments=("${!2}")

  for segment in "${segments[@]}"; do
    GAUDI_THEME_SHELL_ID="$GAUDI_THEME_SHELL_ID" \
      GAUDI_BASH="$GAUDI_BASH" \
      bash "$GAUDI_ROOT/lib/async_segment_worker.bash" "$segment" "$generation"
  done
}

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
  local compensate=58
  local left_prompt=""
  local right_prompt=""
  local async_prompt=""
  local line_separator=""

  prompt_char="${GAUDI_GREEN}>>${NC} "

  gaudi::ensure_async_dirs
  generation="$(gaudi::next_generation)" || return 1

  left_prompt="$(gaudi::render_prompt GAUDI_PROMPT_LEFT[@])"
  right_prompt="$(gaudi::render_prompt GAUDI_PROMPT_RIGHT[@])"
  gaudi::store_prompt_state "$left_prompt" "$right_prompt"

  gaudi::prime_global_async_segments GAUDI_PROMPT_ASYNC[@]
  async_prompt="$(gaudi::render_cached_async_prompt GAUDI_PROMPT_ASYNC[@])"

  if [[ $GAUDI_SPLIT_PROMPT == false ]]; then
    PS1=$(printf "\n%b%b%b\n\n%b" "$right_prompt" "$left_prompt" "$async_prompt" "$prompt_char")
  else
    [[ "$TERM" =~ screen.* ]] && compensate=45
    [[ $GAUDI_SPLIT_PROMPT_TWO_LINES == true ]] && line_separator=$'\n' || line_separator=$'\r'
    PS1=$(printf "\n%*b%b%b%b\n\n%b" "$(($(tput cols) + compensate))" "$right_prompt" "$line_separator" "$left_prompt" "$async_prompt" "$prompt_char")
  fi

  set +m
  gaudi::launch_async_segment_jobs "$generation" GAUDI_PROMPT_ASYNC[@]
}

gaudi::init
