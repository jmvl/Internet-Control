# Calibre-Web Troubleshooting Guide

## Issue Resolution History

### September 12, 2025 - Volume Mount Path Correction

**Problem**: Calibre-Web container was not finding the existing library database

**Symptoms**:
- Container started successfully
- Web interface accessible but showed no books
- Database appeared empty despite existing 1.4MB metadata.db

**Root Cause Analysis**:
```bash
# Found actual library location
/srv/raid/Calibre/Calibre_JM/metadata.db (1.4MB, July 25 update)

# Container was mounting wrong path
/mnt/omv-mirrordisk/Calibre/Calibre_JM/ (empty directory)
```

**Resolution Steps**:
1. **Stopped Container**:
   ```bash
   cd /srv/docker-volume/volumes/portainer_data/_data/compose/32
   docker-compose down
   ```

2. **Backed up Configuration**:
   ```bash
   cp docker-compose.yml docker-compose.yml.backup
   ```

3. **Updated Volume Mounts**:
   ```yaml
   # BEFORE (incorrect):
   volumes:
     - /mnt/omv-mirrordisk/Calibre:/config
     - /mnt/omv-mirrordisk/Calibre/Calibre_JM:/books
   
   # AFTER (corrected):
   volumes:
     - /srv/raid/Calibre:/config
     - /srv/raid/Calibre/Calibre_JM:/books
   ```

4. **Restarted Container**:
   ```bash
   docker-compose up -d
   ```

5. **Verified Database Access**:
   ```bash
   docker exec calibre-web ls -la /books/metadata.db
   # Output: -rw-rw-r-- 1 1000 1000 1384448 Jul 24 22:37 /books/metadata.db
   ```

**Result**: ✅ Container successfully mounted existing Calibre library with all books accessible

---

## Common Troubleshooting Scenarios

### 1. Container Won't Start

**Check Container Status**:
```bash
docker ps -a | grep calibre
docker logs calibre-web
```

**Common Causes**:
- Port 8083 already in use
- Volume mount permission issues
- Invalid docker-compose.yml syntax

**Solutions**:
```bash
# Check port usage
netstat -tlnp | grep 8083

# Fix permissions
chown -R 1000:1000 /srv/raid/Calibre

# Validate compose file
docker-compose config
```

### 2. Database Not Found

**Symptoms**: Web interface shows "Database not configured" or empty library

**Diagnostic Commands**:
```bash
# Check if database exists in container
docker exec calibre-web ls -la /books/metadata.db

# Check host database
ls -la /srv/raid/Calibre/Calibre_JM/metadata.db

# Verify mount paths
docker inspect calibre-web | grep -A 10 Mounts
```

**Solutions**:
- Verify volume mounts in docker-compose.yml
- Ensure database file permissions (should be readable by UID 1000)
- Check database file integrity

### 3. Permission Denied Errors

**Symptoms**: Cannot upload books, edit metadata, or convert files

**Check Current Permissions**:
```bash
ls -la /srv/raid/Calibre/
ls -la /srv/raid/Calibre/Calibre_JM/
```

**Fix Permissions**:
```bash
# Set correct ownership
chown -R 1000:1000 /srv/raid/Calibre/

# Set proper permissions
chmod -R 755 /srv/raid/Calibre/
chmod 664 /srv/raid/Calibre/Calibre_JM/metadata.db
```

### 4. Web Interface Not Accessible

**Test Connectivity**:
```bash
# Test from OMV host
curl -I http://localhost:8083

# Test from network
curl -I http://192.168.1.9:8083
```

**Check Container Network**:
```bash
# Verify container is running
docker ps | grep calibre-web

# Check port binding
docker port calibre-web

# Check container logs
docker logs calibre-web --tail 20
```

### 5. Books Not Displaying

**Verify Database Content**:
```bash
# Check database size and modification date
stat /srv/raid/Calibre/Calibre_JM/metadata.db

# List some book directories
ls /srv/raid/Calibre/Calibre_JM/ | head -10
```

**Database Diagnostics**:
- Database should be > 1MB for active library
- Last modified date should reflect recent activity
- Book directories should contain actual book files

