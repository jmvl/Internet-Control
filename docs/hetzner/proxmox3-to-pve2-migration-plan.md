# Proxmox 3 to PVE2 Migration Plan

**Date**: 2025-10-30
**Source**: Hetzner ns203807 (167.235.9.103) - Proxmox 3.1-14 (OpenVZ)
**Target**: PVE2 - Proxmox VE (LXC/KVM)
**Total Data**: ~88.4GB across 8 containers

## Executive Summary

Migrating 8 OpenVZ containers from a legacy Proxmox 3 server (2013) to modern Proxmox VE on PVE2. **Direct migration is not possible** because:
- Proxmox 3 uses OpenVZ (kernel-based containerization)
- Modern Proxmox uses LXC (userspace containerization)
- No automated conversion path exists

**Migration Strategy**: Backup → Extract → Rebuild as LXC containers

## Pre-Migration Assessment

### Source System (Hetzner)
- **Proxmox Version**: 3.1-14 (released 2013)
- **Kernel**: 2.6.32-24-pve (EOL)
- **OS**: Debian 7 Wheezy (EOL since 2018)
- **Virtualization**: OpenVZ
- **Uptime**: 765 days (never patched)
- **Available Space**: 214GB free for backups

### Target System (PVE2)
- **Hostname**: pve2
- **Access**: SSH via `ssh root@pve2`
- **Network**: 192.168.1.x (internal network)
- **Need to assess**: Storage capacity, Proxmox version, available resources

## Container Migration Priority

| Priority | CTID | Name | Size | Services | Migration Complexity |
|----------|------|------|------|----------|---------------------|
| **P0** | 100 | mysql | 57GB | MySQL Galera, Apache, Icinga2 | **HIGH** - Database cluster |
| **P0** | 102 | tomcat | 21GB | Tomcat 8, Java app | **HIGH** - Application config |
| **P1** | 103 | nginx | 2.1GB | Nginx LB | **MEDIUM** - Config extraction |
| **P2** | 101 | memcached | 2.5GB | Memcached, Apache | **LOW** - Stateless cache |
| **P2** | 106 | hazelcast | 1.9GB | Hazelcast | **LOW** - Can replace with Redis |
| **P3** | 107 | mail | 1.9GB | Postfix, Dovecot | **MEDIUM** - Mail data |
| **P3** | 105 | mysql-stub | 1.2GB | Test DB | **LOW** - Test environment |
| **P3** | 108 | backup | 778MB | Backup storage | **LOW** - Archive only |

## Migration Methods

### Method 1: vzdump Backup → Manual LXC Rebuild (Recommended)

**Pros**:
- Clean migration to modern OS (Debian 12)
- Opportunity to modernize configs
- Full control over the process

**Cons**:
- Manual effort required
- Need to reconfigure services

**Steps**:
1. Create vzdump backups on Hetzner
2. Transfer to PVE2
3. Extract filesystem data
4. Create new LXC containers
5. Copy configs and data
6. Reconfigure services

### Method 2: Filesystem Tarball → LXC Import

**Pros**:
- Preserves file permissions
- Faster than vzdump for large containers

**Cons**:
- Still requires manual service configuration
- May have compatibility issues with old Debian 7

### Method 3: Application-Level Migration (Best for Production)

**Pros**:
- Modernize entire stack
- Use Docker Compose for portability
- Better security and maintainability

**Cons**:
- Most time-intensive
- Requires application knowledge

## Detailed Migration Plan

### Phase 1: Backup Creation (Hetzner)

**Estimated Time**: 4-6 hours
**Disk Space Required**: ~88GB (source) + ~45GB (compressed backups) = 133GB

