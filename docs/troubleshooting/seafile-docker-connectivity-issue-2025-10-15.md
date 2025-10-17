# Seafile Docker Connectivity Issue - Diagnosis and Resolution

**Date:** 2025-10-15
**Affected Hosts:**
- Source: 192.168.1.9 (OMV - NPM container)
- Destination: 192.168.1.25 (Proxmox PCT 103 - Seafile containers)

**Symptom:** Connection refused (errno 111) on all Docker-exposed ports from 192.168.1.9, while SSH (port 22) works fine.

## Problem Summary

### Working Connections
- ✅ SSH (port 22) from 192.168.1.9 to 192.168.1.25
- ✅ ICMP (ping) from 192.168.1.9 to 192.168.1.25
- ✅ All ports from other hosts (192.168.1.134, pve2) to 192.168.1.25

### Failing Connections
- ❌ Ports 80, 443, 3306, 8082, 8090, 8091, 8092 from 192.168.1.9 to 192.168.1.25

## Root Cause Analysis

Based on Docker networking best practices and the symptom pattern, this issue is characteristic of **Docker FORWARD chain filtering** or **connection tracking (conntrack) state issues** specific to the source IP 192.168.1.9.

### Why SSH Works But Docker Ports Don't

**SSH (port 22)** is a native service running directly on the LXC container's network stack, bypassing Docker's network filtering entirely.

**Docker ports** go through multiple network layers:
1. Host kernel receives packet on public interface
2. iptables PREROUTING chain (DNAT rules for port forwarding)
3. iptables FORWARD chain (Docker filtering)
4. Docker bridge network
5. docker-proxy or iptables DNAT to container

The failure point is likely in **step 3 or 4**, where Docker's iptables rules or bridge filtering are blocking packets from 192.168.1.9.

## Diagnostic Commands

Run these commands on **192.168.1.25** (Seafile host) to identify the exact blocking point:

### 1. Check Docker NAT Rules
```bash
# View all DNAT rules for port forwarding
iptables -t nat -L DOCKER -n -v

# Look for rules matching port 8092
iptables -t nat -L DOCKER -n -v | grep 8092
```

**Expected:** You should see DNAT rules like:
```
DNAT tcp -- * !br-xxxxx 0.0.0.0/0 0.0.0.0/0 tcp dpt:8092 to:172.x.x.x:80
```

### 2. Check FORWARD Chain Rules
```bash
# Check if packets from 192.168.1.9 are being dropped
iptables -L FORWARD -n -v | grep -E "DROP|REJECT"

# Check Docker FORWARD rules
iptables -L DOCKER-ISOLATION-STAGE-1 -n -v
iptables -L DOCKER-ISOLATION-STAGE-2 -n -v
```

### 3. Check DOCKER-USER Chain (Critical)
```bash
# This chain allows custom filtering BEFORE Docker's rules
iptables -L DOCKER-USER -n -v
```

**Key Finding:** If there are DROP rules in DOCKER-USER matching source 192.168.1.9, this is your culprit.

### 4. Check Connection Tracking
```bash
# View active connections from 192.168.1.9
conntrack -L -s 192.168.1.9 | grep 8092

# Check for conntrack table corruption
cat /proc/sys/net/netfilter/nf_conntrack_count
cat /proc/sys/net/netfilter/nf_conntrack_max
```

### 5. Test Docker Bridge Directly
```bash
# Get the Docker bridge IP for Seafile container
docker inspect seafile | grep -A 5 '"Networks"' | grep IPAddress

# Try connecting from the bridge network (inside another container)
docker run --rm --network seafile_default alpine:latest nc -vz <seafile_container_ip> 80
```

### 6. Check for br-netfilter Module Issues
```bash
# Verify br-netfilter module is loaded
lsmod | grep br_netfilter

# Check sysctl settings that affect bridge filtering
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
```

## Most Likely Root Causes

### 1. **DOCKER-USER Chain Source IP Filtering** (Highest Probability)
Docker provides the `DOCKER-USER` chain specifically for administrators to add custom filtering rules. If someone previously added rules to block specific IPs or networks, this would explain the selective blocking.

