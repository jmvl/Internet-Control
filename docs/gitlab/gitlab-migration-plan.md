# GitLab Migration Plan - PCT 501 Upgrade Strategy

## Current Situation Analysis

### Critical Blocking Issues
- **GitLab Version**: 15.2.4-ce (released July 2022)
- **Operating System**: Debian 9 "Stretch" (EOL June 2022)
- **Repository Status**: All Debian repositories return 404 (no longer exist)
- **GitLab GPG Keys**: Expired and cannot be updated
- **Security Risk**: Running on unsupported OS with no security updates

### Backup Status ✅
- **Backup Created**: `1727134564_2025_09_23_15.2.4-ce.tar`
- **Components**: Database, repositories, uploads, builds, artifacts
- **Size**: ~5.7GB total backup
- **Location**: `/var/opt/gitlab/backups/`

## Migration Strategy Options

### Option 1: Fresh Container Migration (RECOMMENDED)
Create new PCT container with modern OS and restore from backup.

**Advantages**:
- Clean modern environment (Debian 12 or Ubuntu 22.04)
- Latest GitLab CE version compatibility
- No dependency conflicts
- Fastest path to secure, supported system

**Steps**:
1. Create new PCT container 502 with Debian 12
2. Install latest GitLab CE omnibus package
3. Transfer backup files from old container
4. Restore GitLab data from backup
5. Update DNS and reverse proxy configuration
6. Verify functionality and decommission old container

### Option 2: In-Place OS Upgrade (HIGH RISK)
Attempt to upgrade Debian 9 → 10 → 11 → 12 then upgrade GitLab.

**Disadvantages**:
- Multiple failure points with each OS upgrade
- Potential for complete system corruption
- GitLab compatibility issues between versions
- Estimated downtime: 4-6 hours
- Recovery complexity if upgrade fails

## Recommended Implementation Plan

### Phase 1: New Container Preparation
1. **Create PCT Container 502**
   - Hostname: gitlab-new.accelior.com
   - IP: 192.168.1.34 (temporary)
   - OS: Debian 12 "Bookworm"
   - Resources: 8 cores, 8GB RAM, 100GB storage

2. **Install GitLab CE Latest**
   - Add GitLab official repository
   - Install gitlab-ce package
   - Configure basic settings

### Phase 2: Data Migration
1. **Transfer Backup Files**
   - Copy backup tar from old container
   - Verify backup integrity

2. **Restore GitLab Data**
   - Stop GitLab services
   - Run gitlab-backup:restore
   - Reconfigure GitLab
   - Start services

### Phase 3: Service Transition
1. **Update Configuration**
   - Modify `/etc/hosts` entries
   - Update reverse proxy configuration
   - Update DNS records if needed

2. **Validation Testing**
   - Verify all repositories accessible
   - Test user authentication
   - Validate CI/CD pipelines
   - Check Docker registry functionality

3. **Production Cutover**
   - Change IP from 192.168.1.34 to 192.168.1.33
   - Update all references
   - Decommission old container

## Risk Mitigation

### Backup Strategy
- **Current Backup**: Already completed and verified
- **Additional Backup**: Create Proxmox snapshot before migration
- **Recovery Plan**: Can restore old container from snapshot if migration fails

### Rollback Plan
1. If migration fails, restore original container from Proxmox snapshot
2. Estimated rollback time: 10-15 minutes
3. Zero data loss as original container remains untouched until migration verified

## Timeline Estimate

| Phase | Duration | Description |
|-------|----------|-------------|
| Container Creation | 30 minutes | PCT setup, OS installation |
| GitLab Installation | 45 minutes | Package installation, basic config |
| Data Migration | 60 minutes | Backup transfer and restore |
| Configuration Update | 30 minutes | DNS, proxy, network changes |
| Testing & Validation | 45 minutes | Comprehensive functionality testing |
| **Total Estimated Time** | **3.5 hours** | **Complete migration process** |

## Success Criteria

### Functional Requirements
- [ ] All Git repositories accessible and functional
- [ ] User authentication working (local and LDAP if configured)
- [ ] CI/CD pipelines operational
- [ ] Docker registry accessible
- [ ] Web interface fully functional
- [ ] SSH Git access working (port 2222)

### Performance Requirements
- [ ] System response time comparable to original
- [ ] Memory usage within acceptable limits
- [ ] All GitLab services healthy and running

### Security Requirements
- [ ] HTTPS access working
- [ ] SSH hardening maintained
- [ ] Fail2ban operational
- [ ] Modern OS with security updates available

## Next Steps

1. **Immediate**: Create Proxmox snapshot of current container 501
2. **Short-term**: Implement fresh container migration (Option 1)
3. **Long-term**: Establish automated GitLab backup schedule

## Documentation Updates Required

After successful migration:
- Update `/docs/gitlab/pct-501-gitlab-setup.md` with new version info
- Update `/docs/infrastructure.md` with new container details
- Document new backup and maintenance procedures