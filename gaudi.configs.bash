# shellcheck shell=bash
# shellcheck disable=SC2034

GAUDI_SPLIT_PROMPT="${GAUDI_SPLIT_PROMPT=true}"
GAUDI_SPLIT_PROMPT_TWO_LINES="${GAUDI_SPLIT_PROMPT_TWO_LINES=false}"
GAUDI_ENABLE_HUSHLOGIN="${GAUDI_ENABLE_HUSHLOGIN=true}"
GAUDI_ENABLE_SYMBOLS="${GAUDI_ENABLE_SYMBOLS=true}"
GAUDI_PROMPT_DEFAULT_PREFIX=" "
GAUDI_PROMPT_DEFAULT_SUFFIX=" "

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

GAUDI_PROMPT_LEFT=(
  multiplexer   # tmux segment
  cwd           # Current working directory
)

GAUDI_PROMPT_RIGHT=(
  battery       # Battery level and status
  time          # Time stamps segment
  user          # Username segment
  host          # Hostname segment
)
