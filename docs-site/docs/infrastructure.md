# Network Infrastructure Documentation

## Executive Summary
This document provides comprehensive documentation for a three-tier network infrastructure designed for home internet control, traffic management, and DNS filtering. The system implements multiple layers of security and bandwidth control through hardware-isolated networks, virtualized firewalls, and dedicated DNS filtering services.

## Overview
This infrastructure follows a layered approach with hardware-based network isolation, providing enterprise-grade network control, security, and service hosting capabilities suitable for both home and small business environments.

## Network Topology

```
Internet
    ↓
[OpenWrt Router] ← Wi-Fi Access Point
192.168.1.2
    ↓
[Proxmox Host] ← Virtualization Platform
192.168.1.10 (pve2)
    ↓ (vmbr1 - WAN Bridge)
[OPNsense VM] ← DHCP Server, Firewall, Traffic Shaper
192.168.1.3 (VMID: 133)
    ↓ (vmbr0 - LAN Bridge)
[Pi-hole DNS Server] ← DNS Filtering & Blocking
192.168.1.5
    ↓
LAN Clients + Proxmox Containers
```

## Hardware Infrastructure Setup

### Physical Network Architecture
The network uses hardware-based isolation between WAN and LAN traffic through dedicated NICs on the Proxmox host:

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
```

### Hardware Network Interface Configuration

| Interface | Hardware | PCI Slot | Speed | Bridge | Purpose | Physical Connection |
|-----------|----------|----------|-------|--------|---------|-------------------|
| **enp1s0** | Realtek RTL8125 | 01:00.0 | 2.5GbE | vmbr0 | LAN Traffic | Internal network/OpenWrt |
| **enp2s0f0** | Realtek RTL8111 | 02:00.0 | 1GbE | vmbr1 | WAN Traffic | DSL Router (Internet) |
| **wlp3s0** | WiFi Interface | 03:00.0 | WiFi | - | Backup/Mgmt | Wireless network |

### Network Bridge Configuration

#### vmbr0 (LAN Bridge)
- **Physical NIC**: enp1s0 (RTL8125 2.5GbE)
- **IP Address**: 192.168.1.10/24  
- **Gateway**: 192.168.1.3 (OPNsense)
- **Connected VMs/CTs**: All containers + OPNsense LAN interface
- **Purpose**: Internal network traffic, management, container connectivity

#### vmbr1 (WAN Bridge)  
- **Physical NIC**: enp2s0f0 (RTL8111 1GbE)
- **IP Address**: None (bridge only)
- **Connected VMs**: OPNsense WAN interface only
- **Purpose**: Direct internet connection for firewall WAN side
- **Physical Connection**: Directly connected to DSL router/modem

### OPNsense VM Network Configuration
**VM 133 Dual NIC Setup**:
- **net0** (LAN): virtio NIC → tap133i0 → vmbr0 → enp1s0 → Internal Network
- **net1** (WAN): virtio NIC → tap133i1 → vmbr1 → enp2s0f0 → Internet

This setup provides complete network isolation where:
- WAN traffic flows directly from Internet → enp2s0f0 → vmbr1 → OPNsense WAN
- LAN traffic flows from Internal Network → enp1s0 → vmbr0 → OPNsense LAN  
- OPNsense acts as the gateway between these isolated network segments

## Component Breakdown

### 1. OpenWrt Router (192.168.1.2)
**Role**: Wireless Access Point & Gateway
**Primary Functions**:
- Wi-Fi connectivity for all wireless devices
- Network bridge between wireless and wired infrastructure
- Initial packet routing and forwarding
- Wireless network management (SSID, security, guest networks)

**Key Features**:
- Custom firmware providing advanced wireless control
- QoS capabilities for wireless traffic prioritization
- Bandwidth monitoring and statistics
- Guest network isolation
- Wireless device management

**Traffic Control Capabilities**:
- SQM (Smart Queue Management) for wireless optimization
- Per-device bandwidth limits
- Wireless client isolation
- Traffic classification and prioritization

**Wireless Radio Configuration**:
The OpenWrt router operates with a **4-radio setup** providing comprehensive wireless coverage and network segmentation:

| Radio | Band | Channel | Mode | Status | SSID | Purpose |
|-------|------|---------|------|--------|------|---------|
| **radio0** | 2.4GHz | 9 | HE20 | Active | Znutar | Primary network |
| **radio1** | 5GHz | 36 | HE80 | Disabled | Znutar_2 | High-speed network |
| **radio2** | 2.4GHz | 1 | HE20 | Disabled | OpenWrt | Default/fallback |
| **radio3** | 5GHz | 36 | HE80 | Disabled | OpenWrt | Default/fallback |

**Additional WiFi Interfaces**:
- **Backup Networks**: Hidden backup SSIDs configured on both bands
  - `Znutar_BACKUP` (2.4GHz) - Hidden fallback network
  - `Znutar_2_BACKUP` (5GHz) - Hidden fallback network
- **Security**: All active networks use WPA3/SAE-mixed encryption
- **MAC Filtering**: Enabled on primary network (deny mode)

**Radio Architecture Benefits**:
- **Dual-Band Coverage**: 2.4GHz (longer range) + 5GHz (higher speed)
- **Network Segmentation**: Separate radios for different network zones
- **Redundancy**: Backup SSIDs for failover scenarios
- **Guest Network Capability**: Additional radios available for isolated guest access
- **IoT Segregation**: Can isolate IoT devices on separate radio/SSID combinations

### 2. Proxmox Virtualization Host (192.168.1.10)
**Role**: Virtualization Platform & Infrastructure Host
**Primary Functions**:
- Host virtualized OPNsense firewall and other services
- Container management for application services
- Network bridge management between WAN and LAN
- Resource allocation and VM/CT lifecycle management

**Key Features**:
- **Dual NIC Setup**: 2.5GbE (LAN) + 1GbE (WAN) separation
- **Bridge Networks**: vmbr0 (LAN) and vmbr1 (WAN) for network isolation
- **VM Management**: OPNsense runs as VM 133 with dedicated resources
- **Container Platform**: Multiple LXC containers for various services
- **Resource Management**: Dynamic CPU, memory, and storage allocation

**Hardware Specifications**:
- **enp1s0**: RTL8125 2.5GbE (PCI 01:00.0, connected to vmbr0/LAN)
- **enp2s0f0**: RTL8111 1GbE (PCI 02:00.0, connected to vmbr1/WAN)  
- **wlp3s0**: WiFi interface (backup connectivity, IP: 192.168.1.8)
- **Storage**: ssd-4tb for VM/container storage

**Physical Network Connections**:
- **enp2s0f0 (WAN)**: Connected directly to DSL router/modem (Internet)
- **enp1s0 (LAN)**: Connected to internal LAN switch/OpenWrt
- **Network Isolation**: WAN and LAN traffic completely separated via hardware NICs
- **OPNsense Dual NIC**: VM 133 bridges both networks with firewall rules

**Hosted Services**:
- OPNsense firewall (VM 133)
- Confluence, JIRA, File Server containers
- Mail server and web applications
- Docker and automation platforms

#### Docker Container Services (on 192.168.1.20):
**Development Platform**:
- **n8n** (port 5678) - Workflow automation platform
- **Gotenberg** - Document conversion service

**Supabase Stack** (Full backend-as-a-service deployment):
- **PostgreSQL Database** (15.8.1) - Primary database
- **Supabase Studio** - Admin dashboard and database management
- **Auth Service** - User authentication and authorization
- **Storage API** - File storage and management
- **REST API** (PostgREST) - Auto-generated REST API from database schema
- **Realtime Service** - WebSocket subscriptions for live data ⚠️ (currently unhealthy)
- **Kong Gateway** (ports 8000/8443) - API gateway and load balancer
- **Meta Service** - Database metadata and introspection API
- **Edge Functions** - Serverless function runtime (Deno-based)
- **Analytics** (Logflare, port 4000) - Log aggregation and analytics
- **Connection Pooler** (Supavisor, ports 5432/6543) - Database connection pooling
- **Vector** - Log processing and transformation
- **ImgProxy** - Image processing and optimization

**Network Infrastructure**:
- **Pi-hole** - DNS filtering and ad blocking (also running as standalone service)

**Container Management**:
- **Portainer** (ports 8000/9443) - Docker container management interface
- **Portainer Agent** (port 9001) - Container monitoring agent

#### OMV Docker Container Services (OpenMediaVault Host):
**Content Management & Library**:
- **Calibre** (ports 8082/8083) - E-book library management and conversion
- **Wallabag** (port 8880) - Read-later web application for saving articles
- **Wallabag Redis** - Cache service for Wallabag (healthy)
- **Wallabag MariaDB** - Database for Wallabag ⚠️ (currently unhealthy)

**Photo & Media Management**:
- **Immich Server** (port 2283) - Self-hosted photo and video management platform
- **Immich PostgreSQL** - Database with pgvecto-rs vector support (healthy)
- **Immich Machine Learning** - AI-powered photo recognition and tagging (healthy)
- **Immich Redis** - Cache service for Immich (healthy)

**Network & Proxy Management**:
- **Nginx Proxy Manager** (ports 80/81/443) - Reverse proxy with SSL management

**File Synchronization**:
- **Syncthing** (ports 8384/22000/21027) - Decentralized file synchronization

**Monitoring & Management**:
- **Uptime Kuma** (port 3010) - Service uptime monitoring and alerting
  - **Web Interface**: http://192.168.1.9:3010
  - **Image**: louislam/uptime-kuma:1
  - **Status**: Up 2 weeks (healthy)
  - **Data Volume**: `/srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data`
  - **Docker Socket Access**: Enabled for container monitoring
  - **API Access**: API key configured for automated monitoring setup
  - **Features**: HTTP/HTTPS monitoring, status pages, notifications, real-time alerts
  - **Integration**: Configured to monitor n8n, Supabase, and other critical services
  - **Alert Channels**: Email, Discord, Slack notification support
- **Portainer** (ports 8000/9443) - Docker container management interface
- **Portainer Agent** (port 9001) - Container monitoring and management agent

**Custom Applications**:
- **Wedding Share** (port 8080) - Custom .NET application for event photo sharing

### 5. OpenMediaVault Storage Server (192.168.1.9)
**Role**: Network Attached Storage (NAS) & File Server
**Primary Functions**:
- Centralized file storage and sharing via Samba/SMB
- Media library management and organization
- Docker container hosting for media applications
- RAID and disk management with BTRFS filesystem
- Automated backup services and data protection

**Key Features**:
- **Multi-Drive Configuration**: 6-disk setup with mixed storage technologies
- **MergerFS Pool**: Unified filesystem across multiple drives (18TB total capacity)
- **BTRFS RAID**: Mirror configuration for critical data redundancy
- **Samba File Sharing**: Network file access with user authentication
- **Snapshot Support**: BTRFS snapshots for point-in-time recovery
- **Docker Platform**: Hosting media management applications

#### Storage Architecture

**Physical Drive Configuration**:
| Drive | Model | Capacity | Filesystem | Mount Point | Purpose |
|-------|-------|----------|------------|-------------|---------|
| **sda** | CT240BX500SSD1 | 240GB | ext4 | /boot, / | System drive (SSD) |
| **sdb** | WDC WD40EZRX-00SPEB0 | 4TB | BTRFS | /srv/raid | RAID mirror member |
| **sdc** | WDC WD30EZRX-00MMMB0 | 3TB | BTRFS | Single | MergerFS pool member |
| **sdd** | WDC WD20EVDS-63T3B0 | 2TB | BTRFS | Single | MergerFS pool member |
| **sde** | ST4000NE001-2MA101 | 4TB | BTRFS | /srv/raid | RAID mirror member |
| **sdf** | WDC WD140EMFZ-11A0WA0 | 14TB | BTRFS | Single | MergerFS pool member |

**Storage Pool Summary**:
- **System Storage**: 240GB SSD for OS and applications
- **RAID Mirror**: 3.7TB (sdb + sde) for critical data with redundancy
- **MergerFS Pool**: 18TB unified storage across multiple drives
- **Total Raw Capacity**: ~27TB across all drives
- **Usable Capacity**: ~21TB (accounting for RAID and formatting overhead)

#### MergerFS Unified Storage Pool

**Configuration**:
- **Pool Path**: `/srv/mergerfs/MergerFS/`
- **Member Drives**: sdc (3TB), sdd (2TB), sdf (14TB) 
- **Total Pool Capacity**: 18TB (14TB used, 80% utilization)
- **File Distribution**: Automatic balancing across member drives
- **Redundancy**: None (JBOD-style aggregation)

**Pool Contents**:
```
Pool Structure:
├── borg-repos/          # Borg backup repositories
├── COMFYUI/            # AI/ML ComfyUI installation
├── Data/               # General data storage
├── immich-backups/     # Photo management backups
├── immich-snapshots/   # Photo management snapshots
├── MergerFS/           # Pool metadata
├── POOL/               # User file storage
├── Pool2-Disk/         # Legacy pool data
├── PROXMOX/            # VM/Container backups
└── sda2_backup_*.img   # System disk backup images
```

#### RAID Mirror Configuration

**Mirror Setup** (sdb + sde):
- **Filesystem**: BTRFS RAID1
- **Total Capacity**: 3.7TB usable (4TB raw per drive)
- **Utilization**: 50% (1.9TB used, 1.9TB free)
- **Mount Point**: `/srv/raid` and `/srv/dev-disk-by-uuid-5c67dc41-a5c0-4439-8e68-cd5661b33f1b`
- **Redundancy**: Full mirror - can lose one drive without data loss

**Mirror Contents**:
```
RAID Mirror Structure:
├── AI-Training/        # Machine learning datasets
├── borgbackups/        # Borg backup storage
├── Calibre/           # E-book library database
├── config/            # Application configurations
├── docker-data/       # Docker persistent volumes
├── Files/             # Important document storage
├── immich-lib/        # Photo library data
├── omvbackup/         # OMV system backups
├── Pictures/          # Photo collection
├── synced/            # Syncthing shared folders
└── TopazGigapixelAI/  # AI photo upscaling software
```

#### Samba File Sharing Configuration

**Share Configuration**:
| Share Name | Path | Access | Purpose | Features |
|------------|------|--------|---------|----------|
| **Pool** | `/srv/mergerfs/MergerFS/` | Read/Write | Primary file storage | MergerFS unified pool |
| **MirrorDisk** | `/srv/dev-disk-by-uuid-5c67dc41-a5c0-4439-8e68-cd5661b33f1b/` | User "jm" only | Critical data mirror | BTRFS snapshots, shadow copies |

**Samba Global Settings**:
- **Workgroup**: WORKGROUP
- **Protocol**: SMB2_02 minimum (security hardening)
- **NetBIOS**: Disabled (modern networking)
- **Time Machine Support**: Enabled (macOS backup compatibility)
- **Security**: User authentication required, no guest access

**Permission Structure**:
- **Pool Share**: 
  - Create mask: 0664 (rw-rw-r--)
  - Directory mask: 0775 (rwxrwxr-x)
  - No user restrictions (network-wide access)
- **MirrorDisk Share**:
  - Create mask: 0664 (rw-rw-r--)
  - Directory mask: 0775 (rwxrwxr-x)
  - Restricted to user "jm" (critical data protection)

#### Backup and Snapshot Strategy

**BTRFS Snapshot Configuration**:
- **Snapshot Directory**: `.snapshots/` within each BTRFS volume
- **Naming Convention**: `_%Y%m%dT%H%M%S` timestamp format
- **Retention Policies**: @hourly, @daily, @weekly, @monthly, @yearly
- **Shadow Copy Support**: Windows Previous Versions integration

**Backup Services**:
- **Borg Backup**: Automated incremental backups to dedicated repositories
- **Immich Backups**: Database dumps and photo library snapshots
- **System Imaging**: Full disk images of system drive (sda2_backup_*.img)
- **Configuration Backups**: OMV system configuration preservation

#### Docker Integration

**Container Storage Mapping**:
- **Docker Root**: `/srv/docker-volume/` (system drive)
- **Data Volumes**: Mapped to MergerFS pool and RAID mirror
- **Overlay Networks**: Multiple overlay filesystems for container isolation
- **Persistent Storage**: Critical application data stored on RAID mirror

**Resource Utilization**:
- **Storage Usage**: 14TB of 18TB MergerFS pool (80% full)
- **RAID Usage**: 1.9TB of 3.7TB mirror capacity (50% full)
- **Docker Overhead**: ~20GB for container images and overlay networks
- **Backup Storage**: Multiple backup strategies consuming ~2TB total

#### Network File Access

**SMB/CIFS Access**:
- **Network Path**: `\\192.168.1.9\Pool` (primary storage)
- **Network Path**: `\\192.168.1.9\MirrorDisk` (critical data)
- **Authentication**: Username/password required
- **Performance**: Gigabit Ethernet connectivity
- **Compatibility**: Windows, macOS, Linux client support

**Management Interface**:
- **Web UI**: http://192.168.1.9 (OpenMediaVault admin panel)
- **SSH Access**: root@192.168.1.9 (system administration)
- **API Access**: OMV REST API for automation and monitoring

#### Storage Health and Monitoring

**SMART Monitoring**:
- All 6 drives monitored for health indicators
- Automatic alerting on drive degradation
- Proactive replacement notifications

**File System Health**:
- BTRFS scrub operations for data integrity verification
- Automatic bad sector detection and repair
- File system usage monitoring and alerting

**Performance Metrics**:
- Disk I/O monitoring across all drives
- Network throughput tracking for file shares
- Container resource utilization monitoring
- Storage capacity trending and forecasting

### 3. OPNsense Firewall (192.168.1.3 - Virtualized)
**Role**: Network Security & Traffic Management Hub
**Primary Functions**:
- DHCP server for IP address assignment
- Firewall rules and access control
- Traffic shaping and bandwidth management
- Network monitoring and logging
- VPN gateway capabilities

**Key Features**:
- **Firewall**: Stateful packet inspection, rule-based filtering
- **Traffic Shaper**: Hierarchical token bucket (HTB) traffic control
- **DHCP**: Dynamic IP assignment with reservations
- **Intrusion Detection**: Suricata IDS/IPS integration
- **Load Balancing**: Multi-WAN support and failover
- **VPN**: OpenVPN and IPsec server capabilities

**Traffic Control Capabilities**:
- Bandwidth throttling per device/IP/MAC
- Time-based traffic restrictions
- Application-level traffic shaping
- QoS policies with priority queues
- Traffic monitoring and analytics

### 4. Pi-hole DNS Server (192.168.1.5)
**Role**: DNS Filtering & Ad Blocking
**Primary Functions**:
- DNS resolution for all network devices
- Advertisement and tracking domain blocking
- Malware and phishing protection
- DNS query logging and analytics
- Custom DNS overrides and local resolution

**Key Features**:
- **DNS Filtering**: Block lists for ads, trackers, malware
- **Query Logging**: Detailed DNS request analytics
- **Whitelist/Blacklist**: Custom domain control
- **DHCP Integration**: Seamless IP-to-hostname resolution
- **API Access**: Programmatic control and monitoring

**Traffic Control Capabilities**:
- DNS-based content filtering
- Domain-specific blocking schedules
- Selective DNS resolution (redirect unwanted domains)
- Query rate limiting
- Client-specific DNS policies

## Network Flow & Data Path

### Typical Client Request Flow:
1. **Wireless Device** connects to OpenWrt (192.168.1.2)
2. **OpenWrt** forwards traffic to Proxmox host (192.168.1.10)
3. **Proxmox vmbr1** delivers WAN traffic to OPNsense VM (192.168.1.3)
4. **OPNsense VM** applies firewall rules and traffic shaping
5. **OPNsense VM** forwards DNS queries to Pi-hole (192.168.1.5)
6. **Pi-hole** resolves DNS or blocks unwanted domains
7. **OPNsense VM** routes approved traffic to internet via Proxmox bridges

### Traffic Control Points:
- **Layer 1 (OpenWrt)**: Wireless bandwidth limits, QoS prioritization
- **Layer 2 (Proxmox)**: Network bridge isolation, VM resource limits
- **Layer 3 (OPNsense VM)**: Firewall blocking, traffic shaping, time-based restrictions
- **Layer 4 (Pi-hole)**: DNS filtering, domain blocking, query logging

## IP Address Schema

| Component | IP Address | Network Role | Services |
|-----------|------------|--------------|----------|
| OpenWrt | 192.168.1.2 | Wireless AP | Wi-Fi, Bridge |
| OPNsense | 192.168.1.3 | Firewall/Gateway | DHCP, Firewall, Traffic Shaper |
| Pi-hole | 192.168.1.5 | DNS Server | DNS Filtering, Ad Blocking |
| **OMV NAS** | **192.168.1.9** | **Storage Server** | **Samba/SMB, Docker Containers** |
| **Proxmox Host** | **192.168.1.10** | **Virtualization Host** | **VM/Container Management** |
| **GitLab Server** | **192.168.1.33** | **DevOps Platform** | **Git Repository, CI/CD, Docker Registry** |
| DHCP Pool | 192.168.1.10-200 | Client Range | Dynamic Assignment |

### Proxmox Virtual Infrastructure (192.168.1.10)

#### Virtual Machines (VMs):
| VMID | Name | Status | IP Address | Network | Resources | Purpose |
|------|------|--------|------------|---------|-----------|---------|
| 133 | opnsense | running | 192.168.1.3 (vmbr0)<br/>WAN (vmbr1) | Dual NIC | 6 cores, 3.6GB RAM | Firewall/Gateway |

#### LXC Containers:
| VMID | Hostname | Status | IP Address | Resources | Storage | Purpose |
|------|----------|--------|------------|-----------|---------|---------|
| 100 | ConfluenceDocker20220712 | running | 192.168.1.21 | 10 cores, 9.9GB RAM | 60GB | Confluence Wiki |
| 111 | docker-debian | running | 192.168.1.20 | 12 cores, 10GB RAM | 60GB | Docker Host |
| 102 | jira.accelior.com | running | 192.168.1.22 | 6 cores, 6GB RAM | 70GB | JIRA Issue Tracking |
| 103 | files.accelior.com | running | 192.168.1.25 | 6 cores, 2GB RAM | 310GB | File Server |
| 109 | wanderwish | running | 192.168.1.29 | 12 cores, 4GB RAM | 20GB | Web Application |
| 110 | ansible-mgmt | stopped | 192.168.1.25 | 1 core, 1GB RAM | 15GB | Automation Management |
| 130 | mail.vega-messenger.com | running | 192.168.1.30 | 8 cores, 8GB RAM | 160GB | Mail Server |
| **501** | **gitlab.accelior.com** | **running** | **192.168.1.33** | **8 cores, 6GB RAM** | **95GB** | **GitLab CE Server** |

#### Network Bridges:
- **vmbr0**: LAN Bridge (connected to enp1s0 - 2.5GbE RTL8125)
  - Gateway: 192.168.1.3 (OPNsense)
  - All containers and host management interface
- **vmbr1**: WAN Bridge (connected to enp2s0f0 - 1GbE RTL8111)
  - Dedicated to OPNsense WAN interface
  - Direct internet connection for firewall

## Configuration Dependencies

### DHCP Configuration (OPNsense):
- Primary DNS: 192.168.1.5 (Pi-hole)
- Secondary DNS: 1.1.1.1 (Cloudflare backup)
- Default Gateway: 192.168.1.3 (OPNsense)

### DNS Configuration (Pi-hole):
- Upstream DNS: 1.1.1.1, 8.8.8.8
- Local Network: 192.168.1.0/24
- Reverse DNS: Enabled for local hostname resolution

### Firewall Configuration (OPNsense):
- LAN Interface: 192.168.1.3/24
- WAN Interface: Internet connection
- Traffic Shaper: Enabled for bandwidth management
- Schedules: Time-based rule activation

## Security Considerations

### Network Segmentation:
- Wireless clients isolated from management interfaces
- Guest network separation (if configured)
- Management access restricted to specific IPs

### Traffic Monitoring:
- OPNsense logs all firewall activity
- Pi-hole logs all DNS queries
- OpenWrt monitors wireless connections

### Redundancy:
- Pi-hole failure: OPNsense can serve as backup DNS
- OPNsense failure: Direct internet routing possible
- OpenWrt failure: Wired connections remain functional

## Management Access

### Web Interfaces:
- **OpenWrt**: http://192.168.1.2 (LuCI interface)
- **Proxmox**: https://192.168.1.10:8006 (PVE Web GUI)
- **OPNsense**: https://192.168.1.3 (Web GUI - via Proxmox VM)
- **Pi-hole**: http://192.168.1.5/admin (Admin interface)
- **OMV NAS**: http://192.168.1.9 (OpenMediaVault Web GUI)

### API Access:
- **OPNsense**: REST API for automation
- **Pi-hole**: JSON API for statistics and control
- **OpenWrt**: RPC API for configuration
- **OMV NAS**: REST API for storage management and monitoring

## Monitoring & Logging

### Log Aggregation:
- OPNsense: Firewall logs, traffic analytics
- Pi-hole: DNS query logs, blocking statistics
- OpenWrt: Connection logs, wireless statistics

### Key Metrics:
- Bandwidth utilization per device
- DNS query patterns and blocking rates
- Firewall rule effectiveness
- Wireless connection quality

## Maintenance Tasks

### Regular Maintenance:
- Update block lists on Pi-hole
- Review and update firewall rules
- Monitor traffic patterns and adjust shaping
- Check wireless performance and optimize

### Performance Optimization:
- Adjust traffic shaper parameters based on usage
- Optimize DNS cache settings
- Review and update blocking policies
- Monitor system resource usage

This infrastructure provides comprehensive network control with multiple layers of traffic management, security, and monitoring capabilities.

## System Specifications & Resource Summary

### Resource Allocation Overview
- **Total VM/Container CPU Cores**: ~75 allocated cores across all services
- **Total Memory Usage**: ~44GB across all active VMs and containers
- **Primary Storage**: ssd-4tb for VM/container storage and data
- **Network Throughput**: 2.5GbE LAN capacity, 1GbE WAN capacity
- **Service Count**: 1 primary VM (OPNsense) + 5 active LXC containers + 20+ Docker services

### Performance Characteristics
- **Concurrent Services**: 20+ containerized applications
- **Network Isolation**: Hardware-level WAN/LAN separation
- **Failover Capabilities**: Multiple DNS, network, and service redundancy layers
- **Monitoring Coverage**: Comprehensive logging across all network and application layers

## Service Health Status

### Critical Infrastructure Services
- ✅ **OPNsense Firewall** (VM 133): Primary network gateway and traffic control
- ✅ **Pi-hole DNS** (192.168.1.5): DNS filtering and ad blocking
- ✅ **OMV Storage Server** (192.168.1.9): Network attached storage and file sharing
- ✅ **Proxmox Host** (192.168.1.10): Virtualization infrastructure platform
- ✅ **OpenWrt Router** (192.168.1.2): Wireless access point and bridge

### Application Services Status
- ✅ **Immich Stack**: Photo/video management with AI recognition (healthy)
- ✅ **Supabase Stack**: Complete backend-as-a-service platform (mostly healthy)
- ⚠️ **Realtime Service**: WebSocket subscriptions currently unhealthy
- ⚠️ **Wallabag MariaDB**: Database connectivity issues requiring attention
- ✅ **Nginx Proxy Manager**: Reverse proxy and SSL certificate management
- ✅ **Portainer**: Docker container management interface
- ✅ **Uptime Kuma**: Service monitoring and alerting system

## Network Configuration Troubleshooting

### Common Bridge Configuration Issues

#### Issue: WAN Bridge Missing Physical Interface
**Symptom**: OPNsense VM has connectivity on LAN side but no WAN connectivity to internet.

**Root Cause**: The physical WAN NIC (`enp2s0f0`) was not properly added to the WAN bridge (`vmbr1`) during initial setup.

**Diagnosis Steps**:
```bash
# Check bridge configuration
brctl show vmbr1

