# Hetzner Server Migration & Decommission

**Date:** 2026-02-11
**Server:** ns203807 (167.235.9.103)
**Source OS:** Debian GNU/Linux 7 (wheezy)
**Proxmox Version:** Old OpenVZ-based Proxmox

## Executive Summary

Successfully backed up 8 OpenVZ containers from legacy Hetzner Debian 7 server and transferred them to pve2. The OpenVZ containers **cannot be directly restored** on modern Proxmox VE 8.4 due to technology incompatibility.

## Server Inventory

### Hardware Specifications
| Property | Value |
|-----------|--------|
| Hostname | ns203807 |
| IP Address | 167.235.9.103 |
| OS | Debian 7 (wheezy) - EOL since 2016 |
| RAM | 31GB total |
| Disk | 20GB root + 453GB /var/lib/vz (54% used) |
| Container Tech | OpenVZ (deprecated, predecessor to LXC) |

### Container Details

| CTID | Hostname | IP | Size | Purpose | Backup Size |
|-------|-----------|-----|-------|---------|-------------|
| 100 | mysql.restopad.eu | 10.4.0.100 | 57GB | MySQL Database | 11GB |
| 101 | memcached.restopad.eu | 10.4.0.101 | 2.5GB | Memcached Cache | 935MB |
| 102 | tomcat.restopad.eu | 10.4.0.102 | 21GB | Tomcat Application | 5.7GB |
| 103 | nginx.restopad.eu | 10.4.0.103 | 2.1GB | Nginx Web Server | 1.3GB |
| 105 | mysql-stub.restopad.eu | 10.4.0.105 | 1.2GB | MySQL Stub/Test | 647MB |
| 106 | hazelcast.restopad.eu | 10.4.0.106 | 1.9GB | Hazelcast Distributed Cache | 1.1GB |
| 107 | mail.restopad.eu | 10.4.0.110 | 1.9GB | Mail Server | 797MB |
| 108 | backup.restopad.eu | 10.4.0.180 | 778MB | Backup Server | 396MB |

**Total Container Data:** ~87GB (uncompressed)
**Total Backup Size:** ~23GB (compressed with lzo)

## Backup Process

### Completed Actions

1. ✅ Created backups of all 8 OpenVZ containers using `vzdump`
2. ✅ Compressed backups using lzo algorithm
3. ✅ Transferred all backups to pve2 via rsync
4. ✅ Verified all 8 backup files on destination

### Backup Location

**Destination:** `/mnt/ssd_4tb/hetzner-migration/` on pve2
**Available Space:** 2.3TB free on 4TB SSD

### Backup Files Created

```
vzdump-openvz-100-2026_02_11-17_35_38.tar.lzo    11GB
vzdump-openvz-101-2026_02_11-17_28_35.tar.lzo    935MB
vzdump-openvz-102-2026_02_11-17_30_12.tar.lzo    5.7GB
vzdump-openvz-103-2026_02_11-17_29_12.tar.lzo    1.3GB
vzdump-openvz-105-2026_02_11-17_25_43.tar.lzo    647MB
vzdump-openvz-106-2026_02_11-17_26_01.tar.lzo    1.1GB
vzdump-openvz-107-2026_02_11-17_29_50.tar.lzo    797MB
vzdump-openvz-108-2026_02_11-17_25_23.tar.lzo    396MB
```

## Migration Compatibility Issue

### OpenVZ vs LXC

| Aspect | OpenVZ (Hetzner) | LXC (Modern Proxmox) |
|--------|---------------------|---------------------------|
| Kernel | Shared host kernel (2.6.x) | Per-container kernel namespaces |
| Technology | Pre-2010, deprecated | Current standard |
| Restore Tool | `vzrestore` | `pct restore` |
| Proxmox Support | Removed in Proxmox VE 4.x | Native in all versions |

**Critical Finding:** OpenVZ containers **cannot be directly restored** on Proxmox VE 8.4.

## Additional Data Found

### Items Worth Considering

