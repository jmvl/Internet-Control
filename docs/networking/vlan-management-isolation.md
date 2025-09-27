# VLAN Management Interface Isolation Strategy

## Executive Summary

This document outlines the strategy for implementing VLAN-based management interface isolation within the existing three-tier network infrastructure. The approach focuses on **Management Interface Isolation** rather than complete network segmentation, preserving operational functionality while enhancing security through targeted access controls.

## Architectural Philosophy

### Core Principle: Targeted Security Isolation

The key insight driving this strategy is that **home network environments require service accessibility alongside security**. Rather than implementing enterprise-style full network segmentation (which can break functionality), we focus on isolating what actually needs protection: management interfaces.

### What We Protect
- SSH access (port 22) to infrastructure hosts
- Web admin interfaces (OPNsense:443, Proxmox:8006, OMV:80, etc.)
- Direct database connections (port 5432)
- Infrastructure monitoring and management tools

### What We Preserve
- User access to legitimate services (Immich photos, n8n workflows, file shares)
- DNS resolution from all VLANs to Pi-hole
- Internet access through OPNsense gateway for all devices
- Three-tier traffic control architecture functionality

## VLAN Design Architecture

### VLAN Segmentation Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                 MANAGEMENT INTERFACE ISOLATION                  │
├─────────────────────────────────────────────────────────────────┤
│ Management VLAN 100: 192.168.100.0/24 - Admin Access Only     │
│ ├── OPNsense Admin (100.3:443)                                 │
│ ├── Proxmox Admin (100.10:8006)                                │
│ ├── OMV Admin (100.9:80)                                       │
│ ├── Pi-hole Admin (100.5:80)                                   │
│ └── Admin Workstation/Laptop                                   │
│                                                                 │
│ User VLAN 10: 192.168.10.0/24 - User Devices & Services       │
│ ├── All user devices (laptops, phones, tablets)                │
│ ├── User services (Immich UI, n8n workflows, file shares)      │
│ ├── Media streaming clients                                     │
│ └── Normal internet browsing                                   │
│                                                                 │
│ IoT VLAN 20: 192.168.20.0/24 - Smart Home Devices (Optional)  │
│ ├── Smart home devices                                          │
│ ├── Security cameras                                            │
│ └── IoT sensors                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Gateway Architecture

**OPNsense as Inter-VLAN Router:**
- **Management Gateway**: 192.168.100.1
- **User Gateway**: 192.168.10.1
- **IoT Gateway**: 192.168.20.1
- **Internet Gateway**: Maintains existing WAN configuration

This design allows OPNsense to continue serving as the central gateway and traffic control point while enforcing VLAN-based access policies.

## Inter-VLAN Routing Strategy

### Service Accessibility Matrix

| Service Category | Management VLAN | User VLAN | IoT VLAN | Reasoning |
|------------------|----------------|-----------|----------|-----------|
| **Core Network Services** |
| Pi-hole DNS (53) | ✅ | ✅ | ✅ | Required for all internet resolution |
| Internet Gateway | ✅ | ✅ | ✅ | Basic connectivity requirement |
| DHCP Services | ✅ | ✅ | ✅ | Automatic IP assignment |
| **User Services** |
| Immich Photos (2283) | ✅ | ✅ | ❌ | Photo management for users |
| n8n Workflows (5678) | ✅ | ✅ | ❌ | Automation platform access |
| File Shares (445/2049) | ✅ | ✅ | ❌ | SMB/NFS file access |
| Supabase Services (8000/3000) | ✅ | ✅ | ❌ | Backend services |
| Media Streaming | ✅ | ✅ | ❌ | Plex/Jellyfin access |
| **Management Interfaces** |
| SSH (22) | ✅ | ❌ | ❌ | Administrative access only |
| OPNsense Admin (443) | ✅ | ❌ | ❌ | Firewall management |
| Proxmox Admin (8006) | ✅ | ❌ | ❌ | VM/container management |
| OMV Admin (80) | ✅ | ❌ | ❌ | Storage management |
| Pi-hole Admin (80/admin) | ✅ | ❌ | ❌ | DNS management |
| Database Direct (5432) | ✅ | ❌ | ❌ | Database administration |
| **Monitoring & Infrastructure** |
| Uptime Kuma (3010) | ✅ | ❌ | ❌ | Service monitoring |
| Portainer (9443) | ✅ | ❌ | ❌ | Container management |
| Netdata/Monitoring | ✅ | ❌ | ❌ | System monitoring |

### Traffic Flow Patterns

#### Allowed Inter-VLAN Traffic
```yaml
# DNS Resolution (All VLANs → Pi-hole)
Source: 192.168.{10,20,100}.0/24
Destination: 192.168.100.5:53
Protocol: UDP/TCP
Purpose: DNS resolution for all devices

# Internet Access (All VLANs → Gateway)
Source: 192.168.{10,20,100}.0/24
Destination: 192.168.{10,20,100}.1
Protocol: Any
Purpose: Internet gateway routing

# User Services (User/Management VLANs → Service Hosts)
Source: 192.168.{10,100}.0/24
Destination: 192.168.10.{9,20,21,22}
Ports: 2283,5678,445,2049,8000,3000
Purpose: Legitimate user service access
```

