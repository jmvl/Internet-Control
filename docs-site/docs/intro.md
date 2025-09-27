---
sidebar_position: 1
---

# Internet Control Infrastructure

Welcome to the **Internet Control Infrastructure** documentation. This comprehensive system provides enterprise-grade network control, traffic management, and service hosting capabilities for modern home networks.

## What is Internet Control Infrastructure?

This repository contains a complete enterprise-grade home network infrastructure with multi-layer traffic control, including:

- **OpenWrt Multi-WiFi Throttling**: Production-ready shell scripts for selective bandwidth control across multiple WiFi interfaces
- **Three-Tier Network Architecture**: Hardware-isolated traffic control through OpenWrt → OPNsense → Pi-hole
- **Infrastructure-as-Code**: Complete Proxmox virtualization setup with automated backup/recovery
- **Container Platform**: Full Supabase stack + n8n automation + media services
- **Future Development**: Planned LuCI web module for GUI-based WiFi throttling management

## Key Features

### 🌐 Network Architecture
- **Hardware-Isolated Network Topology**: Complete WAN/LAN separation via dedicated NICs
- **Multi-Layer Traffic Shaping**: OpenWrt (wireless) → OPNsense (firewall) → Pi-hole (DNS)
- **Enterprise-Grade Security**: Virtualized firewall, DNS filtering, traffic monitoring

### 🔧 Traffic Control
- **Multi-WiFi Throttling**: Simultaneous bandwidth control across multiple wireless interfaces
- **SQM Integration**: Smart Queue Management with bufferbloat control
- **Time-Based Restrictions**: Automated scheduling with cron integration
- **Backup Networks**: Hidden emergency access networks unaffected by throttling

### 🐳 Container Platform
- **Supabase Full Stack**: PostgreSQL, Auth, Storage, REST API, Realtime, Edge Functions
- **Development Tools**: n8n workflow automation, GitLab CE, Portainer management
- **Media Services**: Immich photo management, Calibre e-books, Nginx Proxy Manager
- **Monitoring**: Uptime Kuma service monitoring, Netdata system metrics

### 🚀 Service Hosting
- **Virtualization Platform**: Proxmox with VM/container management
- **Storage Infrastructure**: RAID mirror + MergerFS unified storage (21TB capacity)
- **Business Applications**: JIRA, Confluence, mail server, file sharing
- **DevOps Pipeline**: GitLab CI/CD, Docker registry, automated deployments

## Getting Started

### Quick Navigation

- **[Infrastructure Overview](./infrastructure)**: Complete network topology and hardware setup
- **[Traffic Control Architecture](./architecture)**: Three-tier throttling strategy and implementation
- **[OpenWrt Multi-WiFi Throttling](./openwrt/openwrt-time-based-throttling-guide)**: Production-ready bandwidth control scripts
- **[Container Platform](./docker/overview)**: Supabase, n8n, and application services
- **[Monitoring & Management](./uptime-kuma/uptime-kuma-installation)**: Service health and performance tracking

### Emergency Access

For immediate network issues or emergency access:

1. **Hidden Backup Networks**: `Znutar_BACKUP` (2.4GHz) and `Znutar_2_BACKUP` (5GHz)
2. **Direct OPNsense Access**: https://192.168.1.3 (firewall management)
3. **Proxmox Console**: https://192.168.1.10:8006 (VM management)
4. **Service Recovery**: Check Quick Start Guide for recovery procedures

## Production Status

The infrastructure is **production-ready** with the following mature components:

✅ **OpenWrt Multi-WiFi Throttling**: Interactive setup, backup networks, multi-interface support<br/>
✅ **Three-Tier Traffic Control**: OpenWrt → OPNsense → Pi-hole layers active<br/>
✅ **Container Platform**: 20+ services including full Supabase stack<br/>
✅ **Storage Infrastructure**: 21TB NAS with RAID redundancy<br/>
✅ **Monitoring**: Comprehensive service monitoring and alerting<br/>
✅ **Backup & Recovery**: Automated backups with 10-30 minute recovery times

## Development Philosophy

This infrastructure prioritizes:

- **Defensive Security**: Traffic throttling for network management, not blocking
- **Hardware Isolation**: Physical NIC separation for true network segmentation
- **Container-First**: Microservices architecture with Docker orchestration
- **Documentation-Driven**: Comprehensive technical documentation for all services
- **Automation**: Infrastructure-as-code with automated deployment and recovery

Ready to explore? Start with the [Infrastructure Overview](./infrastructure) for a complete technical walkthrough.
