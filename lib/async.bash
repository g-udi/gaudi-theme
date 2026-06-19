#!/usr/bin/env bash
# shellcheck shell=bash

GAUDI_THEME_SHELL_ID="${GAUDI_THEME_SHELL_ID:-$$}"
GAUDI_THEME_CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/gaudi-bash/theme/gaudi"
GAUDI_THEME_ASYNC_CACHE_DIR="${GAUDI_THEME_CACHE_ROOT}/async"
GAUDI_THEME_STATE_DIR="${GAUDI_THEME_CACHE_ROOT}/state/${GAUDI_THEME_SHELL_ID}"
GAUDI_THEME_GENERATION_FILE="${GAUDI_THEME_STATE_DIR}/generation"
GAUDI_THEME_LEFT_PROMPT_FILE="${GAUDI_THEME_STATE_DIR}/left_prompt"
GAUDI_THEME_RIGHT_PROMPT_FILE="${GAUDI_THEME_STATE_DIR}/right_prompt"
GAUDI_THEME_PROMPT_ROWS_FILE="${GAUDI_THEME_STATE_DIR}/prompt_rows"

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

  IFS=' ' read -r checksum _ < <(printf "%s" "$1" | cksum)
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

gaudi::terminal_columns () {
  local columns="${COLUMNS:-}"

  if [[ ! "$columns" =~ ^[0-9]+$ || "$columns" -le 0 ]]; then
    columns="$(tput cols 2>/dev/null || printf "80")"
  fi

  [[ "$columns" =~ ^[0-9]+$ && "$columns" -gt 0 ]] || columns="80"
  printf "%s" "$columns"
}

gaudi::strip_ansi () {
  printf "%s" "$1" | sed -E $'s/\x1B\\[[0-9;?]*[ -/]*[@-~]//g; s/\x1B\\([A-Za-z0-9]//g'
}

gaudi::visible_length () {
  local text=""

  text="$(gaudi::strip_ansi "$1")"
  printf "%s" "${#text}"
}

gaudi::compose_prompt_line () {
  local left="$1"
  local right="$2"
  local columns=""
  local left_length=""
  local right_length=""
  local padding=0

  [[ -n "$right" ]] || {
    printf "%b" "$left"
    return
  }

  columns="$(gaudi::terminal_columns)"
  left_length="$(gaudi::visible_length "$left")"
  right_length="$(gaudi::visible_length "$right")"
  padding=$((columns - left_length - right_length))

  if [[ "$padding" -le 0 ]]; then
    printf "%b" "$left"
    return
  fi

  printf "%b%*s%b" "$left" "$padding" "" "$right"
}

gaudi::prompt_cursor_rows () {
  local right_prompt="${1:-}"

  if [[ $GAUDI_SPLIT_PROMPT == true && $GAUDI_SPLIT_PROMPT_TWO_LINES == true && -n "$right_prompt" ]]; then
    printf "3"
  else
    printf "2"
  fi
}

gaudi::render_prompt_layout () {
  local left_prompt="$1"
  local right_prompt="$2"
  local async_prompt="$3"
  local left_async_prompt="${left_prompt}${async_prompt}"

  if [[ $GAUDI_SPLIT_PROMPT == false ]]; then
    printf "%b%b" "$right_prompt" "$left_async_prompt"
  elif [[ $GAUDI_SPLIT_PROMPT_TWO_LINES == true && -n "$right_prompt" ]]; then
    gaudi::compose_prompt_line "" "$right_prompt"
    printf "\n%b" "$left_async_prompt"
  else
    gaudi::compose_prompt_line "$left_async_prompt" "$right_prompt"
  fi
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
  gaudi::write_atomic "$GAUDI_THEME_RIGHT_PROMPT_FILE" "$2" || return 1
  gaudi::write_atomic "$GAUDI_THEME_PROMPT_ROWS_FILE" "$3"
}

gaudi::cursor_save () {
  tput sc 2>/dev/null || printf "\0337"
}

gaudi::cursor_restore () {
  tput rc 2>/dev/null || printf "\0338"
}

gaudi::cursor_up () {
  local rows="$1"
  local sequence=""

  [[ "$rows" =~ ^[0-9]+$ && "$rows" -gt 0 ]] || return 1
  sequence="$(tput cuu "$rows" 2>/dev/null)" && {
    printf "%s" "$sequence"
    return
  }

  printf "\033[%sA" "$rows"
}

gaudi::clear_to_eol () {
  tput el 2>/dev/null || printf "\033[K"
}

gaudi::redraw_prompt_layout () {
  local layout="$1"
  local line=""
  local first_line=true

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$first_line" == true ]] || printf "\n"
    printf "\r"
    gaudi::clear_to_eol
    printf "%b" "$line"
    gaudi::clear_to_eol
    first_line=false
  done <<< "$layout"
}

gaudi::redraw_prompt () {
  local async_prompt=""
  local left_prompt=""
  local right_prompt=""
  local prompt_layout=""
  local rows_up=""

  left_prompt="$(gaudi::read_file "$GAUDI_THEME_LEFT_PROMPT_FILE")" || return 0
  right_prompt="$(gaudi::read_file "$GAUDI_THEME_RIGHT_PROMPT_FILE")" || return 0
  rows_up="$(gaudi::read_file "$GAUDI_THEME_PROMPT_ROWS_FILE" || printf "2")"
  [[ "$rows_up" =~ ^[0-9]+$ && "$rows_up" -gt 0 ]] || rows_up="2"

  async_prompt="$(gaudi::render_cached_async_prompt GAUDI_PROMPT_ASYNC[@])"
  prompt_layout="$(gaudi::render_prompt_layout "$left_prompt" "$right_prompt" "$async_prompt")"

  gaudi::cursor_save
  gaudi::cursor_up "$rows_up"
  gaudi::redraw_prompt_layout "$prompt_layout"
  gaudi::cursor_restore
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
  declare -a segments=("${!2}")

  [[ ${#segments[@]} -gt 0 ]] || return 0

  GAUDI_THEME_SHELL_ID="$GAUDI_THEME_SHELL_ID" \
    GAUDI_BASH="$GAUDI_BASH" \
    GAUDI_THEME_WORKDIR="$PWD" \
    GAUDI_SPLIT_PROMPT="$GAUDI_SPLIT_PROMPT" \
    GAUDI_SPLIT_PROMPT_TWO_LINES="$GAUDI_SPLIT_PROMPT_TWO_LINES" \
    bash "$GAUDI_ROOT/lib/async_segment_worker.bash" "$generation" "${segments[@]}" &
}
