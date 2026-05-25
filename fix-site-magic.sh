#!/bin/sh
# Workarounds for UniFi Site Magic (wgsts1000) bugs on UDM. Idempotent.

# --- Bug 1: missing TCP MSS clamping ---
# UBIOS_FORWARD_TCPMSS has rules for wgclt1/wgsrv1 but not wgsts1000.
CHAIN="UBIOS_FORWARD_TCPMSS"
IFACE="wgsts1000"

if iptables -t mangle -L "$CHAIN" -n >/dev/null 2>&1 \
   && ip link show "$IFACE" >/dev/null 2>&1; then
    if ! iptables -t mangle -C "$CHAIN" -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null; then
        iptables -t mangle -A "$CHAIN" -o "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
        logger -t fix-site-magic "Added MSS clamp for outbound $IFACE"
    fi
    if ! iptables -t mangle -C "$CHAIN" -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null; then
        iptables -t mangle -A "$CHAIN" -i "$IFACE" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
        logger -t fix-site-magic "Added MSS clamp for inbound $IFACE"
    fi
fi

# --- Bug 2: empty upstream resolvers for per-route dnsmasq ---
# ubios-udapi-server creates /run/resolv.conf.d/wgsts1000 empty, so the
# per-route dnsmasq on port 20178 returns REFUSED for routed clients.
RESOLV="/run/resolv.conf.d/wgsts1000"
PIDFILE="/run/dnsmasq-wgsts1000.pid"

if [ -f "$RESOLV" ] && ! grep -q '^nameserver' "$RESOLV"; then
    {
        echo "nameserver 1.1.1.1"
        echo "nameserver 8.8.8.8"
    } >> "$RESOLV"
    [ -f "$PIDFILE" ] && kill -HUP "$(cat "$PIDFILE")"
    logger -t fix-site-magic "Added nameservers to $RESOLV"
fi
