#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1090,SC1091,SC2016,SC2030,SC2031,SC2034,SC2088,SC2123
#
# Self-contained tests for the gaudi theme. Plain bash: no bats, no network.
#
#   test/run.bash                 run with the bash found in PATH
#   /bin/bash test/run.bash       run with a specific bash
#
# Everything is written under a temporary directory that is removed on exit;
# HOME and XDG_CACHE_HOME point into it, so the real home and cache are never
# touched. Every test runs in its own subshell with a freshly sourced theme.

TEST_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
THEME_SOURCE="${TEST_DIR%/*}"

TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/gaudi-theme-test.XXXXXX")" || exit 1
TEST_TMP="$(cd "$TEST_TMP" && pwd -P)"
trap 'rm -rf "$TEST_TMP"' EXIT

# A copy of the theme made of symbolic links, so tests can add their own
# segments without writing into the repository.
THEME="$TEST_TMP/theme"
mkdir -p "$THEME/segments" "$TEST_TMP/home" "$TEST_TMP/cache" "$TEST_TMP/bin" "$TEST_TMP/work"
ln -s "$THEME_SOURCE/gaudi.theme.bash" "$THEME_SOURCE/gaudi.configs.bash" "$THEME_SOURCE/lib" "$THEME/"
ln -s "$THEME_SOURCE"/segments/*.bash "$THEME/segments/"

# A stand-in for the AWS CLI: the aws segment only checks that it exists.
printf '#!/bin/sh\nexit 0\n' > "$TEST_TMP/bin/aws"
chmod +x "$TEST_TMP/bin/aws"

export HOME="$TEST_TMP/home"
export XDG_CACHE_HOME="$TEST_TMP/cache"
export TERM="xterm-256color"
export COLUMNS=120
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GAUDI_BASH PROMPT_COMMAND RETVAL
unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_VAULT CURRENT_AWS_PROFILE
for name in "${!GAUDI_@}"; do
  unset "$name"
done

ESC=$'\e'
TESTS_RUN=0
TESTS_FAILED=0

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

load_theme () {
  source "$THEME/gaudi.theme.bash"
}

# Source the theme in a new shell, after running <setup>, and print the result
# of expanding <text>.
in_new_shell () {
  "$BASH" --noprofile --norc -c "$1"$'\n''source "$0"'$'\n'"$2" "$THEME/gaudi.theme.bash"
}

fail () {
  printf '    %s\n' "$@" >&2
  exit 1
}

assert_equal () {
  [[ "$1" == "$2" ]] || fail "${3:-values differ}" "  actual:   $(printf '%q' "$1")" "  expected: $(printf '%q' "$2")"
}

assert_contains () {
  [[ "$1" == *"$2"* ]] || fail "${3:-text not found}" "  text:   $(printf '%q' "$1")" "  needle: $(printf '%q' "$2")"
}

refute_contains () {
  [[ "$1" != *"$2"* ]] || fail "${3:-unexpected text found}" "  text:   $(printf '%q' "$1")" "  needle: $(printf '%q' "$2")"
}

assert_nothing_was_executed () {
  [[ -z "$(find "$TEST_TMP" -name 'PWNED*')" ]] || fail "a command embedded in $1 was executed"
}

# Return with the given status, without forking: sets $? for gaudi::prompt.
status_of () {
  return "$1"
}

strip_ansi () {
  gaudi::set_stripped_ansi "$1"
  printf '%s' "$GAUDI_THEME_REPLY"
}

bash_at_least () {
  [[ ${BASH_VERSINFO[0]} -gt $1 || ( ${BASH_VERSINFO[0]} -eq $1 && ${BASH_VERSINFO[1]} -ge $2 ) ]]
}

# Every "$" and "`" of PS1 must be escaped, otherwise bash would expand it.
# Bash decodes backslash escapes first and expands the result afterwards, so a
# literal backslash is written as four backslashes and a literal "$" as two
# backslashes and "$".
assert_prompt_is_inert () {
  local four='\\\\\\\\' two='\\\\'
  local prompt="${1//$four/}"

  prompt="${prompt//$two\$/}"
  prompt="${prompt//$two\`/}"
  refute_contains "$prompt" '$' "PS1 holds an unescaped \$"
  refute_contains "$prompt" '`' "PS1 holds an unescaped backtick"
}

# Expand PS1 the way bash does before printing it (bash 4.4+). Result in REPLY.
expand_prompt () {
  REPLY=""
  bash_at_least 4 4 || return 1
  eval 'REPLY="${PS1@P}"'
}

wait_for_file () {
  local file="$1" tries="${2:-100}"

  while [[ ! -e "$file" && $tries -gt 0 ]]; do
    sleep 0.1
    tries=$((tries - 1))
  done

  [[ -e "$file" ]]
}

run_test () {
  local name="$1"

  TESTS_RUN=$((TESTS_RUN + 1))
  if (cd "$TEST_TMP/work" && "$2"); then
    printf 'ok %d - %s\n' "$TESTS_RUN" "$name"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf 'not ok %d - %s\n' "$TESTS_RUN" "$name"
  fi
}

# ------------------------------------------------------------------------------
# Injection safety
# ------------------------------------------------------------------------------

test_injection_directory_names () {
  local dir=""

  load_theme
  GAUDI_PROMPT_LEFT=(cwd)
  GAUDI_PROMPT_RIGHT=()
  GAUDI_PROMPT_ASYNC=()
  GAUDI_CWD_SHORTEN=false

  for dir in '$(touch PWNED_SUBST)' 'a`touch PWNED_TICK`b' 'c\w$((6*7))${HOME}\u\$(touch PWNED_ESC)'; do
    mkdir -p "$TEST_TMP/work/inject/$dir"
    cd "$TEST_TMP/work/inject/$dir" || fail "cannot enter $dir"

    gaudi::prompt
    assert_prompt_is_inert "$PS1"

    if expand_prompt; then
      assert_contains "$REPLY" "$dir" "the directory name is not shown literally"
    fi
  done

  assert_nothing_was_executed "a directory name"
}

test_injection_branch_name () {
  local repo="$TEST_TMP/work/repo"
  local branch='x`touch${IFS}PWNED_BRANCH`$(touch${IFS}PWNED_BRANCH2)y'

  command -v git > /dev/null 2>&1 || {
    echo "    # skipped: git not found"
    return 0
  }

  mkdir -p "$repo" && cd "$repo" || fail "cannot create the repository"
  git init -q . || fail "git init failed"
  git checkout -q -b "$branch" || fail "git refused the branch name"

  load_theme
  GAUDI_PROMPT_LEFT=(cwd scm)
  GAUDI_PROMPT_RIGHT=()
  GAUDI_PROMPT_ASYNC=()

  gaudi::prompt
  assert_prompt_is_inert "$PS1"
  if expand_prompt; then
    assert_contains "$REPLY" "$branch" "the branch name is not shown literally"
  fi

  assert_nothing_was_executed "a branch name"
}

test_injection_environment_and_symbol () {
  load_theme
  PATH="$TEST_TMP/bin:$PATH"
  GAUDI_PROMPT_LEFT=()
  GAUDI_PROMPT_RIGHT=()
  GAUDI_PROMPT_ASYNC=(aws)
  AWS_PROFILE='$(touch PWNED_AWS)`touch PWNED_AWS2`'
  GAUDI_CHAR_SYMBOL='$(touch PWNED_CHAR)>'

  gaudi::prompt
  assert_prompt_is_inert "$PS1"
  if expand_prompt; then
    assert_contains "$REPLY" "$AWS_PROFILE" "the profile name is not shown literally"
    assert_contains "$REPLY" "$GAUDI_CHAR_SYMBOL" "the prompt character is not shown literally"
  fi

  assert_nothing_was_executed "the environment"
}

# ------------------------------------------------------------------------------
# Prompt character
# ------------------------------------------------------------------------------

test_char_follows_exit_status () {
  load_theme
  GAUDI_PROMPT_LEFT=(cwd)
  GAUDI_PROMPT_RIGHT=()
  GAUDI_PROMPT_ASYNC=()

  status_of 0
  gaudi::prompt
  assert_equal "${PS1##*$'\n'}" "\[${GAUDI_GREEN}\]>>\[${NC}\] " "prompt character after a successful command"
  assert_equal "$RETVAL" "0"

  status_of 1
  gaudi::prompt
  assert_equal "${PS1##*$'\n'}" "\[${GAUDI_RED}\]>>\[${NC}\] " "prompt character after a failed command"
  assert_equal "$RETVAL" "1"

  status_of 130
  gaudi::prompt
  assert_contains "${PS1##*$'\n'}" "\[${GAUDI_RED}\]" "prompt character after an interrupted command"

  status_of 0
  gaudi::prompt
  assert_contains "${PS1##*$'\n'}" "\[${GAUDI_GREEN}\]" "prompt character goes back to the success colour"
}

test_char_is_configurable () {
  local last_line=""

  GAUDI_CHAR_SYMBOL='❯'
  GAUDI_CHAR_SUFFIX=' '
  GAUDI_CHAR_COLOR_SUCCESS=$'\e[36m'
  # The format the segment used to document: already wrapped, expanded by bash.
  GAUDI_CHAR_COLOR_FAILURE='\[${GAUDI_MAGENTA}\]'
  load_theme
  GAUDI_PROMPT_LEFT=()
  GAUDI_PROMPT_RIGHT=()
  GAUDI_PROMPT_ASYNC=()

  status_of 0
  gaudi::prompt
  last_line="${PS1##*$'\n'}"
  assert_contains "$last_line" "\[${ESC}[36m\]" "custom success colour"
  # \u escapes need bash 4.2.
  if bash_at_least 4 2; then
    assert_contains "$last_line" "❯" "custom symbol"
  fi

  status_of 2
  gaudi::prompt
  assert_contains "${PS1##*$'\n'}" '\[${GAUDI_MAGENTA}\]' "pre-wrapped failure colour is kept as it is"

  # Every colour of the last PS1 line is wrapped in \[ \] for readline.
  last_line="${last_line//"\[${ESC}[36m\]"/}"
  last_line="${last_line//"\[${NC}\]"/}"
  refute_contains "$last_line" "$ESC" "colour outside \\[ \\]"
}

test_continuation_has_its_own_variables () {
  local out=""

  out="$(in_new_shell '' 'printf "%s" "$PS2"')"
  assert_contains "$out" "\[${ESC}[33m\]" "default continuation colour is yellow"
  assert_contains "$out" $'\t' "default continuation suffix is a tab"

  # Loading the theme must not leak the continuation defaults into `char`.
  out="$(in_new_shell '' 'printf "%s|%s|%s" "$GAUDI_CHAR_SYMBOL" "$GAUDI_CHAR_SUFFIX" "$GAUDI_CHAR_COLOR_SUCCESS"')"
  assert_equal "$out" ">>| |${ESC}[32m" "char defaults"

  out="$(in_new_shell 'GAUDI_CONTINUATION_SYMBOL="..."; GAUDI_CONTINUATION_SUFFIX=" "; GAUDI_CONTINUATION_COLOR="<C>"; GAUDI_CHAR_SYMBOL="IGNORED"' 'printf "%s" "$PS2"')"
  assert_equal "$out" "\[<C>\]...  \[${ESC}[0m\]" "GAUDI_CONTINUATION_* variables"

  # The old names still work as a fallback.
  out="$(in_new_shell 'GAUDI_CHAR_SYMBOL="->"; GAUDI_CHAR_SUFFIX=" "; GAUDI_CHAR_COLOR_SUCCESS="<C>"' 'printf "%s" "$PS2"')"
  assert_equal "$out" "\[<C>\]->  \[${ESC}[0m\]" "GAUDI_CHAR_* fallback"
}

# ------------------------------------------------------------------------------
# Working directory
# ------------------------------------------------------------------------------

reduced () {
  gaudi::set_reduced_path "$@"
  printf '%s' "$GAUDI_THEME_REPLY"
}

test_cwd_shortening () {
  load_theme
  gaudi::load_segment cwd
  HOME=/home/me

  assert_equal "$(reduced /)" "⚠ ROOT"
  assert_equal "$(reduced /home/me)" "~"
  assert_equal "$(reduced /home/me/src)" "~/src"
  assert_equal "$(reduced /home/meow/src)" "/home/meow/src" "a sibling of HOME is not HOME"
  assert_equal "$(reduced /usr/local/share)" "/usr/local/share" "a path that fits is unchanged"

  # Longest parent first, the current directory is kept whole.
  assert_equal "$(reduced /home/me/Projects/organisation/repository/src 33)" "~/Projects/o/repository/src"
  assert_equal "$(reduced /home/me/Projects/organisation/repository/src 20)" "~/Projects/o/r/src"
  assert_equal "$(reduced /home/me/Projects/organisation/repository/src 12)" "~/P/o/r/src"
  assert_equal "$(reduced /var/lib/containers/storage/overlay 20)" "/var/lib/c/s/overlay"
  assert_equal "$(reduced /var/lib/containers/storage/overlay 16)" "/v/l/c/s/overlay"
  # Equal lengths: leftmost first.
  assert_equal "$(reduced /aaaa/bbbb/cccc/dddd 17)" "/a/bbbb/cccc/dddd"
  assert_equal "$(reduced /aaaa/bbbb/cccc/dddd 14)" "/a/b/cccc/dddd"
  # Hidden directories keep their dot.
  assert_equal "$(reduced /home/me/.config/something/deep 16)" "~/.config/s/deep"
  assert_equal "$(reduced /home/me/.config/something/deep 12)" "~/.c/s/deep"
  # Still too long once every parent is abbreviated: cut in the middle.
  assert_equal "$(reduced /a/b/abcdefghijklmnopqrstuvwxyz 11)" "/a/b/…vwxyz"
  assert_equal "$(reduced /a/b/abcdefghijklmnopqrstuvwxyz 10)" "/a/b…vwxyz"

  # No globbing, no word splitting, no escapes.
  assert_equal "$(reduced '/tmp/* dir/with  spaces/and\backslash/leaf' 20)" '/tmp/* dir/w/a/leaf'
  assert_equal "$(reduced '/tmp/* dir/with  spaces/and\backslash/leaf' 13)" '/t/*/w/a/leaf'
  assert_equal "$(gaudi_reduce_path /home/me/src)" "~/src" "printing variant"

  # Default length comes from GAUDI_CWD_MAX_LENGTH.
  GAUDI_CWD_MAX_LENGTH=12
  assert_equal "$(reduced /usr/local/share/doc)" "/usr/l/s/doc"
}

