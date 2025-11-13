# Hetzner to PVE2 Migration - Status Update

**Date**: 2025-10-30
**Status**: 🟢 **PHASE 1 IN PROGRESS** - Automated backup process running

## Current Status

### ✅ Completed

1. **Documentation Created**
   - Container inventory (`proxmox3-container-inventory.md`)
   - Migration plan (`proxmox3-to-pve2-migration-plan.md`)
   - PVE2 capacity assessment (`pve2-capacity-assessment.md`)
   - Quick reference (`QUICKSTART.md`)

2. **Infrastructure Ready**
   - SSH access configured for both servers
   - Tailscale connectivity established to PVE2
   - PVE2 migration directory created: `/mnt/ssd_4tb/hetzner-migration/`
   - PVE2 has 2.8TB free space (more than enough!)

3. **Backup Process Initiated**
   - CT 100 (MySQL 57GB) backup started at 16:34 CET
   - Automated script ready to backup remaining 7 containers
   - Backup directory: `/var/lib/vz/dump/migration-20251030/`

### 🔄 In Progress

**Phase 1: Creating Backups on Hetzner**
- **Current**: CT 100 (MySQL - 57GB) actively backing up via rsync
- **Queue**: 7 containers waiting (will start automatically after CT 100)
- **Expected completion**: 4-6 hours total (started 16:34 CET → finish ~20:34-22:34 CET)

### ⏳ Pending

**Phase 2**: Transfer backups to PVE2 (2-4 hours)
**Phase 3**: Convert containers to LXC (8-16 hours)

## Active Backup Process

### Container Backup Order

| Order | CTID | Name | Size | Status |
|-------|------|------|------|--------|
| 1 | 100 | mysql | 57GB | 🔄 **IN PROGRESS** |
| 2 | 102 | tomcat | 21GB | ⏳ Queued |
| 3 | 103 | nginx | 2.1GB | ⏳ Queued |
| 4 | 101 | memcached | 2.5GB | ⏳ Queued |
| 5 | 106 | hazelcast | 1.9GB | ⏳ Queued |
| 6 | 107 | mail | 1.9GB | ⏳ Queued |
| 7 | 105 | mysql-stub | 1.2GB | ⏳ Queued |
| 8 | 108 | backup | 778MB | ⏳ Queued |

## Monitoring Commands

### Check Backup Progress

```bash
# Monitor active backup
ssh root@hetzner-old "ps aux | grep vzdump"

# Watch automation script progress
ssh root@hetzner-old "tail -f /var/lib/vz/dump/migration-20251030/backup-remaining.log"

# Check completed backups
ssh root@hetzner-old "ls -lh /var/lib/vz/dump/migration-20251030/*.tar.gz"

# Check disk space
ssh root@hetzner-old "df -h /var/lib/vz"
```

### Quick Status Check

```bash
# One-line status
ssh root@hetzner-old "cd /var/lib/vz/dump/migration-20251030 && echo '=== Backups:' && ls -lh *.tar.gz 2>/dev/null | wc -l && echo '=== Running:' && pgrep -c vzdump || echo 0"
```

## Next Steps (Automated)

The following will happen automatically without intervention:

1. ✅ **CT 100** backs up (currently running)
2. ⏳ Automation script waits for CT 100 to complete
3. ⏳ **CT 102** (Tomcat) backs up automatically
4. ⏳ **CT 103** (Nginx) backs up automatically
5. ⏳ **CT 101-108** back up in sequence
6. ⏳ Manifest file (`MANIFEST.txt`) created
7. ⏳ MD5 checksums (`MD5SUMS`) generated

**Estimated completion**: ~20:34-22:34 CET (4-6 hours from start)

## Next Steps (Manual - After Backups Complete)

### Phase 2: Transfer to PVE2 (Run when backups finish)

```bash
# Transfer all backups to PVE2 via Tailscale
ssh root@hetzner-old "cd /var/lib/vz/dump/migration-20251030 && \
  rsync -avz --progress . root@100.102.0.120:/mnt/ssd_4tb/hetzner-migration/"

# Verify transfer
ssh root@pve2 "cd /mnt/ssd_4tb/hetzner-migration && md5sum -c MD5SUMS"
```

