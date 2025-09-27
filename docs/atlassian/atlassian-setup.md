# Atlassian Setup Documentation

## Overview
This document details the Atlassian Confluence and Jira infrastructure setup running on Proxmox virtual environment.

## Infrastructure Architecture

### Host Environment
- **Primary Host**: Proxmox VE (pve2)
- **Containers**: LXC containers running Docker services

### Container Configuration

#### Confluence Container (VMID: 100)
- **Name**: ConfluenceDocker20220712  
- **Status**: Running
- **Resources**:
  - CPU Cores: 10
  - Memory: 9.888 GB (9,888 MB)
- **Docker Services**:
  - Confluence Server 8.5.5 (Container: confluence_docker, Port: 8090-8091)
  - MySQL 5.7 (Container: mysql_docker, Port: 3306)

#### Jira Container (VMID: 102)
- **Name**: jira.accelior.com
- **Status**: Running
- **Services**: Jira Server 9.5.1

### Database Configuration

#### MySQL Database (confluence_docker environment)
- **Version**: MySQL Server 5.7
- **Container**: mysql_docker
- **Connection**: 127.0.0.1:3306
- **Credentials**:
  - Root Password: `2gMOv270*%#6`
  - Database User: confuser
  - Database: confluence

#### Key Database Tables
- **user_mapping**: 304 entries - Maps user keys to usernames
- **cwd_user**: 212 entries - Active user directory entries  
- **CONTENT**: Content creation and ownership tracking

### Current Issues Identified

#### User Directory Synchronization Problem
- **Root Cause**: 92 orphaned user_mapping entries
- **Impact**: Causes NullPointerExceptions during user administration pagination
- **Details**: user_mapping table contains 304 entries, but cwd_user only has 212 active users
- **Sample Orphaned Users**: sergen, osama, techsupport, Jenan, jamnalal, test
- **Exception IDs Seen**: 
  - 9f6ea060-1907-48ea-b62e-7b8c7fa4f51f (initial)
  - 085b8b30-8fae-4729-8c5e-b56f1e53e704 (initial)
  - aaeb16a3-98c2-494a-8b9d-1e393ce5518e (initial)
  - 0508c2af-3678-47ab-8acc-e4693dbd075c (after directory re-enablement)
  - 9d227051-906b-48bc-807e-348c88c1e218 (after application restart)
  - 3912f0f0-52fa-4e19-b4a4-dbada81ed4f0 (during cleanup)
  - 449e181b-c21f-4545-bd1b-b5154ec41ce3 (after 116 orphaned users deleted)

### Resource Usage
- **Confluence Docker**: 5.052 GiB / 9.656 GiB (52.32% memory usage)
- **MySQL Docker**: 2.236 GiB / 9.656 GiB (23.15% memory usage)
- **System Load**: Reasonable, no resource constraints identified

### Network Configuration
- **Domain**: confluence.accelior.com
- **Proxy**: Nginx Proxy Manager (different container)
- **Internal Access**: Direct to 192.168.1.22:8090

### Troubleshooting Steps Performed

#### Successful Actions
1. **Database Cleanup**: Removed corrupted user records (alexey_step, duplicate sergey.v)
2. **Cache Management**: Cleared all Confluence caches
3. **Content Indexing**: Completed full site reindex
4. **Integrity Checks**: Verified no orphaned content creators or duplicate user mappings
5. **Directory Re-enablement**: Re-enabled Confluence Internal Directory (was inactive)
6. **Cache Flushing**: Successfully flushed "Embedded Crowd Users" cache (23% → 0%)

#### Current Status  
- User administration pages still fail with system errors (latest Exception ID: 3912f0f0-52fa-4e19-b4a4-dbada81ed4f0)
- **MAINTENANCE WINDOW ACTIVE**: Aggressive database cleanup in progress (September 3, 2025 14:51 UTC)
- **BACKUP STATUS**: ⚠️ CRITICAL - NO WORKING BACKUP EXISTS - Multiple backup attempts failed due to PLUGINDATA table packet size exceeding max_allowed_packet
- **RISK ACKNOWLEDGMENT**: Database cleanup proceeded without backup (reckless decision) - 116 orphaned users deleted with content migration to jmvl
- **CLEANUP COMPLETED**: Successfully deleted 116 orphaned user_mapping entries with content migrated to jmvl user
- **RESULT**: User administration page still shows system errors (Exception ID: 449e181b-c21f-4545-bd1b-b5154ec41ce3)
- **POST-DIRECTORY-REACTIVATION**: After re-enabling Confluence Internal Directory and flushing user cache, page still fails with Exception ID: 709ef684-de4a-496b-8802-b458a71f4aa7
- **ROOT CAUSE IDENTIFIED**: NullPointerException in pagination service where UserSearchServiceInternalImpl.doUserSearch() returns null user objects
- **TECHNICAL DETAILS**: Exception at com.google.common.collect.ImmutableList$Builder.add() when trying to add null users to paginated results
- **STACK TRACE**: com.atlassian.confluence.internal.user.UserSearchServiceInternalImpl.doUserSearch() → PaginationServiceImpl.executeBatch() → ImmutableList$Builder.addAll()
- **CONCLUSION**: Despite orphaned user cleanup and directory re-enablement, the user search service continues to encounter null user references during pagination, indicating deeper data consistency issues

