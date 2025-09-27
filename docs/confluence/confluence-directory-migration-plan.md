# Confluence Directory Migration Plan: Consolidate to Single JIRA Remote Directory

## Overview
This document provides a safe migration plan to resolve the duplicate user authentication issue by consolidating all user management to the remote JIRA directory (ID: 139624449) and deactivating the internal directory (ID: 5373953).

## Research Summary

Based on Atlassian official documentation and best practices:

### Key Findings from Research
1. **Directory Order Significance**: Authentication searches directories in order - first directory with user credentials wins
2. **Aggregating Membership**: By default, Confluence aggregates group membership from all directories (since v5.7)
3. **Write Permissions**: Updates go to first directory with write permissions
4. **External User Management**: Confluence can delegate all user management to external applications (JIRA)
5. **Safe Migration Approach**: Atlassian provides specific database migration procedures

### Official Recommendations
- **Avoid Duplicate Usernames**: "Avoid duplicate usernames across directories" - Atlassian official guidance
- **External Management**: Use External User Management setting to disable internal user management
- **Directory Consolidation**: Migrate users between directories using database queries with proper constraints

## Current State Analysis

### Existing Directory Configuration
```sql
-- Internal Directory (Legacy - TO BE DEACTIVATED)
ID: 5373953, Name: "Confluence Internal Directory"
Type: INTERNAL, Status: Active
Users: Legacy users with hashed passwords (last updated 2019)
Operations: Full CRUD permissions

-- Remote JIRA Directory (Target - TO BE PRIMARY)
ID: 139624449, Name: "jira2023"
Type: CROWD (Remote), Status: Active
Users: Current users with external JIRA references
Operations: Limited to attribute updates
```

### Problem Analysis
- **jmvl user duplicated** across both directories
- **Authentication ambiguity** - system doesn't know which directory to authenticate against
- **Credential mismatch** - internal has old password, remote has external reference
- **Directory dependency** - remote directory relies on JIRA connectivity

## Migration Strategy

### Phase 1: Preparation & Backup (CRITICAL - DO NOT SKIP)

#### Step 1.1: Complete System Backup
```bash
# 1. Stop Confluence service (REQUIRED for consistent backup)
ssh root@pve2 "pct exec 100 -- docker stop confluence_docker"

# 2. Create MySQL database backup
ssh root@pve2 "pct exec 100 -- docker exec mysql_docker mysqldump -u root -p'2gMOv270*%#6' --single-transaction --routines --triggers --all-databases > /backup/confluence-full-backup-$(date +%Y%m%d-%H%M%S).sql"

# 3. Create LXC container snapshot
ssh root@pve2 "pct snapshot 100 before-directory-migration"

# 4. Backup Confluence home directory
ssh root@pve2 "pct exec 100 -- tar -czf /backup/confluence-home-$(date +%Y%m%d-%H%M%S).tar.gz /var/atlassian/application-data/confluence"
```

#### Step 1.2: Verify JIRA Directory Connectivity
```bash
# Test JIRA directory connection
ssh root@pve2 "pct exec 100 -- docker logs confluence_docker | grep -i 'jira2023\|directory.*139624449\|remote.*directory'"

# Verify JIRA service is accessible from Confluence container
ssh root@pve2 "pct exec 100 -- docker exec confluence_docker curl -s http://192.168.1.22:8080/status"
```

#### Step 1.3: Document Current State
```sql
-- Save current directory configuration
ssh root@pve2 "pct exec 100 -- docker exec mysql_docker mysql -h127.0.0.1 -uroot -p'2gMOv270*%#6' confluence -e \"SELECT * FROM cwd_directory ORDER BY id;\" > /backup/directories-before-migration.txt"

-- Save current users by directory
ssh root@pve2 "pct exec 100 -- docker exec mysql_docker mysql -h127.0.0.1 -uroot -p'2gMOv270*%#6' confluence -e \"SELECT u.id, u.user_name, u.directory_id, d.directory_name FROM cwd_user u JOIN cwd_directory d ON u.directory_id = d.id ORDER BY d.directory_name, u.user_name;\" > /backup/users-before-migration.txt"
```

### Phase 2: Pre-Migration Validation

#### Step 2.1: Analyze User Conflicts
```sql
-- Identify all duplicate usernames
SELECT user_name, COUNT(*) as directory_count,
       GROUP_CONCAT(directory_id) as directory_ids,
       GROUP_CONCAT(d.directory_name) as directory_names
FROM cwd_user u
JOIN cwd_directory d ON u.directory_id = d.id
GROUP BY user_name
HAVING COUNT(*) > 1;

-- Analyze jmvl user specifically
SELECT u.*, d.directory_name, d.directory_type
FROM cwd_user u
JOIN cwd_directory d ON u.directory_id = d.id
WHERE u.user_name = 'jmvl';
```

