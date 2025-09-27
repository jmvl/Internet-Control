# Firewall Rules Configuration - VLAN Management Interface Isolation

## Overview

This document provides comprehensive firewall rule configurations for implementing VLAN-based management interface isolation using OPNsense. The rules enforce security boundaries while maintaining operational functionality across the three-tier traffic control architecture.

## Rule Design Philosophy

### Security Principles
1. **Default Deny**: All inter-VLAN communication denied by default
2. **Explicit Allow**: Only necessary services explicitly permitted
3. **Least Privilege**: Minimum required access for operational needs
4. **Defense in Depth**: Multiple rule layers for comprehensive protection
5. **Audit Trail**: Comprehensive logging for security monitoring

### Rule Categories
- **Management Rules**: Full administrative access from management VLAN
- **User Service Rules**: Controlled access to user services from user VLAN
- **Infrastructure Rules**: Essential services (DNS, gateway) accessible from all VLANs
- **Security Rules**: Explicit blocks with logging for security monitoring
- **Default Rules**: Catch-all rules for unspecified traffic

## OPNsense Firewall Rule Implementation

### Rule Processing Order
OPNsense processes firewall rules from top to bottom within each interface. The first matching rule determines the action. Rule order is critical for security effectiveness.

```yaml
Rule Priority Order:
  1. Security Block Rules (Highest Priority)
  2. Essential Service Allow Rules
  3. VLAN-Specific Allow Rules
  4. Inter-VLAN Communication Rules
  5. Internet Access Rules
  6. Default Deny Rules (Lowest Priority)
```

### Firewall Aliases Configuration

Before implementing rules, create aliases for easier management:

```yaml
# Navigate to Firewall → Aliases

Management_Networks:
  Type: Networks
  Content:
    - 192.168.100.0/24  # Management VLAN

User_Networks:
  Type: Networks
  Content:
    - 192.168.10.0/24   # User VLAN

IoT_Networks:
  Type: Networks
  Content:
    - 192.168.20.0/24   # IoT VLAN

Legacy_Networks:
  Type: Networks
  Content:
    - 192.168.1.0/24    # Legacy/Transitional VLAN

Management_Hosts:
  Type: Host(s)
  Content:
    - 192.168.100.3     # OPNsense management
    - 192.168.100.5     # Pi-hole management
    - 192.168.100.9     # OMV management
    - 192.168.100.10    # Proxmox management

User_Services:
  Type: Host(s)
  Content:
    - 192.168.10.9      # OMV file shares
    - 192.168.10.20     # Supabase services
    - 192.168.10.21     # Immich photos
    - 192.168.10.22     # n8n automation
    - 192.168.10.23     # Confluence wiki
    - 192.168.10.24     # JIRA issues

Management_Ports:
  Type: Port(s)
  Content:
    - 22       # SSH
    - 80       # HTTP Admin
    - 443      # HTTPS Admin
    - 8006     # Proxmox
    - 5432     # PostgreSQL
    - 3010     # Uptime Kuma
    - 9443     # Portainer

User_Service_Ports:
  Type: Port(s)
  Content:
    - 445      # SMB
    - 2049     # NFS
    - 2283     # Immich
    - 5678     # n8n
    - 8000     # Supabase API
    - 3000     # Supabase Studio
    - 8090     # Confluence
    - 8080     # JIRA

DNS_Ports:
  Type: Port(s)
  Content:
    - 53       # DNS

Web_Ports:
  Type: Port(s)
  Content:
    - 80       # HTTP
    - 443      # HTTPS
```

## Management VLAN (100) Rules

### Interface: OPT1 (Management VLAN)

```yaml
# Rule 1: Allow all management traffic (Highest Priority)
Action: Pass
Source: Management_Networks
Destination: any
Protocol: any
Description: "Allow full access from management VLAN"
Log: Advanced logging enabled
Advanced Options:
  - State Type: Keep state
  - State Timeout: 7200
```

```yaml
# Rule 2: Log critical management actions
Action: Pass
Source: Management_Networks
Destination: Management_Hosts
Port: Management_Ports
Protocol: TCP
Description: "Log management interface access"
Log: Enabled
Advanced Options:
  - Tag: MGMT_ACCESS
  - Max states: 1000
```

**OPNsense Configuration Steps:**
1. Navigate to Firewall → Rules → OPT1 (Management VLAN)
2. Click "Add" to create new rule
3. Configure rule parameters as specified above
4. Enable logging for security audit trail
5. Apply changes

