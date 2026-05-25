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

# Remove old fix-mss-clamping.* if present (renamed to fix-site-magic.*)
ssh "$HOST" '
    if [ -f /etc/systemd/system/fix-mss-clamping.service ]; then
        systemctl disable fix-mss-clamping.service 2>/dev/null || true
        rm -f /etc/systemd/system/fix-mss-clamping.service \
              /etc/cron.d/fix-mss-clamping \
              /data/fix-mss-clamping.sh
    fi
'

# Copy the fix script
scp "$SCRIPT_DIR/fix-site-magic.sh" "$HOST:/data/fix-site-magic.sh"
ssh "$HOST" "chmod +x /data/fix-site-magic.sh"

# Install systemd service
scp "$SCRIPT_DIR/fix-site-magic.service" "$HOST:/etc/systemd/system/fix-site-magic.service"
ssh "$HOST" "systemctl daemon-reload && systemctl enable fix-site-magic.service"

# Install cron job
scp "$SCRIPT_DIR/fix-site-magic.cron" "$HOST:/etc/cron.d/fix-site-magic"

# Run it now
ssh "$HOST" "/data/fix-site-magic.sh"

echo "Done. Verifying:"
ssh "$HOST" "
    echo '--- MSS clamp rules ---'
    iptables -t mangle -S UBIOS_FORWARD_TCPMSS | grep wgsts || echo '(none yet — interface may not be up)'
    echo '--- per-route resolver ---'
    cat /run/resolv.conf.d/wgsts1000 2>/dev/null || echo '(no resolver file yet)'
"
