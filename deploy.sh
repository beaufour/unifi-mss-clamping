#!/bin/sh
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <hostname>"
    echo "  e.g. $0 udm"
    exit 1
fi

HOST="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Deploying to $HOST..."

# Copy the fix script
scp "$SCRIPT_DIR/fix-mss-clamping.sh" "$HOST:/data/fix-mss-clamping.sh"
ssh "$HOST" "chmod +x /data/fix-mss-clamping.sh"

# Install systemd service
scp "$SCRIPT_DIR/fix-mss-clamping.service" "$HOST:/etc/systemd/system/fix-mss-clamping.service"
ssh "$HOST" "systemctl daemon-reload && systemctl enable fix-mss-clamping.service"

# Install cron job
scp "$SCRIPT_DIR/fix-mss-clamping.cron" "$HOST:/etc/cron.d/fix-mss-clamping"

# Run it now
ssh "$HOST" "/data/fix-mss-clamping.sh"

echo "Done. Verifying:"
ssh "$HOST" "iptables -t mangle -L UBIOS_FORWARD_TCPMSS -v -n | grep wgsts"