| Location | Size | Description | Priority |
|----------|-------|-------------|------------|
| `/root/100mysqlbackups/` | 2.4GB | MySQL database dumps | Medium |
| `/root/app_restopad_eu.zip` | 7KB | Application archive | Low |
| `/var/lib/vz/_backup/dump/` | 129GB | Historical backups | High |
| `/usr/local/bin/rsync_backups_to_slave` | - | Custom backup script | Info |
| `/usr/local/rtm/bin/rtm` | - | Monitoring agent (cron: */1 * * * *) | Info |

## Migration Options

### Option 1: Extract & Recreate (Recommended)

1. Extract data from OpenVZ backups
2. Create fresh LXC containers with Debian templates
3. Copy configurations and data
4. Recreate services

**Pros:** Clean modern containers, full control
**Cons:** Manual work, service reconfiguration needed

### Option 2: Container Conversion Tools

Use OpenVZ to LXC conversion utilities (complex, may not work with Debian 7)

**Pros:** Automated
**Cons:** High failure risk, not well-tested

### Option 3: Keep Backups Only

Store backups for reference, migrate services as needed

**Pros:** Safe, no rush
**Cons:** Delayed migration, manual effort later

## Cron Jobs Found

```
*/1 * * * * root    /usr/local/rtm/bin/rtm 42 > /dev/null 2> /dev/null
@daily           root    find /var/lib/vz/_backup/dump -type f -ctime +4 | xargs rm -v
2 */6 * * * root    /usr/local/bin/rsync_backups_to_slave
```

## Decommissioning Checklist

### Pre-Decommission
- [x] All containers backed up
- [x] Backups verified on pve2
- [x] Documentation created
- [ ] Transfer additional data (MySQL backups, app zip)
- [ ] Review old backups (129GB) for relevance
- [ ] Cancel/delete via Hetzner Cloud Console

### Decommission Steps
1. Log into Hetzner Cloud Console (https://console.hetzner.com)
2. Navigate to server `ns203807` / `167.235.9.103`
3. Shut down server gracefully
4. Delete or cancel server subscription

### Post-Decommission
- [ ] Update DNS records (if any still pointing to 167.235.9.103)
- [ ] Update firewall rules removing Hetzner IP
- [ ] Remove SSH keys/configs referencing Hetzner
- [ ] Update monitoring/alerting systems

## pve2 Information

**Proxmox VE Version:** 8.4.0
**LXC Support:** Yes (`pct` command available)
**OpenVZ Support:** No (vzctl not installed)

### Storage Available
| Location | Size | Used | Available |
|----------|-------|-------|-----------|
| /mnt/ssd_4tb | 3.7TB | 1.5TB | 2.2TB |
| /mnt/omv-mirrordisk | 3.7TB | 2.0TB | 1.7TB |

## Commands Reference

### Restore Single File from Backup
```bash
# Extract single file from backup
mkdir -p /tmp/restore
tar -xvzf /mnt/ssd_4tb/hetzner-migration/vzdump-openvz-XXX-YYYY_MM_DD-HH_MM_SS.tar.lzo -C /tmp/restore --strip-components=3
```

### List Backup Contents
```bash
# List contents of backup without full extract
tar -tzf /mnt/ssd_4tb/hetzner-migration/vzdump-openvz-XXX-YYYY_MM_DD-HH_MM_SS.tar.lzo
```

### Create New LXC Container
```bash
# Download Debian template (on pve2)
pveam available | grep debian
pveam download debian-12-standard_12.0-1_amd64.tar.zst

# Create LXC container
pct create 200 local:debian-12-standard_12.0-1_amd64.tar.zst
```

## Next Steps

1. **Decide on additional data** - Transfer MySQL backups (2.4GB) and old backups (129GB)?
2. **Choose migration strategy** - Extract/recreate vs. conversion tools
3. **Decommission Hetzner server** - Cancel via Cloud Console
4. **Document recreated services** - As containers are migrated to LXC

---

**Document Created:** 2026-02-11
**Last Updated:** 2026-02-11 19:30 UTC