## User VLAN (10) Rules

### Interface: OPT2 (User VLAN)

```yaml
# Rule 1: Allow DNS queries to Pi-hole (Essential Service)
Action: Pass
Source: User_Networks
Destination: 192.168.100.5  # Pi-hole
Port: DNS_Ports
Protocol: UDP/TCP
Description: "Allow DNS queries to Pi-hole from user VLAN"
Log: No
Advanced Options:
  - Quick: Yes (stops processing after match)
  - State Type: Keep state
```

```yaml
# Rule 2: Allow access to user services
Action: Pass
Source: User_Networks
Destination: User_Services
Port: User_Service_Ports
Protocol: TCP
Description: "Allow access to legitimate user services"
Log: No
Advanced Options:
  - State Type: Keep state
  - Max states per host: 100
```

```yaml
# Rule 3: Allow internet access
Action: Pass
Source: User_Networks
Destination: !RFC1918  # Not private IP ranges
Protocol: any
Description: "Allow internet access from user VLAN"
Log: No
Advanced Options:
  - State Type: Keep state
  - Gateway: WAN_DHCP (default gateway)
```

```yaml
# Rule 4: Block management interface access (Security Rule)
Action: Block
Source: User_Networks
Destination: Management_Hosts
Port: Management_Ports
Protocol: TCP
Description: "SECURITY: Block user access to management interfaces"
Log: Yes
Advanced Options:
  - Tag: SECURITY_BLOCK
  - Reset: Send TCP reset
```

```yaml
# Rule 5: Block User to IoT VLAN communication
Action: Block
Source: User_Networks
Destination: IoT_Networks
Protocol: any
Description: "SECURITY: Block User to IoT VLAN communication"
Log: Yes
Advanced Options:
  - Tag: VLAN_ISOLATION
```

```yaml
# Rule 6: Block access to management VLAN (Catch-all)
Action: Block
Source: User_Networks
Destination: Management_Networks
Protocol: any
Description: "SECURITY: Block all other access to management VLAN"
Log: Yes
Advanced Options:
  - Tag: MGMT_PROTECTION
```

**Configuration Example:**
```bash
# OPNsense CLI configuration for User VLAN rules
configctl firewall reload

# Verify rules are active
pfctl -sr | grep -A 5 -B 5 "192.168.10"
```

## IoT VLAN (20) Rules

### Interface: OPT3 (IoT VLAN)

```yaml
# Rule 1: Allow DNS queries only
Action: Pass
Source: IoT_Networks
Destination: 192.168.100.5  # Pi-hole
Port: DNS_Ports
Protocol: UDP/TCP
Description: "Allow DNS queries from IoT devices"
Log: No
Advanced Options:
  - Quick: Yes
  - State Type: Keep state
```

```yaml
# Rule 2: Allow limited internet access
Action: Pass
Source: IoT_Networks
Destination: !RFC1918
Port: Web_Ports + 123  # HTTP, HTTPS, NTP
Protocol: TCP/UDP
Description: "Allow limited internet access for IoT devices"
Log: No
Advanced Options:
  - State Type: Keep state
  - Bandwidth: 10% of total (via traffic shaper)
```

```yaml
# Rule 3: Block access to all internal networks
Action: Block
Source: IoT_Networks
Destination: RFC1918  # All private IP ranges
Protocol: any
Description: "SECURITY: Block IoT access to internal networks"
Log: Yes
Advanced Options:
  - Tag: IOT_ISOLATION
  - Reset: Drop silently
```

```yaml
# Rule 4: Default deny for IoT devices
Action: Block
Source: IoT_Networks
Destination: any
Protocol: any
Description: "SECURITY: Default deny for IoT devices"
Log: Yes
Advanced Options:
  - Tag: IOT_DEFAULT_DENY
```

## Legacy VLAN (1) Rules - Transitional

### Interface: LAN (Legacy)

```yaml
# Rule 1: Maintain existing functionality during transition
Action: Pass
Source: Legacy_Networks
Destination: any
Protocol: any
Description: "TRANSITIONAL: Maintain legacy network functionality"
Log: No
Advanced Options:
  - Note: Remove after migration complete
  - Expire: Set expiration date for rule review
```