```bash
# On Hetzner server (167.235.9.103)

# Create backup directory
mkdir -p /var/lib/vz/dump/migration-$(date +%Y%m%d)
cd /var/lib/vz/dump/migration-$(date +%Y%m%d)

# Backup all containers with vzdump
for ct in 100 102 103 101 106 107 105 108; do
  echo "Backing up container $ct..."
  vzdump $ct --mode snapshot --compress gzip --dumpdir $(pwd)
done

# Create manifest
cat > MANIFEST.txt << 'EOF'
Proxmox 3 Container Backup Manifest
Date: $(date)
Source: ns203807.hetzner.com (167.235.9.103)
Containers: 100,101,102,103,105,106,107,108

Container Details:
100 - mysql (57GB) - MySQL Galera cluster + Apache + Icinga2
102 - tomcat (21GB) - Tomcat 8 Java application
103 - nginx (2.1GB) - Nginx load balancer
101 - memcached (2.5GB) - Memcached cache
106 - hazelcast (1.9GB) - Hazelcast distributed cache
107 - mail (1.9GB) - Postfix + Dovecot mail server
105 - mysql-stub (1.2GB) - Test MySQL instance
108 - backup (778MB) - Backup storage
EOF

# Calculate checksums
md5sum *.tar.gz > MD5SUMS

# List backups
ls -lh
```

### Phase 2: Data Transfer (Hetzner → PVE2)

**Estimated Time**: 2-4 hours (depends on network)
**Method**: rsync over SSH

```bash
# On Hetzner server
# Transfer backups to PVE2
rsync -avz --progress \
  /var/lib/vz/dump/migration-$(date +%Y%m%d)/ \
  root@pve2:/var/lib/vz/dump/hetzner-migration/

# Verify transfer
ssh root@pve2 "cd /var/lib/vz/dump/hetzner-migration && md5sum -c MD5SUMS"
```

### Phase 3: Container Conversion (PVE2)

**Estimated Time**: 1-2 hours per container
**Process**: Extract → Create LXC → Configure → Test

#### Example: Migrating CT 100 (MySQL)

```bash
# On PVE2

# 1. Create LXC container with Debian 12
pct create 200 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname mysql-migrated \
  --memory 4096 \
  --swap 2048 \
  --storage local-lvm \
  --rootfs local-lvm:60 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp

# 2. Extract OpenVZ backup
cd /var/lib/vz/dump/hetzner-migration
tar -xzf vzdump-openvz-100-*.tar.gz

# 3. Copy critical data
# MySQL data
pct push 200 /path/to/extracted/var/lib/mysql /var/lib/mysql-old/ -recursive

# MySQL configs
pct push 200 /path/to/extracted/etc/mysql /etc/mysql-old/ -recursive

# 4. Start container and install MySQL
pct start 200
pct enter 200

# Inside container:
apt update
apt install -y mariadb-server
systemctl stop mariadb

# Copy old MySQL data (requires MySQL version compatibility check)
# ... manual data migration steps ...

systemctl start mariadb
```

### Phase 4: Service-by-Service Migration

#### CT 100 - MySQL Galera Cluster
**Challenge**: Galera cluster configuration
**Solution**:
1. Extract MySQL data directory
2. Create new MariaDB 10.11 (Debian 12 default)
3. Import databases with `mysql_upgrade`
4. Reconfigure replication if needed

**Commands**:
```bash
# Extract databases from backup
mysqldump -u root -p --all-databases > all-databases.sql
# Import to new system
mysql -u root -p < all-databases.sql
```

#### CT 102 - Tomcat Application
**Challenge**: Java 8 application, custom configs
**Solution**:
1. Extract application WAR files
2. Install OpenJDK 11 or 17 (modern Java)
3. Deploy application on Tomcat 9 or 10
4. Test compatibility

**Alternative**: Containerize with Docker
```yaml
# docker-compose.yml
version: '3.8'
services:
  tomcat-app:
    image: tomcat:9-jdk11
    volumes:
      - ./webapps:/usr/local/tomcat/webapps
    environment:
      - JAVA_OPTS=-Xmx2048m -Xms256m
    ports:
      - "8080:8080"
```

#### CT 103 - Nginx Load Balancer
**Challenge**: Configuration extraction
**Solution**:
1. Copy `/etc/nginx/` configs
2. Create new LXC with Nginx
3. Adapt configs for new backend IPs

```bash
# Extract nginx configs from backup
tar -xzf vzdump-openvz-103-*.tar.gz ./etc/nginx
# Copy to new container
pct push 203 etc/nginx /etc/nginx-old/ -recursive
```

