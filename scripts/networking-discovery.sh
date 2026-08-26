#!/bin/sh
# Railway Networking provisioning-race tolerance.
# The current deployment environment remains authoritative; this helper only
# waits for that environment to become internally usable.
set -eu

MAX_WAIT="${RAILWAY_NETWORKING_MAX_WAIT:-180}"
INITIAL_BACKOFF="${RAILWAY_NETWORKING_INITIAL_BACKOFF:-2}"
MAX_BACKOFF="${RAILWAY_NETWORKING_MAX_BACKOFF:-60}"

case "$MAX_WAIT" in ''|*[!0-9]*) MAX_WAIT=180;; esac
case "$INITIAL_BACKOFF" in ''|*[!0-9]*) INITIAL_BACKOFF=2;; esac
case "$MAX_BACKOFF" in ''|*[!0-9]*) MAX_BACKOFF=60;; esac

start_epoch=$(date +%s)
backoff="$INITIAL_BACKOFF"
attempt=1

while :; do
  PUBLIC_DOMAIN="${RAILWAY_PUBLIC_DOMAIN:-}"
  TCP_HOST="${RAILWAY_TCP_PROXY_DOMAIN:-}"
  TCP_PORT="${RAILWAY_TCP_PROXY_PORT:-}"

  reason=""
  [ -n "$PUBLIC_DOMAIN" ] || reason="public-domain-unavailable"
  if [ -z "$reason" ] && { [ -z "$TCP_HOST" ] || [ -z "$TCP_PORT" ]; }; then
    reason="tcp-proxy-unavailable"
  fi
  if [ -z "$reason" ]; then
    case "$TCP_PORT" in
      ''|*[!0-9]*) reason="tcp-proxy-port-nonnumeric" ;;
    esac
  fi
  if [ -z "$reason" ] && { [ "$TCP_PORT" -lt 1 ] || [ "$TCP_PORT" -gt 65535 ]; }; then
    reason="tcp-proxy-port-out-of-range"
  fi

  if [ -z "$reason" ]; then
    echo "NETWORK_PROVISIONING_READY=pass attempt=$attempt elapsed=$(($(date +%s)-start_epoch))s"
    export RAILWAY_CURRENT_PUBLIC="$PUBLIC_DOMAIN"
    export RAILWAY_CURRENT_TCP="$TCP_HOST:$TCP_PORT"
    return_value=0
    break
  fi

  elapsed=$(( $(date +%s) - start_epoch ))
  if [ "$elapsed" -ge "$MAX_WAIT" ]; then
    echo "FATAL: Railway networking provisioning timeout after ${elapsed}s reason=$reason" >&2
    exit 1
  fi

  echo "NETWORK_PROVISIONING_RETRY=attempt=$attempt reason=$reason backoff=${backoff}s elapsed=${elapsed}s"
  sleep "$backoff"
  attempt=$((attempt + 1))
  if [ "$backoff" -lt "$MAX_BACKOFF" ]; then
    next=$((backoff * 2))
    [ "$next" -le "$MAX_BACKOFF" ] && backoff="$next" || backoff="$MAX_BACKOFF"
  fi
done

# Export through a sourced shell script; these names are intentionally simple
# so callers can use the values without re-reading the environment.
export RAILWAY_DISCOVERED_PUBLIC_DOMAIN="$PUBLIC_DOMAIN"
export RAILWAY_DISCOVERED_TCP_HOST="$TCP_HOST"
export RAILWAY_DISCOVERED_TCP_PORT="$TCP_PORT"