```yaml
# Rule 2: Log access to new VLAN services
Action: Pass
Source: Legacy_Networks
Destination: Management_Networks + User_Networks + IoT_Networks
Protocol: any
Description: "TRANSITIONAL: Log cross-VLAN access during migration"
Log: Yes
Advanced Options:
  - Tag: MIGRATION_TRAFFIC
```

## Floating Rules (Apply to All Interfaces)

### Global Security Rules

```yaml
# Rule 1: Block private IP spoofing on WAN
Action: Block
Interface: WAN
Direction: In
Source: RFC1918
Destination: any
Protocol: any
Description: "SECURITY: Block private IP spoofing from internet"
Log: Yes
Advanced Options:
  - Tag: SPOOFING_ATTEMPT
  - Quick: Yes
```

```yaml
# Rule 2: Rate limit SSH connections globally
Action: Pass
Source: any
Destination: any
Port: 22
Protocol: TCP
Description: "Rate limit SSH connections"
Log: No
Advanced Options:
  - Max states: 5
  - Max src states: 3
  - State timeout: 300
```

```yaml
# Rule 3: Rate limit management interface access
Action: Pass
Source: any
Destination: Management_Hosts
Port: Management_Ports
Protocol: TCP
Description: "Rate limit management interface access"
Log: Yes
Advanced Options:
  - Max states per host: 10
  - Connection rate: 20/300 (20 connections per 5 minutes)
```

## Traffic Shaping Integration

### VLAN-Specific Bandwidth Control

```yaml
# Traffic Shaper Configuration
# Navigate to Firewall → Traffic Shaper

Root Queue:
  Name: "Root"
  Bandwidth: 100%  # Total available bandwidth
  Scheduler: HFSC

Management VLAN Queue:
  Name: "Management_Queue"
  Parent: Root
  Bandwidth: 20% (guaranteed), 100% (maximum)
  Priority: 7 (highest)
  Description: "High priority for management traffic"

User VLAN Queue:
  Name: "User_Queue"
  Parent: Root
  Bandwidth: 70% (guaranteed), 90% (maximum)
  Priority: 4 (normal)
  Description: "Standard priority for user traffic"

IoT VLAN Queue:
  Name: "IoT_Queue"
  Parent: Root
  Bandwidth: 5% (guaranteed), 20% (maximum)
  Priority: 1 (lowest)
  Description: "Limited bandwidth for IoT devices"
```

### Traffic Shaper Rules

```yaml
# Management Traffic Shaping
Action: Pass
Source: Management_Networks
Destination: any
Protocol: any
Advanced Options:
  - Traffic Shaper: Management_Queue
  - Description: "Route management traffic to high priority queue"

# User Traffic Shaping
Action: Pass
Source: User_Networks
Destination: any
Protocol: any
Advanced Options:
  - Traffic Shaper: User_Queue
  - Description: "Route user traffic to standard priority queue"

# IoT Traffic Shaping
Action: Pass
Source: IoT_Networks
Destination: any
Protocol: any
Advanced Options:
  - Traffic Shaper: IoT_Queue
  - Description: "Route IoT traffic to limited bandwidth queue"
```

## Intrusion Detection Integration

### Suricata IDS/IPS Rules

```yaml
# Enable Suricata on interfaces
# Navigate to Services → Intrusion Detection → Administration

Interfaces:
  - LAN (Legacy)
  - OPT1 (Management)
  - OPT2 (User)
  - OPT3 (IoT)

Detection Categories:
  - Management interface attacks
  - Lateral movement attempts
  - DNS tunneling
  - Malware command and control
  - Data exfiltration attempts

Custom Rules:
  # Detect management interface access from user VLANs
  alert tcp $USER_NETWORKS any -> $MANAGEMENT_HOSTS $MANAGEMENT_PORTS (msg:"Unauthorized management access attempt"; sid:1000001; rev:1;)

  # Detect unusual DNS query volumes
  alert udp any any -> $DNS_SERVER 53 (msg:"High volume DNS queries"; threshold:type both,track by_src,count 100,seconds 60; sid:1000002; rev:1;)

  # Detect cross-VLAN scanning
  alert tcp $USER_NETWORKS any -> $IOT_NETWORKS any (msg:"User to IoT VLAN scanning"; flags:S; sid:1000003; rev:1;)
```

## Rule Testing and Validation

### Firewall Rule Testing Commands

