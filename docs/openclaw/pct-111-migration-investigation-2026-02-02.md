# PCT 111 Migration Investigation Report

**Date**: 2026-02-02
**Investigation**: Check for rsync operations related to PCT 111 migration
**Container**: PCT 111 (docker-debian)
**Status**: STOPPED

## Executive Summary

**FINDING**: No active rsync operations found, but PCT 111 migration appears to be **incomplete and in a problematic state**. The container has partial data on both the source LVM volume and the 4TB SSD target, with filesystem errors detected in system logs.

## Current State Assessment

### Container Status
- **PCT 111 (docker-debian)**: Currently STOPPED
- **Primary storage**: LVM volume `local-lvm:vm-111-disk-0` (110G) at `/dev/pve/vm-111-disk-0` → `/dev/dm-8`
- **Container is mounted** at `/mnt/vm-111-source` for investigation
- **Disk usage**: 77G used / 27G free (75% full)

### Storage Locations Found

#### 1. Primary LVM Volume (Active - 77GB)
- **Location**: `/mnt/vm-111-source` (mounted from `/dev/pve/vm-111-disk-0`)
- **Size**: 77GB used data
- **Status**: **MOUNTED and accessible**
- **Key directories**:
  - `/var/lib/docker`: 59GB (Docker containers and images)
  - `/data`: 5.1GB (application data)
  - `/root`: 5.8GB (user data)
  - `/opt`: 1.6GB (optional software)
  - `/usr`: 3.5GB (system files)

#### 2. 4TB SSD Target (Partial Copy - 78GB)
- **Location**: `/mnt/ssd_4tb/lxc/111`
- **Size**: 78GB (larger than source - likely includes stale data)
- **Status**: **PARTIAL copy, incomplete migration**
- **Last modified**: Dec 10 19:53 (old backup from previous migration attempt)
- **Key observation**: Docker data size matches (59GB) but timestamp is outdated

### Filesystem Errors Detected

**CRITICAL**: System logs show EXT4 filesystem errors on the PCT 111 LVM volume (`dm-8`):

```
EXT4-fs error (device dm-11): mpage_map_and_submit_extent:2308: inode #665553
EXT4-fs error (device dm-11): Failed to mark inode 665553 dirty
EXT4-fs error (device dm-11) in ext4_do_writepages:2724: IO failure
EXT4-fs error (device dm-11): ext4_journal_check_start:84: Detected aborted journal
EXT4-fs warning (device dm-8): ext4_clear_journal_err:6318: Filesystem error recorded from previous mount: IO failure
EXT4-fs (dm-8): warning: mounting fs with errors, running e2fsck is recommended
```

**Analysis**: These errors indicate:
- Previous I/O failures during write operations
- Journal filesystem corruption detected
- Filesystem mounted with errors (e2fsck recommended)

## Rsync Operations Status

### Running Processes
- **No active rsync processes** found
- Only kernel migration threads (CPU core balancing, not data migration)

### Bash History
- **No recent rsync commands** found in root's bash history
- No migration scripts found in `/root` directory

### Incomplete Files Found
- No `.rsync-partial` files detected
- Temporary files found are normal application cache files (Yarn, PostgreSQL snapshots)

## Configuration Analysis

### PCT 111 Configuration (`/etc/pve/lxc/111.conf`)
```conf
arch: amd64
cores: 12
memory: 20480
hostname: docker-debian
rootfs: local-lvm:vm-111-disk-0,size=110G  # Primary storage
mp0: /root/bak,mp=/mnt/bak                  # Mount point
net0: name=eth0,bridge=vmbr0,gw=192.168.1.3,hwaddr=BC:24:11:9D:3B:6C,ip=192.168.1.20/24,type=veth
features: nesting=1
```

**Key findings**:
- Container configured to use LVM storage, NOT the 4TB SSD
- No migration mount point configured
- Container IP: 192.168.1.20 (Docker host)

## Root Cause Analysis

### What Happened

1. **Previous Migration Attempt**: A partial rsync was performed to `/mnt/ssd_4tb/lxc/111` on Dec 10, 2025
2. **Incomplete Migration**: The rsync operation was interrupted or failed before completion
3. **Container Still on LVM**: PCT 111 continues running from the original LVM volume with filesystem errors
4. **No Automation**: No cron jobs or scripts found for ongoing migration

