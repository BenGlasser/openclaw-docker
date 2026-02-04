#!/bin/bash
# Configure OpenClaw Gateway for LAN binding with token auth
# Works on macOS and Linux
# Generates QR code with connection info

set -e

# Detect CLI: prefer openclaw, fall back to clawdbot
if command -v openclaw &> /dev/null; then
  CLI="openclaw"
elif command -v clawdbot &> /dev/null; then
  CLI="clawdbot"
else
  echo "Error: openclaw is not installed."
  echo "Please install openclaw first."
  exit 1
fi
echo "Using CLI: $CLI"

OUTPUT_DIR="${1:-.}"
OUTPUT_FILE="$OUTPUT_DIR/gateway-connection.png"

echo "This script will configure your gateway for LAN access:"
echo ""
echo "  1. Bind gateway to all network interfaces (0.0.0.0)"
echo "     This allows connections from other devices on your local network."
echo ""
echo "     WARNING: This is intended for home networks only."
echo "     Do not run on cloud instances where your IP is publicly accessible."
echo ""
echo "  2. Enable token authentication"
echo "     Requires a secret token to connect, preventing unauthorized access."
echo ""
echo "  3. Generate/reuse an authentication token"
echo "     A secure random token will be created (or existing one reused)."
echo ""
echo "  4. Enable insecure auth for the control UI"
echo "     Allows the control UI to connect to the gateway without HTTPS."
echo ""
read -p "Do you want to proceed with these changes? [y/N] " confirm < /dev/tty
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi
echo ""

# Check for existing token, reuse if present
EXISTING_TOKEN=$($CLI config get gateway.auth.token 2>/dev/null || echo "")
if [ -n "$EXISTING_TOKEN" ] && [ "$EXISTING_TOKEN" != "null" ] && [ "$EXISTING_TOKEN" != "undefined" ]; then
  TOKEN="$EXISTING_TOKEN"
  echo "Using existing auth token"
else
  TOKEN=$(openssl rand -hex 32)
  echo "Generated new auth token"
fi

# Configure gateway
$CLI config set gateway.bind lan
$CLI config set gateway.auth.mode token
$CLI config set gateway.auth.token "$TOKEN"
$CLI config set gateway.controlUi.allowInsecureAuth true

# Restart gateway to apply new settings
restart_gateway_docker_safe() {
  echo "Restarting gateway to apply new settings..."

  # 1) Try the official way first (will work on machines with systemd/launchd)
  if $CLI gateway restart >/dev/null 2>&1; then
    echo "Gateway restarted via service manager."
    return 0
  fi

  echo "Service restart unavailable (common in Docker). Trying in-process restart (SIGUSR1)..."

  # 2) Find PID by port (preferred, reliable)
  # Requires: lsof OR ss
  PID=""

  if command -v lsof >/dev/null 2>&1; then
    PID="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n1 || true)"
  elif command -v ss >/dev/null 2>&1; then
    # ss output can vary; this extracts pid=1234 from users:(("node",pid=1234,fd=...))
    PID="$(ss -lptn "sport = :$PORT" 2>/dev/null | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | head -n1 || true)"
  fi

  if [ -n "$PID" ]; then
    kill -USR1 "$PID" && echo "Sent SIGUSR1 to gateway PID $PID (in-process restart)." && return 0
    echo "SIGUSR1 failed; falling back to kill + relaunch..."
  else
    echo "Could not find gateway PID by port; falling back to process name search..."
  fi

  # 3) Fallback: kill + relaunch
  # This is a bit “brute force” but works in containers.
  pkill -f "openclaw gateway" 2>/dev/null || pkill -f "clawdbot gateway" 2>/dev/null || true

  # Relaunch in background. --force will free the port if something is still holding it.
  # NOTE: choose bind/auth/token/port explicitly so it comes up with the new settings.
  nohup openclaw gateway run \
    --force \
    --bind lan \
    --auth token \
    --token "$TOKEN" \
    --port "$PORT" \
    >/tmp/openclaw-gateway.log 2>&1 &

  echo "Gateway relaunched in background (log: /tmp/openclaw-gateway.log)."

# Get gateway port (default 18789)
PORT=$($CLI config get gateway.port 2>/dev/null || echo "18789")
if [ -z "$PORT" ] || [ "$PORT" = "null" ]; then
  PORT="18789"
fi

# Detect LAN IP addresses (all bindable IPs, excluding non-routable)
get_lan_ips() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: Get all IPs except loopback and link-local
    ifconfig | grep 'inet ' | awk '{print $2}' | \
      grep -v '^127\.' | grep -v '^169\.254\.'
  else
    # Linux: Get all IPs except loopback, link-local, and Docker default bridge
    ip -4 addr show 2>/dev/null | \
      grep -oP '(?<=inet\s)\d+(\.\d+){3}' | \
      grep -v '^127\.' | grep -v '^169\.254\.' | grep -v '^172\.17\.'
  fi
}

# Get IPs as JSON array
IPS=$(get_lan_ips | while read -r ip; do echo "\"$ip\""; done | paste -sd ',' -)
if [ -z "$IPS" ]; then
  echo "Error: No LAN IP addresses detected (ifconfig/ip command may be missing)."
  exit 1
fi

# Create JSON payload
JSON_PAYLOAD=$(cat <<EOF
{"type":"clawdbot-gateway","version":1,"ips":[$IPS],"port":$PORT,"token":"$TOKEN","protocol":"ws"}
EOF
)

echo "Configuration complete!"
echo ""
echo "Gateway Settings:"
echo "  Bind: lan (0.0.0.0)"
echo "  Port: $PORT"
echo "  Auth: token"
echo ""
echo "LAN IP Addresses:"
get_lan_ips | while read -r ip; do echo "  - $ip"; done
echo ""
echo "Token: $TOKEN"
echo ""

# Generate QR code to terminal
echo "QR Code (scan with your r1):"
echo ""
npx --yes qrcode "$JSON_PAYLOAD" --small < /dev/null

# Save QR code as PNG
echo ""
echo "Saving QR code to: $OUTPUT_FILE"
npx --yes qrcode "$JSON_PAYLOAD" -o "$OUTPUT_FILE" < /dev/null

echo ""
echo "Connect from another device using:"
for ip in $(get_lan_ips); do
  echo "  ws://$ip:$PORT"
done
echo ""
echo "With token: $TOKEN"
echo ""

# Wait for Rabbit R1 device and auto-approve
echo "Waiting for Rabbit R1 to connect (timeout: 5 minutes)..."
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  PENDING=$($CLI devices list --json 2>/dev/null | jq -r '.pending[] | select(.displayName == "Rabbit R1") | .requestId' 2>/dev/null | head -1)
  if [ -n "$PENDING" ]; then
    echo "Found Rabbit R1 device, approving..."
    $CLI devices approve "$PENDING"
    echo "Device approved successfully!"
    exit 0
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done
echo "Timeout: No Rabbit R1 device found within 5 minutes."