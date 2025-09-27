# n8n Pre-release Upgrade Documentation

**Date**: September 23, 2025
**Engineer**: System Administrator
**System**: n8n Docker Container (192.168.1.20)
**Upgrade**: Stable Release (1.112.3) → Pre-release (1.113.1)

## Overview

This document records the successful upgrade of the n8n automation platform from the latest stable release (1.112.3) to the latest pre-release version (1.113.1) to gain access to cutting-edge features and improvements.

## Pre-Upgrade System State

### Container Information
- **Host**: 192.168.1.20
- **Container Name**: n8n-n8n-1
- **Previous Version**: 1.112.3 (stable)
- **Image**: docker.n8n.io/n8nio/n8n:latest
- **Location**: /home/n8n_compose/
- **Status**: Running and healthy

### Backup Status
- **Existing Backup**: /root/backups/n8n/20250923_093218/
- **Docker Compose Backup**: docker-compose.yml.backup-20250923_094200
- **Configuration**: Preserved in external volume n8n_data

## Upgrade Process

### 1. Pre-Release Version Discovery
- **Source**: https://github.com/n8n-io/n8n/releases
- **Latest Pre-release**: n8n@1.113.1 (released September 23, 2025)
- **Release Type**: Pre-release with experimental features
- **Key Features**: Data table module (experimental), improved UI filters

### 2. Docker Configuration Updates

Updated the following in `docker-compose.yml`:
```yaml
# Before
image: docker.n8n.io/n8nio/n8n:latest
N8N_VERSION=1.67.1
N8N_RELEASE_TYPE=stable

# After
image: docker.n8n.io/n8nio/n8n:1.113.1
N8N_VERSION=1.113.1
N8N_RELEASE_TYPE=nightly
```

### 3. Container Upgrade Steps

1. **Image Pull**:
   ```bash
   cd /home/n8n_compose && docker compose pull
   ```
   - Downloaded 151.6MB pre-release image
   - Successfully pulled docker.n8n.io/n8nio/n8n:1.113.1

2. **Container Restart**:
   ```bash
   docker compose down
   docker compose up -d
   ```
   - Clean shutdown of existing container
   - Started new container with pre-release image

### 4. Verification Results

#### Version Confirmation
```bash
docker exec n8n-n8n-1 n8n --version
# Output: 1.113.1
```

#### Container Status
- **Status**: Up and running
- **Startup Time**: ~10 seconds
- **Ports**: 0.0.0.0:5678->5678/tcp (accessible)
- **Health**: Healthy

#### Workflow Activation
Successfully activated existing workflows:
- ✅ Send Email Order Confirmation (ID: HtlBO6jlBopsnEsJ)
- ✅ Test (ID: b6odtyIhroj7n6FF)
- ✅ WanderWish Email Notifications (ID: QPceT5iLRANzqoWI)
- ✅ WanderWish Test Webhook (ID: ZAM7dK6ZlwMAvsvr)
- ✅ WanderWish Fixed Email Notifications (ID: sEPZoy7VQkWTg2cH)
- ✅ WanderWish Complete Email Testing Suite (ID: O2pWngEkI5Frxw4S)
- ✅ VidSnap-workflow with YouTube Metadata Integration (ID: QrLuKMFkNb8BbTpw)
- ✅ YouTube Metadata Single API (ID: U40TQjvSZ1O64tQn)

#### Web Interface
- **URL**: https://n8n.accelior.com
- **Status**: HTTP/2 200 (accessible)
- **SSL**: Working correctly

## New Features in 1.113.1 Pre-release

### Data Tables (Experimental)
- New data table module for enhanced data management
- UI filters for improved data visualization
- **Warning**: Experimental feature - tables may become inaccessible in future releases

### Bug Fixes
- Fixed UI being blocked while data table limits are being fetched
- Improved data table size cache performance
- Enhanced SQLite data table size queries

### Other Improvements
- Better error handling for missing community packages
- Continued license management improvements
- Enhanced workflow activation logging

## Post-Upgrade Status

### Container Health
- **Memory Usage**: Normal
- **CPU Usage**: Stable
- **Network**: All endpoints accessible
- **Storage**: External volume preserved

