# Networking Documentation

This directory contains comprehensive networking documentation for the three-tier network infrastructure, with a focus on VLAN management interface isolation and security.

## Documentation Overview

### Core Strategy Documents
- **[vlan-management-isolation.md](vlan-management-isolation.md)** - Main architectural strategy for management interface isolation
- **[implementation-guide.md](implementation-guide.md)** - Step-by-step implementation procedures
- **[security-considerations.md](security-considerations.md)** - Security policies and access control requirements
- **[troubleshooting.md](troubleshooting.md)** - Common issues, solutions, and diagnostic procedures

### Reference Documentation
- **[reference/ip-addressing-scheme.md](reference/ip-addressing-scheme.md)** - Complete VLAN and IP allocation tables
- **[reference/service-access-matrix.md](reference/service-access-matrix.md)** - Service accessibility by VLAN and port-level access control
- **[reference/firewall-rules.md](reference/firewall-rules.md)** - OPNsense configuration snippets and rule examples
- **[reference/rollback-procedures.md](reference/rollback-procedures.md)** - Emergency recovery and rollback procedures

## Quick Navigation

### Current Infrastructure
- **Architecture**: See [../architecture.md](../architecture.md) for three-tier traffic control overview
- **Infrastructure**: See [../infrastructure.md](../infrastructure.md) for complete hardware and service documentation

### Implementation Status
- **Planning Phase**: VLAN management interface isolation strategy documented
- **Implementation Phase**: Ready for deployment following implementation guide
- **Security Phase**: Access control policies defined and ready for enforcement

## Key Concepts

### Management Interface Isolation
The primary goal is to isolate management interfaces (SSH, web admin panels) while maintaining normal service accessibility and preserving the three-tier traffic control architecture.

### Three-Tier Traffic Control Preservation
- **Layer 1 (OpenWrt)**: SQM continues at WiFi interface level
- **Layer 2 (OPNsense)**: Inter-VLAN routing + per-VLAN traffic shaping
- **Layer 3 (Pi-hole)**: DNS filtering for all VLANs

### VLAN Strategy
- **Management VLAN 100**: 192.168.100.0/24 - Admin access only
- **User VLAN 10**: 192.168.10.0/24 - All user devices and services
- **IoT VLAN 20**: 192.168.20.0/24 - Smart home devices (optional)

## Related Documentation
- [OpenWrt Documentation](../openwrt/) - WiFi throttling and wireless management
- [OPNsense Documentation](../OPNsense/) - Firewall and traffic shaping configuration
- [Infrastructure Overview](../infrastructure.md) - Complete network topology and services