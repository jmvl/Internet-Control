# IP Addressing Scheme - VLAN Management Interface Isolation

## Overview

This document defines the complete IP addressing scheme for the VLAN-based management interface isolation implementation. The design preserves existing addressing where possible while introducing new VLAN-specific subnets for security isolation.

## VLAN Architecture Summary

| VLAN ID | Network | Purpose | Gateway | DHCP Range | Static Range |
|---------|---------|---------|---------|------------|--------------|
| **1** | 192.168.1.0/24 | Legacy/Transitional | 192.168.1.3 | 192.168.1.50-200 | 192.168.1.1-49 |
| **10** | 192.168.10.0/24 | User Network | 192.168.10.1 | 192.168.10.50-200 | 192.168.10.1-49 |
| **100** | 192.168.100.0/24 | Management Network | 192.168.100.1 | Disabled | 192.168.100.1-254 |
| **20** | 192.168.20.0/24 | IoT Network | 192.168.20.1 | 192.168.20.50-100 | 192.168.20.1-49 |

## Management VLAN (100) - 192.168.100.0/24

### Infrastructure Services

| Service | IP Address | Interface | Purpose | Access Method |
|---------|------------|-----------|---------|---------------|
| **OPNsense Gateway** | 192.168.100.1 | vtnet0.100 | Inter-VLAN routing | Default gateway |
| **OpenWrt Management** | 192.168.100.2 | eth0.100 | Router administration | HTTPS: 192.168.100.2 |
| **OPNsense Management** | 192.168.100.3 | vtnet0.100 | Firewall administration | HTTPS: 192.168.100.3 |
| **Pi-hole Management** | 192.168.100.5 | eth0.100 | DNS administration | HTTP: 192.168.100.5/admin |
| **OMV Storage Management** | 192.168.100.9 | eth0.100 | Storage administration | HTTP: 192.168.100.9 |
| **Proxmox Management** | 192.168.100.10 | vmbr0.100 | VM/Container management | HTTPS: 192.168.100.10:8006 |

### Administrative Devices

| Device Type | IP Range | Assignment Method | Purpose |
|-------------|----------|-------------------|---------|
| **Admin Workstations** | 192.168.100.100-120 | Static | Primary management access |
| **Management Laptops** | 192.168.100.121-140 | Static/DHCP reserved | Mobile administration |
| **Emergency Devices** | 192.168.100.141-160 | Static | Backup access devices |
| **Monitoring Systems** | 192.168.100.161-180 | Static | Infrastructure monitoring |

### Service Port Mapping

| Service | Primary Port | Alternative Ports | Protocol | Description |
|---------|--------------|-------------------|----------|-------------|
| **SSH** | 22 | - | TCP | Secure shell access |
| **OPNsense Web** | 443 | 80 (redirect) | TCP | Firewall web interface |
| **Proxmox Web** | 8006 | - | TCP | Virtualization management |
| **Pi-hole Admin** | 80 | 443 (if configured) | TCP | DNS management interface |
| **OMV Admin** | 80 | 443 (if configured) | TCP | Storage management |
| **PostgreSQL** | 5432 | - | TCP | Database administration |
| **Uptime Kuma** | 3010 | - | TCP | Service monitoring |
| **Portainer** | 9443 | 8000 | TCP | Container management |

## User VLAN (10) - 192.168.10.0/24

### Network Services

| Service | IP Address | Interface | Purpose | User Access |
|---------|------------|-----------|---------|-------------|
| **User Gateway** | 192.168.10.1 | vtnet0.10 | Internet routing | Default gateway |
| **DNS Server** | 192.168.100.5 | - | DNS resolution | Primary DNS |
| **Backup DNS** | 1.1.1.1 | - | DNS backup | Secondary DNS |

### User Services

| Service | IP Address | Port | Purpose | Access URL |
|---------|------------|------|---------|------------|
| **OMV File Shares** | 192.168.10.9 | 445/2049 | Network file access | \\192.168.10.9\Pool |
| **Supabase API** | 192.168.10.20 | 8000 | Backend services | http://192.168.10.20:8000 |
| **Immich Photos** | 192.168.10.21 | 2283 | Photo management | http://192.168.10.21:2283 |
| **n8n Workflows** | 192.168.10.22 | 5678 | Automation platform | http://192.168.10.22:5678 |
| **Confluence Wiki** | 192.168.10.23 | 8090 | Documentation | http://192.168.10.23:8090 |
| **JIRA Issues** | 192.168.10.24 | 8080 | Issue tracking | http://192.168.10.24:8080 |

