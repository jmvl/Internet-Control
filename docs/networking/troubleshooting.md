# VLAN Management Interface Isolation - Troubleshooting Guide

## Overview

This troubleshooting guide provides systematic diagnostic procedures, common issue resolution, and emergency recovery methods for VLAN-based management interface isolation. It covers both routine operational issues and critical emergency scenarios.

## Quick Diagnostic Commands

### Essential Network Diagnostics

```bash
#!/bin/bash
# quick-vlan-diagnostics.sh - Rapid VLAN infrastructure assessment

echo "=== VLAN Infrastructure Quick Diagnostics ==="

# Test VLAN gateway connectivity
echo "Testing VLAN Gateways:"
for vlan in 1 10 100 20; do
    if [[ $vlan == 1 ]]; then
        gateway="192.168.1.3"
        desc="Legacy"
    else
        gateway="192.168.$vlan.1"
        desc="VLAN $vlan"
    fi

    if ping -c 2 -W 3 $gateway >/dev/null 2>&1; then
        echo "✓ $desc Gateway ($gateway): REACHABLE"
    else
        echo "✗ $desc Gateway ($gateway): UNREACHABLE"
    fi
done

# Test DNS resolution from current host
echo -e "\nTesting DNS Resolution:"
if nslookup google.com 192.168.100.5 >/dev/null 2>&1; then
    echo "✓ Pi-hole DNS (192.168.100.5): WORKING"
else
    echo "✗ Pi-hole DNS (192.168.100.5): FAILED"
fi

# Test management interface accessibility
echo -e "\nTesting Management Interfaces:"
mgmt_services=(
    "192.168.100.3:443:OPNsense"
    "192.168.100.10:8006:Proxmox"
    "192.168.100.5:80:Pi-hole"
    "192.168.100.9:80:OMV"
)

for service in "${mgmt_services[@]}"; do
    IFS=':' read -r ip port name <<< "$service"
    if timeout 3 nc -z $ip $port 2>/dev/null; then
        echo "✓ $name ($ip:$port): ACCESSIBLE"
    else
        echo "✗ $name ($ip:$port): INACCESSIBLE"
    fi
done

echo -e "\n=== Diagnostic Complete ==="
```

### VLAN Configuration Verification

```bash
#!/bin/bash
# vlan-config-check.sh - Verify VLAN configuration across infrastructure

echo "=== VLAN Configuration Verification ==="

# Check Proxmox bridge configuration
echo "Proxmox Bridge Configuration:"
if brctl show | grep -q vmbr0; then
    echo "✓ vmbr0 bridge exists"
    if bridge vlan show | grep -q "vmbr0"; then
        echo "✓ VLAN awareness enabled"
    else
        echo "✗ VLAN awareness not enabled"
    fi
else
    echo "✗ vmbr0 bridge missing"
fi

# Check OPNsense VLAN interfaces (requires SSH access)
echo -e "\nOPNsense VLAN Interfaces:"
if ssh root@192.168.100.3 'ifconfig | grep vtnet0' 2>/dev/null; then
    echo "✓ OPNsense VLAN interfaces detected"
else
    echo "✗ Cannot verify OPNsense VLAN interfaces"
fi

# Check OpenWrt VLAN configuration
echo -e "\nOpenWrt VLAN Configuration:"
if ssh root@192.168.100.2 'ip addr show | grep eth0' 2>/dev/null; then
    echo "✓ OpenWrt VLAN interfaces detected"
else
    echo "✗ Cannot verify OpenWrt VLAN interfaces"
fi

echo -e "\n=== Configuration Check Complete ==="
```

## Common Issues and Solutions

### Issue Category 1: VLAN Connectivity Problems

#### Problem: Cannot Access Management Interfaces
**Symptoms:**
- Management web interfaces timeout or refuse connections
- SSH connections to infrastructure hosts fail
- DNS resolution works but admin panels don't load

**Diagnostic Steps:**
```bash
# 1. Verify you're on the correct VLAN
ip addr show | grep -E "192\.168\.(100|10|20)\."

# 2. Test VLAN gateway connectivity
ping 192.168.100.1  # Management VLAN gateway

# 3. Check firewall rules are allowing traffic
# From OPNsense web interface: Firewall → Log Files → Live View

# 4. Verify services are running
ssh root@192.168.100.3 'systemctl status nginx'  # OPNsense web service
ssh root@192.168.100.10 'systemctl status pveproxy'  # Proxmox web service
```

