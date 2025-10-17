# Immich Major Version Update Plan: v1.141.1 → v2.0.1

## Executive Summary
- **Current Version**: v1.141.1 (running since Sept 12, 2025)
- **Target Version**: v2.0.1 (latest stable, released Oct 3, 2025)
- **Update Type**: **MAJOR VERSION UPGRADE** (v1 → v2)
- **Risk Level**: **MEDIUM-HIGH** (major version changes always carry higher risk)
- **Recommended Approach**: **Staged upgrade with full backup**

## Critical Findings from Research

### Official Release Notes (v2.0.0)
✅ **Good News**:
- Immich team states "no special steps required"
- Standard upgrade process: `docker compose pull && docker compose up`
- Marketed as "first stable version of Immich"
- No explicit breaking changes listed

⚠️ **Community-Reported Issues**:
1. **Invalid Upgrade Path Errors**: Users jumping from v1.129 → v2.0.1 encountered migration errors
2. **Database Reindexing Delays**: Startup can hang for seconds to minutes on:
   - "Reindexing clip_index"
   - "Reindexing face_index"
   - (This is NORMAL for large libraries like yours with 57,383 assets)
3. **v2.0.1 Server Integrity Issues**: Some users reported upload directory access problems
4. **PostgreSQL Concerns**: Database crashes reported in some edge cases

### Your Situation Analysis
✅ **Favorable Factors**:
- You're on v1.141.1 (only 3 versions behind v1.144.1, the last v1.x release)
- Smaller version jump reduces "invalid upgrade path" risk
- BTRFS RAID mirror with automated backups
- Daily backup system in place

⚠️ **Risk Factors**:
- 57,383 assets = substantial reindexing time expected
- Major version upgrade always carries database migration risk
- PostgreSQL already shows "unhealthy" status (though functional)

## Pre-Update Requirements

### 1. Complete Backup (MANDATORY)
```bash
# Connect to OMV host
ssh root@192.168.1.9

# Create timestamped backup directory
BACKUP_DIR="/srv/raid/immich-lib/backups/v2-upgrade-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 1. Database dump (critical)
docker exec immich_postgres pg_dump -U postgres immich | gzip > "$BACKUP_DIR/immich-db-pre-v2.sql.gz"

# 2. Container configurations
docker inspect immich_server immich_postgres immich_machine_learning immich_redis > "$BACKUP_DIR/container-configs.json"

# 3. Environment variables (if using .env file)
cp docker-compose.yml "$BACKUP_DIR/" 2>/dev/null || echo "No compose file found"
cp .env "$BACKUP_DIR/" 2>/dev/null || echo "No .env file found"

# 4. Verify backup integrity
gunzip -t "$BACKUP_DIR/immich-db-pre-v2.sql.gz" && echo "✅ Database backup valid"
```

### 2. Storage Space Verification
```bash
# Check available space (need at least 10-20% free for migrations)
df -h /srv/raid/immich-lib
# Expected: ~1.9TB free (50% available) ✅ SUFFICIENT
```

### 3. Create BTRFS Snapshot (Extra Safety)
```bash
# Create filesystem snapshot before update
btrfs subvolume snapshot /srv/raid /srv/raid-snapshot-pre-v2-$(date +%Y%m%d)
```

### 4. Document Current State
```bash
# Save current container status
docker ps | grep immich > "$BACKUP_DIR/pre-update-status.txt"

# Save current database stats
docker exec immich_postgres psql -U postgres -d immich -c "SELECT COUNT(*) FROM asset;" >> "$BACKUP_DIR/pre-update-status.txt"
```

## Update Procedure

### Phase 1: Preparation (15 minutes)
```bash
# 1. Access OMV host
ssh root@192.168.1.9

# 2. Navigate to Immich directory (find docker-compose.yml)
cd $(find /srv -name "docker-compose.yml" -path "*immich*" -printf "%h\n" | head -1)
pwd  # Confirm location

# 3. Create backup as shown above
# (Execute all Pre-Update Requirements commands)

# 4. Stop Immich services (keep database running)
docker stop immich_server immich_machine_learning
```

