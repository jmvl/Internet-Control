# OPNsense Firewall & Traffic Management

OPNsense serves as the central network security and traffic management hub in our three-tier architecture, running as a virtualized VM (ID: 133) on the Proxmox host.

## Overview

**Role**: Network Security & Traffic Management Hub
**IP Address**: 192.168.1.3
**VM Configuration**: Dual NIC setup with WAN/LAN isolation
**Resource Allocation**: 6 CPU cores, 3.6GB RAM

## Primary Functions

### 🔥 Firewall & Security
- **Stateful Packet Inspection**: Advanced firewall rules and access control
- **Intrusion Detection**: Suricata IDS/IPS integration for threat detection
- **VPN Gateway**: OpenVPN and IPsec server capabilities
- **Network Monitoring**: Comprehensive logging and traffic analysis

### 🚦 Traffic Management
- **Traffic Shaper**: Hierarchical token bucket (HTB) traffic control
- **Bandwidth Throttling**: Per device/IP/MAC address control
- **Time-Based Restrictions**: Scheduled traffic policies
- **QoS Policies**: Priority queues for different traffic types

### 🌐 Network Services
- **DHCP Server**: Dynamic IP assignment with reservations
- **Load Balancing**: Multi-WAN support and failover capabilities
- **DNS Forwarding**: Integration with Pi-hole for DNS filtering
- **Gateway Services**: Primary route between WAN and LAN networks

## Network Architecture Integration

### Dual NIC Configuration
```yaml
WAN Interface:
  Physical: tap133i1 → vmbr1 → enp2s0f0 → Internet
  Purpose: Direct internet connection
  Security: Exposed to external threats

LAN Interface:
  Physical: tap133i0 → vmbr0 → enp1s0 → Internal Network
  IP: 192.168.1.3/24
  Purpose: Internal network gateway
```

### Traffic Flow Integration
```
Internet → WAN Interface → OPNsense Firewall → LAN Interface → Internal Network
                      ↓
                Traffic Shaper → Pi-hole DNS → Client Devices
```

## Key Features

### Traffic Control Capabilities
- **Hierarchical Bandwidth Management**: Root pipes with child allocations
- **Device-Specific Throttling**: MAC/IP-based bandwidth limits
- **Application-Level Shaping**: Protocol-specific traffic control
- **Burst Allowance**: Temporary bandwidth borrowing for short bursts
- **Adaptive Control**: Dynamic adjustment based on network conditions

### Time-Based Policies
```yaml
Midnight Restriction (00:00-06:00):
  - Throttle specific devices to 64 Kbps
  - Block social media ports
  - Maintain local network access

Business Hours (09:00-17:00):
  - Priority for work-related traffic
  - Guaranteed bandwidth for critical services

Evening Limits (20:00-23:59):
  - Fair-share bandwidth distribution
  - Gaming and streaming controls
```

### Device Classification
```yaml
Priority Devices:
  - Work laptops: Guaranteed bandwidth
  - Servers: High-priority traffic
  - Critical infrastructure: Always-on access

Normal Devices:
  - General computing: Fair-share allocation
  - Media streaming: Rate-limited during peak

Restricted Devices:
  - Specific devices: Time-based throttling
  - Guest devices: Limited bandwidth allocation
```

## Configuration Management

### Web Interface Access
- **URL**: https://192.168.1.3
- **Features**: Complete firewall management, traffic shaping, monitoring
- **Dashboard**: Real-time network statistics and rule management

### API Integration
- **REST API**: Programmatic control and automation
- **Monitoring**: Integration with external monitoring systems
- **Automation**: Scheduled rule updates and policy changes

### Backup & Recovery
```bash
# Configuration backup
# Access via OPNsense Web UI → System → Configuration → Backups

# Emergency access via Proxmox console
# Proxmox Web UI → VM 133 → Console
```

## Traffic Shaping Configuration