**Diagnostic:**
```bash
iptables -L DOCKER-USER -n -v --line-numbers
```

**Solution:**
```bash
# If you see DROP rules, either delete them or add an ACCEPT rule for 192.168.1.9
iptables -I DOCKER-USER -s 192.168.1.9 -j ACCEPT

# Make persistent (for Debian/Ubuntu systems)
apt-get install iptables-persistent
netfilter-persistent save
```

### 2. **Connection Tracking Table Corruption**
The kernel's connection tracking (conntrack) table may have stale or corrupted entries for connections from 192.168.1.9, causing new connection attempts to be rejected.

**Diagnostic:**
```bash
# Check conntrack entries
conntrack -L -s 192.168.1.9

# Check for table fullness
dmesg | grep conntrack
```

**Solution:**
```bash
# Flush conntrack entries for this source IP
conntrack -D -s 192.168.1.9

# Or flush all (temporarily disruptive)
conntrack -F

# Increase conntrack max if needed
sysctl -w net.netfilter.nf_conntrack_max=262144
echo "net.netfilter.nf_conntrack_max=262144" >> /etc/sysctl.conf
```

### 3. **Docker Bridge NAT Hairpin Issues**
If both NPM (192.168.1.9) and Seafile (192.168.1.25) are trying to reach each other through published ports, there may be hairpin NAT issues where the kernel is not properly handling the loopback scenario.

**Diagnostic:**
```bash
# Check if hairpin mode is enabled on the Docker bridge
brctl show
brctl showstp docker0 | grep -i hairpin

# For newer systems using bridge tool
bridge link show
```

**Solution:**
```bash
# Enable hairpin mode on Docker bridge ports
# Find the veth interface for the container
docker inspect seafile | grep -i veth

# Enable hairpin mode
brctl hairpin docker0 veth12345 on

# Or configure Docker daemon to enable hairpin by default
cat > /etc/docker/daemon.json <<EOF
{
  "bridge": "docker0",
  "hairpin-mode": true
}
EOF

systemctl restart docker
```

### 4. **LXC Container Networking Restrictions**
Proxmox unprivileged LXC containers have specific network filtering that might interfere with Docker's iptables rules, especially for packets crossing bridges.

**Diagnostic:**
```bash
# Check if the LXC container has network isolation enabled
pct config 103 | grep -i net

# On the Proxmox host (pve2), check firewall settings
pct exec 103 -- iptables -L -n -v
```

**Solution (run on Proxmox host):**
```bash
# Ensure LXC container has proper network features enabled
pct set 103 -features nesting=1,keyctl=1

# Check if LXC is applying network filtering
ls -la /proc/$(pct pid 103)/net/

# Consider enabling Docker in LXC with proper features
# Edit /etc/pve/lxc/103.conf and add:
# lxc.apparmor.profile: unconfined
# lxc.cgroup2.devices.allow: a
# lxc.cap.drop:
# lxc.mount.auto: proc:rw sys:rw cgroup:rw
```

## Recommended Solution Steps

### Step 1: Quick Test - Add DOCKER-USER Accept Rule
This is the safest first step that won't disrupt existing connections:

```bash
# On 192.168.1.25 (Seafile host)
iptables -I DOCKER-USER 1 -s 192.168.1.9 -j ACCEPT
iptables -L DOCKER-USER -n -v

# Test connection from NPM immediately
# From 192.168.1.9:
docker exec npm-app nc -vz 192.168.1.25 8092
```

**If this works:** The issue is confirmed to be DOCKER-USER filtering. Make the rule persistent.

### Step 2: Flush Connection Tracking
```bash
# On 192.168.1.25
conntrack -D -s 192.168.1.9

# Test again from 192.168.1.9
```

### Step 3: Restart Docker Networking
```bash
# On 192.168.1.25
systemctl restart docker

# Restart Seafile containers
cd /path/to/seafile/docker-compose
docker-compose down
docker-compose up -d
```