**Resolution:**
```bash
# Solution 1: Verify network interface configuration
# Check if management VLAN interface exists
ip link show | grep "\.100"

# If missing, add management VLAN interface
sudo ip link add link eth0 name eth0.100 type vlan id 100
sudo ip addr add 192.168.100.100/24 dev eth0.100
sudo ip link set eth0.100 up
sudo ip route add default via 192.168.100.1

# Solution 2: Check firewall rules on OPNsense
# Navigate to Firewall → Rules → Management VLAN
# Ensure pass rules exist for management traffic

# Solution 3: Restart network services
sudo systemctl restart networking  # On Proxmox host
ssh root@192.168.100.3 'service netif restart'  # On OPNsense
```

#### Problem: User Services Inaccessible from User VLAN
**Symptoms:**
- Cannot access Immich, n8n, file shares from user devices
- Error messages about connection refused or timeouts
- DNS works but application services don't load

**Diagnostic Steps:**
```bash
# 1. Verify you're in the User VLAN
ip route show | grep "192.168.10"

# 2. Test service connectivity
nc -zv 192.168.10.21 2283  # Immich
nc -zv 192.168.10.22 5678  # n8n
nc -zv 192.168.10.9 445    # SMB shares

# 3. Check service status on containers
ssh root@192.168.100.20 'docker ps | grep immich'
ssh root@192.168.100.20 'docker ps | grep n8n'
```

**Resolution:**
```bash
# Solution 1: Restart user services
ssh root@192.168.100.20 'docker-compose -f /opt/services/docker-compose.yml restart'

# Solution 2: Check firewall allows user service traffic
# OPNsense → Firewall → Rules → User VLAN
# Verify pass rules for ports 2283, 5678, 445, 2049

# Solution 3: Verify DHCP is assigning correct VLAN addresses
# Check device IP is in 192.168.10.x range
# If not, renew DHCP lease or check VLAN assignment
```

### Issue Category 2: DNS Resolution Problems

#### Problem: DNS Resolution Fails Across VLANs
**Symptoms:**
- Cannot resolve domain names from any VLAN
- Pi-hole web interface shows no queries
- Internet connectivity fails due to DNS issues

**Diagnostic Steps:**
```bash
# 1. Test Pi-hole directly
nslookup google.com 192.168.100.5
dig @192.168.100.5 google.com

# 2. Check Pi-hole service status
ssh root@192.168.100.5 'systemctl status pihole-FTL'
ssh root@192.168.100.5 'pihole status'

# 3. Verify DNS server configuration in DHCP
# OPNsense → Services → DHCP Server → [VLAN] → DNS Servers
```

**Resolution:**
```bash
# Solution 1: Restart Pi-hole services
ssh root@192.168.100.5 'pihole restartdns'
ssh root@192.168.100.5 'systemctl restart pihole-FTL'

# Solution 2: Check Pi-hole VLAN interface configuration
ssh root@192.168.100.5 'ip addr show | grep 192.168.100.5'

# If interface missing, add it:
ssh root@192.168.100.5 << 'EOF'
ip link add link eth0 name eth0.100 type vlan id 100
ip addr add 192.168.100.5/24 dev eth0.100
ip link set eth0.100 up
systemctl restart pihole-FTL
EOF

# Solution 3: Update DHCP DNS server settings
# OPNsense web interface → Services → DHCP Server
# Set DNS servers to 192.168.100.5, 1.1.1.1
```

#### Problem: DNS Works But Web Browsing Fails
**Symptoms:**
- DNS resolution successful (nslookup works)
- Web browsers can't load pages
- Some applications work, others don't

**Diagnostic Steps:**
```bash
# 1. Test DNS and HTTP connectivity separately
nslookup google.com          # Should work
curl -I http://google.com    # May fail

# 2. Check if it's a routing issue
traceroute 8.8.8.8

# 3. Verify firewall rules allow HTTP/HTTPS
# OPNsense → Firewall → Rules → [VLAN] → Check outbound rules
```

**Resolution:**
```bash
# Solution 1: Check outbound firewall rules
# Ensure rules allow ports 80, 443 to internet destinations
# OPNsense → Firewall → Rules → [VLAN] → Add pass rule for HTTP/HTTPS

# Solution 2: Verify gateway configuration
ip route show default  # Should show correct VLAN gateway

# Solution 3: Check for transparent proxy or content filtering
# Disable content filtering temporarily to test
```