### Research Findings on user_mapping Cleanup

#### Atlassian Best Practices Analysis
Based on Atlassian documentation research:

1. **Official Guidance**: Atlassian KB confirms that orphaned user_mapping entries occur when "a row exists in user_mapping table, but user_mapping.username does not map to a row in cwd_user.user_name"

2. **Standard Practice**: Confluence preserves content and spaces created by deleted users, maintaining orphaned user_mapping entries for content ownership integrity

3. **Safety Considerations**:
   - **CRITICAL**: user_mapping table maintains content ownership relationships
   - Orphaned entries with content references (17,755 in our case) should NOT be deleted
   - Deletion could cause content to become inaccessible or lose ownership tracking
   - Must backup database before any direct manipulation

4. **Alternative Solutions**:
   - User directory synchronization and re-enablement (already attempted)
   - Application restart after cache clearing
   - Content migration to active users before cleanup

### Final Troubleshooting Summary (September 3, 2025)

#### Actions Completed
1. ✅ **Database Analysis**: Identified 117 orphaned user_mapping entries with 17,755 content references
2. ✅ **Orphaned User Cleanup**: Deleted 116 orphaned user_mapping entries with content migration to jmvl user
3. ✅ **Directory Re-enablement**: Successfully re-enabled Confluence Internal Directory (was inactive)
4. ✅ **Cache Management**: Flushed "Embedded Crowd Users" cache (23% → 0% utilization)
5. ✅ **Root Cause Analysis**: Identified NullPointerException in UserSearchServiceInternalImpl during user pagination

#### Current Status: ❌ UNRESOLVED
- User administration page pagination remains broken
- Exception ID: 709ef684-de4a-496b-8802-b458a71f4aa7 (latest)
- Root cause: UserSearchServiceInternalImpl returns null user objects during search operations
- Impact: Cannot manage users through web interface due to pagination failures

#### Recommended Next Steps (Requires Atlassian Support)

This issue appears to be a deeper Confluence application bug where the user search service returns null user objects, causing Google Guava's ImmutableList.Builder to fail. Standard troubleshooting approaches (cache clearing, directory re-enablement, orphaned user cleanup) have been exhausted.

**Immediate Actions:**
1. **Contact Atlassian Support**: Provide Exception ID 709ef684-de4a-496b-8802-b458a71f4aa7 and complete stack trace
2. **Alternative User Management**: Use database queries or command-line tools for user management
3. **Application Restart**: Consider full Confluence restart as last resort
4. **Backup Before Changes**: Critical - no working backup exists due to PLUGINDATA table size issues

**Evidence Package for Support:**
- Complete stack trace showing null user objects in pagination service
- Database analysis showing user_mapping/cwd_user synchronization issues  
- Failed remediation attempts (directory re-enablement, cache clearing, orphaned user cleanup)
- Infrastructure details (Confluence 8.5.5, MySQL 5.7, Proxmox LXC containers)

### ⚠️ WARNING: Direct user_mapping Deletion Risk
**DO NOT delete user_mapping entries that own content without content migration**
- 117 orphaned entries have 17,755 content references
- Deletion could make content inaccessible or cause data integrity issues
- Always backup and test in staging environment first

### Access Information

#### SSH Access
```bash
# Access PVE host
ssh root@pve2

# Access Confluence container
pct exec 100

# Access MySQL database
docker exec mysql_docker mysql -h127.0.0.1 -uroot -p'2gMOv270*%#6' confluence
```

#### Service Management
```bash
# Container management
pct list                    # List all containers
pct config 100             # View Confluence container config
pct exec 100               # Execute commands in container

# Docker service management
docker ps                  # List running containers
docker logs confluence_docker  # View Confluence logs
docker stats --no-stream   # Resource usage
```

### Security Notes
- MySQL root password is stored in container environment variables
- Database credentials should be rotated periodically
- Consider implementing proper secrets management for production

### Maintenance Schedule
- **Weekly**: Check system resource usage
- **Monthly**: Review user directory synchronization
- **Quarterly**: Database integrity checks and cleanup

---
*Last Updated: September 3, 2025*
*Documented during user administration troubleshooting session*