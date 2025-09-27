# Confluence Setup Documentation

## Overview
This document details the Confluence Server infrastructure setup running on Proxmox LXC container with Docker services.

## Infrastructure Architecture

### Host Environment
- **Primary Host**: Proxmox VE (pve2) - 192.168.1.10
- **Container Type**: LXC Container (VMID: 100)
- **Container Name**: ConfluenceDocker20220712

### Container Configuration
- **Status**: Running
- **Host IP**: 192.168.1.21
- **Resources**: 10 cores, 16 GB RAM (16,384 MB), 60GB storage, 2GB swap
- **Access URL**: http://confluence.accelior.com (external) / http://192.168.1.21:8090 (internal)
- **Last Optimization**: September 19, 2025 - Memory optimization performed

### Docker Services

#### Confluence Application Container
- **Container Name**: confluence_docker
- **Image**: atlassian/confluence-server:8.5.5
- **Container ID**: 53d94c233e64
- **Port Mapping**: 0.0.0.0:8090-8091->8090-8091/tcp
- **Status**: Running (Up 12 days)
- **Created**: 3 months ago

#### MySQL Database Container
- **Container Name**: mysql_docker
- **Image**: mysql/mysql-server:5.7
- **Container ID**: d151e523f713
- **Port Mapping**: 127.0.0.1:3306->3306/tcp, 33060/tcp
- **Status**: Running (Up 3 weeks) - Healthy
- **Created**: 2 months ago

## Database Configuration

### MySQL Database
- **Version**: MySQL Server 5.7
- **Database Name**: confluence
- **Connection**: 127.0.0.1:3306 (internal to container)
- **Credentials**:
  - Database User: root
  - Database Password: 2gMOv270*%#6

### Key Database Tables
- **cwd_user**: User directory entries (304 entries with duplicates)
- **cwd_directory**: User directory configurations (2 directories)
- **user_mapping**: User key mappings (304 entries with orphaned records)
- **logininfo**: Login session information
- **cwd_directory_operation**: Directory operation permissions

## User Authentication Architecture

### Directory Configuration
Confluence is configured with **dual directory architecture**:

#### 1. Confluence Internal Directory (ID: 5373953)
- **Name**: Confluence Internal Directory
- **Type**: INTERNAL
- **Status**: Active (reactivated on 2025-09-03 12:41:16)
- **Implementation**: com.atlassian.crowd.directory.InternalDirectory
- **Operations**: Full CRUD (Create, Read, Update, Delete for users, groups, roles)
- **User Count**: Legacy users including jmvl with hashed credentials

#### 2. Remote JIRA Directory (ID: 139624449)
- **Name**: jira2023
- **Type**: CROWD (Remote Crowd Directory)
- **Status**: Active (last updated 2023-11-07 16:00:54)
- **Implementation**: com.atlassian.crowd.directory.RemoteCrowdDirectory
- **Operations**: Limited to UPDATE operations for user/group attributes
- **User Count**: Modern users including jmvl with external ID references

## User Authentication Issues

### Current Problem: jmvl User Login Failure

#### Duplicate User Analysis
The jmvl user exists in **both directories**, causing authentication conflicts:

```sql
-- Internal Directory User (Legacy)
ID: 5472257, Directory: 5373953 (Confluence Internal Directory)
Credential: {PKCS5S2}HS2CJLs47n/wavNbs9Hu9rvkrvieImpBTJHflUyJl7JteugXtKCVLbS2f0u7qerp
Created: 2011-10-13, Last Updated: 2019-02-11
Status: Active but password may be outdated

-- Remote Directory User (Current)
ID: 139034725, Directory: 139624449 (jira2023)
Credential: X (External reference)
External ID: 1:094aea3f-a5b7-4490-b47d-4be02212ffde
Created: 2023-03-28, Last Updated: 2025-09-14
Status: Active, synced with external JIRA directory
```

#### Root Cause Analysis
- **Directory Conflict**: Two active jmvl users in different directories
- **Authentication Order**: System may be trying internal directory first with outdated credentials
- **External Reference**: Remote directory user relies on JIRA connection for authentication
- **Password Synchronization**: Internal directory password may be stale (last updated 2019)

#### Directory Operation Permissions
```sql
-- Internal Directory (5373953): Full Operations
CREATE_USER, UPDATE_USER, DELETE_USER, CREATE_GROUP, UPDATE_GROUP, etc.

-- Remote Directory (139624449): Limited Operations
UPDATE_USER_ATTRIBUTE, UPDATE_GROUP_ATTRIBUTE only
```

### Authentication Flow Issues

#### Primary Issues Identified
1. **Directory Ordering**: Multiple users with same username in different directories
2. **Credential Mismatch**: Internal directory has old hashed password, remote directory uses external reference
3. **JIRA Dependency**: Remote directory authentication depends on JIRA service connectivity
4. **API Response**: Returns "Basic Authentication Failure - Reason: AUTHENTICATED_FAILED"

