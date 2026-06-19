#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC1091

generation="${1:-}"
shift || exit 1

[[ -n "$GAUDI_BASH" && -n "$generation" && "$#" -gt 0 ]] || exit 1

GAUDI_ROOT="${GAUDI_BASH}/components/themes/gaudi"
cd "${GAUDI_THEME_WORKDIR:-$PWD}" || exit 1

source "$GAUDI_ROOT/gaudi.configs.bash" > /dev/null 2>&1 || exit 1
source "$GAUDI_ROOT/lib/utils.bash" > /dev/null 2>&1 || exit 1
source "$GAUDI_ROOT/lib/colors.bash" > /dev/null 2>&1 || exit 1
source "$GAUDI_ROOT/lib/scm.bash" > /dev/null 2>&1 || exit 1
source "$GAUDI_ROOT/lib/async.bash" > /dev/null 2>&1 || exit 1

# shellcheck disable=SC2034
GAUDI_PROMPT_ASYNC=("$@")

gaudi::ensure_async_dirs

for segment in "$@"; do
  gaudi::refresh_async_segment "$segment" "$generation"
done
