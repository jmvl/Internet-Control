# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Reading First
- **Infrastructure Overview**: `/docs/infrastructure.md` - Complete network architecture documentation
- **Quick Start Guide**: `QUICK-START.md` - Emergency recovery and daily operations
- **Architecture Details**: `/docs/architecture.md` - Traffic control strategy and implementation

## Project Overview

This repository contains a comprehensive enterprise-grade home network infrastructure with multi-layer traffic control, including:

- **Three-Tier Network Architecture**: Hardware-isolated traffic control through OpenWrt → OPNsense → Pi-hole
- **Infrastructure-as-Code**: Complete Proxmox virtualization setup with automated backup/recovery
- **Container Platform**: Full Supabase stack + n8n automation + media services

## Documentation Architecture
All infrastructure services are documented in organized subdirectories:
- `/docs/` - Main documentation hub with service-specific subdirectories
- `/docs/OPNsense/`, `/docs/Supabase/`, `/docs/docker/` etc. - Service-specific docs
- **Discovery Protocol**: When encountering undocumented services, create comprehensive technical documentation in the appropriate `/docs/` subdirectory

### Confluence Documentation Server
**IMPORTANT - Atlassian MCP Configuration**:
- **Confluence URL**: `https://confluence.accelior.com`
- **Configuration Source**: MCP server configured via Claude Code's Atlassian MCP integration
- **Spaces Available**: INFRA, and others
- ⚠️ **CRITICAL**: Always use the exact URL `https://confluence.accelior.com` - DO NOT hallucinate or guess other URLs
- When posting documentation to Confluence, use the `confluence-doc-expert` agent with proper space and page parameters
- All technical documentation created in `/docs/` subdirectories should be mirrored to appropriate Confluence spaces for team access

## Key Commands

w
### Infrastructure Management
```bash
# Proxmox backup and recovery
ssh root@pve2 '/root/disaster-recovery/backup-status.sh'
ssh root@pve2 '/root/proxmox-bare-metal-backup.sh backup'
ssh root@pve2 '/root/disaster-recovery/proxmox-backup-monitor.sh check'

# Container management (Docker host: 192.168.1.20)
ssh root@192.168.1.20 'docker ps'
ssh root@192.168.1.20 'docker compose -f /path/to/compose.yml up -d'

# Network troubleshooting
ping 192.168.1.3   # OPNsense firewall
ping 192.168.1.5   # Pi-hole DNS
ping 192.168.1.9   # OMV storage server
```

### Supabase Development
```bash
# Local development (from /supabase directory)
supabase start                    # Start local Supabase stack
supabase db reset                 # Reset local database with migrations
supabase gen types typescript    # Generate TypeScript types
supabase db push                  # Push local schema to remote

# Migration management
supabase migration new <name>     # Create new migration
supabase db diff --schema public  # Generate diff migration
```

## Architecture Overview

### Hardware-Isolated Network Topology
This infrastructure implements enterprise-grade hardware isolation with dedicated NICs for complete WAN/LAN separation:

**Physical Network Separation**:
- **WAN NIC**: RTL8111 1GbE (enp2s0f0) → Direct internet connection
- **LAN NIC**: RTL8125 2.5GbE (enp1s0) → Internal network traffic
- **Bridge Architecture**: vmbr1 (WAN) and vmbr0 (LAN) provide complete isolation
- **OPNsense Dual NIC**: VM acts as gateway between isolated network segments

**Three-Tier Traffic Control**:
```
Internet → [OpenWrt] → [OPNsense] → [Pi-hole] → LAN Clients
          ↓           ↓             ↓
      Layer 1:    Layer 2:     Layer 3:
   Wireless QoS  Firewall &   DNS Filtering
   SQM Control   Traffic      Rate Limiting
                 Shaping
```
### Container Platform (192.168.1.20)
**Supabase Full Stack**:
- **PostgreSQL 15.8.1** with pgvecto-rs vector support
- **Auth Service** + **Storage API** + **REST API** (PostgREST)
- **Kong Gateway** (ports 8000/8443) for API management
- **Edge Functions** (Deno-based serverless runtime)
- **Realtime Service** (WebSocket subscriptions) - ⚠️ Currently unhealthy

**Development & Automation**:
- **n8n** (port 5678) - Workflow automation platform
- **Gotenberg** - Document conversion service
- **Analytics Stack** (Logflare, Vector, ImgProxy)

### Storage Infrastructure (192.168.1.9)
**Dual-Tier Storage Architecture**:
- **BTRFS RAID Mirror**: 3.7TB (sdb + sde) for critical data with redundancy
- **MergerFS Pool**: 18TB unified storage (sdc + sdd + sdf) for bulk data
- **System Drive**: 240GB SSD for OS and applications

**Container Services**:
- **Immich Stack**: AI-powered photo management with PostgreSQL + Redis + ML engine
- **Media Management**: Calibre e-books, Nginx Proxy Manager, Syncthing sync
- **Monitoring**: Uptime Kuma service monitoring, Portainer container management

### Common Troubleshooting Patterns
- **Interface Detection Issues**: Check `iw dev` output vs UCI wireless configuration
- **SQM Configuration**: Verify with `uci show sqm` and `/etc/init.d/sqm status`
- **Cron Scheduling**: Test with `crontab -l` and `logread | grep "Multi-WiFi-Throttle"`
- **UCI Persistence**: Confirm changes with `uci commit` and router reboot testing

## Tooling for Shell Interactions
Use modern CLI tools for efficient shell operations:
- **Finding FILES**: Use `fd` (fast file discovery)
- **Finding TEXT/strings**: Use `rg` (ripgrep for text search)
- **Finding CODE STRUCTURE**: Use `ast-grep` (AST-based code search)
- **Selecting from multiple results**: Pipe to `fzf` (fuzzy finder)
- **Interacting with JSON**: Use `jq` (JSON processor)
- **Interacting with YAML or XML**: Use `yq` (YAML/XML processor)