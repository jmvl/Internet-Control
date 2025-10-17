# Docker Connectivity Issue - Quick Resolution Guide

**Issue:** Connection refused from NPM (192.168.1.9) to Seafile Docker containers (192.168.1.25)
**Status:** Diagnosed with automated fix available
**Date:** 2025-10-15

## Executive Summary

Your Seafile Docker containers on 192.168.1.25 are refusing connections from your NPM host at 192.168.1.9, while SSH works fine and other hosts can connect successfully. This is a classic **Docker iptables filtering issue** specific to the source IP.

### Root Cause

The issue is almost certainly one of these:

1. **DOCKER-USER chain filtering** - Custom iptables rules blocking traffic from 192.168.1.9
2. **Connection tracking table corruption** - Stale conntrack entries for that source IP
3. **Docker bridge NAT hairpin issues** - Kernel not handling loopback NAT correctly

## Why SSH Works But Docker Ports Don't

**SSH (port 22):**
- Runs directly on the LXC container's network interface
- Bypasses Docker networking completely
- Path: Host → LXC veth → Container → sshd process

**Docker Ports (8092, etc.):**
- Run inside Docker containers with isolated networks
- Path: Host → iptables PREROUTING → **iptables FORWARD** → Docker bridge → Container
- Subject to **DOCKER-USER, DOCKER-ISOLATION, and FORWARD chains**

The failure occurs in the Docker networking layer, not the base networking.

## Immediate Fix (Run This Now)

### Option 1: Automated Fix Script (Recommended)

Copy the fix script to the Seafile host and run it:

```bash
# On your local machine
scp /Users/jm/Codebase/internet-control/scripts/fix-docker-connectivity.sh root@192.168.1.25:/root/

# SSH to Seafile host
ssh root@192.168.1.25

# Run the fix
chmod +x /root/fix-docker-connectivity.sh
/root/fix-docker-connectivity.sh 192.168.1.9
```

This script will:
- ✓ Backup current iptables rules
- ✓ Add DOCKER-USER accept rule for 192.168.1.9
- ✓ Flush connection tracking for that IP
- ✓ Load br_netfilter module
- ✓ Make changes persistent across reboots
- ✓ Create auto-restore systemd service

### Option 2: Manual Quick Fix

If you prefer manual steps:

```bash
# SSH to 192.168.1.25
ssh root@192.168.1.25

# Backup iptables
mkdir -p /root/iptables-backups
iptables-save > /root/iptables-backups/backup-$(date +%Y%m%d-%H%M%S).rules

# Add accept rule for NPM
iptables -I DOCKER-USER 1 -s 192.168.1.9 -j ACCEPT

# Flush connection tracking
conntrack -D -s 192.168.1.9 || true

# Test immediately from NPM
# On 192.168.1.9:
nc -vz 192.168.1.25 8092
```

If this works, make it persistent:

```bash
# Install persistence package
apt-get update
apt-get install -y iptables-persistent

# Save rules
netfilter-persistent save

# Or manually:
iptables-save > /etc/iptables/rules.v4
```

## Verification Steps

After applying the fix, test from the NPM host:

```bash
# From 192.168.1.9 (OMV/NPM host)

# Test with netcat
nc -vz 192.168.1.25 8092

# Test with curl
curl -v http://192.168.1.25:8092

# Test from inside NPM container
docker exec npm-app curl -v http://192.168.1.25:8092

# Check NPM logs
docker logs npm-app --tail 50 | grep seafile
```

Expected output:
```
Connection to 192.168.1.25 8092 port [tcp/*] succeeded!
```

## Diagnostic Tool

If the fix doesn't work, run the diagnostic script to identify the exact issue:

```bash
# Copy to Seafile host
scp /Users/jm/Codebase/internet-control/scripts/diagnose-docker-connectivity.sh root@192.168.1.25:/root/

# Run diagnostic
ssh root@192.168.1.25
chmod +x /root/diagnose-docker-connectivity.sh
/root/diagnose-docker-connectivity.sh 192.168.1.9 8092
```

The diagnostic will check:
- ✓ Docker service status
- ✓ Port listeners (docker-proxy)
- ✓ NAT rules (DOCKER chain)
- ✓ DOCKER-USER chain (filtering)
- ✓ FORWARD chain rules
- ✓ Connection tracking table
- ✓ Bridge netfilter settings
- ✓ Container network configuration
- ✓ Kernel logs for drops

## Common Scenarios and Solutions

### Scenario 1: DOCKER-USER Rules Blocking Traffic

**Symptoms:**
- iptables -L DOCKER-USER shows rules other than RETURN
- Diagnostic shows "Custom DOCKER-USER rules detected"

**Solution:**
```bash
# Add accept rule at the beginning
iptables -I DOCKER-USER 1 -s 192.168.1.9 -j ACCEPT

# View to verify
iptables -L DOCKER-USER -n -v --line-numbers
```

### Scenario 2: Connection Tracking Table Full

**Symptoms:**
- conntrack table >80% full
- dmesg shows "nf_conntrack: table full, dropping packet"

