#!/usr/bin/env bash
# shellcheck shell=bash

GAUDI_THEME_SHELL_ID="${GAUDI_THEME_SHELL_ID:-$$}"
GAUDI_THEME_CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/gaudi-bash/theme/gaudi"
GAUDI_THEME_ASYNC_CACHE_DIR="${GAUDI_THEME_CACHE_ROOT}/async"
GAUDI_THEME_STATE_DIR="${GAUDI_THEME_CACHE_ROOT}/state/${GAUDI_THEME_SHELL_ID}"

# The generation counter is the only per-shell state kept on disk: the async
# worker re-reads it to notice that a newer prompt has been drawn. Everything
# else lives in shell variables and is handed to the worker through its
# environment (see gaudi::launch_async_segment_jobs).
GAUDI_THEME_GENERATION_FILE="${GAUDI_THEME_STATE_DIR}/generation"
GAUDI_THEME_GENERATION="${GAUDI_THEME_GENERATION:-0}"

# Helpers named gaudi::set_* return their result in GAUDI_THEME_REPLY instead
# of printing it, so the prompt can be assembled without forking a subshell
# for every value.
GAUDI_THEME_REPLY=""

gaudi::ensure_async_cache_dir () {
  [[ -d "$GAUDI_THEME_ASYNC_CACHE_DIR" ]] || mkdir -p "$GAUDI_THEME_ASYNC_CACHE_DIR"
}

gaudi::ensure_async_dirs () {
  gaudi::ensure_async_cache_dir
  [[ -d "$GAUDI_THEME_STATE_DIR" ]] || mkdir -p "$GAUDI_THEME_STATE_DIR"
}

# Remove this shell's state directory. Meant to run from the EXIT trap, so it
# must leave $? untouched for anything chained after it.
gaudi::cleanup_shell_state () {
  local status=$?

  if [[ "$GAUDI_THEME_SHELL_ID" == "$$" && "$GAUDI_THEME_STATE_DIR" == */state/"$$" ]]; then
    rm -f "$GAUDI_THEME_GENERATION_FILE" 2> /dev/null
    rmdir "$GAUDI_THEME_STATE_DIR" 2> /dev/null
  fi

  return "$status"
}

# Chain gaudi::cleanup_shell_state in front of whatever EXIT trap is already
# installed, without replacing it.
gaudi::register_exit_cleanup () {
  local existing=""
  local existing_command=""

  existing="$(trap -p EXIT)"
  [[ "$existing" == *"gaudi::cleanup_shell_state"* ]] && return 0

  if [[ -n "$existing" ]]; then
    # `trap -p` prints `trap -- '<command>' EXIT` in reusable shell quoting.
    eval "set -- $existing"
    existing_command="${3:-}"
  fi

  if [[ -n "$existing_command" ]]; then
    # shellcheck disable=SC2064
    trap -- "gaudi::cleanup_shell_state"$'\n'"$existing_command" EXIT
  else
    trap -- 'gaudi::cleanup_shell_state' EXIT
  fi
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

gaudi::hash_string () {
  local checksum=""

  IFS=' ' read -r checksum _ < <(printf "%s" "$1" | cksum)
  printf "%s" "$checksum"
}

gaudi::async_segment_is_global () {
  case "$1" in
    aws|kubecontext) return 0 ;;
  esac

  return 1
}

gaudi::async_segment_scope () {
  if gaudi::async_segment_is_global "$1"; then
    printf "%s" "global"
  else
    printf "%s" "directory"
  fi
}

# Hash a directory once and remember it: every directory-scoped segment of a
# prompt shares the same key, so cksum only runs when the directory changes.
gaudi::set_directory_scope_key () {
  local scope_target="${1:-$PWD}"

  if [[ -z "${GAUDI_THEME_HASHED_KEY:-}" || "$scope_target" != "${GAUDI_THEME_HASHED_TARGET:-}" ]]; then
    GAUDI_THEME_HASHED_KEY="$(gaudi::hash_string "$scope_target")"
    GAUDI_THEME_HASHED_TARGET="$scope_target"
  fi

  GAUDI_THEME_REPLY="$GAUDI_THEME_HASHED_KEY"
}