### Issue Category 3: Security Access Problems

#### Problem: Blocked from Management Interfaces Despite Correct VLAN
**Symptoms:**
- Connected to Management VLAN but still can't access admin panels
- Connections immediately rejected or dropped
- SSH connections fail with "connection refused"

**Diagnostic Steps:**
```bash
# 1. Verify IP address and VLAN membership
ip addr show | grep -A 2 -B 2 "192.168.100"

# 2. Check firewall logs for blocked connections
# OPNsense → Firewall → Log Files → Live View
# Look for blocked connections from your IP

# 3. Test with telnet to specific ports
telnet 192.168.100.3 443  # Should connect if service is running
```

**Resolution:**
```bash
# Solution 1: Check firewall rule order
# Management VLAN rules should be at top of rule list
# OPNsense → Firewall → Rules → Management VLAN

# Solution 2: Verify source IP is in management range
# Rules should allow from 192.168.100.0/24
# Check your actual IP: ip addr show

# Solution 3: Temporarily disable firewall for testing
# OPNsense → Firewall → Settings → Advanced
# ONLY for troubleshooting - re-enable immediately after
```

#### Problem: Can Access Services That Should Be Blocked
**Symptoms:**
- User VLAN devices can access management interfaces
- IoT devices can access user services
- Security policies not being enforced

**Diagnostic Steps:**
```bash
# 1. Check current VLAN assignment
ip route show | grep default  # Shows which gateway you're using

# 2. Test blocked services from user device
# These should FAIL if security is working:
curl -I https://192.168.100.3    # OPNsense admin from user VLAN
ssh root@192.168.100.10          # Proxmox SSH from user VLAN

# 3. Review firewall rules and order
# OPNsense → Firewall → Rules → [VLAN]
```

**Resolution:**
```bash
# Solution 1: Check firewall rule order
# Block rules must come BEFORE allow rules
# Reorder rules if necessary

# Solution 2: Verify rule specificity
# Ensure block rules are specific enough
# Example: Block source 192.168.10.0/24 to dest 192.168.100.0/24 ports 22,443,8006

# Solution 3: Enable logging on security rules
# Add logging to block rules to verify they're being hit
# Monitor logs to confirm rule effectiveness
```

### Issue Category 4: Performance and Traffic Issues

#### Problem: Slow Inter-VLAN Communication
**Symptoms:**
- DNS queries take several seconds
- File transfers between VLANs are very slow
- Web applications load slowly across VLANs

**Diagnostic Steps:**
```bash
# 1. Test latency between VLANs
ping -c 10 192.168.100.5  # From user VLAN to Pi-hole
ping -c 10 192.168.10.9   # From management VLAN to file server

# 2. Check traffic shaping rules
# OPNsense → Firewall → Traffic Shaper → Queues

# 3. Monitor network utilization
# OPNsense → Reporting → Netflow or Health → Traffic
```

**Resolution:**
```bash
# Solution 1: Check traffic shaping configuration
# Ensure VLAN-to-VLAN traffic isn't overly restricted
# Adjust bandwidth allocations if necessary

# Solution 2: Verify bridge and interface speeds
# Check if VLAN tagging is causing performance issues
ethtool eth0.100  # Check interface speed and duplex

# Solution 3: Optimize firewall rules
# Ensure efficient rule order (most common traffic first)
# Consider creating aliases for frequently accessed services
```

#### Problem: Three-Tier Traffic Control Not Working
**Symptoms:**
- Bandwidth limits not being enforced
- WiFi throttling scripts don't affect VLAN traffic
- No QoS differentiation between VLANs

**Diagnostic Steps:**
```bash
# 1. Check OpenWrt SQM status
ssh root@192.168.100.2 'tc -s qdisc show | grep -A 5 cake'

# 2. Verify OPNsense traffic shaper status
# OPNsense → Firewall → Traffic Shaper → Statistics

# 3. Test bandwidth from different VLANs
iperf3 -c 192.168.10.9 -t 30  # From different VLANs
```

**Resolution:**
```bash
# Solution 1: Reconfigure OpenWrt SQM for VLAN awareness
ssh root@192.168.100.2 << 'EOF'
# Update SQM configuration to handle VLAN tagged traffic
uci set sqm.eth0_100.interface='eth0.100'
uci set sqm.eth0_10.interface='eth0.10'
uci commit sqm
/etc/init.d/sqm restart
EOF

# Solution 2: Configure OPNsense per-VLAN traffic shaping
# Create separate traffic shaper queues for each VLAN
# Apply appropriate bandwidth limits per VLAN

# Solution 3: Verify Pi-hole is handling all VLAN DNS
# Ensure all VLANs are configured to use Pi-hole as primary DNS
# Check Pi-hole query logs for traffic from all VLANs
```

