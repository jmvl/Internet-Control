# Hetzner Proxmox 3 Migration - Quick Reference

**Server**: ns203807 @ 167.235.9.103
**SSH**: `ssh root@hetzner-old` (SSH keys configured)
**Status**: Running, 765 days uptime, needs urgent migration

## Fast Facts

- **8 OpenVZ containers** (cannot be directly migrated to modern Proxmox)
- **88.4GB total data** (57GB MySQL + 21GB Tomcat + 10GB others)
- **Debian 7 Wheezy** (EOL since 2018 - security risk)
- **Production Java stack**: Nginx → Tomcat → MySQL Galera cluster

## Critical Services

1. **CT 100** - MySQL Galera cluster (57GB) - **MOST CRITICAL**
2. **CT 102** - Tomcat Java app (21GB) - **CRITICAL**
3. **CT 103** - Nginx load balancer (2.1GB) - **HIGH**

## Quick Commands

### On Hetzner Server
```bash
# SSH access
ssh root@hetzner-old

# Check containers
vzlist -a

# Create backup of critical container (MySQL)
vzdump 100 --mode snapshot --compress gzip --dumpdir /var/lib/vz/dump/

# Check disk space
df -h /var/lib/vz
```

### Migration Steps (High Level)

1. **Backup** (on Hetzner): Create vzdump backups
2. **Transfer** (Hetzner → PVE2): rsync backups to PVE2
3. **Convert** (on PVE2): Extract → Create LXC → Reconfigure
4. **Test** (on PVE2): Verify services work
5. **Cutover**: Switch DNS/traffic to new servers
6. **Decommission**: Keep Hetzner running 30 days, then cancel

## Documentation

- **Inventory**: `/docs/hetzner/proxmox3-container-inventory.md`
- **Migration Plan**: `/docs/hetzner/proxmox3-to-pve2-migration-plan.md`
- **This Guide**: `/docs/hetzner/QUICKSTART.md`

## Next Actions

**WAITING FOR**:
- [ ] PVE2 capacity assessment
- [ ] Decision: Full migration vs. data extraction only
- [ ] Confirm application is still in use
- [ ] Migration timeline requirements

**READY TO EXECUTE**:
- [x] SSH access configured
- [x] Container inventory complete
- [x] Migration plan documented
- [ ] Start Phase 1: Create backups