# Expected result should show:
# bridge name    bridge id        STP enabled    interfaces
# vmbr1         8000.xxxxxxxxxxxx    no          enp2s0f0
#                                               tap133i1
```

**Resolution**:
```bash
# Add WAN NIC to WAN bridge
brctl addif vmbr1 enp2s0f0

# Verify configuration
brctl show vmbr1
```

**Verification**:
- Check OPNsense LAN connectivity: `ping 192.168.1.3`
- Verify web interface accessibility: `curl -k https://192.168.1.3`
- Confirm both VM tap interfaces are UP and in correct bridges

#### Persistent Configuration
The bridge configuration is already persistent in `/etc/network/interfaces`:
```
auto vmbr1
iface vmbr1 inet manual
    bridge-ports enp2s0f0
    bridge-stp off
    bridge-fd 0
```

**Note**: If the bridge configuration is correct in the interfaces file but not active, the interface may need to be manually added to the bridge after NIC activation or system restart.

### Network Interface Verification Commands

```bash
# Check all network interfaces status
ip link show

# Verify bridge port assignments
bridge link show | grep -E 'enp|tap133'

# Check specific bridge configuration
brctl show vmbr0  # LAN bridge
brctl show vmbr1  # WAN bridge

# Test OPNsense VM connectivity
ping 192.168.1.3
curl -k https://192.168.1.3

# Check VM tap interface status
ip link show tap133i0  # OPNsense LAN interface
ip link show tap133i1  # OPNsense WAN interface
```