#### Blocked Inter-VLAN Traffic
```yaml
# Management Interface Access (User/IoT VLANs → Management)
Source: 192.168.{10,20}.0/24
Destination: 192.168.100.0/24
Ports: 22,443,8006,80,5432,3010,9443
Purpose: Prevent unauthorized admin access

# Direct Inter-User VLAN Communication
Source: 192.168.10.0/24
Destination: 192.168.20.0/24
Protocol: Any
Purpose: Isolate user devices from IoT devices

# IoT to User Services
Source: 192.168.20.0/24
Destination: 192.168.10.0/24
Ports: 2283,5678,445,2049
Purpose: Prevent IoT devices accessing user data
```

## Three-Tier Traffic Control Preservation

### Layer 1: OpenWrt Wireless Control
**Current Functionality Preserved:**
- SQM (Smart Queue Management) continues to operate at WiFi interface level
- VLAN tagging doesn't affect wireless QoS capabilities
- Multi-WiFi throttling scripts remain fully functional
- Per-station fairness and bufferbloat control maintained

**Configuration Impact:**
```bash
# WiFi interfaces can be assigned to different VLANs
config wifi-iface
    option device 'radio0'
    option network 'user_vlan'      # Maps to VLAN 10
    option mode 'ap'
    option ssid 'Znutar'

config wifi-iface
    option device 'radio1'
    option network 'guest_vlan'     # Maps to VLAN 20
    option mode 'ap'
    option ssid 'Znutar_Guest'
```

### Layer 2: OPNsense Traffic Shaping & Routing
**Enhanced Functionality:**
- Acts as inter-VLAN router with multiple gateway addresses
- Traffic shaping rules can be applied per VLAN for granular control
- Firewall rules enforce the service accessibility matrix
- Maintains existing traffic control while adding security isolation

**VLAN-Specific Traffic Shaping:**
```yaml
# Management VLAN - High Priority, Full Bandwidth
VLAN 100:
  Priority: High
  Bandwidth: Unlimited
  QoS: Administrative traffic priority

# User VLAN - Normal Priority, Throttling Rules Apply
VLAN 10:
  Priority: Normal
  Bandwidth: Subject to existing throttling rules
  QoS: Fair queuing among users

# IoT VLAN - Low Priority, Limited Bandwidth
VLAN 20:
  Priority: Low
  Bandwidth: 10% of total (sufficient for IoT communication)
  QoS: Background traffic classification
```

### Layer 3: Pi-hole DNS Filtering
**Multi-VLAN DNS Services:**
- Pi-hole serves DNS requests from all VLANs (accessible on 192.168.100.5:53)
- DNS filtering policies can be customized per VLAN if needed
- Centralized logging and analytics maintained across all VLANs
- Conditional forwarding and local resolution preserved

**VLAN-Specific DNS Policies (Optional):**
```yaml
# Different blocking policies per VLAN
Management VLAN: Minimal blocking (admin needs access)
User VLAN: Standard ad/tracker blocking
IoT VLAN: Aggressive blocking + IoT-specific security lists
```

## Security Considerations

### Defense in Depth Strategy

**Network Layer Security:**
- VLAN isolation prevents lateral movement between network segments
- Firewall rules provide granular control over inter-VLAN communication
- Default deny policies with explicit allow rules for required services

**Access Control Security:**
- Management interfaces require authentication from authorized VLANs only
- Multi-factor authentication for critical management interfaces
- SSH key-based authentication with password authentication disabled
- Session timeouts and automatic logout for web interfaces

**Monitoring and Alerting:**
- Log all inter-VLAN traffic attempts (both allowed and blocked)
- Alert on unauthorized access attempts to management interfaces
- Monitor for unusual traffic patterns that might indicate compromise
- Track authentication failures and implement temporary IP blocking

### Risk Mitigation

**VLAN Hopping Prevention:**
- Disable DTP (Dynamic Trunking Protocol) on all switch ports
- Use explicit VLAN assignments rather than native VLANs where possible
- Regularly audit switch configurations for security compliance
- Monitor for unexpected VLAN memberships

**Bypass Prevention:**
- Block VPN/proxy detection on user VLANs where appropriate
- Monitor for MAC address randomization patterns
- Implement network access control (NAC) for device identification
- Regular security audits of firewall rules and access patterns

## Implementation Benefits

### Security Enhancements
1. **Reduced Attack Surface**: Management interfaces isolated from user devices
2. **Lateral Movement Prevention**: VLANs limit compromise propagation
3. **Access Control Granularity**: Service-level access policies
4. **Audit and Compliance**: Comprehensive logging of access attempts

### Operational Benefits
1. **Preserved Functionality**: All user services remain accessible
2. **Performance Maintenance**: Three-tier traffic control continues to operate
3. **Simplified Management**: Clear separation between user and admin networks
4. **Scalability**: Easy to add new VLANs or modify access policies

### Future Expansion Capabilities
1. **Guest Network Integration**: Easy to add isolated guest VLANs
2. **IoT Segmentation**: Smart home devices isolated from user data
3. **DMZ Implementation**: Public-facing services in dedicated VLAN
4. **VPN Integration**: Site-to-site or remote access VPN termination

## Conclusion

This VLAN management interface isolation strategy provides enterprise-grade security for management interfaces while preserving the functionality and performance characteristics of the existing three-tier network infrastructure. The approach is designed to be implementable in phases with minimal service disruption and includes comprehensive rollback procedures for risk mitigation.

The strategy addresses the fundamental security requirement (management interface protection) without the operational complexity of full network segmentation, making it ideal for sophisticated home network environments that need both security and functionality.