### Step 4: Enable Detailed Logging
```bash
# On 192.168.1.25 - Log dropped packets to identify the blocking chain
iptables -I DOCKER-USER 1 -s 192.168.1.9 -j LOG --log-prefix "DOCKER-USER-NPM: " --log-level 4
iptables -I FORWARD 1 -s 192.168.1.9 -j LOG --log-prefix "FORWARD-NPM: " --log-level 4

# Monitor logs in real-time
tail -f /var/log/kern.log | grep NPM

# Test connection from 192.168.1.9, watch the logs
```

### Step 5: Alternative - Use Host Networking Mode
If iptables rules prove too complex to debug, consider switching Seafile to host networking mode:

```yaml
# docker-compose.yml modification
services:
  seafile:
    network_mode: "host"
    # Remove port mappings - they're implicit with host mode
```

**Warning:** Host networking bypasses Docker's network isolation entirely. Only use if necessary.

## Prevention and Long-Term Fix

### Make iptables Rules Persistent
```bash
# Install persistence package
apt-get update && apt-get install -y iptables-persistent

# Save current rules
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

# Or use netfilter-persistent
netfilter-persistent save
```

### Document Custom Rules
Create `/etc/docker/custom-iptables.sh`:
```bash
#!/bin/bash
# Custom iptables rules for Docker networking
# Applied before Docker's automatic rules

# Allow NPM (192.168.1.9) to access all Docker containers
iptables -I DOCKER-USER -s 192.168.1.9 -j ACCEPT

# Allow established connections
iptables -I DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT

# Log the script execution
logger "Custom Docker iptables rules applied"
```

Make executable and run at boot:
```bash
chmod +x /etc/docker/custom-iptables.sh

# Add to systemd service
cat > /etc/systemd/system/docker-custom-iptables.service <<EOF
[Unit]
Description=Apply Custom Docker iptables Rules
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/etc/docker/custom-iptables.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable docker-custom-iptables.service
systemctl start docker-custom-iptables.service
```

## Verification Tests

After applying fixes, verify full connectivity:

```bash
# From 192.168.1.9 (NPM host)
nc -vz 192.168.1.25 8092
curl -v http://192.168.1.25:8092
docker exec npm-app curl -v http://192.168.1.25:8092

# From other hosts (should still work)
nc -vz 192.168.1.25 8092  # From 192.168.1.134
ssh root@pve2 "nc -vz 192.168.1.25 8092"

# Check NPM logs for successful proxy
docker logs npm-app | grep seafile
```

## Technical Explanation: Why SSH Works

**SSH Service:**
- Runs directly on LXC container's network interface (eth0)
- Listens on 0.0.0.0:22 in the container's root network namespace
- Packets go: Host eth0 → LXC veth → Container eth0 → sshd process
- **Bypasses Docker entirely** - no bridge, no NAT, no FORWARD chain

**Docker Ports:**
- Run inside Docker containers with isolated network namespaces
- Packets go: Host eth0 → PREROUTING (DNAT) → FORWARD → Docker bridge → veth → Container eth0 → docker-proxy/container process
- **Subject to all Docker iptables chains:** DOCKER-USER, FORWARD, DOCKER-ISOLATION, etc.

This is why SSH works while Docker ports fail - they traverse completely different networking paths through the kernel.

## References

- Docker Official Docs: [Packet filtering and firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
- Docker Network Bridge Driver: [Bridge networking](https://docs.docker.com/engine/network/drivers/bridge/)
- Linux Bridge Netfilter: [br_netfilter module](https://ebtables.netfilter.org/documentation/bridge-nf.html)
- Proxmox LXC Networking: [Linux Container networking](https://pve.proxmox.com/wiki/Linux_Container#pct_network)

## Next Steps

1. **Immediate:** Add DOCKER-USER accept rule and test
2. **Short-term:** Flush conntrack and restart Docker
3. **Long-term:** Implement persistent iptables rules with documentation
4. **Monitoring:** Set up alerting for similar connectivity issues

## Status

- **Issue Identified:** 2025-10-15
- **Diagnostic Phase:** In Progress
- **Resolution:** Pending remote access to 192.168.1.25
- **Owner:** Infrastructure Team
