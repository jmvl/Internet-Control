# PVE2 Backup Investigation - Root Cause Analysis

**Date**: 2026-02-05
**Host**: pve2 (192.168.1.10)
**Issue**: Backup health checks revealing multiple failures

## Executive Summary

Investigation of PVE2 backup failures revealed **three critical issues**:

1. **Boot disk backup failure** - Incorrect boot device configured (`/dev/sda` is 3.6TB data drive, not boot disk)
2. **Remote sync not configured** - Sync function exists but never called by cron jobs
3. **Recovery scripts and checksums not generated** - Only config backups running via cron, not full backups

## Detailed Findings

### Issue 1: Boot Disk Backup Failure (Size Check)

**Problem**: Backup size is 650M (below 1GB threshold)

**Root Cause**: The backup script is configured with the wrong boot device:
- **Script configuration**: `BOOT_DEVICE="/dev/sda"` (line 25 of comprehensive backup script)
- **Actual /dev/sda**: 3.6TB data drive mounted at `/mnt/ssd_4tb` (storage backup target)
- **Actual boot device**: Not `/dev/sda` - needs identification

**Evidence**:
```bash
lsblk /dev/sda
NAME MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda    8:0    0  3.6T  0 disk /mnt/ssd_4tb
```

The boot disk backup function (`run_boot_disk_backup`) attempts to image `/dev/sda`, which would fail or create an enormous 3.6TB image. This is why:
- `boot-disk/` directory exists but is **empty** (0 bytes)
- No boot disk images or checksums are created
- Backup size is only 650M (config backup only)

**Impact**:
- No boot disk backup available for disaster recovery
- Cannot restore from bare metal backup alone if boot disk fails

### Issue 2: Integrity Check Failures

**Missing Files**:
1. `boot-disk/` checksums - Empty directory, no files to checksum
2. `scripts/comprehensive-restore.sh` - Not created
3. `verification/integrity-check.txt` - Not created

**Root Cause**: The cron job only runs **config backups**, not full backups:

**Current Cron Configuration**:
```bash
# Daily configuration backup at 2 AM
0 2 * * * /root/disaster-recovery/proxmox-comprehensive-backup.sh config >> /var/log/proxmox-backup/config-backup.log 2>&1

# Weekly full backup at 3 AM on Sunday
0 3 * * 0 /root/disaster-recovery/proxmox-comprehensive-backup.sh full >> /var/log/proxmox-backup/full-backup.log 2>&1
```

**Analysis**:
- Daily jobs run `config` command (lines 437-442): Creates config backup, recovery scripts, and verification
- Weekly jobs run `full` command (lines 428-435): Adds boot disk backup
- However, the `config` command calls `create_recovery_scripts` and `verify_backup`, so these should be created
- The functions exist but are not completing successfully

**Evidence from backup log**:
```
[2026-02-04 02:00:02] Backup directory created
[2026-02-04 02:00:02] Running configuration backup...
[2026-02-04 02:00:25] Backup size: 228M
```

Log shows config backup started but no completion messages for recovery scripts or verification. The script may be failing silently after config backup.

### Issue 3: Remote Sync Failure

**Problem**: No remote backups found on 192.168.1.9

**Root Cause**: Remote sync function exists but is **never called by automated backups**:

**Script Analysis**:
- `sync_to_remote()` function exists (lines 364-380)
- Function is configured with correct parameters:
  - `REMOTE_HOST="192.168.1.9"`
  - `REMOTE_USER="root"`
  - `REMOTE_DIR="/root/proxmox-backups"`
- SSH connection test: **Successful** (verified via `ssh root@192.168.1.9`)
- Remote directory exists: `/root/proxmox-backups/` (empty but present)

**Problem**: The `sync_to_remote` function is only available as a manual command:
```bash
# Line 465-468 - Only runs when manually executed
"sync")
    sync_to_remote
    ;;
```

**Neither `config` nor `full` backup commands call `sync_to_remote`**.