#### Step 2.2: Check Dependencies
```sql
-- Check user_mapping entries
SELECT username, COUNT(*) as mapping_count
FROM user_mapping
WHERE username = 'jmvl';

-- Check group memberships
SELECT m.*, d.directory_name
FROM cwd_membership m
JOIN cwd_directory d ON m.directory_id = d.id
WHERE m.child_user_id IN (
    SELECT id FROM cwd_user WHERE user_name = 'jmvl'
);
```

### Phase 3: Migration Execution (DANGER ZONE - PROCEED WITH EXTREME CAUTION)

#### Step 3.1: Enable External User Management
```bash
# First enable External User Management to prevent new users in internal directory
# This can be done through UI: Admin -> General Configuration -> Security Configuration -> External user management checkbox

# Alternative: Via REST API (requires admin authentication)
curl -H 'Content-type: application/json' \
     -X PUT \
     -d '{"externalUserManagement":true}' \
     -u admin_user:password \
     http://192.168.1.21:8090/rest/crowd/latest/application
```

#### Step 3.2: User Migration Database Queries
⚠️ **CRITICAL WARNING**: These queries will permanently modify your database. Ensure backups are complete and tested.

```sql
-- Start transaction for rollback safety
BEGIN;

-- Step 3.2.1: Remove duplicate users from internal directory
-- (Keep only the JIRA remote directory users)
DELETE FROM cwd_user
WHERE directory_id = 5373953
AND user_name IN (
    SELECT DISTINCT user_name
    FROM cwd_user
    WHERE directory_id = 139624449
);

-- Step 3.2.2: Clean up related tables for deleted users
DELETE FROM cwd_user_attribute
WHERE directory_id = 5373953
AND user_id NOT IN (SELECT id FROM cwd_user WHERE directory_id = 5373953);

DELETE FROM cwd_membership
WHERE directory_id = 5373953
AND child_user_id NOT IN (SELECT id FROM cwd_user WHERE directory_id = 5373953);

-- Step 3.2.3: Update user_mapping to point to JIRA directory users only
UPDATE user_mapping
SET user_key = (
    SELECT CONCAT('jira2023:', external_id)
    FROM cwd_user
    WHERE cwd_user.user_name = user_mapping.username
    AND directory_id = 139624449
)
WHERE username IN (
    SELECT user_name FROM cwd_user WHERE directory_id = 139624449
);

-- CHECKPOINT: Verify changes look correct before committing
SELECT 'Users in Internal Directory' as description, COUNT(*) as count
FROM cwd_user WHERE directory_id = 5373953
UNION ALL
SELECT 'Users in JIRA Directory' as description, COUNT(*) as count
FROM cwd_user WHERE directory_id = 139624449
UNION ALL
SELECT 'Duplicate usernames remaining' as description, COUNT(*) as count
FROM (
    SELECT user_name
    FROM cwd_user
    GROUP BY user_name
    HAVING COUNT(*) > 1
) duplicates;

-- If results look good, commit. If not, ROLLBACK immediately!
COMMIT;
-- ROLLBACK;  -- Use this instead if anything looks wrong
```

#### Step 3.3: Directory Reordering and Deactivation
```sql
-- Move JIRA directory to first position (highest priority)
UPDATE cwd_directory SET directory_position = 0 WHERE id = 139624449;
UPDATE cwd_directory SET directory_position = 1 WHERE id = 5373953;

-- Optionally deactivate internal directory entirely
-- (Only do this after confirming authentication works with JIRA directory)
-- UPDATE cwd_directory SET active = 'F' WHERE id = 5373953;
```

### Phase 4: Testing & Validation

#### Step 4.1: Start Services
```bash
# Start Confluence service
ssh root@pve2 "pct exec 100 -- docker start confluence_docker"

# Wait for service to fully start
sleep 60

# Check service health
ssh root@pve2 "pct exec 100 -- docker logs --tail 20 confluence_docker"
```

#### Step 4.2: Authentication Testing
```bash
# Test jmvl user authentication
curl -s -X GET http://192.168.1.21:8090/rest/api/user/current \
     -u "jmvl:correct_password" \
     -H "Accept: application/json"

# Expected: User details returned (HTTP 200)
# If HTTP 401: Authentication still failing - investigate further
```

