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

# Log startup info
echo "OpenClaw Docker container starting..."
echo "User: $(whoami) ($(id -u):$(id -g))"
echo "Data directory: /home/node/.openclaw"

# Replace this shell with the main command
# Critical: exec ensures signals from dumb-init reach the node process
exec "$@"
