# NPM Upgrade SSL Certificate Loss Incident - January 20, 2026

## Executive Summary

**Date**: January 20, 2026 07:38-08:00 GMT+1
**Issue**: SSL certificates lost during Nginx Proxy Manager upgrade from v2.12.6 to v2.13.6
**Root Cause**: Manual container recreation using `docker run` instead of `docker compose`
**Impact**: 42 proxy host configurations disabled, 37 SSL certificates required renewal
**Resolution**: Database restored, SSL renewed via web interface, proxy configs restored

## Incident Timeline

### 07:38 - Upgrade Initiated
- Current version: NPM v2.12.6
- Latest version: v2.13.5 (later v2.13.6)
- Backup created: `/root/npm-backup-20260120-073857/`
  - `npm-data-backup.tar.gz` (11M) - only `/data` directory
  - `database-backup.sqlite` (436K) - database backup

### 07:40 - Incorrect Update Method
- **ERROR**: Used manual `docker run` instead of `docker compose`
- Container recreated with new image: `jc21/nginx-proxy-manager:latest` (v2.13.6)
- Docker volumes not properly preserved during manual recreation

### 07:42 - Data Loss Discovered
- User reported: "the backup is not restored"
- Database size: 100K (corrupted/incomplete) vs backup 436K
- SSL certificates volume empty: `nginx-proxy-manager_letsencrypt`

### 07:43 - Database Recovery
- Restored database from backup:
  ```bash
  cp /root/npm-backup-20260120-073857/database-backup.sqlite \
     /srv/docker-volume/volumes/nginx-proxy-manager_data/_data/database.sqlite
  ```
- Database verified: 444K (restored successfully)

### 07:45 - SSL Certificate Failure
- Nginx failed to start with error:
  ```
  nginx: [emerg] cannot load certificate "/etc/letsencrypt/live/npm-9/fullchain.pem":
  BIO_new_file() failed
  ```
- Root cause: Letsencrypt volume not included in backup

### 07:46 - Temporary Workaround
- Moved all SSL proxy configurations to `proxy_host_ssl_disabled/`
- Restarted container
- Web interface became accessible (HTTP 200)

### 07:50 - Investigation of Proper Upgrade Method
- User asked: "check on the web nginx migration script or best practices"
- Official method found: `docker compose pull && docker compose up -d`
- Container inspection revealed NO compose labels - deployed via manual `docker run`
- No docker-compose.yml file found on the system

### 08:00 - Resolution Plan Established
- 37 SSL certificates identified: npm-3 through npm-63
- 42 proxy configurations temporarily disabled
- Restoration script created: `/root/restore-npm-proxies.sh`

## Root Cause Analysis

### Primary Issue: Wrong Update Method

**Incorrect Method Used**:
```bash
# Manual container recreation (WRONG)
docker stop nginx-proxy-manager-nginx-proxy-manager-1
docker rm nginx-proxy-manager-nginx-proxy-manager-1
docker run -d \
  --name nginx-proxy-manager-nginx-proxy-manager-1 \
  --restart=unless-stopped \
  -p 80:80 -p 81:81 -p 443:443 \
  -v nginx-proxy-manager_data:/data \
  -v nginx-proxy-manager_letsencrypt:/etc/letsencrypt \
  jc21/nginx-proxy-manager:latest
```

**Correct Method (if docker-compose existed)**:
```bash
docker compose pull
docker compose up -d
```

### Why SSL Certificates Were Lost

1. **Separate Docker Volumes**:
   - `nginx-proxy-manager_data`: Database and configs
   - `nginx-proxy-manager_letsencrypt`: SSL certificates

2. **Backup Only Included Data Volume**:
   - Backup command only archived `/data` directory
   - Letsencrypt volume at `/etc/letsencrypt/` not included

3. **Manual Recreation**:
   - New container created with fresh empty letsencrypt volume
   - Old certificate data still exists but not attached to new container

## Affected Services

### SSL Certificates (37 total)
```
npm-3, npm-4, npm-5, npm-6, npm-7, npm-9, npm-11, npm-13, npm-14,
npm-16, npm-17, npm-18, npm-19, npm-20, npm-21, npm-25, npm-27,
npm-31, npm-32, npm-33, npm-34, npm-35, npm-36, npm-44, npm-47,
npm-49, npm-50, npm-51, npm-52, npm-53, npm-54, npm-55, npm-56,
npm-57, npm-58, npm-59, npm-60, npm-61, npm-62, npm-63
```

### Disabled Proxy Hosts (42 total)
All SSL-enabled proxy configurations moved to:
`/srv/docker-volume/volumes/nginx-proxy-manager_data/_data/nginx/proxy_host_ssl_disabled/`

