#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1091

generation="${1:-}"
shift || exit 1

[[ -n "$generation" && "$#" -gt 0 ]] || exit 1

# The theme root is the parent of the directory this script lives in. The value
# handed over by the shell that started the worker, then the framework's default
# location, are the fallbacks.
GAUDI_THEME_WORKER_ROOT="${BASH_SOURCE[0]%/*}"
GAUDI_THEME_WORKER_ROOT="${GAUDI_THEME_WORKER_ROOT%/lib}"
if [[ -f "$GAUDI_THEME_WORKER_ROOT/gaudi.configs.bash" ]]; then
  GAUDI_ROOT="$GAUDI_THEME_WORKER_ROOT"
elif [[ ! -f "${GAUDI_ROOT:-}/gaudi.configs.bash" ]]; then
  GAUDI_ROOT="${GAUDI_BASH:-}/components/themes/gaudi"
fi

cd "${GAUDI_THEME_WORKDIR:-$PWD}" || exit 1

source "$GAUDI_ROOT/gaudi.configs.bash" > /dev/null 2>&1 || exit 1
source "$GAUDI_ROOT/lib/utils.bash" > /dev/null 2>&1 || exit 1
source "$GAUDI_ROOT/lib/colors.bash" > /dev/null 2>&1 || exit 1
source "$GAUDI_ROOT/lib/scm.bash" > /dev/null 2>&1 || exit 1
source "$GAUDI_ROOT/lib/async.bash" > /dev/null 2>&1 || exit 1

# shellcheck disable=SC2034
GAUDI_PROMPT_ASYNC=("$@")

# Inline segments were rendered by the shell that drew the prompt and are
# reused from the environment (see gaudi::set_inline_async_segment).
# shellcheck disable=SC2034
GAUDI_THEME_WORKER=1

# Only the shared cache directory: the state directory belongs to the parent
# shell, which removes it on exit.
gaudi::ensure_async_cache_dir
gaudi::register_async_worker

for segment in "$@"; do
  # A newer prompt has been drawn (or the shell is gone): stand down instead of
  # rendering segments nobody will see.
  gaudi::generation_matches "$generation" || break
  gaudi::async_segment_is_inline "$segment" && continue
  gaudi::refresh_async_segment "$segment" "$generation"
done
