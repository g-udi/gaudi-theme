#!/usr/bin/env bash
#
# VPN
# Show if the connection is made through a VPN
# Currently supports VPN Unlimited

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

GAUDI_VPN_SHOW="${GAUDI_VPN_SHOW=true}"
GAUDI_VPN_SYMBOL="\\uf98c"
GAUDI_VPN_PREFIX="${GAUDI_VPN_PREFIX="$GAUDI_PROMPT_DEFAULT_PREFIX"}"
GAUDI_VPN_SUFFIX="${GAUDI_VPN_SUFFIX="$GAUDI_PROMPT_DEFAULT_SUFFIX"}"
GAUDI_VPN_COLOR="${GAUDI_VPN_COLOR="$GAUDI_WHITE$BACKGROUND_GAUDI_ORANGE"}"

# ------------------------------------------------------------------------------
# Section
# ------------------------------------------------------------------------------

gaudi_vpn () {
  [[ $GAUDI_VPN_SHOW == false ]] && return

  local vpn_active=""

  case "$(uname)" in
    Darwin)
      ifconfig ipsec0 &> /dev/null && vpn_active=true
      ;;
    Linux)
      [[ -d /proc/sys/net/ipv4/conf/tun0 ]] && vpn_active=true
      ;;
  esac

  [[ -z "$vpn_active" ]] && return

  gaudi::section \
    "$GAUDI_VPN_COLOR" \
    "$GAUDI_VPN_PREFIX" \
    "$GAUDI_VPN_SYMBOL" \
    "VPN" \
    "$GAUDI_VPN_SUFFIX"
}