gaudi::set_async_segment_cache_file () {
  local segment="$1"

  if gaudi::async_segment_is_global "$segment"; then
    GAUDI_THEME_REPLY="global"
  else
    gaudi::set_directory_scope_key "${2:-$PWD}"
  fi

  GAUDI_THEME_REPLY="${GAUDI_THEME_ASYNC_CACHE_DIR}/${segment}--${GAUDI_THEME_REPLY}.cache"
}

gaudi::async_segment_cache_file () {
  gaudi::set_async_segment_cache_file "$@"
  printf "%s" "$GAUDI_THEME_REPLY"
}

# Read a whole file into GAUDI_THEME_REPLY without forking. Trailing newlines
# are dropped, as `$(<file)` would.
gaudi::set_file_content () {
  local content=""

  GAUDI_THEME_REPLY=""
  [[ -s "$1" ]] || return 1

  { IFS= read -r -d '' content < "$1"; } 2> /dev/null
  while [[ "$content" == *$'\n' ]]; do
    content="${content%$'\n'}"
  done

  GAUDI_THEME_REPLY="$content"
}

gaudi::set_terminal_columns () {
  local columns="${COLUMNS:-}"

  if [[ ! "$columns" =~ ^[0-9]+$ || "$columns" -le 0 ]]; then
    columns="$(tput cols 2>/dev/null || printf "80")"
  fi

  [[ "$columns" =~ ^[0-9]+$ && "$columns" -gt 0 ]] || columns="80"
  GAUDI_THEME_REPLY="$columns"
}

gaudi::terminal_columns () {
  gaudi::set_terminal_columns
  printf "%s" "$GAUDI_THEME_REPLY"
}

# CSI sequences (ESC [ parameters intermediates final) and charset selections
# (ESC ( x). The byte classes are spelled out so they do not depend on the
# collation order of the current locale.
GAUDI_THEME_ANSI_REGEX=$'\x1b''(\[[0-9;?]*[ !"#$%&'"'"'()*+,./-]*[]@A-Za-z[\^_`{|}~]|\([A-Za-z0-9])'

gaudi::set_stripped_ansi () {
  local text="$1"

  while [[ "$text" =~ $GAUDI_THEME_ANSI_REGEX ]]; do
    text="${text//"${BASH_REMATCH[0]}"/}"
  done

  GAUDI_THEME_REPLY="$text"
}

gaudi::strip_ansi () {
  gaudi::set_stripped_ansi "$1"
  printf "%s" "$GAUDI_THEME_REPLY"
}

gaudi::set_visible_length () {
  gaudi::set_stripped_ansi "$1"
  GAUDI_THEME_REPLY="${#GAUDI_THEME_REPLY}"
}

gaudi::visible_length () {
  gaudi::set_visible_length "$1"
  printf "%s" "$GAUDI_THEME_REPLY"
}

gaudi::set_composed_prompt_line () {
  local left="$1"
  local right="$2"
  local columns=""
  local left_length=""
  local right_length=""
  local padding=0

  [[ -n "$right" ]] || {
    printf -v GAUDI_THEME_REPLY "%b" "$left"
    return
  }

  gaudi::set_terminal_columns
  columns="$GAUDI_THEME_REPLY"
  gaudi::set_visible_length "$left"
  left_length="$GAUDI_THEME_REPLY"
  gaudi::set_visible_length "$right"
  right_length="$GAUDI_THEME_REPLY"
  padding=$((columns - left_length - right_length))

  if [[ "$padding" -le 0 ]]; then
    printf -v GAUDI_THEME_REPLY "%b" "$left"
    return
  fi

  printf -v GAUDI_THEME_REPLY "%b%*s%b" "$left" "$padding" "" "$right"
}

gaudi::compose_prompt_line () {
  gaudi::set_composed_prompt_line "$@"
  printf "%s" "$GAUDI_THEME_REPLY"
}

