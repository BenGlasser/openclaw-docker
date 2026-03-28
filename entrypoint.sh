#!/bin/bash
set -e

# Ensure data directory exists
mkdir -p /home/node/.openclaw

# Generate default token if not set
# Users should override with OPENCLAW_GATEWAY_TOKEN environment variable
if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
  export OPENCLAW_GATEWAY_TOKEN="openclaw-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
  echo "Generated temporary gateway token (set OPENCLAW_GATEWAY_TOKEN to use a persistent token)"
fi

# Configure LAN binding: OpenClaw requires allowed origins for non-loopback Control UI
# Use Host-header fallback so the UI works from any IP/hostname on the local network
node dist/index.js config set gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback true 2>/dev/null || true

# Log startup info
echo "OpenClaw Docker v${OPENCLAW_DOCKER_VERSION:-unknown} starting..."
echo "Data directory: /home/node/.openclaw"
echo "Gateway token: ${OPENCLAW_GATEWAY_TOKEN:0:10}..."

./connect-qr.sh || true

exec "$@"
