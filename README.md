# UniFi Site Magic MSS Clamping Fix

Workaround for a UniFi firmware bug where TCP MSS clamping rules are missing for Site Magic (SD-WAN) tunnel interfaces (`wgsts1000`).

## The Problem

When using a Policy-Based Route (Traffic Route) to send VLAN traffic through a Site Magic SD-WAN tunnel, UniFi automatically adds TCP MSS clamping rules for `wgclt1` and `wgsrv1` interfaces, but **not** for `wgsts1000` (Site Magic). This causes:

- Large TCP packets to exceed the tunnel MTU (1420), resulting in fragmentation failures
- Degraded performance for web browsing and downloads
- Speed tests (e.g., fast.com) failing entirely

## The Fix

A small idempotent script that adds the missing MSS clamping rules to the `UBIOS_FORWARD_TCPMSS` mangle chain. It checks before adding and exits cleanly if the chain or interface doesn't exist yet.

## Files

| File | Install location | Purpose |
|---|---|---|
| `fix-mss-clamping.sh` | `/data/fix-mss-clamping.sh` | The fix script (idempotent) |
| `fix-mss-clamping.service` | `/etc/systemd/system/fix-mss-clamping.service` | Runs at boot after network is up |
| `fix-mss-clamping.cron` | `/etc/cron.d/fix-mss-clamping` | Runs every 5 min to catch reprovisioning |

## Installation

Install on **both** Site Magic endpoints (both gateways in the SD-WAN mesh).

```bash
# Copy the script
cp fix-mss-clamping.sh /data/fix-mss-clamping.sh
chmod +x /data/fix-mss-clamping.sh

# Install the systemd service (runs at boot)
cp fix-mss-clamping.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable fix-mss-clamping.service

# Install the cron job (catches reprovisioning)
cp fix-mss-clamping.cron /etc/cron.d/fix-mss-clamping

# Run it now
/data/fix-mss-clamping.sh
```

## Persistence

On UniFi OS 5.x, the root filesystem is an overlayfs with a persistent read-write upper layer (`/mnt/.rwfs/data`). This means:

- `/data/` — persists across reboots and firmware upgrades
- `/etc/systemd/system/` — persists (overlayfs upper layer)
- `/etc/cron.d/` — persists (overlayfs upper layer)

## Why both systemd and cron?

- **systemd service**: Handles boot (runs after `network-online.target` with retry on failure)
- **cron job**: Handles reprovisioning — when you change network settings in the UniFi UI, the gateway rebuilds all iptables chains, wiping custom rules. The cron restores them within 5 minutes.

## Tested on

- UniFi Dream Machine (UDM) — firmware 5.0.16
- UniFi Dream Router 7 (UDR7) — firmware 5.0.16

## Related bug

There is a secondary bug where the PBR-specific dnsmasq instance (`dnsmasq-wgsts1000`) has no upstream DNS servers configured, causing DNS to fail for all devices on the PBR'd VLAN. The workaround is to set custom DNS servers (e.g., 1.1.1.1, 8.8.8.8) in the VLAN's DHCP settings via the UniFi UI.