gaudi::set_prompt_cursor_rows () {
  local right_prompt="${1:-}"

  if [[ $GAUDI_SPLIT_PROMPT == true && $GAUDI_SPLIT_PROMPT_TWO_LINES == true && -n "$right_prompt" ]]; then
    GAUDI_THEME_REPLY="3"
  else
    GAUDI_THEME_REPLY="2"
  fi
}

gaudi::prompt_cursor_rows () {
  gaudi::set_prompt_cursor_rows "$@"
  printf "%s" "$GAUDI_THEME_REPLY"
}

gaudi::set_prompt_layout () {
  local left_prompt="$1"
  local right_prompt="$2"
  local async_prompt="$3"
  local left_async_prompt="${left_prompt}${async_prompt}"
  local layout=""

  if [[ $GAUDI_SPLIT_PROMPT == false ]]; then
    printf -v layout "%b%b" "$right_prompt" "$left_async_prompt"
  elif [[ $GAUDI_SPLIT_PROMPT_TWO_LINES == true && -n "$right_prompt" ]]; then
    gaudi::set_composed_prompt_line "" "$right_prompt"
    printf -v layout "%s\n%b" "$GAUDI_THEME_REPLY" "$left_async_prompt"
  else
    gaudi::set_composed_prompt_line "$left_async_prompt" "$right_prompt"
    layout="$GAUDI_THEME_REPLY"
  fi

  # Same result as capturing the layout with $(...), which drops trailing newlines.
  while [[ "$layout" == *$'\n' ]]; do
    layout="${layout%$'\n'}"
  done

  GAUDI_THEME_REPLY="$layout"
}

gaudi::render_prompt_layout () {
  gaudi::set_prompt_layout "$@"
  printf "%s" "$GAUDI_THEME_REPLY"
}