#### Step 4.3: Comprehensive Validation
```sql
-- Verify no duplicate users remain
SELECT user_name, COUNT(*) as count
FROM cwd_user
GROUP BY user_name
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- Check jmvl user is in JIRA directory only
SELECT u.user_name, d.directory_name, d.directory_type
FROM cwd_user u
JOIN cwd_directory d ON u.directory_id = d.id
WHERE u.user_name = 'jmvl';
-- Expected: 1 row, directory_name = 'jira2023'

-- Verify user_mapping consistency
SELECT username, COUNT(*) as mapping_count
FROM user_mapping
WHERE username = 'jmvl';
-- Expected: 1 row (or consistent count)
```

### Phase 5: Cleanup & Finalization

#### Step 5.1: Deactivate Internal Directory (Optional but Recommended)
```sql
-- Only after confirming everything works correctly
UPDATE cwd_directory SET active = 'F' WHERE id = 5373953;
```

#### Step 5.2: Clean Up Orphaned Data
```sql
-- Remove orphaned user_mapping entries
DELETE FROM user_mapping
WHERE username NOT IN (
    SELECT user_name FROM cwd_user WHERE active = 'T'
);

-- Clean up empty groups in internal directory (if deactivated)
DELETE FROM cwd_group
WHERE directory_id = 5373953
AND group_name NOT IN ('confluence-administrators');
```

#### Step 5.3: Update Documentation
```bash
# Document final state
ssh root@pve2 "pct exec 100 -- docker exec mysql_docker mysql -h127.0.0.1 -uroot -p'2gMOv270*%#6' confluence -e \"SELECT * FROM cwd_directory ORDER BY id;\" > /backup/directories-after-migration.txt"
```

## Rollback Plan (If Migration Fails)

### Emergency Rollback Procedure
```bash
# 1. Stop Confluence
ssh root@pve2 "pct exec 100 -- docker stop confluence_docker"

# 2. Restore database from backup
ssh root@pve2 "pct exec 100 -- docker exec mysql_docker mysql -u root -p'2gMOv270*%#6' < /backup/confluence-full-backup-YYYYMMDD-HHMMSS.sql"

# 3. Restore from LXC snapshot (nuclear option)
ssh root@pve2 "pct rollback 100 before-directory-migration"

# 4. Start services
ssh root@pve2 "pct exec 100 -- docker start confluence_docker"
```

## Risk Assessment

### High Risk Components
1. **Database Manipulation**: Direct SQL changes to user management tables
2. **Authentication Dependency**: Relies on JIRA service connectivity
3. **User Mapping Changes**: Could break content ownership if not handled correctly
4. **No Rollback for Partial Changes**: Database changes are immediate

### Mitigation Strategies
1. **Complete Backups**: Multiple backup layers (database, container, filesystem)
2. **Transaction Safety**: Use BEGIN/COMMIT/ROLLBACK for atomic changes
3. **Testing Environment**: Recommend testing on development instance first
4. **Staged Approach**: Validate each step before proceeding
5. **External User Management**: Enable to prevent new internal directory users

## Success Criteria

### Authentication Success
- [ ] jmvl user can log in via web interface
- [ ] jmvl user can authenticate via REST API
- [ ] No HTTP 401 authentication failures

### Data Integrity
- [ ] No duplicate usernames across directories
- [ ] User content ownership preserved
- [ ] Group memberships maintained
- [ ] External directory connectivity functional

### System Stability
- [ ] Confluence service starts successfully
- [ ] No critical errors in application logs
- [ ] User directory synchronization working
- [ ] Web interface fully functional

## Post-Migration Monitoring

### Week 1: Intensive Monitoring
- Daily authentication testing for key users
- Monitor Confluence logs for directory-related errors
- Verify JIRA-Confluence integration remains functional
- Check user synchronization status

### Month 1: Stability Validation
- Weekly user directory sync verification
- Monitor system performance and resource usage
- Validate backup and restore procedures work
- Document any issues and resolutions

## Conclusion

This migration plan provides a comprehensive approach to consolidating Confluence user management to a single JIRA remote directory. The key to success is:

1. **Thorough Preparation**: Complete backups and documentation
2. **Careful Execution**: Follow each step precisely with validation
3. **Testing at Each Stage**: Verify changes before proceeding
4. **Rollback Readiness**: Be prepared to revert if issues arise

The migration eliminates the duplicate user authentication issue while centralizing user management in JIRA, which is the intended architecture for integrated Atlassian environments.

---
*Created: September 16, 2025*
*Based on Official Atlassian Documentation and Community Best Practices*