### Phase 2: Image Update (10-15 minutes)
```bash
# 1. Pull new v2.0.1 images
docker pull ghcr.io/immich-app/immich-server:v2.0.1
docker pull ghcr.io/immich-app/immich-machine-learning:v2.0.1

# 2. Verify image download
docker images | grep immich
# Should show both v1.141.1 and v2.0.1 images

# 3. Optional: Update docker-compose.yml to pin v2.0.1
# (If using compose file, update image tags)
```

### Phase 3: Container Recreation (5-10 minutes)
```bash
# Method A: If using docker-compose
docker-compose pull
docker-compose up -d

# Method B: Manual container recreation (if no compose file)
# 1. Remove old containers
docker rm immich_server immich_machine_learning

# 2. Recreate with v2.0.1 (use same docker run commands but with new tag)
# (Exact commands depend on your original setup - check container-configs.json)
```

### Phase 4: Database Migration Monitoring (10-60 minutes)
⚠️ **CRITICAL**: Do NOT interrupt this phase!

```bash
# Monitor server logs for migration progress
docker logs -f immich_server

# Expected log sequence:
# 1. "Starting database migration..."
# 2. "Reindexing clip_index..." ← MAY HANG HERE (this is NORMAL)
# 3. "Reindexing face_index..." ← MAY HANG HERE (this is NORMAL)
# 4. "Migration complete"
# 5. "Immich Server is listening on 0.0.0.0:2283"

# With 57,383 assets, expect 10-60 minutes for reindexing
# WAIT PATIENTLY - do not restart container!
```

### Phase 5: Post-Update Verification (15 minutes)
```bash
# 1. Check container health
docker ps | grep immich
# All containers should show "Up" status

# 2. Test web interface
curl -I http://192.168.1.9:2283
# Should return HTTP 200 OK

# 3. Verify database integrity
docker exec immich_postgres psql -U postgres -d immich -c "SELECT COUNT(*) FROM asset;"
# Should return 57,383 (same as before)

# 4. Check for errors in logs
docker logs immich_server --tail 100 | grep -i error
docker logs immich_postgres --tail 100 | grep -i error

# 5. Test critical functionality
# - Access http://192.168.1.9:2283 in browser
# - Verify photo library loads
# - Test search functionality
# - Upload a test photo
# - Verify AI tagging works
```

## Known Issues and Workarounds

### Issue 1: Upload Directory Access Problems (v2.0.1)
**Symptoms**: Server stuck creating/reading files in upload directory

**Solution**:
```bash
# Create .immich file in upload directory
docker exec immich_server touch /usr/src/app/upload/.immich

# Or try Docker system cleanup:
docker system prune -a  # ⚠️ WARNING: Removes unused images
docker compose pull
docker compose up -d
```

### Issue 2: Reindexing Hangs (Expected Behavior)
**Symptoms**: Logs stuck at "Reindexing clip_index" or "Reindexing face_index"

**Resolution**:
- This is NORMAL for large libraries
- Wait patiently (can take 10-60+ minutes for 57k assets)
- DO NOT restart container
- Monitor with `docker stats` to confirm activity

### Issue 3: PostgreSQL Already "Unhealthy"
**Current State**: Your PostgreSQL shows 6,522+ health check failures but is functional

**Action**:
- Document current health check output before upgrade
- After upgrade, compare to ensure no degradation
- Functional database > health check status

## Rollback Procedure (If Needed)

### Quick Rollback (If Migration Fails)
```bash
# 1. Stop v2 containers
docker stop immich_server immich_machine_learning

# 2. Remove v2 containers
docker rm immich_server immich_machine_learning

# 3. Restore database from backup
BACKUP_FILE=$(ls -t /srv/raid/immich-lib/backups/v2-upgrade-*/immich-db-pre-v2.sql.gz | head -1)
gunzip -c "$BACKUP_FILE" | docker exec -i immich_postgres psql -U postgres -d immich

# 4. Pull v1.141.1 images
docker pull ghcr.io/immich-app/immich-server:v1.141.1
docker pull ghcr.io/immich-app/immich-machine-learning:v1.141.1

# 5. Recreate containers with v1.141.1
# (Use saved container-configs.json for exact parameters)
```