This documentation should be referenced when setting up new Proxmox hosts or troubleshooting network connectivity issues with the OPNsense VM.

## Infrastructure Summary & Capabilities

This comprehensive network infrastructure delivers enterprise-grade capabilities through a carefully orchestrated combination of hardware isolation, virtualization, and layered security controls. The system provides:

### Core Network Control Features
- **Hardware-Isolated Traffic Paths**: Complete WAN/LAN separation via dedicated NICs
- **Multi-Layer Traffic Shaping**: OpenWrt (wireless) → OPNsense (firewall) → Pi-hole (DNS)
- **Comprehensive Monitoring**: Real-time visibility across all network and application layers
- **Automated Failover**: Built-in redundancy for critical services (DNS, routing, connectivity)

### Service Hosting Platform
- **Virtualized Infrastructure**: Proxmox-based with 75+ CPU cores and 44GB RAM allocation
- **Container Orchestration**: 20+ Docker services including full Supabase backend
- **Media & Content Management**: AI-powered photo management, e-book libraries, file sync
- **Business Applications**: JIRA, Confluence, mail server, custom web applications

### Security & Control Layers
- **Network Segmentation**: Hardware-level isolation with bridge-based traffic control  
- **DNS Filtering**: Ad-blocking, malware protection, custom domain policies
- **Traffic Analysis**: Comprehensive logging and analytics across all infrastructure layers
- **Access Control**: Time-based restrictions, bandwidth throttling, device-specific policies

### Operational Excellence
- **Centralized Management**: Web-based interfaces for all major components
- **Health Monitoring**: Automated service monitoring with alerting (Uptime Kuma)
- **Performance Optimization**: Dynamic resource allocation and traffic shaping
- **Maintenance Automation**: Scheduled updates, backup procedures, log rotation

This infrastructure serves as a robust foundation for both residential internet control and small business operations, providing the security, performance, and reliability typically found in enterprise environments while maintaining the flexibility and cost-effectiveness suitable for home use.