#### CT 101/106 - Cache Layers (Memcached/Hazelcast)
**Recommendation**: Replace with Redis
**Rationale**:
- Modern, actively maintained
- Better persistence options
- Simpler deployment

```bash
# Create Redis LXC
pct create 201 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname redis-cache \
  --memory 2048 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp

pct start 201
pct exec 201 -- apt update
pct exec 201 -- apt install -y redis-server
```

#### CT 107 - Mail Server
**Challenge**: Mail data and configurations
**Solution**:
1. Extract `/var/mail` and Dovecot/Postfix configs
2. Install mail stack on new LXC
3. Migrate mailboxes
4. Update DNS if needed

```bash
# Extract mail data
tar -xzf vzdump-openvz-107-*.tar.gz ./var/mail ./etc/postfix ./etc/dovecot
# Migrate to new system
# ... detailed mail migration steps ...
```

## Timeline & Resource Requirements

### Estimated Timeline
- **Phase 1** (Backups): 4-6 hours
- **Phase 2** (Transfer): 2-4 hours
- **Phase 3** (Conversion): 8-16 hours (1-2 hours × 8 containers)
- **Phase 4** (Testing): 4-8 hours
- **Total**: 18-34 hours of work (can be spread over days)

### Storage Requirements on PVE2
- **Backup Storage**: ~50GB (compressed backups)
- **New LXC Containers**: ~100GB (allowing for overhead)
- **Total**: ~150GB free space needed

### Network Bandwidth
- **Transfer Size**: ~45GB compressed
- **Time**: 2-4 hours (assuming 3-6 MB/s average)

## Risk Mitigation

### Critical Risks

1. **Data Loss During Transfer**
   - Mitigation: Checksum verification, keep original backups

2. **Service Incompatibility**
   - Mitigation: Test in staging first, maintain old server running

3. **MySQL Version Mismatch**
   - Mitigation: Use mysqldump for logical backup, not physical files

4. **Application Dependencies**
   - Mitigation: Document all configs before migration

### Rollback Plan
- **Keep Hetzner server running** during entire migration
- Test each service before decommissioning source
- Maintain backups for 90 days post-migration

## Post-Migration Tasks

1. **Update DNS** records (if applicable)
2. **Update firewall** rules for new IPs
3. **Configure monitoring** (Icinga2 → modern monitoring)
4. **Update documentation** with new architecture
5. **Decommission Hetzner server** (after 30-day safety period)

## Modern Architecture Recommendation

Instead of 8 separate LXC containers, consider **Docker Compose stack**:

```yaml
version: '3.8'
services:
  mysql:
    image: mariadb:10.11
    volumes:
      - mysql-data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}

  tomcat-app:
    image: tomcat:9-jdk11
    depends_on:
      - mysql
      - redis
    volumes:
      - ./webapps:/usr/local/tomcat/webapps

  nginx:
    image: nginx:alpine
    depends_on:
      - tomcat-app
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf

  redis:
    image: redis:alpine
    volumes:
      - redis-data:/data

  mail:
    image: mailserver/docker-mailserver:latest
    volumes:
      - ./mail-data:/var/mail

volumes:
  mysql-data:
  redis-data:
```

## Next Steps

1. **Assess PVE2 capacity** (storage, CPU, RAM)
2. **Review this plan** and adjust based on PVE2 capabilities
3. **Start with Phase 1** (create backups on Hetzner)
4. **Test migration** with lowest-priority container first (CT 108)
5. **Proceed incrementally** with increasing priority

## Questions to Answer

- [ ] What Proxmox version is running on PVE2?
- [ ] How much free storage is available on PVE2?
- [ ] Is this application still actively used?
- [ ] Do you have application documentation/source code?
- [ ] Should we modernize to Docker instead of LXC?
- [ ] What is the target timeline for migration?

## References

- OpenVZ to LXC Migration: https://pve.proxmox.com/wiki/Migration_of_servers_to_Proxmox_VE
- Proxmox Backup: https://pve.proxmox.com/wiki/Backup_and_Restore
- LXC Container Management: https://pve.proxmox.com/wiki/Linux_Container
