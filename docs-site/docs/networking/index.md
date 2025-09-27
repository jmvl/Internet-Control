# Network Infrastructure

The Internet Control Infrastructure implements a sophisticated three-tier network architecture with hardware-level isolation, providing enterprise-grade network control and security capabilities.

## Network Topology Overview

```
Internet (DSL Router)
    ↓
[enp2s0f0] ← RTL8111 1GbE WAN NIC
    ↓
(Proxmox Host - pve2)
192.168.1.10
    ↓
[enp1s0] ← RTL8125 2.5GbE LAN NIC
    ↓
OpenWrt Router/LAN Switch
192.168.1.2
```

## Hardware Network Configuration

### Physical Network Interface Architecture

| Interface | Hardware | PCI Slot | Speed | Bridge | Purpose | Physical Connection |
|-----------|----------|----------|-------|--------|---------|-------------------|
| **enp1s0** | Realtek RTL8125 | 01:00.0 | 2.5GbE | vmbr0 | LAN Traffic | Internal network/OpenWrt |
| **enp2s0f0** | Realtek RTL8111 | 02:00.0 | 1GbE | vmbr1 | WAN Traffic | DSL Router (Internet) |
| **wlp3s0** | WiFi Interface | 03:00.0 | WiFi | - | Backup/Mgmt | Wireless network |

### Network Bridge Configuration

#### vmbr0 (LAN Bridge)
```yaml
Physical NIC: enp1s0 (RTL8125 2.5GbE)
IP Address: 192.168.1.10/24
Gateway: 192.168.1.3 (OPNsense)
Connected VMs/CTs: All containers + OPNsense LAN interface
Purpose: Internal network traffic, management, container connectivity
```

#### vmbr1 (WAN Bridge)
```yaml
Physical NIC: enp2s0f0 (RTL8111 1GbE)
IP Address: None (bridge only)
Connected VMs: OPNsense WAN interface only
Purpose: Direct internet connection for firewall WAN side
Physical Connection: Directly connected to DSL router/modem
```

## Three-Tier Traffic Control Architecture

### Layer 1: OpenWrt (192.168.1.2)
**Purpose**: Wireless Access Point & QoS Management

#### Key Functions:
- **Wireless Control**: 4-radio setup with dual-band coverage
- **SQM (Smart Queue Management)**: Bufferbloat control and fair queuing
- **Network Bridge**: Connection between wireless and wired infrastructure
- **Initial Traffic Shaping**: Wireless-specific optimization

#### Wireless Configuration:
```yaml
Radio Setup:
  radio0: 2.4GHz Channel 9 (HE20) - Primary network "Znutar"
  radio1: 5GHz Channel 36 (HE80) - High-speed network "Znutar_2"
  radio2: 2.4GHz Channel 1 (HE20) - Backup/fallback
  radio3: 5GHz Channel 36 (HE80) - Backup/fallback

Backup Networks:
  Znutar_BACKUP: Hidden 2.4GHz emergency access
  Znutar_2_BACKUP: Hidden 5GHz emergency access
```

### Layer 2: OPNsense (192.168.1.3)
**Purpose**: Centralized Firewall & Traffic Management

#### Network Integration:
```yaml
Dual NIC Setup:
  WAN Interface: tap133i1 → vmbr1 → enp2s0f0 → Internet
  LAN Interface: tap133i0 → vmbr0 → enp1s0 → Internal Network

Traffic Control:
  Hierarchical Token Bucket (HTB) shaping
  Time-based restriction policies
  Device-specific bandwidth allocation
  Application-aware traffic prioritization
```

### Layer 3: Pi-hole (192.168.1.5)
**Purpose**: DNS Filtering & Content Control

#### DNS Architecture:
```yaml
Primary DNS: Pi-hole (192.168.1.5)
Secondary DNS: 1.1.1.1 (Cloudflare backup)
Upstream DNS: 1.1.1.1, 8.8.8.8

Filtering Capabilities:
  - Advertisement blocking
  - Malware domain blocking
  - Custom whitelist/blacklist
  - Time-based domain restrictions
```

## IP Address Schema & Network Services

### Core Infrastructure
```yaml
Network Range: 192.168.1.0/24
Gateway: 192.168.1.3 (OPNsense)
DNS: 192.168.1.5 (Pi-hole)
DHCP Pool: 192.168.1.10-200

Infrastructure Services:
  192.168.1.2:  OpenWrt Router
  192.168.1.3:  OPNsense Firewall/Gateway
  192.168.1.5:  Pi-hole DNS Server
  192.168.1.9:  OMV Storage Server
  192.168.1.10: Proxmox Virtualization Host
  192.168.1.20: Primary Docker Host
  192.168.1.33: GitLab DevOps Server
```

### Virtualized Infrastructure (Proxmox 192.168.1.10)

#### Virtual Machines
```yaml
VM 133: opnsense
  Status: running
  Networks: vmbr0 (LAN) + vmbr1 (WAN)
  Resources: 6 cores, 3.6GB RAM
  Purpose: Network gateway and firewall
```

