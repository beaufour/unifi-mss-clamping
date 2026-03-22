#!/bin/sh
# Fix missing MSS clamping for Site Magic (wgsts1000) tunnel.
# UniFi bug: UBIOS_FORWARD_TCPMSS has rules for wgclt1/wgsrv1 but not wgsts1000.
# This script is idempotent — safe to run repeatedly.

CHAIN="UBIOS_FORWARD_TCPMSS"
IFACE="wgsts1000"

# Exit if chain does not exist yet (network stack not ready)
iptables -t mangle -L "$CHAIN" -n >/dev/null 2>&1 || exit 0

# Exit if interface does not exist
ip link show "$IFACE" >/dev/null 2>&1 || exit 0

# Check if rules already present
if ! iptables -t mangle -C "$CHAIN" -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null; then
    iptables -t mangle -A "$CHAIN" -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    logger -t fix-mss "Added MSS clamp for outbound $IFACE"
fi

if ! iptables -t mangle -C "$CHAIN" -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null; then
    iptables -t mangle -A "$CHAIN" -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    logger -t fix-mss "Added MSS clamp for inbound $IFACE"
fi
