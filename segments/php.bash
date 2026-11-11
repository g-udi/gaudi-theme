#!/usr/bin/env bash
#
# PHP
#
# PHP is a server-side scripting language designed primarily for web development.
# Link: http://www.php.net/

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_PHP_SHOW="${GAUDI_PHP_SHOW=true}"
GAUDI_PHP_PREFIX="${GAUDI_PHP_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_PHP_SUFFIX="${GAUDI_PHP_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_PHP_SYMBOL="${GAUDI_PHP_SYMBOL="\\ue608"}"
GAUDI_PHP_COLOR="${GAUDI_PHP_COLOR="$GAUDI_BLUE"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

# Show current version of PHP
gaudi_php () {
  [[ $GAUDI_PHP_SHOW == false ]] && return

  # Show only if php files or composer.json exist in current directory
  [[ -f composer.json ]] || gaudi::has_files '*.php' || return

  gaudi::exists php || return

  local php_version
  php_version=$(php -v 2>&1 | grep --color=never -oe "^PHP\s*[0-9.]\+" | awk '{print $2}')

  gaudi::section \
    "$GAUDI_PHP_COLOR" \
    "$GAUDI_PHP_PREFIX" \
    "$GAUDI_PHP_SYMBOL" \
    "$php_version" \
    "${GAUDI_PHP_SUFFIX}"
}
