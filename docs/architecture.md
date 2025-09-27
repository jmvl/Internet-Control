# Traffic Throttling Architecture & Strategy

## Executive Summary

This document outlines the comprehensive strategy for implementing traffic throttling and bandwidth management across a three-tier network infrastructure utilizing OpenWrt, OPNsense, and Pi-hole components. The architecture provides multiple layers of control with redundancy, granular management, and best-practice implementation.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRAFFIC CONTROL LAYERS                      │
├─────────────────────────────────────────────────────────────────┤
│ Layer 1: OpenWrt (192.168.1.2) - Wireless QoS & SQM          │
│ Layer 2: OPNsense (192.168.1.3) - Firewall & Traffic Shaper  │
│ Layer 3: Pi-hole (192.168.1.5) - DNS Filtering & Rate Limit  │
└─────────────────────────────────────────────────────────────────┘
```

## Best-Practice Throttling Strategy

### 1. Layer 1: OpenWrt Wireless Control
**Purpose**: First-line wireless traffic management and bufferbloat mitigation
**Technology**: SQM (Smart Queue Management) with FQ-CoDel

#### Implementation Strategy:
```bash
# Primary Configuration
- Enable SQM on wireless interface
- Use cake or fq_codel algorithms
- Set bandwidth limits at 80-90% of actual capacity
- Configure per-station fairness
```

#### Key Features:
- **Automatic Bufferbloat Control**: SQM automatically manages queue depths
- **Fair Queuing**: Ensures no single device monopolizes bandwidth
- **Wireless-Specific Optimization**: Handles wireless medium characteristics
- **Low CPU Overhead**: Efficient implementation for embedded devices

#### Configuration Parameters:
```yaml
SQM Settings:
  Interface: wlan0
  Download Speed: 90% of ISP speed
  Upload Speed: 90% of ISP speed
  Queue Discipline: cake
  Link Layer: Ethernet with overhead
  Per-host Isolation: Enabled
```

### 2. Layer 2: OPNsense Centralized Traffic Management
**Purpose**: Comprehensive traffic shaping with time-based controls
**Technology**: IPFW/dummynet with HTB (Hierarchical Token Bucket)

#### Implementation Strategy:
```bash
# Hierarchical Bandwidth Control
1. Create Root Pipe (Total Bandwidth)
2. Create Child Pipes (Per-Device/Service)
3. Apply Time-Based Schedules
4. Implement Priority Queues
```

#### Core Components:

##### A. Pipe Configuration
```yaml
Root Pipe:
  Name: "Internet_Main"
  Bandwidth: 100% (e.g., 100 Mbps)
  Scheduler: FlowQueue-CoDel
  
Child Pipes:
  - Name: "Critical_Services"
    Bandwidth: 20% (guaranteed)
    Priority: High
    
  - Name: "Normal_Users"
    Bandwidth: 60% (guaranteed)
    Priority: Medium
    
  - Name: "Restricted_Devices"
    Bandwidth: 64 Kbps (throttled)
    Priority: Low
```

##### B. Time-Based Scheduling
```yaml
Schedules:
  - Name: "midnight_restriction"
    Time: "00:00-06:00"
    Days: "Mon,Tue,Wed,Thu,Fri,Sat,Sun"
    
  - Name: "business_hours"
    Time: "09:00-17:00"
    Days: "Mon,Tue,Wed,Thu,Fri"
    
  - Name: "evening_limit"
    Time: "20:00-23:59"
    Days: "Mon,Tue,Wed,Thu,Fri,Sat,Sun"
```

##### C. Device Classification
```yaml
Aliases:
  restricted_devices:
    - Rica_iPhone1: "f6:d0:95:cd:52:13"
    - Rica_iPhone2: "12:24:46:0c:b3:1d"
    - Rica_MacBook: "66:46:fb:9c:0a:0a"
    
  priority_devices:
    - Work_Laptop: "aa:bb:cc:dd:ee:ff"
    - Server: "11:22:33:44:55:66"
    
  normal_devices:
    - All other devices
```

#### Advanced Features:
- **Adaptive Bandwidth**: Dynamic adjustment based on network conditions
- **Application-Aware Shaping**: Different limits for different protocols
- **Burst Allowance**: Temporary bandwidth borrowing for short-duration traffic
- **Fail-Safe**: Fallback to basic rules if advanced features fail

### 3. Layer 3: Pi-hole DNS-Based Control
**Purpose**: Content filtering and DNS-level traffic control
**Technology**: DNS blocking with conditional forwarding

#### Implementation Strategy:
```bash
# DNS-Based Traffic Control
1. Time-based domain blocking
2. Conditional forwarding for local services
3. Rate limiting for abuse prevention
4. Custom DNS responses for throttled devices
```

#### Key Features:
- **Selective DNS Resolution**: Block specific domains during restriction periods
- **DNS Redirection**: Route certain domains to local servers
- **Query Rate Limiting**: Prevent DNS abuse attacks
- **Logging and Analytics**: Comprehensive query tracking

#### Configuration:
```yaml
DNS Blocking Lists:
  - Social Media: Block during restriction hours
  - Gaming: Limit to specific time windows
  - Streaming: Throttle during peak hours
  - Educational: Always allow
  
Rate Limiting:
  - Per-client: 50 queries/minute
  - Per-domain: 1000 queries/minute
  - Global: 10000 queries/minute
