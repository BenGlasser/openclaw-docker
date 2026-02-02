#!/bin/bash
# Configure OpenClaw Gateway for LAN binding with token auth

TOKEN=$(openclaw config get gateway.auth.token 2>/dev/null || echo "")

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