test_cwd_segment () {
  local deep="$TEST_TMP/home/projects/organisation/repository/some-package/src"

  load_theme
  gaudi::load_segment cwd
  mkdir -p "$deep" && cd "$deep" || fail "cannot create $deep"

  GAUDI_CWD_MAX_LENGTH=30
  assert_equal "$(strip_ansi "$(gaudi::render_segment cwd)")" " ~/projects/o/repository/s/src "

  GAUDI_CWD_SHORTEN=false
  assert_equal "$(strip_ansi "$(gaudi::render_segment cwd)")" " ~/projects/organisation/repository/some-package/src "

  # Rendered in the current shell: nothing may leak out of the segment.
  unset color cwd GAUDI_CWD
  gaudi::segment_cwd
  assert_contains "$GAUDI_THEME_REPLY" "${GAUDI_CWD_COLOR}" "writable directory colour"
  [[ -z "${color+set}${cwd+set}${GAUDI_CWD+set}" ]] || fail "the cwd segment leaks variables"

  GAUDI_CWD_SUMMARY=true
  : > one
  : > two
  assert_contains "$(strip_ansi "$(gaudi::render_segment cwd)")" "[2 Files, " "summary counts the entries"

  GAUDI_CWD_SHOW=false
  assert_equal "$(gaudi::render_segment cwd)" ""
}