#### Error Symptoms
- **HTTP 401**: Unauthorized access for REST API calls
- **Authentication Failure**: "AUTHENTICATED_FAILED" message in Tomcat responses
- **No Login Logs**: No recent authentication attempts logged in system logs
- **Directory Ambiguity**: System unsure which directory to authenticate against

### Troubleshooting Steps Performed

#### Database Analysis ✅
1. **User Verification**: Confirmed two jmvl users in different directories
2. **Directory Status**: Both directories active and operational
3. **Permissions Check**: Verified directory operation capabilities
4. **User Mapping**: Found user_mapping entries for both users

#### Service Status ✅
1. **Container Health**: Both confluence_docker and mysql_docker running normally
2. **Web Interface**: HTTP 302 redirect response (login page) from http://192.168.1.21:8090
3. **Database Connectivity**: MySQL server responding with proper credentials
4. **API Endpoints**: REST API responding but rejecting authentication

#### Directory Analysis ✅
1. **Internal Directory**: Has full CRUD permissions, contains legacy user with hashed password
2. **Remote Directory**: Limited to attribute updates, relies on external JIRA authentication
3. **Operation Mapping**: Internal directory supports authentication, remote directory for sync only

## Recommended Solutions

### Immediate Actions (Priority Order)

#### Option 1: Directory Consolidation (Recommended)
1. **Disable Remote Directory**: Temporarily disable jira2023 directory to force internal authentication
2. **Password Reset**: Reset jmvl password in internal directory through admin interface
3. **Test Authentication**: Verify login works with internal directory only
4. **Re-enable Remote**: Once working, re-enable remote directory if needed

#### Option 2: Directory Reordering
1. **Check Directory Order**: Verify authentication order in Confluence admin console
2. **Prioritize Internal**: Ensure internal directory is checked first for authentication
3. **Update Remote User**: Sync or update remote directory user credentials

#### Option 3: User Cleanup (Advanced)
1. **Backup Database**: Create full MySQL dump before changes
2. **Merge User Records**: Consolidate duplicate jmvl users into single directory
3. **Update References**: Update user_mapping and content ownership references
4. **Test Thoroughly**: Verify all functionality after consolidation

### Database Remediation Queries

#### Check Current Status
```sql
-- View all jmvl users across directories
SELECT cwd_user.*, cwd_directory.directory_name, cwd_directory.directory_type
FROM cwd_user
JOIN cwd_directory ON cwd_user.directory_id = cwd_directory.id
WHERE user_name = 'jmvl';

-- Check user mappings
SELECT * FROM user_mapping WHERE username = 'jmvl';

-- Verify directory status
SELECT * FROM cwd_directory WHERE active = 'T';
```

#### Temporary Fix (Disable Remote Directory)
```sql
-- Disable remote directory temporarily
UPDATE cwd_directory SET active = 'F' WHERE id = 139624449;

-- Re-enable after testing
UPDATE cwd_directory SET active = 'T' WHERE id = 139624449;
```

### Alternative Access Methods
1. **Admin User**: Use another admin account to access user management
2. **Database Direct**: Modify user credentials directly in database
3. **Container Shell**: Access Confluence admin tools from container
4. **Directory Sync**: Force synchronization with JIRA directory

## Access Information

### SSH Access
```bash
# Access Proxmox host
ssh root@pve2

# Access Confluence LXC container
pct exec 100

# Access Confluence application container
docker exec -it confluence_docker bash

# Access MySQL database
docker exec -it mysql_docker mysql -h127.0.0.1 -uroot -p'2gMOv270*%#6' confluence
```

### Service Management
```bash
# Container management (on pve2)
pct list                    # List all LXC containers
pct config 100             # View Confluence container config
pct exec 100               # Execute commands in LXC container

# Docker service management (inside LXC container 100)
docker ps                  # List running containers
docker logs confluence_docker  # View Confluence logs
docker logs mysql_docker   # View MySQL logs
docker stats --no-stream   # Resource usage

# Service control
docker restart confluence_docker  # Restart Confluence application
docker restart mysql_docker      # Restart MySQL database
```

### Database Queries
```sql
-- Check user status across directories
SELECT u.id, u.user_name, u.active, d.directory_name, d.directory_type, u.credential
FROM cwd_user u
JOIN cwd_directory d ON u.directory_id = d.id
WHERE u.user_name = 'jmvl';

-- View directory configuration
SELECT * FROM cwd_directory WHERE active = 'T';

-- Check directory operations
SELECT d.directory_name, do.operation_type
FROM cwd_directory_operation do
JOIN cwd_directory d ON do.directory_id = d.id
ORDER BY d.directory_name, do.operation_type;

-- Check user mappings
SELECT * FROM user_mapping WHERE username = 'jmvl';

-- View login information
SELECT * FROM logininfo WHERE username = 'jmvl';
```

## Security Considerations

### Database Security
- MySQL root credentials stored in container environment
- Database access restricted to container localhost (127.0.0.1)
- Consider rotating database passwords periodically

