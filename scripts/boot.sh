#!/bin/sh

# Repository-native build identity. One source for runtime/build metadata.
REPOSITORY_IDENTITY="$(python3 /opt/xray/scripts/version.py 2>/dev/null || echo runtime)"
export RELEASE="$REPOSITORY_IDENTITY"
export BUILD_ID="$REPOSITORY_IDENTITY"
export SOURCE_BUILD="$REPOSITORY_IDENTITY"

set -eu
umask 077
D="${RAILWAY_VOLUME_MOUNT_PATH:-${DATA_DIR:-/data}}"
mkdir -p "$D"
for f in "$D/runtime.json" "$D/state.json" "$D/manifest.json" "$D/runtime-manifest.json" "$D/subscription.txt" "$D/subscription.txt.tmp" "$D/subscription_url.txt" "$D/networking-snapshot.json" "${XRAY_CONFIG:-$D/config.json}"; do
  rm -f "$f"
done
PUBLIC_DOMAIN="${RAILWAY_PUBLIC_DOMAIN:-}"
TCP_HOST="${RAILWAY_TCP_PROXY_DOMAIN:-}"
TCP_PORT="${RAILWAY_TCP_PROXY_PORT:-}"
. /opt/xray/scripts/networking-discovery.sh
PUBLIC_DOMAIN="$RAILWAY_DISCOVERED_PUBLIC_DOMAIN"
TCP_HOST="$RAILWAY_DISCOVERED_TCP_HOST"
TCP_PORT="$RAILWAY_DISCOVERED_TCP_PORT"
printf '{"source":"current-deployment-environment","authoritative":true,"public_domain":"%s","tcp_proxy_domain":"%s","tcp_proxy_port":%s,"application_port":8080}\n' "$PUBLIC_DOMAIN" "$TCP_HOST" "$TCP_PORT" > "$D/networking-snapshot.json"
chmod 600 "$D/networking-snapshot.json"
echo "STARTUP_LIFECYCLE=networking-discovery"
echo "RAILWAY_NETWORKING_SOURCE=current-deployment-environment"
echo "RAILWAY_NETWORKING_AUTHORITATIVE=true"
echo "RAILWAY_CURRENT_PUBLIC=$PUBLIC_DOMAIN"
echo "RAILWAY_CURRENT_TCP=$TCP_HOST:$TCP_PORT"
echo "RUNTIME_REGENERATION=required"
echo "SUBSCRIPTION_REGENERATION=required"
echo "ENDPOINT_VALIDATION=required"
echo "XRAY_GATEWAY_START=blocked-until-validation-pass"
exec /opt/xray/scripts/guard.sh