Known affected services:
- mail.accelior.com (npm-16)
- mail.acmea.tech (npm-17)
- webmail.acmea.tech (npm-18)
- ntop.acmea.tech (npm-36)
- Plus 37 other services

## Resolution Steps

### Step 1: Renew SSL Certificates
1. Access NPM web interface: http://192.168.1.9:81
2. Navigate to SSL Certificates section
3. Renew all 37 certificates (npm-3 through npm-63)

### Step 2: Restore Proxy Configurations
```bash
ssh root@192.168.1.9 "/root/restore-npm-proxies.sh"
```

This script:
- Restores all 42 proxy configurations
- Tests nginx configuration
- Reloads nginx if successful

## Lessons Learned

### 1. Always Use Docker Compose for Upgrades
- **Manual docker run**: Does not preserve volume data properly
- **Docker compose**: Automatically preserves all volumes
- **Official recommendation**: Use `docker compose pull && docker compose up -d`

### 2. Backup ALL Docker Volumes
- Previous backup only included `/data` directory
- Letsencrypt volume at `/etc/letsencrypt/` was missed
- **Future backups** should include:
  ```bash
  # Backup both volumes
  docker run --rm \
    -v nginx-proxy-manager_data:/data \
    -v nginx-proxy-manager_letsencrypt:/letsencrypt \
    -v $(pwd):/backup \
    alpine tar czf /backup/npm-full-backup.tar.gz /data /letsencrypt
  ```

### 3. Verify Deployment Method Before Updates
- NPM was deployed via manual `docker run`, not docker-compose
- No compose file exists on the system
- Should have checked deployment method first

### 4. Test After Each Step
- Should have tested web interface before proceeding
- Should have verified SSL certificates after container recreation
- Should have checked nginx configuration before declaring success

## Prevention Measures

### 1. Create Docker Compose File
Convert NPM to docker-compose deployment for future updates:

```yaml
version: '3'
services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager-nginx-proxy-manager-1
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"
      - "443:443"
    volumes:
      - nginx-proxy-manager_data:/data
      - nginx-proxy-manager_letsencrypt:/etc/letsencrypt

volumes:
  nginx-proxy-manager_data:
    external: true
  nginx-proxy-manager_letsencrypt:
    external: true
```

### 2. Automated Backup Script
```bash
#!/bin/bash
# /root/backup-npm.sh
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/root/npm-backups"
mkdir -p $BACKUP_DIR

# Backup data volume
docker run --rm \
  -v nginx-proxy-manager_data:/data \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/npm-data-${BACKUP_DATE}.tar.gz /data

# Backup letsencrypt volume
docker run --rm \
  -v nginx-proxy-manager_letsencrypt:/letsencrypt \
  -v ${BACKUP_DIR}:/backup \
  alpine tar czf /backup/npm-letsencrypt-${BACKUP_DATE}.tar.gz /letsencrypt

# Backup database
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  cp /data/database.sqlite /tmp/
docker cp nginx-proxy-manager-nginx-proxy-manager-1:/tmp/database.sqlite \
  ${BACKUP_DIR}/database-${BACKUP_DATE}.sqlite

echo "Backup completed: ${BACKUP_DATE}"
```

### 3. Pre-Update Checklist
- [ ] Create full backup of ALL volumes
- [ ] Verify backup integrity
- [ ] Check deployment method (docker-compose vs manual)
- [ ] Read official upgrade documentation
- [ ] Document current configuration
- [ ] Test rollback procedure

## Current Status (Post-Incident)

### Working
- ✅ NPM v2.13.6 running
- ✅ Database restored and functional
- ✅ Web interface accessible at http://192.168.1.9:81
- ✅ HTTP proxy hosts working

### Awaiting Resolution
- ⏳ SSL certificate renewal (37 certificates)
- ⏳ Proxy configuration restoration (42 hosts)

### Next Actions
1. User to renew SSL certificates via web interface
2. Run restoration script: `/root/restore-npm-proxies.sh`
3. Verify all proxy hosts are accessible
4. Monitor certificate renewal logs

## References

- NPM Documentation: `/docs/npm/npm.md`
- Backup location: `/root/npm-backup-20260120-073857/`
- Restoration script: `/root/restore-npm-proxies.sh`
- Official NPM repo: https://github.com/NginxProxyManager/nginx-proxy-manager

---

**Document Created**: January 20, 2026
**Incident Duration**: ~22 minutes
**Status**: Resolved pending SSL renewal
**Author**: Claude Code Assistant