### User Devices

| Device Category | IP Range | Assignment | Typical Devices |
|-----------------|----------|------------|-----------------|
| **Laptops/Desktops** | 192.168.10.50-100 | DHCP | Work computers, personal laptops |
| **Mobile Devices** | 192.168.10.101-150 | DHCP | Smartphones, tablets |
| **Media Devices** | 192.168.10.151-180 | DHCP | Smart TVs, streaming devices |
| **Gaming Devices** | 192.168.10.181-200 | DHCP | Game consoles, gaming PCs |

## IoT VLAN (20) - 192.168.20.0/24

### Network Configuration

| Component | IP Address | Purpose | Restrictions |
|-----------|------------|---------|-------------|
| **IoT Gateway** | 192.168.20.1 | Internet routing | Limited bandwidth |
| **DNS Server** | 192.168.100.5 | DNS resolution | Filtered DNS queries |

### IoT Device Categories

| Device Type | IP Range | Assignment | Examples |
|-------------|----------|------------|----------|
| **Smart Home Hub** | 192.168.20.10-19 | Static | Home Assistant, SmartThings |
| **Security Cameras** | 192.168.20.20-39 | Static/Reserved | IP cameras, doorbells |
| **Smart Switches/Outlets** | 192.168.20.40-59 | DHCP | Smart plugs, wall switches |
| **Sensors** | 192.168.20.60-79 | DHCP | Temperature, motion, door sensors |
| **Entertainment IoT** | 192.168.20.80-100 | DHCP | Smart speakers, displays |

## Legacy VLAN (1) - 192.168.1.0/24 (Transitional)

### Infrastructure (During Transition)

| Service | IP Address | Status | Migration Target |
|---------|------------|--------|------------------|
| **OPNsense Gateway** | 192.168.1.3 | Active | Remains as backup |
| **OpenWrt Router** | 192.168.1.2 | Active | Dual-homed (1.2 + 100.2) |
| **Pi-hole DNS** | 192.168.1.5 | Active | Dual-homed (1.5 + 100.5) |
| **OMV Storage** | 192.168.1.9 | Active | Dual-homed (1.9 + 10.9) |
| **Proxmox Host** | 192.168.1.10 | Active | Dual-homed (1.10 + 100.10) |

### Transitional Device Pool

| Purpose | IP Range | Assignment | Timeline |
|---------|----------|------------|----------|
| **Legacy Devices** | 192.168.1.50-200 | DHCP | Gradual migration to VLAN 10 |
| **Infrastructure** | 192.168.1.1-49 | Static | Maintained during transition |

## DNS Configuration

### Primary DNS Server (Pi-hole)

| VLAN | DNS Server IP | Domain Suffix | Blocking Policy |
|------|---------------|---------------|-----------------|
| **Management** | 192.168.100.5 | mgmt.local | Minimal blocking |
| **User** | 192.168.100.5 | user.local | Standard ad/tracker blocking |
| **IoT** | 192.168.100.5 | iot.local | Aggressive blocking + IoT security |
| **Legacy** | 192.168.1.5 | lan.local | Current blocking policy |

### Local DNS Entries

```yaml
# Local hostname resolution
Management VLAN:
  opnsense.mgmt.local: 192.168.100.3
  proxmox.mgmt.local: 192.168.100.10
  pihole.mgmt.local: 192.168.100.5
  omv.mgmt.local: 192.168.100.9

User Services:
  files.user.local: 192.168.10.9
  photos.user.local: 192.168.10.21
  automation.user.local: 192.168.10.22
  wiki.user.local: 192.168.10.23
  issues.user.local: 192.168.10.24

IoT Services:
  hub.iot.local: 192.168.20.10
  cameras.iot.local: 192.168.20.20
```

## DHCP Configuration

### Management VLAN DHCP (Disabled)

```yaml
# Static assignments only for security
DHCP Status: DISABLED
Assignment Method: Manual static configuration
Lease Database: None
Reservations: None (use static IPs)
```

### User VLAN DHCP

```yaml
Network: 192.168.10.0/24
DHCP Range: 192.168.10.50 - 192.168.10.200
Gateway: 192.168.10.1
DNS Servers: 192.168.100.5, 1.1.1.1
Lease Time: 24 hours
Domain: user.local

Reserved Addresses:
  192.168.10.9: OMV file server (MAC: xx:xx:xx:xx:xx:xx)
  192.168.10.20: Supabase services (MAC: xx:xx:xx:xx:xx:xx)
  192.168.10.21: Immich photos (MAC: xx:xx:xx:xx:xx:xx)
  192.168.10.22: n8n automation (MAC: xx:xx:xx:xx:xx:xx)
```