## Emergency Recovery Procedures

### Emergency Access Methods

#### Method 1: Physical Console Access
```bash
# If network access is completely lost:
# 1. Connect monitor and keyboard to Proxmox host
# 2. Log in as root locally
# 3. Check network interface status:
ip addr show
brctl show

# 4. Restore basic connectivity:
ifdown vmbr0 && ifup vmbr0
systemctl restart networking

# 5. Access OPNsense VM console:
qm terminal 133
```

#### Method 2: Backup WiFi Network
```bash
# Connect to hidden backup WiFi network:
# SSID: Znutar_BACKUP
# Password: [documented in secure location]
# IP Range: 192.168.1.100-120

# This network bypasses VLAN isolation for emergency access
# Should provide basic internet and management access
```

#### Method 3: Out-of-Band Management
```bash
# If available, use:
# - IPMI/iLO access to Proxmox host
# - VPN connection to management network
# - Secondary internet connection for remote access
```

### Critical Service Recovery

#### Complete Network Failure Recovery
```bash
#!/bin/bash
# emergency-network-recovery.sh

echo "EMERGENCY NETWORK RECOVERY PROCEDURE"
echo "This will attempt to restore basic network connectivity"

# 1. Restore basic Proxmox networking
echo "Restoring Proxmox network configuration..."
cp /etc/network/interfaces.backup /etc/network/interfaces
systemctl restart networking
sleep 10

# 2. Check bridge status
if brctl show | grep -q vmbr0; then
    echo "✓ Basic bridge restored"
else
    echo "✗ Bridge restoration failed - manual intervention required"
    exit 1
fi

# 3. Start OPNsense VM if stopped
echo "Starting OPNsense VM..."
qm start 133
sleep 30

# 4. Test basic connectivity
if ping -c 3 192.168.1.3 >/dev/null 2>&1; then
    echo "✓ Basic connectivity restored"
    echo "Access OPNsense at: https://192.168.1.3"
else
    echo "✗ Connectivity not restored - check VM status"
    qm status 133
fi
```

#### Service-Specific Recovery

**Pi-hole DNS Recovery:**
```bash
#!/bin/bash
# pi-hole-recovery.sh

echo "Recovering Pi-hole DNS service..."

# 1. Check Pi-hole host connectivity
if ! ping -c 3 192.168.1.5 >/dev/null 2>&1; then
    echo "Pi-hole host unreachable - check physical connectivity"
    exit 1
fi

# 2. Restart Pi-hole services
ssh root@192.168.1.5 << 'EOF'
systemctl stop pihole-FTL
systemctl start pihole-FTL
pihole restartdns
EOF

# 3. Update DHCP servers to use Pi-hole
# Temporarily configure clients to use 1.1.1.1 if Pi-hole unavailable

# 4. Test DNS resolution
if nslookup google.com 192.168.1.5 >/dev/null 2>&1; then
    echo "✓ Pi-hole DNS service recovered"
else
    echo "✗ Pi-hole DNS service still failing"
fi
```

**User Services Recovery:**
```bash
#!/bin/bash
# user-services-recovery.sh

echo "Recovering user services..."

# 1. Check Docker host status
if ping -c 3 192.168.1.20 >/dev/null 2>&1; then
    echo "✓ Docker host reachable"
else
    echo "✗ Docker host unreachable"
    exit 1
fi

# 2. Restart container services
ssh root@192.168.1.20 << 'EOF'
# Stop all containers gracefully
docker-compose -f /opt/services/docker-compose.yml down

# Start core services first
docker-compose -f /opt/services/docker-compose.yml up -d postgres redis

# Wait for database to be ready
sleep 30

# Start application services
docker-compose -f /opt/services/docker-compose.yml up -d

# Check service status
docker ps --format "table {{.Names}}\t{{.Status}}"
EOF

echo "User services recovery attempted"
```

### Complete VLAN Rollback

