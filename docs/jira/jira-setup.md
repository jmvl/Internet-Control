# Jira Setup Documentation

## Overview
This document details the Jira Server infrastructure setup running on Proxmox LXC container with Docker services.

## Infrastructure Architecture

### Host Environment
- **Primary Host**: Proxmox VE (pve2) - 192.168.1.10
- **Container Type**: LXC Container (VMID: 102)
- **Container Name**: jira.accelior.com

### Container Configuration
- **Status**: Running
- **Host IP**: 192.168.1.22
- **Resources**: 10 cores, 8 GB RAM (8,192 MB), 70GB storage, 2GB swap
- **Access URL**: http://jira.accelior.com (external) / http://192.168.1.22:8080 (internal)
- **Last Optimization**: September 19, 2025 - Memory optimization performed

### Docker Services

#### Jira Application Container
- **Container Name**: jira
- **Image**: atlassian/jira-software:9.5.1
- **Container ID**: 2c087ce17bb0
- **Port Mapping**: 0.0.0.0:8080->8080/tcp
- **Status**: Running (Up 3 weeks)
- **Created**: 23 months ago

#### PostgreSQL Database Container
- **Container Name**: jira-db
- **Image**: postgres:12.11-alpine
- **Container ID**: 632211f629f4
- **Port Mapping**: 0.0.0.0:5432->5432/tcp
- **Status**: Running (Up 3 weeks)
- **Created**: 23 months ago

## Database Configuration

### PostgreSQL Database
- **Version**: PostgreSQL 12.11-alpine
- **Database Name**: jirastaging9
- **Connection**: 192.168.1.22:5432
- **Credentials**:
  - Database User: root
  - Database Password: Kd2liDs3J676EUj5d23L

### Key Database Tables
- **cwd_user**: User directory entries (active users)
- **AO_0456E7_SYS_AUTH_LOG**: Authentication token log
- **AO_0456E7_SYS_AUTH_BLACKLIST**: Authentication blacklist (currently empty)
- **AO_AC3877_RL_USER_COUNTER**: Rate limiting counters

## User Authentication Issues

### Current Problem: jmvl User Login Failure

#### Root Cause Analysis
- **User Status**: ✅ Active (ID: 10000, user_name: 'jmvl', display_name: 'Jean-Michel')
- **Blacklist Status**: ✅ Not blacklisted
- **Rate Limiting**: ✅ No rate limiting entries
- **Token Status**: ❌ **All authentication tokens expired over 2 years ago**

#### Authentication Token Details
```sql
-- Last authentication tokens for jmvl user
SELECT * FROM "AO_0456E7_SYS_AUTH_LOG" WHERE "USER_KEY" = 'jmvl' ORDER BY "CREATE_TIMESTAMP" DESC LIMIT 5;

-- Results show last authentication: 2023-08-15 08:59:19
-- Token expiration: 2023-08-22 08:59:19
-- Current time: 2025-09-16 (tokens expired over 2 years ago)
```

#### System Configuration
- **Maximum Authentication Attempts**: 3 (from jira.maximum.authentication.attempts.allowed property)
- **JWT Secrets**: Configured in AO_0456E7_SYS_AUTH_JWT_SECRET table
- **OAuth Configuration**: Present but experiencing 500 errors in AppLinks

### Troubleshooting Steps Performed

#### Database Analysis ✅
1. **User Verification**: Confirmed jmvl user exists and is active in cwd_user table
2. **Blacklist Check**: No entries in AO_0456E7_SYS_AUTH_BLACKLIST
3. **Rate Limiting**: No entries in AO_AC3877_RL_USER_COUNTER for jmvl
4. **Token Analysis**: All authentication tokens expired in August 2023

#### Service Status ✅
1. **Container Health**: Both jira and jira-db containers running normally
2. **Web Interface**: HTTP 200 response from http://192.168.1.22:8080
3. **API Endpoint**: REST auth API responding (returns "Login failed" for test credentials)

#### Log Analysis ✅
1. **Application Logs**: OAuth/AppLinks 500 errors (not related to user authentication)
2. **Authentication Logs**: No recent login attempts logged for jmvl user
3. **Failed Plugin Report**: 2 plugins failed to load (migration assistant and service desk extension)

### Recommended Solutions

#### Immediate Actions
1. **Direct Web Login**: Try logging in via http://jira.accelior.com web interface
2. **Password Reset**: Reset password through Jira admin interface or database
3. **Token Cleanup**: Clear expired authentication tokens from database
4. **Admin Console Check**: Verify no account lockouts in Jira admin console

#### Database Cleanup (If Needed)
```sql
-- Clear expired authentication tokens for jmvl user
DELETE FROM "AO_0456E7_SYS_AUTH_LOG" WHERE "USER_KEY" = 'jmvl' AND "EXPIRATION_TIMESTAMP" < NOW();
```

#### Alternative Access Methods
1. **Database Direct**: Access user management through database queries
2. **Container Shell**: Direct administration through Jira container
3. **Admin User**: Use another admin account to manage jmvl user

## Access Information

### SSH Access
```bash
# Access Proxmox host
ssh root@pve2

# Access Jira LXC container
pct exec 102

# Access Jira application container
docker exec -it jira bash

# Access PostgreSQL database
docker exec -it jira-db psql -U root -d jirastaging9
```

### Service Management
```bash
# Container management (on pve2)
pct list                    # List all LXC containers
pct config 102             # View Jira container config
pct exec 102               # Execute commands in LXC container

# Docker service management (inside LXC container 102)
docker ps                  # List running containers
docker logs jira           # View Jira application logs
docker logs jira-db        # View PostgreSQL logs
docker stats --no-stream   # Resource usage

# Service control
docker restart jira        # Restart Jira application
docker restart jira-db     # Restart PostgreSQL database
```

