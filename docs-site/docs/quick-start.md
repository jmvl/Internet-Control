# Quick Start Guide

This guide provides essential commands and procedures for daily operations and emergency recovery of the Internet Control Infrastructure.

## Emergency Recovery & Daily Operations

### Multi-WiFi Throttling (OpenWrt)

#### Essential Commands
```bash
# Enable throttling with optional custom speeds
multi-wifi-throttle on

# Restore normal speeds for all WiFi
multi-wifi-throttle off

# Show current configuration and status
multi-wifi-throttle status
```

#### Backup Network Management
```bash
# Check hidden backup networks
backup-wifi status

# View connection instructions
backup-wifi guide

# Control backup networks
backup-wifi enable/disable
```

### Infrastructure Management

#### Proxmox Backup and Recovery
```bash
# Check backup status
ssh root@pve2 '/root/disaster-recovery/backup-status.sh'

# Create full system backup
ssh root@pve2 '/root/proxmox-bare-metal-backup.sh backup'

# Monitor backup health
ssh root@pve2 '/root/disaster-recovery/proxmox-backup-monitor.sh check'
```

#### Container Management (Docker host: 192.168.1.20)
```bash
# Check running containers
ssh root@192.168.1.20 'docker ps'

# Restart specific service
ssh root@192.168.1.20 'docker compose -f /path/to/compose.yml restart service-name'

# View container logs
ssh root@192.168.1.20 'docker compose -f /path/to/compose.yml logs -f service-name'
```

### Network Troubleshooting

#### Connectivity Tests
```bash
ping 192.168.1.3   # OPNsense firewall
ping 192.168.1.5   # Pi-hole DNS
ping 192.168.1.9   # OMV storage server
ping 192.168.1.10  # Proxmox host
ping 192.168.1.20  # Docker host
ping 192.168.1.33  # GitLab server
```

#### Service Health Checks
```bash
# OPNsense web interface
curl -k https://192.168.1.3

# Pi-hole admin panel
curl http://192.168.1.5/admin

# Proxmox web console
curl -k https://192.168.1.10:8006
```

## Supabase Development

### Local Development
```bash
# Start local Supabase stack
supabase start

# Reset local database with migrations
supabase db reset

# Generate TypeScript types
supabase gen types typescript

# Push local schema to remote
supabase db push
```

### Migration Management
```bash
# Create new migration
supabase migration new <name>

# Generate diff migration
supabase db diff --schema public

# Apply migrations
supabase db push
```

## Emergency Access

### Hidden Backup WiFi Networks

If main WiFi networks are throttled or unavailable:

1. **Znutar_BACKUP** (2.4GHz) - Hidden fallback network
2. **Znutar_2_BACKUP** (5GHz) - Hidden fallback network

Use standard WPA3 credentials for emergency access.

### Direct Management Access

#### Web Interfaces
- **OpenWrt**: http://192.168.1.2 (router management)
- **OPNsense**: https://192.168.1.3 (firewall/gateway)
- **Proxmox**: https://192.168.1.10:8006 (VM management)
- **Pi-hole**: http://192.168.1.5/admin (DNS management)
- **OMV NAS**: http://192.168.1.9 (storage management)

#### SSH Access
```bash
# OpenWrt router
ssh root@192.168.1.2

# Proxmox host
ssh root@192.168.1.10

# Docker host
ssh root@192.168.1.20

# GitLab server
ssh root@192.168.1.33
```

## Common Issues & Solutions

### WiFi Throttling Not Working
```bash
# Check SQM status on OpenWrt
ssh root@192.168.1.2 '/etc/init.d/sqm status'

# Verify interface configuration
ssh root@192.168.1.2 'uci show sqm'

# Restart SQM service
ssh root@192.168.1.2 '/etc/init.d/sqm restart'
```

### Container Services Down
```bash
# Check all container status
ssh root@192.168.1.20 'docker ps --all'

# Restart unhealthy containers
ssh root@192.168.1.20 'docker compose restart unhealthy-service'

# Check logs for errors
ssh root@192.168.1.20 'docker logs container-name'
```

### Network Connectivity Issues
```bash
# Check OPNsense firewall rules
# Access via https://192.168.1.3 → Firewall → Rules

# Verify DNS resolution
nslookup example.com 192.168.1.5

# Check routing table
ip route show
```

### Storage Issues
```bash
# Check filesystem health
ssh root@192.168.1.9 'df -h'

# RAID status check
ssh root@192.168.1.9 'btrfs filesystem show'

# MergerFS pool status
ssh root@192.168.1.9 'df -h /srv/mergerfs/MergerFS'
```

## Recovery Time Estimates

- **WiFi throttling changes**: Immediate (< 30 seconds)
- **Container service restart**: 1-3 minutes
- **VM recovery**: 5-10 minutes
- **Full Proxmox restore**: 10-30 minutes
- **Complete infrastructure rebuild**: 2-4 hours

## Monitoring Dashboard

Access **Uptime Kuma** at http://192.168.1.9:3010 for real-time service monitoring and health status of all infrastructure components.

## Support Resources

- **Infrastructure Overview**: [Infrastructure Documentation](./infrastructure)
- **Network Architecture**: [Architecture Guide](./architecture)
- **Container Platform**: [Docker Services](./docker/overview)
- **Service-Specific Docs**: Check individual service documentation in respective folders

For detailed troubleshooting procedures, refer to the specific service documentation or the comprehensive [Infrastructure Documentation](./infrastructure).