### Pipe Hierarchy Example
```yaml
Root Pipe: "Internet_Main"
  Bandwidth: 100 Mbps total
  Scheduler: FlowQueue-CoDel

Child Pipes:
  Critical_Services:
    Bandwidth: 20% guaranteed
    Priority: High

  Normal_Users:
    Bandwidth: 60% guaranteed
    Priority: Medium

  Restricted_Devices:
    Bandwidth: 64 Kbps max
    Priority: Low
```

### Firewall Rules Integration
- **Traffic Classification**: Automatic packet marking for shaping
- **Rule Ordering**: Priority-based rule processing
- **Exception Handling**: Emergency access bypass rules
- **Logging**: Comprehensive rule hit tracking

## Monitoring & Analytics

### Real-Time Statistics
- **Bandwidth Utilization**: Per-interface and per-device metrics
- **Traffic Patterns**: Protocol and application analysis
- **Rule Effectiveness**: Firewall rule hit counts and performance
- **System Resources**: CPU, memory, and network interface utilization

### Historical Data
- **Traffic Logs**: Long-term bandwidth usage patterns
- **Security Events**: Firewall blocks and IDS alerts
- **Performance Metrics**: System health and response times
- **Policy Compliance**: Restriction effectiveness tracking

## Security Considerations

### Network Segmentation
- **DMZ Configuration**: Isolated network zones for different device types
- **VLAN Support**: Virtual network separation capabilities
- **Guest Network Isolation**: Separate network for temporary access

### Threat Protection
- **IDS/IPS**: Real-time intrusion detection and prevention
- **Geo-blocking**: Country-based access restrictions
- **DDoS Protection**: Rate limiting and connection tracking
- **VPN Security**: Encrypted remote access capabilities

## High Availability & Redundancy

### Failover Configuration
```yaml
Primary Scenario:
  OPNsense Active: Full traffic control and security

Failure Scenario:
  Bypass Mode: Direct routing via ISP router
  Limitations: No traffic shaping or advanced firewall
  Recovery: Automatic or manual VM restart
```

### Backup Strategies
- **Configuration Backups**: Automated daily backups
- **VM Snapshots**: Pre-change system state preservation
- **Hardware Redundancy**: Proxmox host redundancy planning

## Performance Optimization

### Resource Allocation
- **CPU Cores**: 6 dedicated cores for traffic processing
- **Memory**: 3.6GB RAM for rule processing and logging
- **Storage**: SSD-backed for optimal performance

### Network Optimization
- **Buffer Sizing**: Optimized for traffic shaping performance
- **Queue Management**: Efficient packet processing algorithms
- **Connection Tracking**: Optimized for high-connection environments

## Troubleshooting

### Common Issues
```bash
# Check firewall status
# Web UI → System → Activity

# Verify traffic shaper operation
# Web UI → Traffic Shaper → Statistics

# Monitor network interfaces
# Web UI → Interfaces → Status

# Review system logs
# Web UI → System → Log Files
```

### Emergency Procedures
1. **VM Console Access**: Direct access via Proxmox
2. **Configuration Reset**: Factory defaults if needed
3. **Backup Restoration**: Restore from known-good configuration
4. **Network Bypass**: Direct ISP router connection if critical

## Integration Points

### Pi-hole DNS Integration
- **DNS Forwarding**: All DNS queries routed to Pi-hole (192.168.1.5)
- **Custom Overrides**: Local domain resolution support
- **Conditional Forwarding**: Local network name resolution

### Proxmox Host Coordination
- **Network Bridges**: Seamless integration with vmbr0/vmbr1
- **Resource Management**: Dynamic resource allocation
- **Backup Integration**: VM-level backup and snapshot coordination

### Monitoring Integration
- **Uptime Kuma**: Service health monitoring at http://192.168.1.9:3010
- **Log Aggregation**: Centralized logging via external systems
- **Performance Metrics**: Integration with network monitoring tools

For detailed configuration procedures and advanced features, refer to the official OPNsense documentation and the specific setup guides in this documentation section.