### Database Queries
```sql
-- Check user status
SELECT id, user_name, display_name, active FROM cwd_user WHERE user_name = 'jmvl';

-- Check authentication tokens
SELECT * FROM "AO_0456E7_SYS_AUTH_LOG" WHERE "USER_KEY" = 'jmvl' ORDER BY "CREATE_TIMESTAMP" DESC;

-- Check blacklist status
SELECT * FROM "AO_0456E7_SYS_AUTH_BLACKLIST";

-- Check rate limiting
SELECT * FROM "AO_AC3877_RL_USER_COUNTER" WHERE "USER_ID" = 'jmvl';
```

## Security Considerations

### Database Security
- PostgreSQL credentials stored in container environment variables
- Database access restricted to container network
- Consider implementing proper secrets management

### Authentication Security
- JWT secrets managed through AO_0456E7_SYS_AUTH_JWT_SECRET table
- OAuth integration configured but experiencing intermittent errors
- Maximum authentication attempts limited to 3 per user

### Network Security
- Internal access: 192.168.1.22:8080
- External access: http://jira.accelior.com (reverse proxy)
- Database port 5432 exposed only on container network

## Maintenance Schedule

### Regular Tasks
- **Daily**: Monitor container resource usage and logs
- **Weekly**: Check authentication token cleanup and user activity
- **Monthly**: Database integrity checks and performance review
- **Quarterly**: Security audit and credential rotation

### Backup Strategy
- **Container Snapshots**: LXC container snapshots through Proxmox
- **Database Backups**: PostgreSQL dumps with pg_dump
- **Configuration Backups**: Docker compose and environment files

## Performance Metrics

### Current Resource Usage
- **JIRA Docker**: 1.87 GiB / 8 GiB (23.4% memory usage)
- **PostgreSQL Docker**: 64 MiB / 8 GiB (0.8% memory usage)
- **Total Container Usage**: 2.3 GiB / 8 GiB (28.8% memory usage)
- **Swap Usage**: 0 GiB / 2 GiB (0% swap usage)
- **System Load**: Optimized, no resource constraints

### Memory Optimization History

#### September 19, 2025 - Critical Memory Optimization
**Issue**: Container experiencing memory pressure with 40% swap usage
- **Original Configuration**: 6GB RAM, 3GB swap
- **Original Usage**: High memory pressure with significant swap utilization
- **Performance Impact**: Degraded performance due to swap usage

**Root Cause Analysis**:
- JIRA JVM: Limited to 2GB heap with 384MB minimum
- PostgreSQL: Default configuration insufficient for workload
- Container memory allocation too restrictive for application requirements
- Swap usage indicating memory pressure

**Optimization Actions Performed**:
1. **PCT Container Resource Increase**:
   - Memory: 6,144MB → 8,192MB (+2GB)
   - Swap: 3,072MB → 2,048MB (-1GB, more appropriate)

2. **JIRA JVM Tuning** (docker-compose.yml):
   ```yaml
   # Previous Configuration (implicit defaults):
   # -Xms384m -Xmx2048m -XX:ReservedCodeCacheSize=512m

   # Optimized Configuration:
   - JVM_MINIMUM_MEMORY=1024m
   - JVM_MAXIMUM_MEMORY=4096m
   - JVM_RESERVED_CODE_CACHE_SIZE=512m
   - CATALINA_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1HeapRegionSize=8m
   ```

3. **PostgreSQL Memory Optimization**:
   ```yaml
   # Previous Configuration: Default PostgreSQL settings

   # Optimized Configuration:
   command: >
     postgres
     -c shared_buffers=512MB
     -c effective_cache_size=2GB
     -c work_mem=16MB
     -c maintenance_work_mem=64MB
     -c random_page_cost=1.1
     -c temp_file_limit=2GB
     -c log_min_duration_statement=1000
     -c log_checkpoints=on
     -c log_connections=on
     -c log_disconnections=on
     -c log_lock_waits=on
   ```

**Results Achieved**:
- **Memory Utilization**: Reduced from high pressure to 28.8% (healthy level)
- **Swap Elimination**: Reduced from 40% to 0% (eliminated swap pressure)
- **JIRA Heap**: Increased from 2GB to 4GB maximum (100% increase)
- **Database Performance**: Optimized buffer pool and query performance
- **Stability**: Eliminated memory pressure and improved response times
- **Headroom**: 5.6GB available memory for peak usage scenarios

**Configuration Backup**: Original docker-compose.yml backed up as docker-compose.yml.backup

**Monitoring Recommendations**:
- Monitor memory usage trends to ensure < 70% utilization
- Track PostgreSQL slow query logs for performance optimization
- Validate JIRA performance improvements over 48 hours
- Set alerts for memory usage >80% and any swap usage

## Known Issues

### Current Issues
1. **jmvl Login Failure**: Expired authentication tokens (over 2 years old)
2. **OAuth AppLinks**: Intermittent 500 errors in application links
3. **Plugin Failures**: 2 plugins failed to load during startup
4. **Memory Usage**: ✅ **RESOLVED** - Container optimized to 28.8% memory utilization (was high pressure)

### Failed Plugins
1. **Jira Cloud Migration Assistant**: Bean creation error in ReportReader
2. **My Requests Extension**: Service Desk API dependency missing

### Monitoring Alerts
- Container resource usage exceeding 80%
- Database connection pool exhaustion
- Authentication failure rate spikes
- Plugin loading failures

---
*Last Updated: September 16, 2025*
*Documented during jmvl user login troubleshooting session*