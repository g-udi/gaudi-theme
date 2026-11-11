#!/usr/bin/env bash
#
# Ruby
#
# A dynamic, reflective, object-oriented, general-purpose programming language.
# Link: https://www.ruby-lang.org/

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_RUBY_SHOW="${GAUDI_RUBY_SHOW=true}"
GAUDI_RUBY_PREFIX="${GAUDI_RUBY_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_RUBY_SUFFIX="${GAUDI_RUBY_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_RUBY_SYMBOL="${GAUDI_RUBY_SYMBOL="\\uf43b"}"
GAUDI_RUBY_COLOR="${GAUDI_RUBY_COLOR="$GAUDI_RED"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Show current version of Ruby
gaudi_ruby () {

  shopt -s nullglob

  [[ $GAUDI_RUBY_SHOW == false ]] && return

  # Show versions only for Ruby-specific folders
  [[ -f Gemfile || -f Rakefile ]] || gaudi::has_files '*.rb' || return

  local 'ruby_version'

 ruby_version=$(ruby -v 2>/dev/null | grep "ruby" --color=never | cut -d ' ' -f 2 | cut -c1-5)

  [[ -z $ruby_version || "${ruby_version}" == "system" ]] && return

  # Add 'v' before ruby version that starts with a number
  [[ "${ruby_version}" =~ ^[0-9].+$ ]] && ruby_version="v${ruby_version}"

  gaudi::section \
    "$GAUDI_RUBY_COLOR" \
    "$GAUDI_RUBY_PREFIX" \
    "$GAUDI_RUBY_SYMBOL" \
    "$ruby_version" \
    "$GAUDI_RUBY_SUFFIX"
}