**Evidence from cron jobs**:
```bash
# Daily config backup - no sync
0 2 * * * .../proxmox-comprehensive-backup.sh config

# Weekly full backup - no sync
0 3 * * 0 .../proxmox-comprehensive-backup.sh full
```

**Impact**:
- All backups stored locally on `/mnt/ssd_4tb` on pve2
- Single point of failure - if pve2 storage fails, all backups lost
- Remote storage on 192.168.1.9 is completely unused

## Recommendations

### Priority 1: Fix Boot Device Configuration

1. **Identify actual boot device**:
   ```bash
   # Find boot device
   lsblk -f
   df -h /boot
   mount | grep 'on / type'
   ```

2. **Update backup script**:
   ```bash
   # Edit line 25 of comprehensive backup script
   BOOT_DEVICE="/dev/sdX"  # Replace with actual boot device
   ```

3. **Test boot disk backup**:
   ```bash
   /root/disaster-recovery/proxmox-comprehensive-backup.sh boot
   ```

### Priority 2: Fix Silent Failures

1. **Check why recovery scripts and verification are not created**:
   - Script may be failing silently after config backup
   - Need to add error trapping and logging
   - Test config backup manually to see full output

2. **Update cron jobs to capture all output**:
   ```bash
   # Add explicit error output capture
   0 2 * * * /root/disaster-recovery/proxmox-comprehensive-backup.sh config >> /var/log/proxmox-backup/config-backup.log 2>&1
   ```

### Priority 3: Enable Remote Sync

1. **Add sync to cron jobs**:
   ```bash
   # Daily config backup + sync
   0 2 * * * /root/disaster-recovery/proxmox-comprehensive-backup.sh config && /root/disaster-recovery/proxmox-comprehensive-backup.sh sync >> /var/log/proxmox-backup/config-backup.log 2>&1

   # Weekly full backup + sync
   0 3 * * 0 /root/disaster-recovery/proxmox-comprehensive-backup.sh full && /root/disaster-recovery/proxmox-comprehensive-backup.sh sync >> /var/log/proxmox-backup/full-backup.log 2>&1
   ```

2. **Alternative: Modify script to auto-sync**:
   - Add `sync_to_remote` call to end of `full` and `config` commands
   - Or create a new `config-sync` and `full-sync` command

## Current Backup Status

### What's Working:
- Daily configuration backups: ✅ Running at 2 AM
- Config backup content: ✅ Contains 228M of Proxmox config, network, SSH, drivers
- Local storage: ✅ 30-day retention working
- SSH to remote host: ✅ Connection successful
- Remote directory: ✅ Exists and accessible

### What's Broken:
- Boot disk backup: ❌ Wrong device configured
- Recovery scripts: ❌ Not being created
- Verification files: ❌ Not being generated
- Remote sync: ❌ Never called by cron
- Full backups: ❌ Only runs weekly (Sunday 3 AM), not tested

### Backup Locations:
- **Local**: `/mnt/ssd_4tb/comprehensive-backups/`
- **Remote**: `192.168.1.9:/root/proxmox-backups/` (empty)

## Next Steps

1. Identify correct boot device
2. Update BOOT_DEVICE in comprehensive backup script
3. Test manual boot backup
4. Investigate why recovery scripts aren't created
5. Add sync to cron jobs
6. Update health check script to verify boot disk backups exist
7. Run full backup test cycle
8. Document recovery procedure

## Files Referenced

- `/root/disaster-recovery/proxmox-comprehensive-backup.sh` (503 lines)
- `/root/proxmox-bare-metal-backup.sh` (313 lines)
- `/var/log/proxmox-backup/config-backup.log`
- `/var/log/proxmox-backup/full-backup.log`
- `/var/log/proxmox-backup/monitor.log`
- `/mnt/ssd_4tb/comprehensive-backups/proxmox-comprehensive-20260204-020001/`

## Related Documentation

- PCT-111 migration investigation: `/docs/pve2/pct-111-migration-investigation-2026-02-02.md`
- Backup monitoring: `/root/disaster-recovery/proxmox-backup-monitor.sh`
- Infrastructure database: `/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db`
