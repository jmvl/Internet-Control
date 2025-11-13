# Proxmox 3 Container Inventory - Hetzner Server

**Server**: ns203807 (167.235.9.103)
**Proxmox Version**: 3.1-14 (2013)
**Kernel**: 2.6.32-24-pve
**Uptime**: 765 days (2+ years)
**Total Container Data**: ~88.4GB
**Available Backup Space**: 214GB free

## Application Architecture

This is a **production Java application stack** with distributed database and caching:

```
Internet → [Nginx LB] → [Tomcat App] → [MySQL Galera] + [Memcached/Hazelcast]
                ↓           ↓                ↓
            CT 103      CT 102           CT 100
```

## Container Inventory

| CTID | Hostname | Size | Status | Primary Services | Priority |
|------|----------|------|--------|------------------|----------|
| 100 | mysql | 57GB | Running | **MySQL Galera Cluster**, Apache, Icinga2, BIND | **CRITICAL** |
| 102 | tomcat | 21GB | Running | **Tomcat 8 (Java 8, 2GB heap)**, Icinga2, BIND | **CRITICAL** |
| 103 | nginx | 2.1GB | Running | **Nginx Load Balancer**, Icinga2, BIND | **HIGH** |
| 101 | memcached | 2.5GB | Running | **Memcached Cache**, Apache, Collectd, BIND, Samba | MEDIUM |
| 106 | hazelcast | 1.9GB | Running | **Hazelcast Cache**, Apache, BIND | MEDIUM |
| 107 | mail | 1.9GB | Running | **Postfix + Dovecot**, OpenDKIM, Icinga2, BIND | LOW |
| 105 | mysql-stub | 1.2GB | Running | Test Database, Apache, Samba | LOW |
| 108 | backup | 778MB | Running | Backup Storage, Apache | LOW |

## Critical Services Detail

### CT 100 - MySQL Galera Cluster (57GB)
- **MySQL Process**: Galera cluster node (wsrep position: 125517381)
- **Database**: Production MySQL with replication
- **Monitoring**: Icinga2
- **Web**: Apache
- **DNS**: BIND
- **Status**: Active replication member

### CT 102 - Tomcat Application Server (21GB)
- **Java Version**: Oracle JDK 8
- **Heap**: 2GB max (-Xmx2048m)
- **GC**: ConcMarkSweepGC
- **Timezone**: Europe/Brussels
- **Runtime**: 2354 hours of processing time
- **Monitoring**: Icinga2

### CT 103 - Nginx Load Balancer (2.1GB)
- **Workers**: 4 nginx worker processes
- **Function**: Reverse proxy / load balancer to Tomcat
- **Monitoring**: Icinga2

## Extraction Strategy Options

### Option 1: MySQL Data Only (Recommended for Recovery)
**Size**: ~57GB
**Time**: 1-2 hours

```bash
# Dump MySQL databases from CT 100
vzdump 100 --mode snapshot --compress gzip --dumpdir /var/lib/vz/dump/
# OR extract MySQL data directly
vzctl exec 100 "mysqldump --all-databases --single-transaction" > mysql-backup.sql
```

### Option 2: Full Container Backups (vzdump)
**Size**: ~88GB compressed (~40-50GB)
**Time**: 3-5 hours

```bash
# Create compressed backups of all containers
for ct in 100 101 102 103 105 106 107 108; do
  vzdump $ct --mode stop --compress gzip --dumpdir /var/lib/vz/dump/
done
```

### Option 3: Filesystem-Level Archive
**Size**: ~88GB raw
**Time**: 2-3 hours

```bash
# Archive container filesystems directly
for ct in 100 101 102 103 105 106 107 108; do
  tar -czf /var/lib/vz/dump/ct-$ct-filesystem.tar.gz /var/lib/vz/private/$ct/
done
```

### Option 4: Application Migration to Modern Stack
**Recommended**: Rebuild on modern infrastructure
- MySQL Galera → PostgreSQL or modern MySQL on Docker/LXC
- Tomcat → Modern Java containerized deployment
- Nginx → Modern reverse proxy configuration

## Disk Space Analysis

```
Filesystem               Size  Used Avail Use%
/dev/md1 (root)          20G   13G  5.5G  71%
/dev/mapper/pve-data    453G  217G  214G  51%   ← Container storage (safe for backups)
```

## Security & Compliance Notes

- **Debian 7 (Wheezy)**: EOL since May 2018 - **UNSUPPORTED**
- **Kernel 2.6.32**: Ancient, multiple CVEs
- **Java 8**: Requires valid Oracle license for production use
- **OpenVZ**: Deprecated technology, not supported on modern kernels
- **Uptime 765 days**: Never patched, likely vulnerable

## Recommended Actions

1. **Immediate**: Create vzdump backups of CT 100 (MySQL) and CT 102 (Tomcat)
2. **Document**: Extract application configs and database schemas
3. **Migrate**: Plan migration to modern containerized stack
4. **Decommission**: Plan server retirement after data extraction

## Migration Path to Modern Infrastructure

### From OpenVZ → Docker/LXC
- **CT 100 (MySQL)**: → PostgreSQL on Docker or MySQL 8 on LXC
- **CT 102 (Tomcat)**: → Java Spring Boot on Docker
- **CT 103 (Nginx)**: → Nginx on Docker or Traefik
- **CT 101 (Memcached)**: → Redis on Docker
- **CT 106 (Hazelcast)**: → Redis Cluster or modern Hazelcast on K8s

### Target Architecture
```
Docker Compose Stack:
- nginx-lb (traefik or nginx)
- java-app (spring-boot container)
- postgres-db (or mysql-8)
- redis-cache
- monitoring (prometheus + grafana)
```

## Next Steps

**Choose extraction strategy:**
1. Quick MySQL dump only (fastest, most critical data)
2. Full vzdump backups (complete recovery option)
3. Application migration plan (rebuild on modern stack)

**Questions to answer:**
- Is this application still in use?
- What data is absolutely critical?
- Is there existing documentation for the Java application?
- Where should backups be stored?