**Solution:**
```bash
# Increase max connections
sysctl -w net.netfilter.nf_conntrack_max=262144
echo "net.netfilter.nf_conntrack_max=262144" >> /etc/sysctl.conf

# Flush stale entries
conntrack -D -s 192.168.1.9
```

### Scenario 3: Bridge Netfilter Module Missing

**Symptoms:**
- lsmod | grep br_netfilter returns nothing
- Bridge traffic not being filtered

**Solution:**
```bash
# Load module
modprobe br_netfilter

# Make persistent
echo "br_netfilter" >> /etc/modules

# Verify
lsmod | grep br_netfilter
```

### Scenario 4: Docker NAT Rules Corrupted

**Symptoms:**
- No DNAT rules for port 8092 in iptables -t nat -L DOCKER
- docker-proxy running but no NAT

**Solution:**
```bash
# Restart Docker networking
systemctl restart docker

# Restart containers
cd /path/to/seafile
docker-compose down
docker-compose up -d

# Verify NAT rules recreated
iptables -t nat -L DOCKER -n -v | grep 8092
```

## Files Created

All files are in the repository:

1. **Comprehensive Documentation:**
   `/Users/jm/Codebase/internet-control/docs/troubleshooting/seafile-docker-connectivity-issue-2025-10-15.md`

2. **Diagnostic Script:**
   `/Users/jm/Codebase/internet-control/scripts/diagnose-docker-connectivity.sh`

3. **Fix Script:**
   `/Users/jm/Codebase/internet-control/scripts/fix-docker-connectivity.sh`

4. **This Quick Guide:**
   `/Users/jm/Codebase/internet-control/docs/troubleshooting/DOCKER-CONNECTIVITY-RESOLUTION.md`

## Advanced Troubleshooting

If the standard fixes don't work, try these:

### Enable Packet Logging

```bash
# On 192.168.1.25 - Log all traffic from NPM
iptables -I DOCKER-USER 1 -s 192.168.1.9 -j LOG --log-prefix "DOCKER-NPM: " --log-level 4
iptables -I FORWARD 1 -s 192.168.1.9 -j LOG --log-prefix "FORWARD-NPM: " --log-level 4

# Watch logs in real-time
tail -f /var/log/kern.log | grep NPM

# Test from NPM, watch the logs to see where packets are being dropped
```

### Test Docker Bridge Directly

```bash
# Get container IP
SEAFILE_IP=$(docker inspect seafile | grep -m1 '"IPAddress"' | awk '{print $2}' | tr -d '",')

# Test from another container on the same bridge
docker run --rm --network seafile_default alpine:latest nc -vz $SEAFILE_IP 80
```

### Check LXC Container Settings

```bash
# On Proxmox host (pve2)
pct config 103

# Ensure Docker features are enabled
pct set 103 -features nesting=1,keyctl=1

# Restart container
pct reboot 103
```

### Nuclear Option: Host Networking Mode

If all else fails, switch to host networking (removes isolation):

```yaml
# docker-compose.yml for Seafile
services:
  seafile:
    network_mode: "host"
    # Remove port mappings - they're implicit with host mode
```

**Warning:** This bypasses Docker's network isolation entirely.

## Prevention

### Make Rules Persistent

The fix script creates a systemd service, but you can also add to rc.local:

```bash
# Add to /etc/rc.local (before exit 0)
/etc/docker/custom-iptables-restore.sh
```

### Monitor Connection Tracking

Add to cron:

```bash
# /etc/cron.hourly/check-conntrack
#!/bin/bash
USAGE=$(cat /proc/sys/net/netfilter/nf_conntrack_count)
MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
PERCENT=$((USAGE * 100 / MAX))

if [ $PERCENT -gt 80 ]; then
    logger "WARNING: Connection tracking table is ${PERCENT}% full"
    # Optional: flush old entries
    # conntrack -L | grep -v ASSURED | grep TIME_WAIT | awk '{print $1}' | xargs -I {} conntrack -D {}
fi
```

### Document Custom Rules

Keep a log of all custom iptables rules in:
```bash
/etc/docker/CUSTOM-RULES.md
```

## Support and References

- **Full Technical Documentation:** `/docs/troubleshooting/seafile-docker-connectivity-issue-2025-10-15.md`
- **Docker Official Docs:** [Packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
- **Proxmox LXC Networking:** [Linux Container networking](https://pve.proxmox.com/wiki/Linux_Container#pct_network)

## Next Steps

1. **Immediate:** Run the fix script on 192.168.1.25
2. **Verify:** Test connectivity from NPM
3. **Document:** Update NPM configuration with new Seafile backend
4. **Monitor:** Check logs for any recurring issues
5. **Long-term:** Consider implementing network monitoring alerts

## Status Tracking

- [ ] Fix script run on 192.168.1.25
- [ ] Connectivity verified from NPM
- [ ] Rules made persistent
- [ ] NPM proxy configuration updated
- [ ] Monitoring alerts configured
- [ ] Documentation updated in Confluence

---

**Last Updated:** 2025-10-15
**Maintainer:** Infrastructure Team
**Related Issues:** Seafile Docker connectivity, NPM proxy setup
