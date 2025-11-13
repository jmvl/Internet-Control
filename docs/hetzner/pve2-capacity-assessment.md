# PVE2 Capacity Assessment for Hetzner Migration

**Date**: 2025-10-30
**Assessment**: PVE2 can handle the Proxmox 3 migration

## PVE2 System Overview

**Access**: Via Tailscale @ 100.102.0.120 (`pve-home-asrock`)
**SSH**: `ssh root@pve2` (now configured to use Tailscale IP)

### Hardware & OS
- **Proxmox Version**: 8.4.14 (modern, LXC-based)
- **Kernel**: 6.8.12-15-pve (latest stable)
- **Uptime**: 11 days
- **Memory**: 62GB total, 33GB available (good headroom)
- **Swap**: 8GB (3.8GB used - acceptable)

### Storage Capacity

| Storage | Type | Total | Used | Available | Usage |
|---------|------|-------|------|-----------|-------|
| **local** | dir | 65GB | 39GB | 22GB | 60% |
| **local-lvm** | lvmthin | 130GB | 69GB | 67GB | 51% |
| **ssd-4tb** | dir | **3.9TB** | 896GB | **3TB** | 23% |

**Key Finding**: `ssd-4tb` has **3TB free** - more than enough for the ~88GB migration!

### Network
- **Tailscale VPN**: Active connection
- **Local Network**: 192.168.1.x
- **PBS Backups**: Two PBS instances offline (not critical for this migration)

## Migration Capacity Analysis

### Requirements (from Hetzner)
- **Source Data**: 88.4GB (8 OpenVZ containers)
- **Compressed Backups**: ~45-50GB estimated
- **Target LXC Containers**: ~100GB (with overhead)
- **Total Space Needed**: ~150GB

### PVE2 Capacity: ✅ EXCELLENT

**Recommended Storage Strategy**:
1. **Backup Storage**: Use `ssd-4tb` (3TB free - plenty of room)
   - Path: `/mnt/pve/ssd-4tb/hetzner-migration/`
   - Store all vzdump backups here

2. **Container Storage**: Use `local-lvm` (67GB free)
   - For smaller containers (< 10GB each)
   - CT 103, 101, 106, 107, 105, 108

3. **Large Container Storage**: Use `ssd-4tb`
   - CT 100 (MySQL - 57GB)
   - CT 102 (Tomcat - 21GB)

## Migration Compatibility

### Proxmox Versions
- **Source**: Proxmox 3.1-14 (2013) with OpenVZ
- **Target**: Proxmox 8.4.14 (2025) with LXC
- **Gap**: 12 years of technology evolution
- **Direct Migration**: ❌ NOT POSSIBLE
- **Manual Conversion**: ✅ REQUIRED

### OS Compatibility
- **Source Containers**: Debian 7 Wheezy (EOL 2018)
- **Target Templates**: Debian 12 Bookworm (current stable)
- **Migration Path**: Application-level migration recommended

## Resource Allocation Plan

### Proposed LXC Container Layout on PVE2

| CTID | Name | vCPU | RAM | Disk | Storage | Priority |
|------|------|------|-----|------|---------|----------|
| 200 | mysql | 4 | 8GB | 60GB | ssd-4tb | P0 |
| 201 | tomcat | 4 | 4GB | 30GB | local-lvm | P0 |
| 202 | nginx | 2 | 1GB | 5GB | local-lvm | P1 |
| 203 | redis | 2 | 2GB | 5GB | local-lvm | P2 |
| 204 | mail | 2 | 2GB | 10GB | local-lvm | P3 |

**Total Resources**:
- vCPU: 14 cores (PVE2 has capacity)
- RAM: 17GB (well within 33GB available)
- Disk: 110GB (67GB local-lvm + 60GB ssd-4tb)

**Modernization Note**: Combine memcached + hazelcast → Redis cluster

## Network Configuration

