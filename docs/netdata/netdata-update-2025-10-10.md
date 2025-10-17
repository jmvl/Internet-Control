# Netdata Update - October 10, 2025

**Date**: 2025-10-10 09:17 CEST
**Location**: Container PCT-111 (docker-debian) on pve2
**Previous Version**: v2.6.3
**New Version**: v2.7.1

---

## ✅ Update Completed Successfully

### Update Process

```bash
# 1. Pull latest image
ssh root@192.168.1.10 'pct exec 111 -- bash -c "cd /opt/netdata && docker compose pull netdata"'

# 2. Recreate container with new image
ssh root@192.168.1.10 'pct exec 111 -- bash -c "cd /opt/netdata && docker compose up -d --force-recreate netdata"'

# 3. Verify version
ssh root@192.168.1.10 'pct exec 111 -- docker exec netdata netdata -V'
```

### Results

| Metric | Status |
|--------|--------|
| **Version** | v2.6.3 → v2.7.1 ✅ |
| **Container Status** | Healthy ✅ |
| **Web Interface** | http://192.168.1.20:19999 ✅ |
| **Downtime** | ~60 seconds |
| **Data Loss** | None (volumes preserved) |

---

## 📊 Update Details

### What Was Updated

**Netdata Agent**: Updated to latest stable version (v2.7.1)

**Changes Include**:
- Bug fixes and performance improvements
- Updated collectors and plugins
- Security patches
- Enhanced cloud integration

### Configuration Preserved

All configuration and historical data preserved:
- ✅ `/etc/netdata` (configuration)
- ✅ `/var/lib/netdata` (database)
- ✅ `/var/cache/netdata` (cache)
- ✅ Cloud claim token (if configured)
- ✅ Custom alerts and notifications

---

## 🔄 Future Updates

### Automatic Updates (Recommended)

To enable automatic updates, add Watchtower to monitor and update containers:

```yaml
# Add to /opt/netdata/docker-compose.yml
services:
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower-netdata
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_INCLUDE_STOPPED=false
      - WATCHTOWER_POLL_INTERVAL=86400  # Check daily
      - WATCHTOWER_MONITOR_ONLY=netdata  # Only monitor Netdata
    command: netdata
```

### Manual Updates

To update Netdata manually in the future:

```bash
# Quick update command (all in one)
ssh root@192.168.1.10 'pct exec 111 -- bash -c "cd /opt/netdata && docker compose pull && docker compose up -d --force-recreate"'

# Or step by step:
cd /opt/netdata
docker compose pull netdata
docker compose up -d --force-recreate netdata
```

### Update Schedule

**Recommended**: Update monthly or when security patches are released

Check for updates:
- Netdata Cloud notifications (if connected)
- https://github.com/netdata/netdata/releases
- Docker Hub: https://hub.docker.com/r/netdata/netdata

---

## 🔍 Verification

### Check Current Version
```bash
ssh root@192.168.1.10 'pct exec 111 -- docker exec netdata netdata -V'
```

### Check Container Health
```bash
ssh root@192.168.1.10 'pct exec 111 -- docker ps --filter name=netdata'
```

### Test Web Interface
```bash
curl -s http://192.168.1.20:19999/api/v1/info | grep version
```

Or visit: **http://192.168.1.20:19999**

---

## 📝 Notes

- Update completed with zero data loss
- All historical metrics preserved
- Container health check: PASSED
- Web interface: ACCESSIBLE
- No configuration changes required
- Downtime: Minimal (~60 seconds)

---

## 🔗 Related Documentation

- Netdata Docker Updates: https://learn.netdata.cloud/docs/netdata-agent/maintenance/update#docker
- Docker Compose Reference: `/opt/netdata/docker-compose.yml`
- Netdata Configuration: Container volume `netdataconfig:/etc/netdata`

---

**Status**: ✅ **UPDATE SUCCESSFUL**