### Filesystem Corruption Source

The EXT4 errors on `dm-8` (PCT 111's LVM volume) suggest:
- Possible disk I/O issues during previous rsync operation
- Journal corruption from interrupted write operations
- **Requires filesystem check (e2fsck) with container STOPPED**

## Impact Assessment

### Current State
- **Container**: STOPPED (safe for maintenance)
- **Data**: Intact on LVM volume with filesystem errors
- **Backup**: Partial copy on 4TB SSD (outdated, Dec 10)

### Risks
1. **Filesystem Corruption**: EXT4 errors could lead to data loss if container started without fsck
2. **No Valid Backup**: 4TB SSD copy is incomplete and outdated
3. **Docker Services**: Container hosts critical services (Supabase, n8n, AI services) - currently unavailable

### Services Affected
PCT 111 hosts the Docker production platform with:
- **AI Services**: Agent Zero, Ollama LLM, Perplexica AI, OpenCode
- **Automation**: n8n 2.4.6 workflow automation
- **Applications**: Supabase Storage API, Karakeep bookmarks, Happy Server
- **Monitoring**: Netdata system monitoring

## Recommended Actions

### Immediate Priority 1: Filesystem Repair

```bash
# 1. Ensure container is stopped (already done)
pct status 111

# 2. Unmount the filesystem if mounted
umount /mnt/vm-111-source

# 3. Run filesystem check on LVM volume
e2fsck -f -y /dev/pve/vm-111-disk-0

# 4. Remount and verify
mount /dev/pve/vm-111-disk-0 /mnt/vm-111-source
```

### Priority 2: Complete Migration to 4TB SSD

```bash
# 1. Create fresh migration target
rm -rf /mnt/ssd_4tb/lxc/111
mkdir -p /mnt/ssd_4tb/lxc/111

# 2. Perform complete rsync with progress tracking
rsync -avh --progress /mnt/vm-111-source/ /mnt/ssd_4tb/lxc/111/

# 3. Verify migration integrity
rsync -avh --dry-run --delete /mnt/vm-111-source/ /mnt/ssd_4tb/lxc/111/

# 4. Update PCT 111 configuration to use 4TB SSD
# Edit /etc/pve/lxc/111.conf to point to new location
```

### Priority 3: Container Recovery

```bash
# 1. Start container after successful migration
pct start 111

# 2. Verify container services
pct exec 111 -- docker ps
pct exec 111 -- systemctl status

# 3. Check service connectivity
# (verify Supabase, n8n, and other services are accessible)
```

## Monitoring Recommendations

### Add Health Checks
1. **Filesystem monitoring**: Alert on EXT4 errors
2. **Storage monitoring**: Track LVM volume health
3. **Container monitoring**: Ensure PCT 111 stays running
4. **Migration monitoring**: Track rsync completion for future migrations

### Uptime Kuma Monitors
Create monitors for:
- PCT 111 container status: `pct status 111`
- Docker host reachability: ping 192.168.1.20
- Critical services: Supabase API, n8n web interface
- Filesystem errors: `journalctl -k | grep -i "EXT4-fs error"`

## Conclusion

**No active rsync operations were found**, but the PCT 111 migration is incomplete with filesystem errors on the source LVM volume. The container is currently stopped (safe state), but requires:

1. **Immediate**: Filesystem repair (e2fsck) on `/dev/pve/vm-111-disk-0`
2. **Short-term**: Complete migration to 4TB SSD with fresh rsync
3. **Long-term**: Update container configuration to use 4TB SSD as primary storage

The Docker production platform services remain unavailable until the container is recovered.

## Next Steps

1. Run `e2fsck -f -y /dev/pve/vm-111-disk-0` to repair filesystem
2. Complete fresh rsync to `/mnt/ssd_4tb/lxc/111/`
3. Update Proxmox storage configuration
4. Start container and verify all services
5. Document completion and update infrastructure database

---

**Investigation completed**: 2026-02-02
**Status**: Awaiting filesystem repair before proceeding with migration
