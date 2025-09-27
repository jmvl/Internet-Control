# n8n Container Update Maintenance - September 23, 2025

## Overview
Updated n8n Docker container from version 1.108.1 to 1.112.3 on Docker host 192.168.1.20.

## Pre-Update Status
- **Previous Version**: 1.108.1
- **Container Name**: n8n-n8n-1
- **Docker Image**: docker.n8n.io/n8nio/n8n:latest
- **Configuration Location**: /home/n8n_compose/docker-compose.yml
- **Port**: 5678
- **Database**: External Supabase PostgreSQL
- **Workflow Count**: 51 workflows exported

## Update Process

### 1. Backup Creation
```bash
# Created data volume backup
mkdir -p /root/backups/n8n/20250923_093218
docker run --rm -v n8n_data:/source -v /root/backups/n8n/20250923_093218:/backup alpine tar czf /backup/n8n_data_backup.tar.gz -C /source .

# Exported workflows
docker exec n8n-n8n-1 n8n export:workflow --backup --output=/tmp/workflows_backup.json
```

**Backup Location**: `/root/backups/n8n/20250923_093218/`
- `n8n_data_backup.tar.gz` (13,806 bytes)
- `workflows_backup.json` (51 workflows)

### 2. Container Update Steps
```bash
# Stop containers
docker stop n8n-n8n-1 n8n-gotenberg-1

# Pull latest image
docker pull docker.n8n.io/n8nio/n8n:latest

# Remove old containers
docker rm n8n-n8n-1 n8n-gotenberg-1

# Start with updated image
cd /home/n8n_compose && docker compose up -d
```

### 3. Post-Update Verification
- **New Version**: 1.112.3 ✓
- **Container Status**: Running ✓
- **Web Interface**: Accessible on port 5678 ✓
- **Workflows**: All 51 workflows preserved ✓
- **Database Connection**: Connected to Supabase ✓

## Issues Identified

### Community Package Error
One workflow (`VideoSnape-Summarizer_v1`) shows errors due to missing custom node:
```
Unrecognized node type: n8n-nodes-supadata.supadata
```

**Resolution**: This appears to be a custom/community package that was not preserved during the update. The package `n8n-nodes-supadata` is not available in the public npm registry, suggesting it was either:
- A local development package
- A package that has been deprecated/removed
- A typo in the node type name

**Recommendation**: Review the workflow and either:
- Replace with equivalent functionality using built-in nodes
- Find an alternative community package
- Rebuild the custom node if it was locally developed

### Environment Variable Deprecations
The system shows warnings about deprecated configuration:
- `N8N_RUNNERS_ENABLED` - Task runners will be enabled by default in future versions
- `N8N_BLOCK_ENV_ACCESS_IN_NODE` - Default will change from false to true

## Configuration Recommendations

### Update Environment Variables
Add to `/home/n8n_compose/.env`:
```bash
N8N_RUNNERS_ENABLED=true
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_BLOCK_ENV_ACCESS_IN_NODE=false  # If environment access is needed
```

### Docker Compose Cleanup
Remove obsolete version attribute from `/home/n8n_compose/docker-compose.yml`:
```yaml
# Remove this line:
# version: '3.8'
```

## System Status After Update

### Functional Verification
- ✅ n8n version successfully updated to 1.112.3
- ✅ Container running and healthy
- ✅ Web interface accessible (HTTP 200)
- ✅ Database connectivity maintained
- ✅ All 51 workflows preserved
- ✅ Core functionality operational
- ⚠️ One workflow with custom node dependency issue

### Network Configuration
- **Host**: 192.168.1.20
- **Port**: 5678 (mapped to container port 5678)
- **External URL**: https://n8n.accelior.com/
- **Database**: Supabase PostgreSQL (aws-0-eu-central-1.pooler.supabase.com:6543)

## Maintenance Notes

### Backup Strategy
- Backups are stored in `/root/backups/n8n/` with timestamp directories
- Both volume data and workflow exports are created
- Retention policy should be implemented for backup cleanup

### Future Updates
- Monitor for new releases at https://github.com/n8n-io/n8n/releases
- Consider implementing automated backup before updates
- Review community packages before major version updates
- Test custom workflows after updates

### Docker Compose Management
The system uses Docker Compose in `/home/n8n_compose/` with:
- External volume: `n8n_data`
- External network: `n8n_default`
- Environment file: `.env`

## Rollback Procedure (if needed)
```bash
# Stop current container
docker stop n8n-n8n-1 && docker rm n8n-n8n-1

# Restore data from backup
docker run --rm -v n8n_data:/restore -v /root/backups/n8n/20250923_093218:/backup alpine tar xzf /backup/n8n_data_backup.tar.gz -C /restore

# Pull specific version (if needed)
docker pull docker.n8n.io/n8nio/n8n:1.108.1

# Update docker-compose.yml to use specific version
# Then: docker compose up -d
```

## Contact Information
- **Infrastructure Engineer**: Claude Code
- **Maintenance Date**: September 23, 2025
- **Documentation**: /docs/n8n/n8n-update-maintenance-2025-09-23.md