```bash
#!/bin/bash
# firewall-rule-test.sh - Test firewall rules from different VLANs

echo "=== Firewall Rule Testing ==="

# Test from Management VLAN (should succeed)
echo "Testing from Management VLAN:"
timeout 5 nc -zv 192.168.100.3 443 && echo "✓ OPNsense admin accessible" || echo "✗ OPNsense admin blocked"
timeout 5 nc -zv 192.168.100.10 8006 && echo "✓ Proxmox admin accessible" || echo "✗ Proxmox admin blocked"

# Test from User VLAN (should fail for management, succeed for services)
echo -e "\nTesting from User VLAN:"
timeout 5 nc -zv 192.168.100.3 443 && echo "✗ OPNsense admin improperly accessible" || echo "✓ OPNsense admin properly blocked"
timeout 5 nc -zv 192.168.10.21 2283 && echo "✓ Immich service accessible" || echo "✗ Immich service blocked"
timeout 5 nc -zv 192.168.100.5 53 && echo "✓ DNS service accessible" || echo "✗ DNS service blocked"

# Test from IoT VLAN (should fail for internal services)
echo -e "\nTesting from IoT VLAN:"
timeout 5 nc -zv 192.168.10.21 2283 && echo "✗ User service improperly accessible" || echo "✓ User service properly blocked"
timeout 5 nc -zv 192.168.100.5 53 && echo "✓ DNS service accessible" || echo "✗ DNS service blocked"

echo -e "\n=== Test Complete ==="
```

### Rule Performance Monitoring

```bash
#!/bin/bash
# rule-performance-monitor.sh - Monitor firewall rule performance

# Check rule hit counts
pfctl -vsr | grep -E "(evaluations|packets|bytes)"

# Monitor state table utilization
pfctl -si | grep -E "(states|src-nodes)"

# Check for rule bottlenecks
pfctl -vsl | head -20

# Monitor dropped packets
netstat -s | grep -i drop
```

### Log Analysis Scripts

```bash
#!/bin/bash
# firewall-log-analysis.sh - Analyze firewall logs for security events

# Count blocked management access attempts
grep "SECURITY.*BLOCK" /var/log/filter.log | wc -l

# Identify top blocked source IPs
grep "SECURITY.*BLOCK" /var/log/filter.log | awk '{print $8}' | sort | uniq -c | sort -nr | head -10

# Check for VLAN isolation violations
grep "VLAN_ISOLATION" /var/log/filter.log | tail -20

# Monitor DNS query patterns
grep "53/udp" /var/log/filter.log | awk '{print $6 " " $8}' | sort | uniq -c | sort -nr | head -10
```

## Backup and Recovery

### Rule Backup Procedures

```bash
#!/bin/bash
# backup-firewall-rules.sh - Backup OPNsense firewall configuration

# Create timestamped backup
timestamp=$(date +%Y%m%d_%H%M%S)
backup_dir="./firewall-backup-$timestamp"
mkdir -p "$backup_dir"

# Export configuration via API (requires API key)
curl -k -u "api_key:api_secret" \
  "https://192.168.100.3/api/core/backup/download/this" \
  -o "$backup_dir/opnsense-config-$timestamp.xml"

# Export firewall rules specifically
curl -k -u "api_key:api_secret" \
  "https://192.168.100.3/api/firewall/filter/exportrules" \
  -o "$backup_dir/firewall-rules-$timestamp.json"

# Document current rule state
pfctl -sr > "$backup_dir/active-rules-$timestamp.txt"
pfctl -sn > "$backup_dir/nat-rules-$timestamp.txt"

echo "Firewall configuration backed up to: $backup_dir"
```

### Rule Restoration

```bash
#!/bin/bash
# restore-firewall-rules.sh - Restore firewall configuration

backup_file="$1"

if [[ -z "$backup_file" ]]; then
    echo "Usage: $0 <backup-file.xml>"
    exit 1
fi

# Restore via web interface or API
echo "Restoring firewall configuration from: $backup_file"
echo "Navigate to System → Configuration → Backups in OPNsense web interface"
echo "Upload and restore the configuration file: $backup_file"

# Alternative: API restoration (requires setup)
# curl -k -u "api_key:api_secret" \
#   -X POST -F "conffile=@$backup_file" \
#   "https://192.168.100.3/api/core/backup/restore"
```

This comprehensive firewall rules configuration provides the foundation for secure VLAN-based management interface isolation while maintaining operational functionality across the network infrastructure.