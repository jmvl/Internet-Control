# Proxmox Backup Quick Start Guide

## Daily Operations

### Check Backup Status
```bash
ssh root@pve2 '/root/disaster-recovery/backup-status.sh'
```

### Run Manual Backup
```bash
# Configuration backup (250MB, ~2 minutes)
ssh root@pve2 '/root/proxmox-bare-metal-backup.sh backup'

# Full backup (16GB+, ~30 minutes)
ssh root@pve2 '/root/disaster-recovery/proxmox-comprehensive-backup.sh full'
```

### Check Logs
```bash
ssh root@pve2 'tail -f /var/log/proxmox-backup/config-backup.log'
```

## Emergency Recovery

### Configuration Problem (10 minutes)
```bash
# 1. Get latest backup
scp root@pve2:/root/proxmox-bare-metal-backup-*.tar.gz .

# 2. Extract and restore
tar -xzf proxmox-bare-metal-backup-*.tar.gz
cd proxmox-bare-metal-backup-*
./restore.sh
```

### Complete System Loss (30 minutes)
```bash
# 1. Boot from live USB
# 2. Get boot disk image from OMV
scp root@192.168.1.9:/root/proxmox-backups/pve2-boot-*.img.gz .

# 3. Restore to new hardware
gunzip -c pve2-boot-*.img.gz | dd of=/dev/sda bs=4M status=progress

# 4. Reboot - system ready
```

## Automated Schedule

- **Daily 2 AM:** Configuration backup
- **Sunday 3 AM:** Full backup (boot disk)
- **Daily 8 AM:** Health monitoring
- **Monday 4 AM:** Cleanup old backups

## Storage Locations

- **Local:** `/mnt/ssd_4tb/comprehensive-backups/`
- **Remote:** `root@192.168.1.9:/root/proxmox-backups/`
- **Logs:** `/var/log/proxmox-backup/`

## Key Commands

| Action | Command |
|--------|---------|
| Status | `ssh root@pve2 '/root/disaster-recovery/backup-status.sh'` |
| Backup | `ssh root@pve2 '/root/proxmox-bare-metal-backup.sh backup'` |
| Health | `ssh root@pve2 '/root/disaster-recovery/proxmox-backup-monitor.sh check'` |
| List | `ssh root@pve2 '/root/disaster-recovery/proxmox-comprehensive-backup.sh list'` |

## Monthly Tasks

1. **Test backup integrity**
2. **Verify remote storage access**
3. **Check disk space usage**
4. **Test recovery procedures**

---
**System:** pve2 (192.168.1.10)  
**Backup:** ✅ Automated  
**Recovery:** ⚡ 10-30 minutes