# ------------------------------------------------------------------------------
# AWS
# ------------------------------------------------------------------------------

aws_text () {
  gaudi::segment_aws
  strip_ansi "$GAUDI_THEME_REPLY"
}

test_aws_segment () {
  load_theme
  gaudi::load_segment aws
  PATH="$TEST_TMP/bin:$PATH"
  GAUDI_ENABLE_SYMBOLS=false
  GAUDI_SYMBOL_ALT=aws

  assert_equal "$(aws_text)" "" "no profile, no segment"

  CURRENT_AWS_PROFILE=legacy
  assert_equal "$(aws_text)" " aws legacy "
  AWS_DEFAULT_PROFILE=older
  assert_equal "$(aws_text)" " aws older "
  AWS_PROFILE=dev
  assert_equal "$(aws_text)" " aws dev " "AWS_PROFILE wins over AWS_DEFAULT_PROFILE"
  AWS_VAULT=vaulted
  assert_equal "$(aws_text)" " aws vaulted " "an aws-vault session wins"
  unset AWS_VAULT

  AWS_PROFILE=default
  assert_equal "$(aws_text)" "" "the default profile is hidden"

  AWS_PROFILE=dev
  GAUDI_AWS_SHOW=false
  assert_equal "$(aws_text)" ""
  GAUDI_AWS_SHOW=true

  assert_equal "$(strip_ansi "$(gaudi::render_segment aws)")" " aws dev " "printing variant"

  # Without the AWS CLI the profile is not shown.
  PATH="/nonexistent"
  hash -r
  assert_equal "$(aws_text)" ""
}

