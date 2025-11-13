# Immich Migration Plan: OMV → pve2

**Date Created**: 2025-10-17
**Migration Type**: Service relocation with zero data loss
**Priority**: HIGH (Post swap memory intervention)
**Status**: 📋 PLANNING PHASE
**Target Completion**: TBD (requires careful preparation)

---

## 🎯 EXECUTIVE SUMMARY

### Migration Objective

Relocate the Immich photo management stack from OpenMediaVault (192.168.1.9) to Proxmox pve2 (192.168.1.10) LXC container to:

1. **Resolve Critical Memory Pressure** on OMV (7.4 GB RAM insufficient)
2. **Improve Service Reliability** by moving to infrastructure with 62 GB RAM
3. **Enable Better Resource Allocation** via Proxmox container management
4. **Reduce Swap Dependency** on OMV (currently 99.99% utilized)

### Current State Analysis

**Source System (OMV - 192.168.1.9)**:
- **Total RAM**: 7.4 GB
- **Swap Usage**: 975 MB of 9 GB (10.8% after adding 8 GB swap file)
- **Memory Pressure**: CRITICAL before swap expansion
- **Immich Containers**: 4 (server, ML, PostgreSQL, Redis)
- **Total Data Size**: ~463 GB photo library + 435 GB backups

**Target System (pve2 - 192.168.1.10)**:
- **Total RAM**: 62 GB
- **Available RAM**: 33 GB free
- **Swap Usage**: 0% (cleared after tuning)
- **Docker Host**: PCT-111 (docker-debian) - currently running
- **Container Resources**: Configurable memory limits via LXC

---

## 📊 CURRENT IMMICH DEPLOYMENT

### Container Stack (on OMV)

| Container | Image | Version | Status | Memory | Port |
|-----------|-------|---------|--------|--------|------|
| **immich_server** | ghcr.io/immich-app/immich-server | v1.143.1 | healthy | ~510 MB | 2283 |
| **immich_machine_learning** | ghcr.io/immich-app/immich-machine-learning | v1.143.1 | healthy | ~300 MB | - |
| **immich_postgres** | tensorchord/pgvecto-rs | pg14-v0.2.0 | healthy | ~113 MB | 5432 |
| **immich_redis** | redis | 6.2-alpine | healthy | ~50 MB | 6379 |

