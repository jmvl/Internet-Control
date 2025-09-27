# GitLab 18.4.0 Instance Credentials

## Instance Information
- **URL**: https://gitlab.accelior.com
- **GitLab Version**: 18.4.0-ce.0
- **Container**: CT502 (Proxmox)
- **IP Address**: 192.168.1.33
- **OS**: Debian 12

## Admin Account
- **Username**: `root`
- **Password**: `WGKP4Ydi2LNZZc/0BoSv+QPBaAIJzEtCPPfUEBvU3Us=`
- **Email**: Not set (default admin account)

## SSL Certificates
- **Certificate Path**: `/etc/gitlab/ssl/gitlab.accelior.com.crt`
- **Private Key Path**: `/etc/gitlab/ssl/gitlab.accelior.com.key`
- **SSL Working**: Yes (copied from old GitLab instance)

## Migration Status
- **Migration Date**: September 24, 2025
- **Migrated From**: GitLab 15.2.4 (CT501)
- **Method**: Export/Import (database restore incompatible due to major version jump)
- **Data Status**:
  - ✅ Git repositories preserved (1.8GB)
  - ✅ SSL certificates migrated
  - ⏳ Projects being imported via export files
  - ⏳ Users being recreated

## Available Export Files
Located in `/tmp/` on CT502:
- `2025-09-24_09-32-036_next_admin-2_export.tar.gz` (804KB)
- `2025-09-24_09-32-236_next_kyc-2_export.tar.gz` (3.2MB)
- `2025-09-24_09-32-335_restopad_restopad_export.tar.gz` (236MB)
- `2025-09-24_09-32-341_next_company-2_export.tar.gz` (737KB)
- `2025-09-24_09-32-578_next_agent-2_export.tar.gz` (1.4MB)
- `2025-09-24_09-32-596_next_new-backend_export.tar.gz` (4.2MB)
- `2025-09-24_09-33-744_vega_vega-ios_export.tar.gz` (227MB)

## User Account Creation
- **Registration**: Open (requires admin approval)
- **Key User**: jmvl (Jean-Michel Van Lippevelde) - **PENDING APPROVAL**

## Legacy Instance (Fully Restored)
- **URL**: https://192.168.1.35
- **GitLab Version**: 15.2.4
- **Container**: CT501 (Proxmox)
- **Status**: All original data intact (115 users, 77 projects)
- **Purpose**: Fallback and data export source

## Access Commands
```bash
# Access containers
ssh root@pve2 'pct enter 502'  # New GitLab 18.4.0
ssh root@pve2 'pct enter 501'  # Legacy GitLab 15.2.4

# GitLab management
gitlab-ctl status
gitlab-ctl restart
gitlab-rails console

# Check services
curl -I -k https://gitlab.accelior.com
```

## Security Notes
- **Change admin password** immediately after initial setup
- **Review SSL certificate** expiration dates
- **Enable 2FA** for admin accounts
- **Configure backup** schedule for new instance

## Next Steps
1. Approve pending user registrations
2. Import project export files
3. Test Git repository access
4. Configure CI/CD pipelines if needed
5. Update DNS/networking if switching from legacy instance