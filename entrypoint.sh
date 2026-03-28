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

# Log startup info
echo "OpenClaw Docker v${OPENCLAW_DOCKER_VERSION:-unknown} starting..."
echo "Data directory: /home/node/.openclaw"
echo "Gateway token: ${OPENCLAW_GATEWAY_TOKEN:0:10}..."

exec "$@"