test_aws_is_rendered_from_the_environment () {
  local other=""

  load_theme
  PATH="$TEST_TMP/bin:$PATH"
  GAUDI_PROMPT_LEFT=()
  GAUDI_PROMPT_RIGHT=()
  GAUDI_PROMPT_ASYNC=(aws)

  export AWS_PROFILE=first
  gaudi::prompt
  assert_contains "$PS1" "first" "the profile is shown on the very first prompt"

  # A change in this shell shows on the next prompt, with no worker involved.
  AWS_PROFILE=second
  gaudi::prompt
  assert_contains "$PS1" "second"
  refute_contains "$PS1" "first"
  wait

  # Another shell with another profile is not affected by this one.
  other="$(AWS_PROFILE=other in_new_shell '' 'GAUDI_PROMPT_LEFT=(); GAUDI_PROMPT_RIGHT=(); GAUDI_PROMPT_ASYNC=(aws); gaudi::prompt; wait; printf "%s" "$PS1"')"
  assert_contains "$other" "other"
  refute_contains "$other" "second"

  gaudi::prompt
  assert_contains "$PS1" "second"
  wait

  [[ -z "$(find "$XDG_CACHE_HOME" -name 'aws--*')" ]] || fail "the aws segment was written to the shared cache"
}

# ------------------------------------------------------------------------------
# gaudi::has_files
# ------------------------------------------------------------------------------