**Estimated time**: 2-4 hours (via Tailscale over internet)

### Phase 3: Container Conversion (After transfer complete)

See detailed instructions in `proxmox3-to-pve2-migration-plan.md`

## Server Access

### Hetzner Server (Source)
```bash
# SSH access
ssh root@hetzner-old
# or direct IP
ssh root@167.235.9.103
```

### PVE2 (Destination)
```bash
# SSH via Tailscale (requires Tailscale running)
ssh root@pve2
# or Tailscale IP
ssh root@100.102.0.120

# Web UI
https://100.102.0.120:8006
```

## Storage Locations

### Hetzner
- **Backup directory**: `/var/lib/vz/dump/migration-20251030/`
- **Container data**: `/var/lib/vz/private/{100-108}/`
- **Available space**: 214GB (sufficient)

### PVE2
- **Migration directory**: `/mnt/ssd_4tb/hetzner-migration/`
- **Available space**: 2.8TB (more than enough!)
- **SSD-4TB mount**: `/mnt/ssd_4tb/`

## Timeline

### Actual Timeline
- **16:34 CET** - CT 100 backup started
- **16:35 CET** - Automation script deployed
- **~20:34-22:34 CET** - All backups estimated complete

### Planned Timeline
- **Phase 1** (Backups): 4-6 hours ← **WE ARE HERE**
- **Phase 2** (Transfer): 2-4 hours
- **Phase 3** (Conversion): 8-16 hours (can be done incrementally)
- **Total**: 18-34 hours (can span multiple days)

## Risk Mitigation

### Safety Measures in Place
✅ Original Hetzner server stays online during entire migration
✅ All backups compressed with gzip
✅ MD5 checksums for integrity verification
✅ Automated process logs everything
✅ PVE2 has 19x more space than needed

### Rollback Plan
- Keep Hetzner server running for 30+ days
- Test each service on PVE2 before decommissioning
- Maintain backups on both systems during transition

## What to Do Next

### Option 1: Wait for Automated Completion (Recommended)
- Let the backup process run (4-6 hours)
- Check progress occasionally with monitoring commands above
- Proceed to Phase 2 (transfer) when backups complete

### Option 2: Monitor Actively
```bash
# Watch real-time progress
ssh root@hetzner-old
cd /var/lib/vz/dump/migration-20251030
watch -n 30 'ls -lh *.tar.gz 2>/dev/null; echo ""; df -h /var/lib/vz'
```

### Option 3: Go Do Something Else
The backup process is fully automated and will complete on its own. You can:
- Check back in 4-6 hours
- Monitor via SSH periodically
- Continue with other work

## Questions & Support

### Common Questions

**Q: Can I monitor without SSH?**
A: No, but you can schedule a check:
```bash
# Check every hour
while true; do ssh root@hetzner-old "ls -1 /var/lib/vz/dump/migration-20251030/*.tar.gz 2>/dev/null | wc -l"; sleep 3600; done
```

**Q: What if the backup fails?**
A: Each container is logged separately. Failed backups are noted in the log files. You can manually retry:
```bash
ssh root@hetzner-old "vzdump <CTID> --mode snapshot --compress gzip --dumpdir /var/lib/vz/dump/migration-20251030/"
```

**Q: Can I stop and resume?**
A: Yes, but it's safer to let it complete. To stop:
```bash
ssh root@hetzner-old "pkill vzdump"
```

**Q: How do I know when it's done?**
A: Check for 8 tar.gz files:
```bash
ssh root@hetzner-old "ls -1 /var/lib/vz/dump/migration-20251030/*.tar.gz | wc -l"
# Should return: 8
```

## Contact & Documentation

- **Main Plan**: `/docs/hetzner/proxmox3-to-pve2-migration-plan.md`
- **Inventory**: `/docs/hetzner/proxmox3-container-inventory.md`
- **PVE2 Assessment**: `/docs/hetzner/pve2-capacity-assessment.md`
- **This Status**: `/docs/hetzner/migration-status.md`

---

**Last Updated**: 2025-10-30 16:37 CET
**Next Update**: After Phase 1 completion (check back in 4-6 hours)
