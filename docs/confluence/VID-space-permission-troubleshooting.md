# Confluence VID Space Permission Issue - Diagnostic Report

**Date**: 2025-10-07
**Space**: VID (VIDSNAP)
**Issue**: Users from acmea-team group not appearing in permission assignment UI
**Reporter**: JMVL
**Status**: Root cause identified

## Executive Summary

The issue preventing users like "rachel-docs" from appearing in the VID space permission assignment UI is **NOT** related to space-level permissions, but rather to **Confluence application access**. Users in the acmea-team group lack membership in the required `confluence-user` or `confluence-users` application access groups.

## Diagnostic Findings

### 1. Space Configuration
- **Space Key**: VID
- **Space ID**: 264503297
- **Space Name**: VIDSNAP
- **Space Type**: global
- **Current Access**: Only JMVL has explicit permissions

### 2. Group Verification

#### acmea-team Group (CONFIRMED EXISTS)
The group exists and contains 11 members:
- alex-architect
- clara-design
- david-qa
- elena-database
- igor-backend
- jmvl
- maxim-devops
- maya-product
- **rachel-docs** ✓
- sarah-scrum
- sophie-frontend

**Group Endpoint**: `https://confluence.accelior.com/rest/api/group/acmea-team`

### 3. User Verification

#### rachel-docs User Analysis
- **Username**: rachel-docs
- **Display Name**: Rachel (Docs)
- **User Key**: 2c92808399801de70199a220f4f80009
- **Account Type**: known
- **Status**: Active

#### Current Group Memberships
rachel-docs is a member of only 2 groups:
1. `acmea-team` ✓
2. `jira-users` (JIRA application access only)

#### MISSING Critical Membership
- **NOT in**: `confluence-user` group (singular)
- **NOT in**: `confluence-users` group (plural)

### 4. Application Access Groups

Three Confluence-related groups exist in the system:
1. `confluence-administrators` - Admin access
2. `confluence-user` (singular) - Standard application access group
3. `confluence-users` (plural) - Alternative application access group (32 members currently)

#### Comparison with Working User (JMVL)
JMVL (who can access and has VID permissions) is a member of 18 groups including:
- `confluence-user` ✓ (CRITICAL)
- `confluence-administrators` ✓
- `acmea-team` ✓
- `jira-users` ✓
- Other project-specific groups

## Root Cause Analysis

### Primary Issue: Missing Confluence Application Access

The **confluence-user** or **confluence-users** group membership is a prerequisite for:
1. Appearing in Confluence user picker/search interfaces
2. Being assignable to space/page permissions
3. Creating and editing Confluence content
4. Full Confluence UI functionality

### Why This Affects Permission Assignment

When attempting to assign permissions via the Confluence UI:
1. The permission picker queries for users with Confluence application access
2. Users without `confluence-user(s)` membership are filtered out
3. The group "acmea-team" exists, but its members lack the base application access
4. Result: Users like rachel-docs don't appear in the selection dialog

### Distinction from Space Permissions

This is **NOT** a space-level permission issue. This is an **application-level licensing/access** issue:
- Space permissions control what users can do within a specific space
- Application access controls whether users can use Confluence at all
- Without application access, users cannot be assigned space permissions

## Remediation Steps

### Immediate Solution

Add all acmea-team members who need Confluence access to the appropriate application access group:

```bash
# Via Confluence REST API (requires admin token)
# For each user in acmea-team:

curl -X PUT 'https://confluence.accelior.com/rest/api/group/user?groupname=confluence-user' \
  -H 'Authorization: Bearer <ADMIN_TOKEN>' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "rachel-docs"
  }'
```

### Manual UI Steps

1. Navigate to Confluence Administration
2. Go to **User Management** > **Groups**
3. Select the `confluence-user` group
4. Click **Add Members**
5. Search and add the following users:
   - alex-architect
   - clara-design
   - david-qa
   - elena-database
   - igor-backend
   - maxim-devops
   - maya-product
   - rachel-docs
   - sarah-scrum
   - sophie-frontend

### Alternative Automated Approach

