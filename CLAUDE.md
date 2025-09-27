# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Reading First
- **Infrastructure Overview**: `/docs/infrastructure.md` - Complete network architecture documentation
- **Quick Start Guide**: `QUICK-START.md` - Emergency recovery and daily operations
- **Architecture Details**: `/docs/architecture.md` - Traffic control strategy and implementation

## Project Overview

This repository contains a comprehensive enterprise-grade home network infrastructure with multi-layer traffic control, including:

- **OpenWrt Multi-WiFi Throttling**: Production-ready shell scripts for selective bandwidth control across multiple WiFi interfaces
- **Three-Tier Network Architecture**: Hardware-isolated traffic control through OpenWrt → OPNsense → Pi-hole
- **Infrastructure-as-Code**: Complete Proxmox virtualization setup with automated backup/recovery
- **Container Platform**: Full Supabase stack + n8n automation + media services
- **Future Development**: Planned LuCI web module for GUI-based WiFi throttling management

## Documentation Architecture
All infrastructure services are documented in organized subdirectories:
- `/docs/` - Main documentation hub with service-specific subdirectories
- `/docs/OPNsense/`, `/docs/Supabase/`, `/docs/docker/` etc. - Service-specific docs
- **Discovery Protocol**: When encountering undocumented services, create comprehensive technical documentation in the appropriate `/docs/` subdirectory

## Key Commands

### Multi-WiFi Throttling (OpenWrt)
```bash
# Initial setup (interactive configuration)
./openwrt_multi_wifi_throttle.sh

# Create backup hidden WiFi networks (emergency access)
./openwrt_backup_wifi_setup.sh

# Once installed on router, these commands are available:
multi-wifi-throttle on     # Enable throttling with optional custom speeds
multi-wifi-throttle off    # Restore normal speeds for all WiFi
multi-wifi-throttle status # Show current configuration and status

# Backup network management
backup-wifi status         # Check hidden backup networks
backup-wifi guide          # View connection instructions
backup-wifi enable/disable  # Control backup networks
```

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

### OpenWrt Multi-WiFi Throttling Architecture
The core throttling system uses a **master-slave pattern** with centralized SQM control:

**Script Architecture**:
- **Master Scripts**: `/root/scripts/multi_wifi_throttle.sh` and `/root/scripts/multi_wifi_normal.sh`
- **Interface Detection**: Dynamic discovery using `iw dev` and UCI wireless configuration
- **SQM Backend**: Individual SQM instances per WiFi interface (e.g., `wifi_phy0ap0`, `wifi_phy1ap0`)
- **Cron Integration**: Time-based scheduling with automated throttle/restore cycles
- **Safety Features**: Backup hidden WiFi networks unaffected by throttling

**Key Design Patterns**:
1. **Interface Abstraction**: UCI configuration names mapped to physical interfaces
2. **Atomic Operations**: Stop SQM → Update config → Restart SQM for consistent state
3. **Logging Integration**: All operations logged via `logger` for system visibility
4. **Idempotent Scripts**: Can be run multiple times safely without side effects

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

## Development Context & Patterns

### Current Production State
The WiFi throttling system is **production-ready** with the following mature components:
- **Interactive Setup Wizard**: `openwrt_multi_wifi_throttle.sh` with guided configuration
- **Backup WiFi Creation**: `openwrt_backup_wifi_setup.sh` for emergency access networks
- **Multi-Interface Support**: Simultaneous control of multiple WiFi radios/interfaces
- **SQM Integration**: Deep integration with OpenWrt's Smart Queue Management
- **Automated Scheduling**: Cron-based time restrictions with logging
- **Status Monitoring**: Comprehensive real-time status and control capabilities

### Script Architecture Patterns
**Configuration Management**:
- UCI-based configuration persistence (`uci set/get/commit`)
- Template-based script generation with placeholder replacement
- Atomic configuration updates (stop → configure → start)

**Error Handling & Safety**:
- Root privilege validation before execution
- Interface existence checking before configuration
- Graceful fallback for missing UCI values
- Comprehensive logging via `logger` command

**State Management**:
- SQM instance naming convention: `wifi_$(echo $iface | tr -d '-')`
- Separate UCI sections per WiFi interface for independent control
- Cron job management with backup and restoration of schedules

### Future Development (LuCI Module)
**PRD-Defined Roadmap** (`docs/prd.md`):
- **LuCI Web Interface**: Browser-based GUI following OpenWrt MVC architecture
- **Real-time Monitoring**: Live bandwidth graphs and status updates
- **Advanced Scheduling**: Visual time picker with complex rule configuration
- **Mobile-Responsive Design**: Touch-friendly controls for mobile management
- **API Integration**: RESTful API for automation and third-party integration

### Key Development Considerations

**OpenWrt Platform Requirements**:
- Target: OpenWrt 21.02+ with SQM support
- Dependencies: `sqm-scripts`, `luci-app-sqm`, `ip-full`, `iw`
- Testing: Always verify with `/etc/init.d/sqm status` and `uci show sqm`

**Security & Safety**:
- **Defensive Purpose**: Bandwidth throttling for parental controls and network management
- **No Blocking**: Speed limitation, not access blocking (emergency access maintained)
- **Backup Networks**: Hidden SSIDs unaffected by throttling for emergency access
- **Input Validation**: All user inputs sanitized and validated

**Infrastructure Integration**:
- **Proxmox Backup**: 10-30 minute recovery times for configuration disasters
- **Multi-Layer Control**: Coordination with OPNsense traffic shaping and Pi-hole DNS filtering
- **Monitoring Integration**: Uptime Kuma monitoring, centralized logging via rsyslog

### Development Workflow
1. **Testing**: Use Proxmox VM environment for safe testing
2. **Backup**: Always backup UCI configuration before changes (`uci export > backup.uci`)
3. **Validation**: Test interface detection with `iw dev` and `uci show wireless`
4. **Verification**: Confirm SQM status and cron scheduling after deployment
5. **Documentation**: Update service-specific docs in `/docs/` subdirectories

### Common Troubleshooting Patterns
- **Interface Detection Issues**: Check `iw dev` output vs UCI wireless configuration
- **SQM Configuration**: Verify with `uci show sqm` and `/etc/init.d/sqm status`
- **Cron Scheduling**: Test with `crontab -l` and `logread | grep "Multi-WiFi-Throttle"`
- **UCI Persistence**: Confirm changes with `uci commit` and router reboot testing