test_has_files () {
  local dir="$TEST_TMP/work/files"

  load_theme
  mkdir -p "$dir/sub.d" && cd "$dir" || fail "cannot create $dir"

  gaudi::has_files '*.js' && fail "matched in a directory without .js files"
  gaudi::has_files && fail "matched without a pattern"

  : > 'with space.js'
  : > .hidden.py
  : > nested.rs.txt
  : > sub.d/inner.go

  gaudi::has_files '*.js' || fail "*.js not found"
  gaudi::has_files '*.rb' '*.js' || fail "second pattern not tried"
  gaudi::has_files '*.py' && fail "a hidden file matched *.py"
  gaudi::has_files '.*.py' || fail "an explicit dot pattern did not match"
  gaudi::has_files '*.rs' && fail "*.rs matched nested.rs.txt"
  gaudi::has_files '*.go' && fail "matched a file in a sub directory"
  gaudi::has_files '*.d' || fail "directories count as entries"

  # Shell options set by other segments must not change the answer.
  shopt -s nullglob
  gaudi::has_files '*.rb' && fail "matched with nullglob set"
  gaudi::has_files '*.js' || fail "*.js not found with nullglob set"
  shopt -u nullglob

  # A segment that relies on it (a loaded nvm defines nvm_ls_current).
  nvm () { echo "v99.0.0"; }
  nvm_ls_current () { :; }
  assert_contains "$(gaudi::render_segment node)" "v99.0.0" "node segment in a directory with .js files"
  rm -f 'with space.js'
  assert_equal "$(gaudi::render_segment node)" "" "node segment in a directory without .js files"
}

# ------------------------------------------------------------------------------
# Configuration set before the theme loads
# ------------------------------------------------------------------------------