If you want to automatically grant Confluence access to all acmea-team members:

```bash
#!/bin/bash
# Script to add all acmea-team members to confluence-user group

CONFLUENCE_URL="https://confluence.accelior.com"
ADMIN_TOKEN="<YOUR_ADMIN_TOKEN>"

# Get all acmea-team members
members=$(curl -s -X GET \
  "${CONFLUENCE_URL}/rest/api/group/acmea-team/member?limit=200" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" | \
  jq -r '.results[].username')

# Add each member to confluence-user group
for user in $members; do
  echo "Adding ${user} to confluence-user group..."
  curl -X PUT \
    "${CONFLUENCE_URL}/rest/api/group/user?groupname=confluence-user" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${user}\"}"
  sleep 1
done
```

### VID Space Permission Assignment (After Application Access)

Once users have Confluence application access, assign acmea-team group to VID space:

1. Navigate to **VID Space** > **Space Settings** > **Space Permissions**
2. Click **Add Group**
3. Search for "acmea-team"
4. Select desired permissions (e.g., View, Edit)
5. Save changes

Alternatively via API (after application access is granted):
```bash
# Note: Space permission API may vary by Confluence version
# Consult your Confluence REST API documentation for exact endpoint
```

## Licensing Considerations

### Important Note
Adding users to `confluence-user` group typically consumes Confluence user licenses. Verify:
1. Available Confluence licenses in your instance
2. Whether rachel-docs and other acmea-team members should have licensed Confluence access
3. Budget approval for additional licenses if needed

Check current license usage:
- Navigate to **Confluence Admin** > **License Details**
- Verify available user seats

## Verification Steps

After adding users to confluence-user group:

1. **Test User Search**:
   - Go to VID space permissions
   - Click "Add Permissions"
   - Search for "rachel-docs"
   - User should now appear in results ✓

2. **Verify Group Membership**:
   ```bash
   curl -s -X GET \
     'https://confluence.accelior.com/rest/api/user/memberof?username=rachel-docs' \
     -H 'Authorization: Bearer <TOKEN>' | \
     jq '.results[] | .name'
   ```
   Should include `confluence-user` or `confluence-users`

3. **Test Login**:
   - Have rachel-docs log into Confluence
   - Verify they can access the Confluence homepage
   - Check they can navigate (even without space permissions yet)

## Prevention for Future

### Best Practice: Automate Application Access
When creating functional groups like "acmea-team":
1. Define a policy for which groups automatically get Confluence access
2. Document application access requirements in group descriptions
3. Consider using group hierarchy (nested groups) if supported

### Monitoring
Set up alerts for:
- New users added to functional groups without application access
- Permission assignment failures in Confluence admin logs
- License utilization thresholds

## Related Documentation

- **Confluence User Management**: https://confluence.accelior.com/admin/users
- **Group Management**: https://confluence.accelior.com/admin/groups
- **License Management**: https://confluence.accelior.com/admin/license

## API Endpoints Used in Diagnostics

```
GET  /rest/api/space/VID
GET  /rest/api/group/acmea-team
GET  /rest/api/group/acmea-team/member
GET  /rest/api/user?username=rachel-docs
GET  /rest/api/user/memberof?username=rachel-docs
GET  /rest/api/group/confluence-user
GET  /rest/api/group/confluence-users
GET  /rest/api/group/confluence-user/member
```

## Summary of Root Cause

**The issue is NOT**:
- ❌ VID space permissions misconfiguration
- ❌ Group "acmea-team" doesn't exist
- ❌ User "rachel-docs" doesn't exist
- ❌ Directory sync issues
- ❌ User visibility settings

**The issue IS**:
- ✅ Missing Confluence application access for acmea-team members
- ✅ Users not in `confluence-user` or `confluence-users` group
- ✅ Application-level access prerequisite not met

**Solution**: Add acmea-team members to the `confluence-user` group to grant Confluence application access, then assign space permissions.

---

**Diagnostic Tools**: Confluence REST API
**Authentication**: Bearer token authentication
**Investigation Method**: Systematic API querying of users, groups, and space configuration