#### LXC Containers
```yaml
Container Services:
  100: ConfluenceDocker20220712 (192.168.1.21)
  111: docker-debian (192.168.1.20) - Primary Docker host
  102: jira.accelior.com (192.168.1.22)
  103: files.accelior.com (192.168.1.25)
  130: mail.vega-messenger.com (192.168.1.30)
  501: gitlab.accelior.com (192.168.1.33)
```

## Network Traffic Flow

### Typical Request Path
```
Wireless Device
    ↓ (WiFi connection)
OpenWrt (192.168.1.2)
    ↓ (SQM/QoS processing)
Proxmox vmbr0 Bridge
    ↓ (Network isolation)
OPNsense VM (192.168.1.3)
    ↓ (Firewall rules + Traffic shaping)
Pi-hole DNS (192.168.1.5)
    ↓ (DNS filtering)
Internet/Local Services
```

### Control Points
```yaml
Layer 1 (OpenWrt):
  - Wireless bandwidth limits
  - Per-device QoS prioritization
  - WiFi interface management

Layer 2 (Proxmox):
  - Network bridge isolation
  - VM/container resource limits
  - Virtual network management

Layer 3 (OPNsense):
  - Firewall rule enforcement
  - Traffic shaping and throttling
  - Time-based access restrictions

Layer 4 (Pi-hole):
  - DNS filtering and blocking
  - Domain-based access control
  - Query logging and analytics
```

## Network Security & Isolation

### Hardware-Level Isolation
```yaml
WAN Isolation:
  - Dedicated NIC (enp2s0f0) for internet traffic
  - No direct LAN access to WAN interface
  - OPNsense VM acts as controlled gateway

LAN Segmentation:
  - Separate bridge (vmbr0) for internal traffic
  - Container network isolation via Docker
  - VM-level network access controls
```

### Firewall Integration
```yaml
Stateful Inspection:
  - Connection tracking across all interfaces
  - Rule-based access control
  - Intrusion detection via Suricata IDS

Traffic Analysis:
  - Real-time bandwidth monitoring
  - Protocol-based traffic classification
  - Historical usage analytics
```

## Performance & Optimization

### Network Capacity
```yaml
WAN Capacity: 1GbE (enp2s0f0)
LAN Capacity: 2.5GbE (enp1s0)
Wireless: Dual-band 802.11ax (WiFi 6)

Throughput Optimization:
  - SQM bufferbloat control
  - Traffic shaping efficiency
  - Container network performance
```

### Resource Allocation
```yaml
Proxmox Host Resources:
  Network Processing: Hardware-accelerated NICs
  VM Allocation: Dedicated resources for OPNsense
  Container Networking: Optimized Docker networks

Performance Metrics:
  Latency: &lt;10ms for interactive traffic
  Jitter: &lt;5ms for real-time applications
  Packet Loss: &lt;0.1% under normal conditions
```

## Monitoring & Management

### Network Monitoring
```yaml
Real-Time Monitoring:
  - OPNsense: Traffic statistics and rule hits
  - Pi-hole: DNS query patterns and blocking
  - OpenWrt: Wireless connection quality

Historical Analytics:
  - Bandwidth utilization trends
  - Device-specific usage patterns
  - Security event correlation
```

### Management Interfaces
```yaml
Web Interfaces:
  - OpenWrt LuCI: http://192.168.1.2
  - OPNsense GUI: https://192.168.1.3
  - Pi-hole Admin: http://192.168.1.5/admin
  - Proxmox Console: https://192.168.1.10:8006

Command Line Access:
  - SSH to individual components
  - Console access via Proxmox
  - Direct router management
```

## Troubleshooting & Maintenance

### Network Diagnostics
```bash
# Connectivity verification
ping 192.168.1.3   # OPNsense gateway
ping 192.168.1.5   # Pi-hole DNS
ping 1.1.1.1       # External connectivity

# Interface status
ip link show       # Physical interfaces
brctl show         # Bridge configuration
docker network ls  # Container networks
```

### Common Issues
```yaml
Bridge Configuration:
  Issue: WAN bridge missing physical interface
  Solution: brctl addif vmbr1 enp2s0f0

DNS Resolution:
  Issue: Pi-hole service down
  Fallback: OPNsense DNS or direct ISP DNS

Traffic Shaping:
  Issue: SQM not working on OpenWrt
  Solution: Check interface configuration and restart SQM
```

## Redundancy & Failover

### Network Resilience
```yaml
DNS Redundancy:
  Primary: Pi-hole (192.168.1.5)
  Secondary: Cloudflare (1.1.1.1)
  Tertiary: ISP DNS servers

Gateway Failover:
  Primary: OPNsense VM (192.168.1.3)
  Emergency: Direct ISP router bypass
  Wireless Backup: Hidden backup networks

Service Recovery:
  VM Restart: &lt;5 minutes
  Configuration Restore: &lt;15 minutes
  Full Infrastructure: &lt;30 minutes
```

This network infrastructure provides enterprise-grade capabilities while maintaining the flexibility and cost-effectiveness suitable for advanced home networking requirements.