test_preset_configuration_is_kept () {
  local out=""

  out="$(in_new_shell 'GAUDI_PROMPT_LEFT=(cwd); GAUDI_PROMPT_RIGHT=(); GAUDI_PROMPT_DEFAULT_PREFIX="<"' \
    'printf "%s|%s|%s|%s|%s" "${GAUDI_PROMPT_LEFT[*]}" "${#GAUDI_PROMPT_RIGHT[@]}" "${#GAUDI_PROMPT_ASYNC[@]}" "$GAUDI_PROMPT_DEFAULT_PREFIX" "$GAUDI_PROMPT_DEFAULT_SUFFIX"')"
  assert_equal "$out" "cwd|0|17|<| " "arrays and defaults set before the theme loads are kept, the rest gets its default"

  out="$(in_new_shell '' 'printf "%s|%s|%s" "${GAUDI_PROMPT_LEFT[*]}" "${GAUDI_PROMPT_RIGHT[*]}" "${GAUDI_PROMPT_ASYNC[0]}"')"
  assert_equal "$out" "multiplexer duration cwd|battery time user host|scm" "defaults when nothing is set"

  # Every setting of a segment is a default too.
  out="$(in_new_shell 'GAUDI_TIME_SYMBOL=T; GAUDI_DURATION_SYMBOL=D; GAUDI_MULTIPLEXER_SYMBOL=M; GAUDI_VPN_SYMBOL=V; GAUDI_SYSTEM_CPU_SYMBOL=C; GAUDI_DOCKERCOMPOSE_SYMBOL_UP=U; GAUDI_THEME_PROMPT_CLEAN_COLOR=K' \
    'for s in time duration multiplexer vpn system dockercompose scm; do gaudi::load_segment "$s"; done; printf "%s" "$GAUDI_TIME_SYMBOL$GAUDI_DURATION_SYMBOL$GAUDI_MULTIPLEXER_SYMBOL$GAUDI_VPN_SYMBOL$GAUDI_SYSTEM_CPU_SYMBOL$GAUDI_DOCKERCOMPOSE_SYMBOL_UP$GAUDI_THEME_PROMPT_CLEAN_COLOR"')"
  assert_equal "$out" "TDMVCUK" "segment symbols and colours set before the theme loads are kept"
}

# ------------------------------------------------------------------------------
# Node segment and lazy-loaded version managers
# ------------------------------------------------------------------------------

test_node_never_calls_lazy_stubs () {
  local dir="$TEST_TMP/work/node" bin="$TEST_TMP/nodebin"

  load_theme
  mkdir -p "$dir" "$bin" && cd "$dir" || fail "cannot create $dir"
  : > package.json

  # What a lazy-loading plugin leaves behind: functions that would load nvm.
  nvm () { : > "$TEST_TMP/STUB_CALLED"; echo "v1.0.0"; }
  node () { : > "$TEST_TMP/STUB_CALLED"; echo "v1.0.0"; }

  printf '#!/bin/sh\necho v20.1.0\n' > "$bin/node"
  chmod +x "$bin/node"

  # No node program on PATH: nothing is shown and no stub is called.
  PATH="/nonexistent"
  hash -r
  assert_equal "$(gaudi::render_segment node)" "" "no node program on PATH"
  [[ ! -e "$TEST_TMP/STUB_CALLED" ]] || fail "a lazy-load stub was called"

  # A node program on PATH is asked directly, not through the stub.
  PATH="$bin"
  hash -r
  assert_contains "$(gaudi::render_segment node)" "v20.1.0" "the node program on PATH"
  [[ ! -e "$TEST_TMP/STUB_CALLED" ]] || fail "a lazy-load stub was called"
}

# ------------------------------------------------------------------------------
# Battery
# ------------------------------------------------------------------------------

# Stand-ins for uname and pmset, so the same test runs on Linux and macOS:
# pmset prints the content of $TEST_TMP/pmset.out.
battery_text () {
  strip_ansi "$(gaudi_battery)"
}

test_battery_segment () {
  local bin="$TEST_TMP/battbin" out=""

  load_theme
  gaudi::load_segment battery
  mkdir -p "$bin"
  printf '#!/bin/sh\necho Darwin\n' > "$bin/uname"
  printf '#!/bin/sh\ncat "%s"\n' "$TEST_TMP/pmset.out" > "$bin/pmset"
  chmod +x "$bin/uname" "$bin/pmset"
  PATH="$bin:$PATH"
  GAUDI_ENABLE_SYMBOLS=false

  assert_equal "$GAUDI_BATTERY_SHOW" "always" "the battery is always shown by default"

  # A machine without a battery shows nothing at all.
  printf "Now drawing from 'AC Power'\n" > "$TEST_TMP/pmset.out"
  assert_equal "$(gaudi_battery)" "" "no battery, no segment"

  printf "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=1)\t85%%; discharging; 3:10 remaining present: true\n" > "$TEST_TMP/pmset.out"
  out="$(gaudi_battery)"
  assert_contains "$out" "85%"
  assert_contains "$out" "$GAUDI_YELLOW" "yellow above the threshold"
  GAUDI_BATTERY_SHOW=true
  assert_equal "$(gaudi_battery)" "" "true: hidden above the threshold"
  GAUDI_BATTERY_THRESHOLD=90
  assert_contains "$(gaudi_battery)" "85%" "true: shown below the threshold"
  GAUDI_BATTERY_THRESHOLD=10

  printf "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=1)\t5%%; discharging; 0:10 remaining present: true\n" > "$TEST_TMP/pmset.out"
  out="$(gaudi_battery)"
  assert_contains "$out" "5%" "true: shown below the threshold"
  assert_contains "$out" "$GAUDI_RED" "red below the threshold"

  printf "Now drawing from 'AC Power'\n -InternalBattery-0 (id=1)\t100%%; charged; 0:00 remaining present: true\n" > "$TEST_TMP/pmset.out"
  out="$(gaudi_battery)"
  assert_contains "$out" "100%" "true: shown when fully charged"
  assert_contains "$out" "$GAUDI_GREEN" "green when fully charged"

  GAUDI_BATTERY_SHOW=false
  assert_equal "$(gaudi_battery)" ""

  out="$(battstat '{x}' 2>&1)" && fail "an unknown token was accepted"
  assert_contains "$out" "unknown argument"
}

# ------------------------------------------------------------------------------
# Jobs
# ------------------------------------------------------------------------------

test_jobs_segment () {
  local out=""

  load_theme
  gaudi::load_segment jobs
  GAUDI_ENABLE_SYMBOLS=false
  GAUDI_SYMBOL_ALT="jobs"
  GAUDI_JOBS_AMOUNT_PREFIX="["
  GAUDI_JOBS_AMOUNT_SUFFIX="]"

  assert_equal "$(gaudi_jobs)" "" "no jobs, no segment"

  sleep 30 &
  out="$(strip_ansi "$(gaudi_jobs)")"
  assert_equal "$out" " jobs  " "one job: the icon alone (the threshold is 1)"

  sleep 30 &
  out="$(strip_ansi "$(gaudi_jobs)")"
  assert_equal "$out" " jobs [2] " "more jobs than the threshold: the count, with its prefix and suffix"
  assert_equal "$GAUDI_JOBS_AMOUNT_PREFIX" "[" "the settings are left as they were"

  kill %1 %2 2> /dev/null
  wait 2> /dev/null
  return 0
}

# ------------------------------------------------------------------------------
# Async zone
# ------------------------------------------------------------------------------

test_cached_async_content_is_shown () {
  printf '%s\n' 'gaudi_cached () { printf "%s" "fresh"; }' > "$THEME/segments/cached.bash"

  load_theme
  GAUDI_PROMPT_LEFT=()
  GAUDI_PROMPT_RIGHT=()
  GAUDI_PROMPT_ASYNC=(cached)

  gaudi::set_async_segment_cache_file cached
  printf '%s' "stale" > "$GAUDI_THEME_REPLY"

  gaudi::prompt > /dev/null
  assert_contains "$PS1" "stale" "the cached value is shown at once"
  wait
  gaudi::prompt > /dev/null
  assert_contains "$PS1" "fresh" "the worker refreshed the cache"
  wait
}

test_previous_worker_is_cancelled () {
  local marks="$TEST_TMP/marks"
  local worker_file="" first_worker=""

  mkdir -p "$marks"
  printf '%s\n' 'gaudi_slowa () { : > "$GAUDI_TEST_MARKS/a.$GAUDI_TEST_RUN"; sleep 1; printf "%s" "a$GAUDI_TEST_RUN"; }' > "$THEME/segments/slowa.bash"
  printf '%s\n' 'gaudi_slowb () { : > "$GAUDI_TEST_MARKS/b.$GAUDI_TEST_RUN"; printf "%s" "b$GAUDI_TEST_RUN"; }' > "$THEME/segments/slowb.bash"

  load_theme
  GAUDI_PROMPT_LEFT=()
  GAUDI_PROMPT_RIGHT=()
  GAUDI_PROMPT_ASYNC=(slowa slowb)
  export GAUDI_TEST_MARKS="$marks"
  worker_file="$GAUDI_THEME_WORKER_FILE"

  export GAUDI_TEST_RUN=1
  gaudi::prompt > /dev/null
  wait_for_file "$marks/a.1" || fail "the first worker never started"
  [[ -s "$worker_file" ]] || fail "the worker did not publish its process id"
  first_worker="$(< "$worker_file")"
  kill -0 "$first_worker" 2> /dev/null || fail "the first worker is not running"

  # A new prompt while the first worker is still busy. Old non-interactive
  # shells report the cancelled worker ("Terminated") when they reap it, so
  # stderr is parked meanwhile.
  export GAUDI_TEST_RUN=2
  exec 3>&2 2> /dev/null
  gaudi::prompt > /dev/null
  wait_for_file "$marks/b.2"
  wait
  exec 2>&3 3>&-
  [[ -e "$marks/b.2" ]] || fail "the second worker did not finish"

  [[ ! -e "$marks/b.1" ]] || fail "the first worker kept rendering after a newer prompt"
  kill -0 "$first_worker" 2> /dev/null && fail "the first worker is still alive"
  [[ ! -s "$worker_file" ]] || fail "a finished worker left its process id behind"
  [[ -z "$(find "$XDG_CACHE_HOME" -name '.gaudi.*')" ]] || fail "temporary cache files were left behind"

  gaudi::prompt > /dev/null
  assert_contains "$PS1" "a2b2" "the newest results are shown"
  wait
}

test_shell_state_is_removed_on_exit () {
  local state=""

  state="$(in_new_shell '' 'GAUDI_PROMPT_ASYNC=(); gaudi::register_exit_cleanup; gaudi::prompt; printf "%s" "$GAUDI_THEME_STATE_DIR"')"
  [[ -n "$state" && "$state" == "$XDG_CACHE_HOME"/* ]] || fail "unexpected state directory: $state"
  [[ ! -e "$state" ]] || fail "the state directory survived the shell"
}

# ------------------------------------------------------------------------------
# Run
# ------------------------------------------------------------------------------

printf '# gaudi theme tests, bash %s\n' "$BASH_VERSION"

run_test "injection: directory names are never expanded" test_injection_directory_names
run_test "injection: branch names are never expanded" test_injection_branch_name
run_test "injection: environment values and the prompt symbol are never expanded" test_injection_environment_and_symbol
run_test "char: colour follows the exit status of the last command" test_char_follows_exit_status
run_test "char: symbol and colours are configurable" test_char_is_configurable
run_test "continuation: own variables, GAUDI_CHAR_* as fallback" test_continuation_has_its_own_variables
run_test "cwd: path shortening" test_cwd_shortening
run_test "cwd: segment output and options" test_cwd_segment
run_test "aws: profile selection" test_aws_segment
run_test "aws: rendered from the environment of each shell, never cached" test_aws_is_rendered_from_the_environment
run_test "has_files: glob matching without find" test_has_files
run_test "config: values set before the theme loads are kept" test_preset_configuration_is_kept
run_test "node: lazy-load stubs of version managers are never called" test_node_never_calls_lazy_stubs
run_test "battery: no battery, threshold colour and visibility" test_battery_segment
run_test "jobs: icon, and the count above the threshold" test_jobs_segment
run_test "async: cached content is shown, then refreshed" test_cached_async_content_is_shown
run_test "async: a new prompt cancels the previous worker" test_previous_worker_is_cancelled
run_test "async: per-shell state is removed on exit" test_shell_state_is_removed_on_exit

printf '# %d tests, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
