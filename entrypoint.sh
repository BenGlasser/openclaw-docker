#!/bin/bash
set -e

# Create .openclaw directory if it doesn't exist
mkdir -p /root/.openclaw

# Generate default token if not set
# Users should override with OPENCLAW_GATEWAY_TOKEN environment variable
if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
  export OPENCLAW_GATEWAY_TOKEN="openclaw-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
  echo "⚠️  Generated temporary gateway token (set OPENCLAW_GATEWAY_TOKEN to use a persistent token)"
fi

# Log startup info
echo "OpenClaw Docker container starting..."
echo "Data directory: /root/.openclaw"
echo "Gateway token: ${OPENCLAW_GATEWAY_TOKEN:0:10}..."

./connect-qr.sh || true

exec "$@"