```bash
#!/bin/bash
# complete-vlan-rollback.sh - Emergency rollback to pre-VLAN state

echo "COMPLETE VLAN ROLLBACK PROCEDURE"
echo "This will remove all VLAN configuration and restore legacy networking"
echo "WARNING: This will cause temporary network outage"

read -p "Are you sure you want to proceed? (type 'ROLLBACK' to confirm): " confirm
if [[ $confirm != "ROLLBACK" ]]; then
    echo "Rollback cancelled"
    exit 1
fi

# 1. Restore Proxmox network configuration
echo "Restoring Proxmox configuration..."
cp /etc/network/interfaces.backup /etc/network/interfaces
systemctl restart networking

# 2. Rollback OPNsense VM to pre-VLAN snapshot
echo "Rolling back OPNsense VM..."
latest_snapshot=$(pvesh get /nodes/pve2/qemu/133/snapshot | grep pre-vlan | tail -1 | awk '{print $1}')
if [[ -n $latest_snapshot ]]; then
    pvesh create /nodes/pve2/qemu/133/snapshot/$latest_snapshot/rollback
    echo "OPNsense rolled back to: $latest_snapshot"
else
    echo "ERROR: No pre-VLAN snapshot found!"
fi

# 3. Restore OpenWrt configuration
echo "Restoring OpenWrt configuration..."
if [[ -f ./backup/openwrt/network ]]; then
    scp ./backup/openwrt/network root@192.168.1.2:/etc/config/
    ssh root@192.168.1.2 '/etc/init.d/network restart'
    echo "OpenWrt configuration restored"
else
    echo "ERROR: OpenWrt backup not found!"
fi

# 4. Reset service IP addresses to legacy addresses
echo "Resetting service IP addresses..."
# This would require manual reconfiguration of each service

# 5. Verify legacy connectivity
echo "Verifying legacy network connectivity..."
sleep 60  # Wait for services to stabilize

if ping -c 5 192.168.1.3 >/dev/null 2>&1; then
    echo "✓ VLAN rollback successful"
    echo "Legacy network restored - OPNsense accessible at 192.168.1.3"
else
    echo "✗ VLAN rollback failed - manual intervention required"
    echo "Connect to physical console for further troubleshooting"
fi
```

## Monitoring and Alerting

### Automated Health Checks

```bash
#!/bin/bash
# vlan-health-monitor.sh - Continuous VLAN infrastructure monitoring

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Check VLAN gateway connectivity
    gateways=("192.168.1.3:Legacy" "192.168.10.1:User" "192.168.100.1:Management" "192.168.20.1:IoT")
    for gateway_info in "${gateways[@]}"; do
        IFS=':' read -r gateway name <<< "$gateway_info"
        if ! ping -c 1 -W 3 $gateway >/dev/null 2>&1; then
            echo "$timestamp ERROR: $name VLAN gateway ($gateway) unreachable"
            # Send alert (email, webhook, etc.)
        fi
    done

    # Check critical services
    services=("192.168.100.3:443:OPNsense" "192.168.100.5:53:Pi-hole" "192.168.100.10:8006:Proxmox")
    for service_info in "${services[@]}"; do
        IFS=':' read -r ip port name <<< "$service_info"
        if ! timeout 5 nc -z $ip $port 2>/dev/null; then
            echo "$timestamp ERROR: $name service ($ip:$port) unavailable"
            # Send alert
        fi
    done

    sleep 300  # Check every 5 minutes
done
```

### Log Analysis and Alerting

```bash
#!/bin/bash
# security-log-monitor.sh - Monitor for security events

# Monitor OPNsense firewall logs for blocked management access attempts
tail -f /var/log/filter.log | while read line; do
    if echo "$line" | grep -q "192.168.100" && echo "$line" | grep -q "block"; then
        echo "SECURITY ALERT: Blocked access to management VLAN: $line"
        # Send security alert
    fi
done &

# Monitor authentication failures
tail -f /var/log/auth.log | while read line; do
    if echo "$line" | grep -q "Failed password" || echo "$line" | grep -q "Invalid user"; then
        echo "AUTH ALERT: Authentication failure: $line"
        # Send authentication alert
    fi
done &

# Monitor for unusual DNS queries
ssh root@192.168.100.5 'tail -f /var/log/pihole.log' | while read line; do
    if echo "$line" | grep -qE "(malware|phishing|botnet)"; then
        echo "DNS ALERT: Suspicious DNS query: $line"
        # Send DNS security alert
    fi
done &
```

This troubleshooting guide provides comprehensive diagnostic and recovery procedures for maintaining VLAN-based management interface isolation while ensuring rapid resolution of common issues and effective emergency response capabilities.