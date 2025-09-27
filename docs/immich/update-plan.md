# Immich Update Plan: v1.138.1 → v1.141.1

## Update Overview
- **Current Version**: v1.138.1
- **Target Version**: v1.141.1
- **Update Type**: Minor version update (3 patch releases)
- **Risk Level**: Low to Medium

## Pre-Update Analysis

### Release Notes Summary
**v1.141.1** (Latest):
- ✅ Auto-add uploaded assets to albums (beta)
- ✅ View similar photos using CLIP search
- ✅ Bug fixes for HEIC thumbnails and iOS compatibility
- ✅ Mobile UI improvements and performance fixes

**v1.140.0**:
- ✅ Background Sync (Beta) - automatic asset detection
- ✅ Read-only mode for mobile viewing
- ✅ Location management utility for missing GPS data
- ⚠️ **Action Required**: Toggle upload button off/on for beta timeline users

**v1.139.0**:
- Limited release information available
- Appears to be maintenance release

### Breaking Changes Identified
1. **Beta Timeline Users**: Must toggle upload button off then on to enable background workers
2. **No major configuration changes** required
3. **No database migrations** explicitly mentioned

## Pre-Update Backup Strategy

### 1. Database Backup
```bash
# Create manual database backup
ssh root@192.168.1.9 "docker exec immich_postgres pg_dump -U postgres immich > /srv/raid/immich-lib/backups/pre-v1141-upgrade-$(date +%Y%m%d_%H%M%S).sql"
```

### 2. Configuration Backup
```bash
# Backup container configurations
ssh root@192.168.1.9 "docker inspect immich_server immich_postgres immich_machine_learning immich_redis > /srv/raid/immich-lib/backups/container-config-backup-$(date +%Y%m%d_%H%M%S).json"
```

### 3. Storage Verification
- Current storage: 57,383 assets in `/srv/raid/immich-lib/`
- Available space: 1.9TB free on BTRFS RAID mirror
- Backup location verified and accessible

## Update Procedure

### Step 1: Stop Services
```bash
ssh root@192.168.1.9 "docker stop immich_server immich_machine_learning"
# Keep postgres and redis running to avoid data issues
```

### Step 2: Pull New Images
```bash
ssh root@192.168.1.9 "docker pull ghcr.io/immich-app/immich-server:v1.141.1"
ssh root@192.168.1.9 "docker pull ghcr.io/immich-app/immich-machine-learning:v1.141.1"
```

### Step 3: Update Containers
```bash
# Remove old containers
ssh root@192.168.1.9 "docker rm immich_server immich_machine_learning"

# Recreate with new version (using existing configuration)
# Note: This assumes the containers were created with proper volume mounts
# Container recreation will use existing volumes and configuration
```

### Step 4: Start Updated Services
```bash
ssh root@192.168.1.9 "docker start immich_postgres immich_redis"
# Start new containers (method depends on how containers were originally created)
```

### Step 5: Post-Update Verification
```bash
# Check web interface
curl -I http://192.168.1.9:2283

# Verify database connectivity
ssh root@192.168.1.9 "docker exec immich_postgres pg_isready -U postgres"

# Check asset count
ssh root@192.168.1.9 "docker exec immich_postgres psql -U postgres -d immich -c 'SELECT COUNT(*) FROM asset;'"
```

## Post-Update Actions

### 1. Beta Timeline Configuration
If using beta timeline features:
1. Access web interface: http://192.168.1.9:2283
2. Navigate to settings
3. Toggle upload button OFF then ON to enable background workers

### 2. Feature Verification
- ✅ Test photo upload functionality
- ✅ Verify AI recognition still working
- ✅ Check album access and creation
- ✅ Test new CLIP search feature
- ✅ Verify mobile app connectivity

### 3. Performance Monitoring
- Monitor container resource usage
- Check thumbnail generation speed
- Verify database performance
- Watch for any error logs

## Rollback Plan

### If Update Fails:
1. **Stop new containers**
2. **Restore previous container versions**:
   ```bash
   docker pull ghcr.io/immich-app/immich-server:v1.138.1
   docker pull ghcr.io/immich-app/immich-machine-learning:v1.138.1
   ```
3. **Restore database if needed**:
   ```bash
   docker exec immich_postgres psql -U postgres -d immich < /srv/raid/immich-lib/backups/pre-v1141-upgrade-*.sql
   ```
4. **Verify rollback successful**

## Risk Assessment

### Low Risk Items:
- ✅ Patch version update (minor changes)
- ✅ No major database schema changes mentioned
- ✅ Existing data and volumes preserved
- ✅ Automatic daily backups available

### Medium Risk Items:
- ⚠️ Container recreation process
- ⚠️ Beta timeline feature changes
- ⚠️ New background sync functionality

### Mitigation:
- Complete backup before starting
- Test web interface immediately after update
- Monitor logs for first 24 hours
- Keep rollback plan ready

## Recommended Timing
- **Best Time**: During low usage period (early morning)
- **Estimated Downtime**: 15-30 minutes
- **Monitoring Period**: 24-48 hours post-update

## Update Command Summary

```bash
# Execute update script
cd /Users/jm/Codebase/internet-control/docs/immich
./immich-update.sh
```

This update should be relatively straightforward given the minor version increment and lack of major breaking changes in the release notes.