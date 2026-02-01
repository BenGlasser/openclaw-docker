#!/bin/bash
set -e

# Fix ownership of persistent volume if it exists
# This handles the case where host creates the directory with different UID
# The chown runs as the current user (node) - may fail on root-owned files
# which is expected and safe to ignore
if [ -d /home/node/.openclaw ]; then
  chown -R node:node /home/node/.openclaw 2>/dev/null || true
fi

# Create .openclaw directory if it doesn't exist
mkdir -p /home/node/.openclaw

# Generate default token if not set
# Users should override with OPENCLAW_GATEWAY_TOKEN environment variable
if [ -z "$OPENCLAW_GATEWAY_TOKEN" ]; then
  # Generate a random token for this container instance
  # This allows the gateway to start while maintaining security
  export OPENCLAW_GATEWAY_TOKEN="openclaw-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
  echo "⚠️  Generated temporary gateway token (set OPENCLAW_GATEWAY_TOKEN to use a persistent token)"
fi

# Log startup info
echo "OpenClaw Docker container starting..."
echo "User: $(whoami) ($(id -u):$(id -g))"
echo "Data directory: /home/node/.openclaw"
echo "Gateway token: ${OPENCLAW_GATEWAY_TOKEN:0:10}..."

# Replace this shell with the main command
# Critical: exec ensures signals from dumb-init reach the node process
exec "$@"
