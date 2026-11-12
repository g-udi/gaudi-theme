# shellcheck shell=bash
# shellcheck disable=SC2034

# Every value below is a default: one that is already set when the theme loads
# (in your profile, before the framework is sourced) is kept. The three prompt
# arrays can also be changed after the theme has loaded, they are read on every
# prompt.

GAUDI_SPLIT_PROMPT="${GAUDI_SPLIT_PROMPT=true}"
GAUDI_SPLIT_PROMPT_TWO_LINES="${GAUDI_SPLIT_PROMPT_TWO_LINES=false}"
GAUDI_ENABLE_SYMBOLS="${GAUDI_ENABLE_SYMBOLS=true}"
GAUDI_PROMPT_DEFAULT_PREFIX="${GAUDI_PROMPT_DEFAULT_PREFIX=" "}"
GAUDI_PROMPT_DEFAULT_SUFFIX="${GAUDI_PROMPT_DEFAULT_SUFFIX=" "}"

# `declare -p` tells whether the array exists at all, so an array that was set
# to () on purpose (no segments) is kept as well.
if ! declare -p GAUDI_PROMPT_ASYNC > /dev/null 2>&1; then
  GAUDI_PROMPT_ASYNC=(
    scm           # code management segment (git, mercurial, perforce, etc.)
    aws           # Amazon WebServices (AWS) segment
    docker        # Docker segment
    node          # Node.js segment
    ruby          # Ruby segment
    elixir        # Elixir segment
    golang        # Go segment
    angular       # Angular segment
    react         # React segment
    php           # PHP segment
    rust          # Rust segment
    haskell       # Haskell Stack segment
    julia         # Julia segment
    pyenv         # Pyenv segment
    elm           # Elm segment
    java          # Java segment
    package       # Javascript package managers
  )
fi

if ! declare -p GAUDI_PROMPT_LEFT > /dev/null 2>&1; then
  GAUDI_PROMPT_LEFT=(
    multiplexer   # tmux segment
    duration      # Last command duration
    cwd           # Current working directory
  )
fi

if ! declare -p GAUDI_PROMPT_RIGHT > /dev/null 2>&1; then
  GAUDI_PROMPT_RIGHT=(
    battery       # Battery level and status
    time          # Time stamps segment
    user          # Username segment
    host          # Hostname segment
  )
fi