**Total Memory Footprint**: ~973 MB (13% of OMV's total RAM)

### Data Storage Locations

| Location | Path | Size | Type | Purpose |
|----------|------|------|------|---------|
| **Photo Library** | `/srv/.../immich-lib` | 463 GB | BTRFS RAID Mirror | Primary photo storage |
| **Backups** | `/srv/.../immich-backups` | 435 GB | MergerFS Pool | Database/config backups |
| **Database Backup** | `/srv/.../immich_backup_20250820_005617.sql` | 773 MB | SQL Dump | PostgreSQL snapshot |
| **Borg Backups** | `/srv/backups/immich-borg` | 4 KB | Borg Repository | Incremental backups |

**Total Storage Requirement**: ~900 GB (excluding backups)

### Network Configuration

- **Public Access**: Port 2283 exposed on OMV
- **Internal Communication**: Redis/PostgreSQL via Docker network
- **Reverse Proxy**: Likely via Nginx Proxy Manager (192.168.1.9)

---

## 🚀 MIGRATION STRATEGY

### Phase 1: Pre-Migration Preparation (Week 1)

#### 1.1 Resource Planning

**LXC Container Specification for pve2**:

```bash
# Recommended LXC configuration
VMID: 112 (next available)
Hostname: immich-prod
OS Template: debian-12-standard
Cores: 6-8 CPU cores
RAM: 8 GB (expandable to 12 GB)
Swap: 2 GB
Disk: 500 GB (on ssd-4tb storage)
Network: vmbr0 (192.168.1.x/24)
IP Address: 192.168.1.27 (static, DHCP reservation)
```

**Storage Strategy**:
- **Option A** (RECOMMENDED): SMB/CIFS mount of OMV's MirrorDisk share to pve2 LXC
  - **Advantages**: OMV already has SMB configured and working
  - **Share**: `\\192.168.1.9\MirrorDisk\immich-lib`
  - **Authentication**: User credentials (already configured)
  - **Performance**: Gigabit Ethernet, proven reliability
- **Option B**: Copy data to pve2 local storage (NOT RECOMMENDED - requires 500+ GB free, loses RAID protection)
- **Option C**: NFS mount (possible but unnecessary - SMB already working)

#### 1.2 Backup Verification

```bash
# Verify latest database backup
ssh root@192.168.1.9 'ls -lh /srv/.../immich_backup_*.sql | tail -1'

# Create fresh backup before migration
ssh root@192.168.1.9 'docker exec immich_postgres \
  pg_dump -U postgres immich > /backups/immich_pre_migration_$(date +%Y%m%d).sql'

# Backup docker-compose configuration
ssh root@192.168.1.9 'tar -czf /backups/immich-compose-$(date +%Y%m%d).tar.gz \
  /srv/docker-data/immich/'
```

#### 1.3 Dependency Mapping

**External Dependencies**:
- [ ] Nginx Proxy Manager reverse proxy configuration
- [ ] DNS records (if using custom domain)
- [ ] Firewall rules on OPNsense (port 2283)
- [ ] Uptime Kuma monitoring (if configured)
- [ ] Backup automation scripts

---

### Phase 2: Test Environment Setup (Week 2)

#### 2.1 Create LXC Container on pve2

```bash
# Create unprivileged LXC container
pct create 112 \
  local:vztmpl/debian-12-standard_12.9-1_amd64.tar.zst \
  --hostname immich-prod \
  --cores 8 \
  --memory 8192 \
  --swap 2048 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.27/24,gw=192.168.1.3 \
  --storage ssd-4tb \
  --rootfs ssd-4tb:500 \
  --unprivileged 1 \
  --features nesting=1 \
  --onboot 1

# Start container
pct start 112
```

#### 2.2 Install Docker in LXC

```bash
# Enter container
pct enter 112

# Install Docker
apt update
apt install -y docker.io docker-compose curl git
systemctl enable docker
systemctl start docker

# Verify installation
docker --version
docker-compose --version
```

#### 2.3 Configure SMB/CIFS Mount (Recommended)

```bash
# On pve2 container: Install CIFS utilities
pct enter 112
apt update
apt install -y cifs-utils

# Create credentials file (secure storage)
cat > /root/.smbcredentials << EOF
username=jm
password=YOUR_SMB_PASSWORD_HERE
domain=WORKGROUP
EOF
chmod 600 /root/.smbcredentials

# Create mount point
mkdir -p /mnt/immich-library

# Test mount manually
mount -t cifs //192.168.1.9/MirrorDisk /mnt/immich-library \
  -o credentials=/root/.smbcredentials,uid=1000,gid=1000,file_mode=0664,dir_mode=0775

# Verify access
ls -la /mnt/immich-library/immich-lib

# Add to /etc/fstab for persistence
echo "//192.168.1.9/MirrorDisk /mnt/immich-library cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,file_mode=0664,dir_mode=0775,_netdev 0 0" >> /etc/fstab

# Test fstab mount
umount /mnt/immich-library
mount -a
```

**OMV Share Details** (already configured):
- **Share Name**: MirrorDisk
- **Path**: `/srv/dev-disk-by-uuid-5c67dc41-a5c0-4439-8e68-cd5661b33f1b/`
- **Immich Data**: `immich-lib/` subdirectory (463 GB)
- **Access**: User "jm" authenticated
- **Features**: BTRFS snapshots, shadow copy support
- **Network Path**: `\\192.168.1.9\MirrorDisk` or `//192.168.1.9/MirrorDisk`

---

### Phase 3: Service Deployment (Week 3)

#### 3.1 Deploy Immich Stack

```bash
# Create directory structure
pct exec 112 -- mkdir -p /opt/immich/{config,postgres,redis}

# Copy docker-compose.yml from OMV
scp root@192.168.1.9:/srv/docker-data/immich/docker-compose.yml /tmp/
pct push 112 /tmp/docker-compose.yml /opt/immich/docker-compose.yml

# Update paths in docker-compose.yml
pct enter 112
cd /opt/immich
vi docker-compose.yml
# Update library path to /mnt/immich-library/immich-lib
# The MirrorDisk share root is /mnt/immich-library
# Immich data is in the immich-lib subdirectory
```

#### 3.2 Restore Database

```bash
# Copy latest database backup
scp root@192.168.1.9:/srv/.../immich_backup_*.sql /tmp/

# Start PostgreSQL container only
pct exec 112 -- docker-compose -f /opt/immich/docker-compose.yml up -d postgres

# Wait for PostgreSQL to be ready
pct exec 112 -- docker exec immich_postgres pg_isready

# Restore database
pct push 112 /tmp/immich_backup_*.sql /tmp/backup.sql
pct exec 112 -- docker exec -i immich_postgres \
  psql -U postgres immich < /tmp/backup.sql
```

#### 3.3 Start All Services

```bash
# Bring up entire stack
pct exec 112 -- docker-compose -f /opt/immich/docker-compose.yml up -d

# Verify all containers healthy
pct exec 112 -- docker-compose -f /opt/immich/docker-compose.yml ps

# Check logs
pct exec 112 -- docker-compose -f /opt/immich/docker-compose.yml logs --tail=50
```

---

### Phase 4: Network Cutover (Week 4)

#### 4.1 Parallel Testing

**Test Access**:
- Temporary access: http://192.168.1.27:2283
- Upload test photo
- Verify ML processing
- Check existing photo library accessibility
- Validate search functionality

#### 4.2 Update Reverse Proxy

```bash
# Update Nginx Proxy Manager backend
# Change from: 192.168.1.9:2283
# Change to:   192.168.1.27:2283

ssh root@192.168.1.9 "docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  sed -i 's/192.168.1.9:2283/192.168.1.27:2283/g' \
  /data/nginx/proxy_host/*.conf"

# Reload Nginx
ssh root@192.168.1.9 "docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  nginx -s reload"
```

#### 4.3 DNS/Firewall Updates

**OPNsense Firewall**:
- Update NAT port forward rules (if applicable)
- Update firewall aliases

**Internal DNS**:
- Update any local DNS records
- Update monitoring systems (Uptime Kuma)

---

### Phase 5: Validation & Cutover (Week 5)

#### 5.1 Smoke Tests

**Functional Tests**:
- [ ] Web interface accessible
- [ ] User authentication works
- [ ] Photo upload successful
- [ ] Photo download/sharing functional
- [ ] ML face detection active
- [ ] Search returns results
- [ ] Mobile app connectivity (iOS/Android)

**Performance Tests**:
- [ ] Page load times < 2 seconds
- [ ] Photo thumbnails generate quickly
- [ ] Database queries responsive
- [ ] No memory pressure warnings

#### 5.2 Monitor First 24 Hours

```bash
# Monitor memory usage
pct exec 112 -- watch -n 5 free -h

# Monitor container health
pct exec 112 -- docker stats

# Check for errors
pct exec 112 -- docker-compose logs -f --tail=100
```

#### 5.3 Decommission OMV Instance

**After 1 week of successful operation**:

```bash
# Stop Immich containers on OMV
ssh root@192.168.1.9 'cd /srv/docker-data/immich && docker-compose stop'

# Remove from autostart
ssh root@192.168.1.9 'cd /srv/docker-data/immich && docker-compose rm -f'

# Keep data for 30 days before deletion
ssh root@192.168.1.9 'mv /srv/.../immich-lib /srv/.../immich-lib.OLD'
```

---

## ⚠️ RISK ASSESSMENT

### Critical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Data Loss** | LOW | CRITICAL | Multiple backups, database dump, test restore |
| **Extended Downtime** | MEDIUM | HIGH | Parallel deployment, quick rollback plan |
| **Permission Issues** | MEDIUM | MEDIUM | Test NFS mounts, verify UID/GID mappings |
| **Performance Degradation** | LOW | MEDIUM | Load testing, resource monitoring |
| **Network Connectivity** | LOW | HIGH | Test all network paths, fallback routes |

### Rollback Plan

**If migration fails**:

1. **Immediate Rollback** (< 1 hour):
   ```bash
   # Revert proxy to OMV
   # Restart Immich on OMV
   ssh root@192.168.1.9 'cd /srv/docker-data/immich && docker-compose up -d'
   ```

2. **Partial Rollback** (< 4 hours):
   - Keep new database on pve2
   - Restore database backup to OMV
   - Restart OMV services

3. **Full Rollback** (< 24 hours):
   - Restore from pre-migration backup
   - Rebuild OMV Immich stack
   - Revert all network changes

---

## 📋 PRE-MIGRATION CHECKLIST

### Week Before Migration

- [ ] Create fresh database backup
- [ ] Verify backup integrity (test restore)
- [ ] Document all container configurations
- [ ] Map all external dependencies
- [ ] Create LXC container on pve2
- [ ] Install Docker in LXC
- [ ] Configure NFS mounts
- [ ] Test NFS performance
- [ ] Review and update docker-compose.yml
- [ ] Notify users of planned maintenance

### Day Before Migration

- [ ] Create final database backup
- [ ] Export all Immich settings/configurations
- [ ] Stop all backup jobs temporarily
- [ ] Verify pve2 has sufficient resources
- [ ] Confirm network paths functional
- [ ] Prepare rollback scripts
- [ ] Schedule maintenance window (2-4 hours, low-traffic period)

### Migration Day

- [ ] Send maintenance notification
- [ ] Create point-in-time backup
- [ ] Stop OMV Immich containers
- [ ] Deploy on pve2
- [ ] Restore database
- [ ] Start all services
- [ ] Run smoke tests
- [ ] Update proxy/DNS
- [ ] Monitor for 1 hour
- [ ] Send completion notification

---

## 🔧 POST-MIGRATION OPTIMIZATION

### Resource Tuning

**Memory Limits** (docker-compose.yml):
```yaml
services:
  immich-server:
    mem_limit: 2g
    mem_reservation: 1g

  immich-machine-learning:
    mem_limit: 1g
    mem_reservation: 512m

  immich-postgres:
    mem_limit: 1g
    mem_reservation: 512m
```

### LXC Container Tuning

```bash
# Set memory limits in LXC config
pct set 112 -memory 8192
pct set 112 -swap 2048

# Enable memory ballooning for dynamic adjustment
pct set 112 -balloon 4096
```

### Monitoring Setup

```bash
# Add to Netdata monitoring
# Add to Uptime Kuma
# Configure backup automation
# Set up log rotation
```

---

## 📈 SUCCESS METRICS

### Performance Targets

- **Uptime**: > 99.9% (< 8.8 hours downtime/year)
- **Response Time**: < 2 seconds for photo loading
- **Memory Usage**: < 4 GB average
- **Swap Usage**: < 10% on pve2
- **Database Performance**: Query time < 100ms
- **ML Processing**: < 30 seconds per photo

### Monitoring Dashboard

**Metrics to Track**:
1. Container memory usage
2. Database connection pool
3. Redis cache hit ratio
4. ML queue length
5. Storage I/O performance
6. Network throughput

---

## 📞 SUPPORT & CONTACTS

### Key Systems

- **Source**: OMV (192.168.1.9)
- **Target**: pve2 LXC-112 (192.168.1.27)
- **Proxy**: Nginx Proxy Manager (192.168.1.9)
- **Firewall**: OPNsense (192.168.1.3)

### Documentation References

- **Infrastructure Overview**: `/docs/infrastructure.md`
- **Swap Intervention**: `/docs/troubleshooting/swap-memory-high-utilization-2025-10-17.md`
- **OMV Docker Services**: `/docs/infrastructure.md` (lines 188-223)
- **pve2 Containers**: `/docs/infrastructure.md` (lines 472-491)

---

## ⏱️ TIMELINE ESTIMATE

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| **Planning & Preparation** | 1 week | Resource allocation approval |
| **Test Environment Setup** | 1 week | LXC container creation |
| **Service Deployment** | 1 week | NFS configuration complete |
| **Network Cutover** | 2-4 hours | Off-peak maintenance window |
| **Validation** | 1 week | Functional testing |
| **Decommission** | 1 week | Stable operation confirmed |

**Total Estimated Timeline**: 4-5 weeks from planning to decommission

---

## 🎯 NEXT STEPS

### Immediate Actions (This Week)

1. **Review & Approve Plan**: Stakeholder sign-off on migration approach
2. **Resource Allocation**: Reserve pve2 resources (VMID 112, IP 192.168.1.27)
3. **Backup Strategy**: Implement automated daily database backups
4. **Documentation**: Map all Immich dependencies and integrations

### Scheduled Tasks

1. **Week 1**: Create LXC container, install Docker, configure NFS
2. **Week 2**: Deploy test stack, restore database, functional testing
3. **Week 3**: Parallel operation, load testing, proxy updates
4. **Week 4**: Final cutover, 24/7 monitoring, decommission OMV instance

---

**Plan Status**: 📋 **READY FOR REVIEW**
**Next Review**: 2025-10-24
**Approval Required**: Yes
**Estimated Complexity**: MEDIUM-HIGH