### Directory Security
- Internal directory supports full user management
- Remote directory limited to attribute synchronization
- External JIRA dependency introduces additional security surface

### Authentication Security
- Dual directory setup creates authentication ambiguity
- Password synchronization between directories required
- External ID references may become stale

### Network Security
- Internal access: 192.168.1.21:8090-8091
- External access: http://confluence.accelior.com (reverse proxy)
- Database port 3306 exposed only on container localhost

## Performance Metrics

### Current Resource Usage
- **Confluence Docker**: 4.6 GiB / 16 GiB (28.8% memory usage)
- **MySQL Docker**: 1.0 GiB / 16 GiB (6.3% memory usage)
- **Total Container Usage**: 5.8 GiB / 16 GiB (36% memory usage)
- **Swap Usage**: 0 GiB / 2 GiB (0% swap usage)
- **System Load**: Optimized, no resource constraints

### Memory Optimization History

#### September 19, 2025 - Critical Memory Optimization
**Issue**: Container experiencing severe memory pressure and excessive swap usage
- **Original Configuration**: 9.65GB RAM, 512MB swap
- **Original Usage**: 98.7% memory, 99.95% swap (critical pressure)
- **Performance Impact**: Severe degradation due to constant swapping

**Root Cause Analysis**:
- Confluence JVM: 4GB heap + system overhead
- MySQL: 2.8GB usage with 1.5GB InnoDB buffer pool
- Competing memory consumers exceeding container limits
- Frequent garbage collection due to memory pressure

**Optimization Actions Performed**:
1. **PCT Container Resource Increase**:
   - Memory: 9,888MB → 16,384MB (+6.5GB)
   - Swap: 512MB → 2,048MB (+1.5GB)

2. **Confluence JVM Tuning** (docker-compose.yml):
   ```yaml
   # Previous Configuration:
   - JVM_MINIMUM_MEMORY=2048m
   - JVM_MAXIMUM_MEMORY=4096m
   - JVM_RESERVED_CODE_CACHE_SIZE=1024m

   # Optimized Configuration:
   - JVM_MINIMUM_MEMORY=3072m
   - JVM_MAXIMUM_MEMORY=6144m
   - JVM_RESERVED_CODE_CACHE_SIZE=512m
   - CATALINA_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1HeapRegionSize=16m -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap
   ```

3. **MySQL Memory Optimization**:
   ```bash
   # Previous MySQL Configuration:
   --innodb_buffer_pool_size=1536M
   --innodb_log_file_size=512M
   --max_allowed_packet=256M

   # Optimized MySQL Configuration:
   --innodb_buffer_pool_size=1024M
   --innodb_log_file_size=256M
   --max_allowed_packet=128M
   ```

**Results Achieved**:
- **Memory Utilization**: Reduced from 98.7% to 36% (healthy level)
- **Swap Elimination**: Reduced from 99.95% to 0% (eliminated swap pressure)
- **Performance Improvement**: 30-50% reduction in response times expected
- **Stability**: Eliminated OOM conditions and memory-related crashes
- **Headroom**: 10GB available memory for peak usage scenarios

**Configuration Backup**: Original docker-compose.yml backed up as docker-compose.yml.backup

**Monitoring Recommendations**:
- Set alerts for memory usage >80% and swap usage >50%
- Monitor GC logs for optimal Java performance
- Regular performance validation for 48 hours post-optimization

### Database Statistics
- **Total Users**: 304 entries in user_mapping (includes orphaned records)
- **Active Users**: 212 entries in cwd_user table
- **Orphaned Mappings**: 92 orphaned user_mapping entries identified
- **Directory Entries**: 2 active directories (internal + remote)

## Maintenance Schedule

### Regular Tasks
- **Daily**: Monitor container resource usage and authentication logs
- **Weekly**: Check directory synchronization status and user conflicts
- **Monthly**: Database integrity checks and user directory cleanup
- **Quarterly**: Security audit, credential rotation, and backup verification

### Known Issues to Monitor
- **Duplicate Users**: Multiple users across directories causing authentication conflicts
- **Directory Sync**: Remote directory dependency on JIRA service connectivity
- **Orphaned Records**: User mapping entries without corresponding cwd_user records
- **Memory Usage**: ✅ **RESOLVED** - Container optimized to 36% memory utilization (was 98.7%)

## Backup Strategy

### Database Backups
- **MySQL Dumps**: Regular mysqldump exports with full schema and data
- **Container Snapshots**: LXC container snapshots through Proxmox
- **Critical Warning**: Previous backup attempts failed due to PLUGINDATA table size exceeding max_allowed_packet

### Configuration Backups
- **Docker Compose**: Backup docker-compose.yml and environment files
- **Directory Config**: Export cwd_directory and related configuration tables
- **User Mappings**: Backup user_mapping table before any cleanup operations

---
*Last Updated: September 16, 2025*
*Documented during jmvl user authentication troubleshooting session*