### IoT VLAN DHCP

```yaml
Network: 192.168.20.0/24
DHCP Range: 192.168.20.50 - 192.168.20.100
Gateway: 192.168.20.1
DNS Servers: 192.168.100.5
Lease Time: 12 hours
Domain: iot.local

Options:
  - NTP Server: 192.168.20.1 (OPNsense)
  - Bandwidth Limit: 10% of total (via traffic shaping)
```

## Routing Configuration

### Inter-VLAN Routing Table

| Source VLAN | Destination VLAN | Policy | Ports Allowed | Purpose |
|-------------|------------------|--------|---------------|---------|
| **100 (Mgmt)** | **All VLANs** | ALLOW | All | Administrative access |
| **10 (User)** | **100 (Mgmt)** | ALLOW | 53 | DNS queries only |
| **10 (User)** | **10 (User)** | ALLOW | All | Intra-VLAN communication |
| **10 (User)** | **Internet** | ALLOW | All | Internet access |
| **10 (User)** | **20 (IoT)** | DENY | All | Security isolation |
| **20 (IoT)** | **100 (Mgmt)** | ALLOW | 53 | DNS queries only |
| **20 (IoT)** | **10 (User)** | DENY | All | Security isolation |
| **20 (IoT)** | **20 (IoT)** | ALLOW | Limited | IoT communication |
| **20 (IoT)** | **Internet** | ALLOW | 80,443 | Limited internet |

### Static Routes

```yaml
# Default routes per VLAN
Management VLAN: 0.0.0.0/0 via 192.168.100.1
User VLAN: 0.0.0.0/0 via 192.168.10.1
IoT VLAN: 0.0.0.0/0 via 192.168.20.1
Legacy VLAN: 0.0.0.0/0 via 192.168.1.3

# Cross-VLAN service routes (handled by OPNsense)
DNS Service: All VLANs → 192.168.100.5 via respective gateways
File Services: VLAN 10 → 192.168.10.9 direct
Photo Services: VLAN 10 → 192.168.10.21 direct
```

## Network Security Zones

### Zone Classification

| Zone | Trust Level | VLAN(s) | Security Policy |
|------|-------------|---------|-----------------|
| **Trusted** | High | 100 | Full access, minimal restrictions |
| **Internal** | Medium | 10 | Controlled access, user services allowed |
| **Restricted** | Low | 20 | Limited access, internet only |
| **Transitional** | Medium | 1 | Legacy support during migration |

### Security Boundaries

```yaml
Trusted → Internal: Allowed (administrative access)
Trusted → Restricted: Allowed (administrative access)
Internal → Trusted: Blocked (except DNS)
Internal → Restricted: Blocked (security isolation)
Restricted → Trusted: Blocked (except DNS)
Restricted → Internal: Blocked (security isolation)
```

## Migration Mapping

### Current to Target IP Mapping

| Current IP | Target IP | Service | Migration Method |
|------------|-----------|---------|------------------|
| 192.168.1.2 | 192.168.100.2 | OpenWrt Management | Add VLAN interface |
| 192.168.1.3 | 192.168.100.3 | OPNsense Management | Add VLAN interface |
| 192.168.1.5 | 192.168.100.5 | Pi-hole Management | Add VLAN interface |
| 192.168.1.9 | 192.168.10.9 | OMV User Services | Move to User VLAN |
| 192.168.1.9 | 192.168.100.9 | OMV Management | Add Management interface |
| 192.168.1.10 | 192.168.100.10 | Proxmox Management | Add VLAN interface |
| 192.168.1.20+ | 192.168.10.50+ | User devices | DHCP migration |

### Address Conservation

```yaml
# Preserve addressing where possible
Legacy Infrastructure: Maintain 192.168.1.x for compatibility
User Services: Move to 192.168.10.x for clarity
Management: Isolate on 192.168.100.x for security
IoT Devices: Segregate to 192.168.20.x for control

# Dual-homing during transition
Critical Services: Accessible on both legacy and new VLANs
Gradual Migration: Device-by-device movement to new VLANs
```

This IP addressing scheme provides clear separation between management and user traffic while preserving the existing three-tier traffic control architecture and allowing for gradual migration with minimal service disruption.