### Current Hetzner Setup
- **Public IP**: 167.235.9.103
- **Services**: Exposed to internet
- **Access**: Direct SSH

### Target PVE2 Setup
- **Network**: Private 192.168.1.x
- **Access**: Via Tailscale or internal network
- **Reverse Proxy**: Configure Nginx or Traefik for external access
- **Security**: Improved isolation

## Performance Considerations

### Hetzner Server (Source)
- **Uptime**: 765 days (2+ years)
- **Never rebooted**: Likely memory leaks/issues
- **Kernel**: 2.6.32 (ancient)
- **Performance**: Degraded over time

### PVE2 (Target)
- **Fresh Kernel**: 6.8.12 (modern)
- **LXC Overhead**: ~2-5% (vs OpenVZ ~1-2%)
- **Expected Performance**: Better due to modern kernel and regular maintenance

## Backup Strategy During Migration

### Phase 1: Create Backups on Hetzner
**Location**: `/var/lib/vz/dump/migration-20251030/`
**Estimated Size**: 45-50GB compressed
**Estimated Time**: 4-6 hours

### Phase 2: Transfer to PVE2
**Target**: `/mnt/pve/ssd-4tb/hetzner-migration/`
**Method**: rsync over SSH (via Tailscale)
**Estimated Time**: 2-4 hours (depends on network speed)
**Bandwidth**: Tailscale over internet (not LAN speed)

### Phase 3: Verify Integrity
**Method**: MD5 checksums
**Location**: MD5SUMS file in backup directory

## Risk Assessment

### Low Risk ✅
- **Storage Capacity**: 3TB free (20x what we need)
- **RAM**: 33GB available (2x what we'll use)
- **Proxmox Version**: Modern LXC support

### Medium Risk ⚠️
- **Transfer Time**: 4-6 hours over internet via Tailscale
- **Downtime**: Services offline during transfer (if needed immediately)
- **Application Compatibility**: Debian 7 → Debian 12 may need config updates

### Mitigated Risks
- **Data Loss**: Keep Hetzner online during entire migration
- **Rollback**: Original server stays active for 30+ days
- **Verification**: Checksum all transfers

## Recommendations

### ✅ GO Decision: Migration is FEASIBLE

**Strengths**:
1. Abundant storage capacity (3TB free)
2. Sufficient RAM (33GB available)
3. Modern Proxmox version (8.4.14)
4. Good network connectivity via Tailscale

**Proceed with**:
1. ✅ Phase 1: Create backups on Hetzner (can start immediately)
2. ✅ Phase 2: Transfer via Tailscale to PVE2 ssd-4tb
3. ✅ Phase 3: Manual LXC conversion (application-by-application)

### Alternative: Docker Compose Stack

Instead of 8 separate LXC containers, consider **single VM with Docker Compose**:
- Easier management
- Better portability
- Modern development workflow
- Simpler backup/restore

**Docker Compose Resource Requirements**:
- 1 VM: 8 vCPU, 16GB RAM, 120GB disk
- All services in containers
- Single backup point

## Next Steps

1. ✅ **PVE2 Capacity Confirmed** - Ready for migration
2. 🔄 **Start Phase 1** - Create vzdump backups on Hetzner
3. ⏳ **Phase 2** - Transfer backups to PVE2 (after Phase 1 completes)
4. ⏳ **Phase 3** - Convert to LXC containers

**Ready to proceed?** All systems are GO for migration! 🚀

## Commands Reference

### PVE2 Access
```bash
# SSH via Tailscale (now configured)
ssh root@pve2

# Web UI
https://100.102.0.120:8006
# or
https://pve2:8006
```

### Storage Paths
```bash
# ssd-4tb storage location
/mnt/pve/ssd-4tb/

# Create migration directory
mkdir -p /mnt/pve/ssd-4tb/hetzner-migration/
```

### Check Status Anytime
```bash
ssh root@pve2 'pvesm status && df -h /mnt/pve/ssd-4tb'
```