```

## Multi-Layer Throttling Implementation

### Scenario 1: Internet Addiction Control
**Objective**: Limit specific devices during midnight hours

#### Layer 1 (OpenWrt):
```bash
# Maintain normal SQM operation
# No device-specific restrictions at wireless level
```

#### Layer 2 (OPNsense):
```bash
# Primary control layer
- Create "restricted_devices" alias
- Apply 64 Kbps throttle during "midnight_restriction"
- Block social media ports (80, 443 to specific IPs)
- Allow local network access (192.168.1.0/24)
```

#### Layer 3 (Pi-hole):
```bash
# DNS-level enforcement
- Block entertainment domains (00:00-06:00)
- Allow essential services (email, news, emergency)
- Log all queries for monitoring
```

### Scenario 2: Bandwidth Fair-Share
**Objective**: Ensure equitable bandwidth distribution

#### Layer 1 (OpenWrt):
```bash
# SQM with per-station fairness
- Enable cake with "besteffort" mode
- Set bandwidth to 90% of actual capacity
- Enable per-host isolation
```

#### Layer 2 (OPNsense):
```bash
# Hierarchical bandwidth allocation
- Root pipe: 100% total bandwidth
- User pipes: 80% shared equally
- Priority pipe: 20% for critical services
```

#### Layer 3 (Pi-hole):
```bash
# No specific throttling
- Standard DNS resolution
- Monitor for abuse patterns
```

### Scenario 3: Quality of Service (QoS)
**Objective**: Prioritize critical applications

#### Layer 1 (OpenWrt):
```bash
# Application-aware SQM
- Video calls: High priority
- Gaming: Low latency queue
- Bulk downloads: Background priority
```

#### Layer 2 (OPNsense):
```bash
# Protocol-based shaping
- VoIP (SIP/RTP): Guaranteed 1 Mbps
- Video streaming: Limited to 5 Mbps per device
- P2P traffic: Throttled to 10% of total
```

#### Layer 3 (Pi-hole):
```bash
# Support QoS with DNS
- Fast resolution for priority services
- Slower resolution for entertainment
```

## Monitoring and Analytics

### Real-Time Monitoring
```yaml
OpenWrt:
  - Wireless connection quality
  - Per-device bandwidth usage
  - SQM queue statistics
  
OPNsense:
  - Traffic shaper statistics
  - Firewall rule hit counts
  - Bandwidth utilization graphs
  
Pi-hole:
  - DNS query patterns
  - Blocked domain statistics
  - Client query volumes
```

### Performance Metrics
```yaml
Key Performance Indicators:
  - Latency: <10ms for interactive traffic
  - Jitter: <5ms for real-time applications
  - Packet Loss: <0.1% under normal conditions
  - Bandwidth Utilization: 80-90% efficiency
  
Throttling Effectiveness:
  - Restriction Compliance: >95%
  - Bypass Attempts: <5%
  - User Satisfaction: Measured via surveys
```

## Implementation Phases

### Phase 1: Foundation (Week 1)
- Configure OpenWrt SQM for basic bufferbloat control
- Set up OPNsense traffic shaper with basic pipes
- Configure Pi-hole with standard block lists

### Phase 2: Advanced Features (Week 2)
- Implement time-based restrictions in OPNsense
- Configure device-specific throttling rules
- Set up DNS-based content filtering schedules

### Phase 3: Optimization (Week 3)
- Fine-tune SQM parameters based on usage patterns
- Optimize traffic shaper weights and priorities
- Implement adaptive DNS filtering

### Phase 4: Monitoring (Week 4)
- Deploy comprehensive monitoring solution
- Set up alerting for policy violations
- Create performance dashboards

## Failover and Redundancy

### Component Failure Scenarios:
```yaml
OpenWrt Failure:
  - Wired devices continue through OPNsense
  - Wireless connectivity lost
  - Fallback: Secondary wireless AP
  
OPNsense Failure:
  - Traffic bypasses to ISP router
  - No traffic shaping or firewall
  - Fallback: Basic router QoS
  
Pi-hole Failure:
  - DNS resolves via ISP servers
  - No content filtering
  - Fallback: Secondary Pi-hole or ISP DNS
```

### Redundancy Strategy:
- **High Availability**: CARP setup for OPNsense
- **Load Balancing**: Multiple Pi-hole instances
- **Backup Configuration**: Regular config backups
- **Monitoring**: Automated health checks

## Security Considerations

### Access Control:
- Management interfaces on separate VLANs
- API keys rotated regularly
- Strong authentication mechanisms
- Audit logging enabled

### Bypass Prevention:
- MAC address randomization detection
- VPN/proxy detection and blocking
- Alternative network access monitoring
- Physical device management

### Data Protection:
- Encrypted configuration backups
- Secure API communications
- Privacy-compliant logging
- Regular security updates

## Best Practices Summary

1. **Start Simple**: Begin with basic SQM and gradually add complexity
2. **Monitor Continuously**: Track performance and adjust accordingly
3. **Test Thoroughly**: Validate all configurations before deployment
4. **Document Everything**: Maintain comprehensive configuration records
5. **Regular Maintenance**: Update firmware and review configurations monthly
6. **User Communication**: Clearly explain restrictions and their purpose
7. **Flexibility**: Allow for reasonable exceptions and adjustments
8. **Backup Planning**: Maintain rollback capabilities for all changes

This architecture provides a robust, scalable, and maintainable solution for comprehensive traffic throttling and bandwidth management across your network infrastructure.