# Make text safe to embed in PS1/PS2. Bash decodes backslash escapes in the
# prompt and then, with `promptvars` on, runs parameter expansion, command
# substitution and arithmetic expansion over the result. Segment content (a
# directory or branch name) must come out of both passes as literal text.
gaudi::set_prompt_escaped () {
  local text="$1"
  local backslash='\'

  if shopt -q promptvars; then
    local escaped_backslash='\\\\'
    local escaped_dollar='\\$'
    local escaped_backtick='\\`'

    # The replacements are quoted so that bash 5.2+ (patsub_replacement) does
    # not treat their backslashes as escapes.
    text=${text//"$backslash"/"$escaped_backslash"}
    text=${text//'$'/"$escaped_dollar"}
    text=${text//'`'/"$escaped_backtick"}
  else
    local escaped_backslash='\\'

    text=${text//"$backslash"/"$escaped_backslash"}
  fi

  GAUDI_THEME_REPLY="$text"
}

gaudi::set_cached_async_prompt () {
  local prompt=""
  local segment=""
  declare -a segments=("${!1}")

  for segment in "${segments[@]}"; do
    gaudi::set_async_segment_cache_file "$segment"
    gaudi::set_file_content "$GAUDI_THEME_REPLY" || continue
    prompt+="$GAUDI_THEME_REPLY"
  done

  GAUDI_THEME_REPLY="$prompt"
}

gaudi::render_cached_async_prompt () {
  gaudi::set_cached_async_prompt "$@"
  printf "%s" "$GAUDI_THEME_REPLY"
}

# Global segments have no directory to key on, so they are rendered once,
# synchronously, the first time a shell finds no cache for them.
gaudi::prime_global_async_segments () {
  local segment=""
  local cache_file=""
  local output=""
  local primed_var=""
  declare -a segments=("${!1}")

  for segment in "${segments[@]}"; do
    gaudi::async_segment_is_global "$segment" || continue

    primed_var="GAUDI_THEME_PRIMED_${segment//[^a-zA-Z0-9_]/_}"
    [[ ${!primed_var:-0} == 1 ]] && continue
    printf -v "$primed_var" '%s' '1'

    gaudi::set_async_segment_cache_file "$segment"
    cache_file="$GAUDI_THEME_REPLY"
    [[ -e "$cache_file" ]] && continue

    output="$(gaudi::render_segment "$segment")"
    [[ -n "$output" ]] || continue
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

# Start a new prompt generation: bump the counter and publish it for workers.
# Only workers of older generations can be reading the file at this point and
# any value other than their own makes them stand down, so a plain write is
# enough here.
gaudi::advance_generation () {
  GAUDI_THEME_GENERATION=$((${GAUDI_THEME_GENERATION:-0} + 1))
  printf "%s" "$GAUDI_THEME_GENERATION" 2> /dev/null > "$GAUDI_THEME_GENERATION_FILE"
}

gaudi::store_prompt_state () {
  GAUDI_THEME_LEFT_PROMPT="$1"
  GAUDI_THEME_RIGHT_PROMPT="$2"
  GAUDI_THEME_PROMPT_ROWS="$3"
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
    # The layout is already rendered; printing it with %b again would read
    # backslashes in segment content (a directory name) as escapes.
    printf "%s" "$line"
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

  [[ -n "${GAUDI_THEME_LEFT_PROMPT+set}" && -n "${GAUDI_THEME_RIGHT_PROMPT+set}" ]] || return 0
  left_prompt="$GAUDI_THEME_LEFT_PROMPT"
  right_prompt="$GAUDI_THEME_RIGHT_PROMPT"
  rows_up="${GAUDI_THEME_PROMPT_ROWS:-2}"
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
  local fresh_output=""
  local cached_output=""
  local had_cache=false

  gaudi::set_async_segment_cache_file "$segment"
  cache_file="$GAUDI_THEME_REPLY"
  fresh_output="$(gaudi::render_segment "$segment")"

  gaudi::generation_matches "$generation" || return 0

  if [[ -e "$cache_file" ]]; then
    had_cache=true
    gaudi::set_file_content "$cache_file"
    cached_output="$GAUDI_THEME_REPLY"
  fi

  if [[ -z "$fresh_output" ]]; then
    # Nothing to show: keep no cache file at all rather than an empty one.
    [[ "$had_cache" == true ]] || return 0
    rm -f "$cache_file"
    [[ -n "$cached_output" ]] || return 0
  else
    [[ "$had_cache" == true && "$cached_output" == "$fresh_output" ]] && return 0
    gaudi::write_atomic "$cache_file" "$fresh_output" || return 1
  fi

  gaudi::generation_matches "$generation" || return 0
  gaudi::redraw_prompt
}

gaudi::run_async_segment_worker () {
  GAUDI_THEME_SHELL_ID="$GAUDI_THEME_SHELL_ID" \
    GAUDI_BASH="$GAUDI_BASH" \
    GAUDI_THEME_WORKDIR="$PWD" \
    GAUDI_THEME_LEFT_PROMPT="${GAUDI_THEME_LEFT_PROMPT:-}" \
    GAUDI_THEME_RIGHT_PROMPT="${GAUDI_THEME_RIGHT_PROMPT:-}" \
    GAUDI_THEME_PROMPT_ROWS="${GAUDI_THEME_PROMPT_ROWS:-2}" \
    GAUDI_SPLIT_PROMPT="$GAUDI_SPLIT_PROMPT" \
    GAUDI_SPLIT_PROMPT_TWO_LINES="$GAUDI_SPLIT_PROMPT_TWO_LINES" \
    bash "$GAUDI_ROOT/lib/async_segment_worker.bash" "$@"
}

gaudi::launch_async_segment_jobs () {
  local generation="$1"
  declare -a segments=("${!2}")

  [[ ${#segments[@]} -gt 0 ]] || return 0

  if [[ $- == *i* ]]; then
    # Interactive shell: start the worker from a subshell so it never enters
    # this shell's job table. That keeps "[1] 12345" / "Done" notices away
    # without switching monitor mode (job control) off.
    (gaudi::run_async_segment_worker "$generation" "${segments[@]}" &)
  else
    gaudi::run_async_segment_worker "$generation" "${segments[@]}" &
  fi
}