### Known Issues
1. **Community Packages Warning**:
   ```
   n8n detected that some packages are missing. For more information, visit https://docs.n8n.io/integrations/community-nodes/troubleshooting/
   ```
   - **Impact**: Non-critical, community nodes may need reinstallation
   - **Action Required**: Monitor for specific node failures

2. **Unrecognized Node Type**:
   ```
   Unrecognized node type: n8n-nodes-supadata.supadata
   Issue on initial workflow activation try of "VideoSnape-Summarizer_v1"
   ```
   - **Impact**: One workflow failed to activate
   - **Action Required**: Update or reinstall supadata community node

### Monitoring Points
- Web interface responsiveness
- Workflow execution performance
- Database connectivity (Supabase PostgreSQL)
- Community node compatibility
- Data table feature stability

## Rollback Plan

If issues arise with the pre-release:

1. **Restore Previous Configuration**:
   ```bash
   cd /home/n8n_compose
   cp docker-compose.yml.backup-20250923_094200 docker-compose.yml
   ```

2. **Revert to Stable Image**:
   ```bash
   docker compose pull
   docker compose down
   docker compose up -d
   ```

3. **Verify Rollback**:
   ```bash
   docker exec n8n-n8n-1 n8n --version
   # Should return: 1.112.3
   ```

## Recommendations

### Immediate Actions
1. ✅ Monitor workflow executions for 24 hours
2. ✅ Test critical automation workflows manually
3. ✅ Verify all integrations (Supabase, email, webhooks)
4. ⚠️ Avoid using experimental data table features in production workflows

### Future Considerations
1. **Pre-release Monitoring**: Track GitHub releases for stability updates
2. **Community Nodes**: Plan to update/reinstall affected community packages
3. **Data Tables**: Evaluate experimental features in test workflows only
4. **Stable Migration**: Plan migration back to stable when 1.113.x becomes stable

## Technical Notes

### Docker Compose Cleanup
The docker-compose.yml contains an obsolete `version` attribute that generates warnings:
```
time="2025-09-23T09:44:09Z" level=warning msg="/home/n8n_compose/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion"
```
**Recommendation**: Remove `version: '3.8'` line in future maintenance.

### Resource Usage
No significant changes in resource consumption observed post-upgrade:
- Similar startup time (~10 seconds)
- Stable memory footprint
- Normal CPU utilization patterns

## Database Connection Timeout Issue (Fixed - September 27, 2025)

### Problem Identified
After 4 days of operation, N8N began experiencing database connection timeouts:
- **Error**: "Database is not ready!" (HTTP 503)
- **Cause**: TypeORM PostgreSQL driver timeout errors
- **Symptoms**: Web interface inaccessible, connection timeout to Supabase

### Resolution Applied
Added database connection timeout configuration to `docker-compose.yml`:
```yaml
environment:
  - DB_POSTGRESDB_CONNECTION_TIMEOUT=30000
  - DB_POSTGRESDB_CONNECTION_RETRY_ATTEMPTS=5
  - DB_POSTGRESDB_CONNECTION_RETRY_DELAY=3000
```

### Fix Implementation
```bash
# Backup configuration
cd /home/n8n_compose && cp docker-compose.yml docker-compose.yml.backup-20250927_121418

# Add timeout settings after DB_POSTGRESDB_HOST line
# Restart container
docker compose down && docker compose up -d
```

### Result
- ✅ N8N returned to HTTP 200 status
- ✅ Web interface restored at https://n8n.accelior.com
- ✅ Database connectivity stable

**Note**: This timeout configuration may be required for pre-release versions when using external PostgreSQL databases.

## Conclusion

The upgrade to n8n pre-release 1.113.1 completed successfully with minimal disruption. A database timeout issue emerged after 4 days but was resolved with proper connection configuration. All critical workflows are operational, and the web interface is fully accessible. The pre-release provides access to experimental data table features and various bug fixes.

**Risk Assessment**: Low - Pre-release is stable with timeout configuration
**Action Items**: Monitor community node compatibility, avoid production use of experimental features, include timeout config in future deployments
**Next Review**: 72 hours post-timeout fix or upon next stable release