### 6. Conversion Errors

**Symptoms**: E-book format conversion fails

**Check Calibre Dependencies**:
```bash
# Verify DOCKER_MODS is configured
docker inspect calibre-web | grep DOCKER_MODS

# Check if Calibre tools are installed
docker exec calibre-web which calibredb
docker exec calibre-web which ebook-convert
```

**Solution**: Ensure `DOCKER_MODS=linuxserver/mods:universal-calibre` is set

---

## Diagnostic Script

Create a comprehensive diagnostic script:

```bash
#!/bin/bash
# Calibre-Web Diagnostic Script

echo "=== Calibre-Web Diagnostics ==="
echo "Date: $(date)"
echo

echo "1. Container Status:"
docker ps | grep calibre-web
echo

echo "2. Database Status:"
echo "Host database:"
ls -la /srv/raid/Calibre/Calibre_JM/metadata.db 2>/dev/null || echo "Database not found on host"
echo "Container database:"
docker exec calibre-web ls -la /books/metadata.db 2>/dev/null || echo "Database not accessible in container"
echo

echo "3. Volume Mounts:"
docker inspect calibre-web | grep -A 5 '"Mounts"'
echo

echo "4. Recent Logs:"
docker logs calibre-web --tail 10
echo

echo "5. Web Interface Test:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://192.168.1.9:8083
echo

echo "6. Port Binding:"
docker port calibre-web 2>/dev/null || echo "Container not running"
echo

echo "7. Configuration File:"
echo "Docker Compose location: /srv/docker-volume/volumes/portainer_data/_data/compose/32/"
ls -la /srv/docker-volume/volumes/portainer_data/_data/compose/32/docker-compose.yml
```

---

## Recovery Procedures

### Complete Container Reset

If all else fails, completely reset the container:

```bash
# 1. Backup current data
cp -r /srv/raid/Calibre /srv/raid/Calibre.backup

# 2. Stop and remove container
cd /srv/docker-volume/volumes/portainer_data/_data/compose/32
docker-compose down
docker rmi lscr.io/linuxserver/calibre-web:latest

# 3. Clean start
docker-compose pull
docker-compose up -d

# 4. Monitor startup
docker logs calibre-web -f
```

### Database Recovery

If the Calibre database becomes corrupted:

```bash
# 1. Stop container
docker-compose down

# 2. Backup corrupted database
cp /srv/raid/Calibre/Calibre_JM/metadata.db /srv/raid/Calibre/metadata.db.corrupted

# 3. Restore from backup (if available)
cp /srv/raid/Calibre/backups/metadata.db.backup /srv/raid/Calibre/Calibre_JM/metadata.db

# 4. Or recreate with Calibre desktop
# - Open Calibre desktop
# - Point to /srv/raid/Calibre/Calibre_JM/
# - Let Calibre rebuild database from book files

# 5. Restart container
docker-compose up -d
```

---

## Monitoring and Alerts

### Health Check Script
```bash
#!/bin/bash
# Add to cron for regular health checks

CONTAINER_STATUS=$(docker inspect --format="{{.State.Health.Status}}" calibre-web 2>/dev/null)
WEB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.1.9:8083)

if [ "$WEB_STATUS" != "200" ] && [ "$WEB_STATUS" != "302" ]; then
    echo "Alert: Calibre-Web not responding (HTTP $WEB_STATUS)"
    # Add notification logic here
fi

if [ "$CONTAINER_STATUS" != "healthy" ] && [ -n "$CONTAINER_STATUS" ]; then
    echo "Alert: Calibre-Web container unhealthy ($CONTAINER_STATUS)"
    # Add notification logic here
fi
```

### Log Monitoring
```bash
# Monitor for errors
docker logs calibre-web --tail 100 | grep -i error

# Monitor for specific issues
docker logs calibre-web | grep -E "(permission|denied|failed|error)" | tail -20
```

This troubleshooting guide documents the successful resolution of the volume mount path issue and provides comprehensive procedures for future troubleshooting scenarios.