### Full System Rollback (If Database Corrupted)
```bash
# 1. Stop all Immich containers
docker stop immich_server immich_postgres immich_machine_learning immich_redis

# 2. Restore BTRFS snapshot
mv /srv/raid/immich-lib /srv/raid/immich-lib-broken
cp -a /srv/raid-snapshot-pre-v2-YYYYMMDD /srv/raid/immich-lib

# 3. Restart containers
docker start immich_postgres immich_redis
docker start immich_server immich_machine_learning
```

## Expected Timeline

| Phase | Duration | Can Fail? |
|-------|----------|-----------|
| Backup Creation | 15-20 min | Low risk |
| Image Download | 10-15 min | Network-dependent |
| Container Stop/Recreate | 5-10 min | Low risk |
| **Database Migration** | **10-60 min** | **HIGHEST RISK** |
| Post-Update Verification | 15-20 min | Low risk |
| **TOTAL DOWNTIME** | **45-120 min** | - |

**Best Time Window**: Early morning (2-6 AM) during low usage

## Decision Matrix

### Proceed with Update IF:
- ✅ You have 2+ hours of downtime tolerance
- ✅ Complete backup successfully created
- ✅ BTRFS snapshot created
- ✅ Comfortable monitoring logs for extended period
- ✅ Can wait patiently through reindexing (no interruptions)

### DELAY Update IF:
- ❌ Current system is critical and cannot tolerate downtime
- ❌ Cannot monitor the update process actively
- ❌ Backup creation fails or cannot be verified
- ❌ Need immediate photo access in next 2 hours

## Recommendation

**PROCEED with CAUTION**:

**Pros**:
- v2.0 is the "stable" release (v1.x will eventually be unsupported)
- Your current v1.141.1 is recent enough for safer migration
- Excellent backup infrastructure in place
- BTRFS snapshots provide additional safety net

**Cons**:
- Major version upgrades always carry risk
- 57k assets = extended migration time
- Some users reported v2.0.1 stability concerns
- PostgreSQL already showing health check issues

**Recommended Path**:
1. ✅ **Create full backup** (database + BTRFS snapshot)
2. ✅ **Perform update during low-usage window** (early morning)
3. ⚠️ **Monitor closely** during database migration phase
4. ✅ **Have rollback plan ready** (practice rollback commands beforehand)
5. ⏸️ **Consider waiting 1-2 weeks** for v2.0.2+ if not urgent (let community find issues)

## Post-Update Monitoring (48 hours)

### Immediate Checks (First Hour)
- Web interface accessibility
- Photo browsing and search
- Upload functionality
- AI tagging/recognition
- Mobile app connectivity

### 24-Hour Monitoring
- Container stability (no crashes/restarts)
- Database performance
- Storage usage patterns
- Error logs review
- Backup system functionality

### 48-Hour Verification
- All features working as before
- No unexpected performance degradation
- Backup system continues to function
- Consider this the "safe" milestone

## Additional Resources

- **Official Upgrade Docs**: https://immich.app/docs/install/upgrading/
- **v2.0.0 Release Discussion**: https://github.com/immich-app/immich/discussions/22546
- **Community Troubleshooting**: https://github.com/immich-app/immich/discussions

## Update Execution Checklist

Before starting, print this checklist:

- [ ] Read entire update plan
- [ ] Schedule 2-hour maintenance window
- [ ] Create database backup
- [ ] Verify backup integrity
- [ ] Create BTRFS snapshot
- [ ] Document current state
- [ ] Pull v2.0.1 images
- [ ] Stop immich_server and immich_machine_learning
- [ ] Recreate containers with v2.0.1
- [ ] Monitor migration logs (DO NOT INTERRUPT)
- [ ] Verify web interface accessible
- [ ] Verify asset count matches (57,383)
- [ ] Test upload functionality
- [ ] Test AI features
- [ ] Monitor for 48 hours
- [ ] Document update completion

---

**Status**: Ready for execution
**Created**: 2025-10-10
**Next Review**: After v2.0.2+ releases or when ready to proceed
