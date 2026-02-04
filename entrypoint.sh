#!/bin/bash
set -e

# PUID/PGID defaults
# PUID=1000 preserves backward compatibility for non-Unraid users
# PGID=100 matches Unraid's 'users' group default
PUID=${PUID:-1000}
PGID=${PGID:-100}

# Remap node user/group to match PUID/PGID
# This enables Unraid's permission model (typically 99:100)
if [ "$(id -u node)" != "$PUID" ]; then
  usermod -o -u "$PUID" node
fi
if [ "$(id -g node)" != "$PGID" ]; then
  groupmod -o -g "$PGID" node
fi

# Create .openclaw directory if it doesn't exist
mkdir -p /home/node/.openclaw

# Fix ownership of persistent volume and app directory
# Must run after UID/GID remapping to use correct values
chown -R node:node /home/node/.openclaw 2>/dev/null || true
chown -R node:node /app 2>/dev/null || true

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
echo "PUID: $PUID, PGID: $PGID"
echo "Data directory: /home/node/.openclaw"
echo "Gateway token: ${OPENCLAW_GATEWAY_TOKEN:0:10}..."

su node -c "npm install -g openclaw"
apt update && apt install iproute2 -y 

su node -c ./connect-qr.sh

# Replace this shell with the main command, dropping to remapped user
# gosu properly replaces the process and maintains signal handling with dumb-init
exec gosu node "$@"
