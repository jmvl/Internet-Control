# Ansible Playbooks - Enhanced Maintenance Suite

## Overview

This directory contains comprehensive maintenance playbooks for the infrastructure with **full OS updates and log cleanup** capabilities.

## Enhanced Playbooks (October 2025)

### 1. HestiaCP Mail Server Maintenance
**File**: `hestia-mail-maintenance.yml`
**Target**: PCT-130 at 192.168.1.30
**Purpose**: Complete mail server maintenance with OS updates and aggressive log cleanup

**Features**:
- ✅ **System Updates**: Full dist-upgrade with autoremove/autoclean
- ✅ **Log Cleanup**: System journals, HestiaCP, Apache, Nginx, Exim4
- ✅ **Mail Services**: Queue management, frozen message removal, service health checks
- ✅ **SSL Monitoring**: Certificate expiration tracking for all mail domains
- ✅ **Radicale Container**: Health check for CalDAV/CardDAV service
- ✅ **Comprehensive Mode**: SpamAssassin rules update, ClamAV updates, mail domain rebuild

**Logs Cleaned**:
- System journals (30-day retention)
- HestiaCP logs (30-day retention, >100MB truncated)
- Apache logs (30-day retention, >200MB truncated)
- Nginx domain logs (30-day retention, >100MB truncated)
- Exim4 mail logs (30-day retention, >200MB truncated)

**Usage**:
```bash
# Standard weekly maintenance
ansible-playbook hestia-mail-maintenance.yml

# Logs only
ansible-playbook hestia-mail-maintenance.yml --tags logs

# Comprehensive monthly maintenance
ansible-playbook hestia-mail-maintenance.yml --extra-vars "comprehensive_maintenance=true"
```

**Recommended Schedule**:
- **Daily**: Log rotation only (2 AM)
- **Weekly**: Full maintenance (Sunday 4 AM)
- **Monthly**: Comprehensive with SpamAssassin/ClamAV updates

---

### 2. JIRA System Maintenance
**File**: `jira-maintenance.yml`
**Target**: PCT-102 at 192.168.1.22
**Purpose**: Complete JIRA maintenance with OS updates and application log cleanup

**Features**:
- ✅ **System Updates**: Full dist-upgrade with autoremove/autoclean
- ✅ **Log Cleanup**: System journals, JIRA logs, Catalina, Tomcat logs
- ✅ **JIRA Services**: Process monitoring, HTTP port checks, database connectivity
- ✅ **Work Directory Cleanup**: Import/export files, temp directory cleanup
- ✅ **Comprehensive Mode**: Database vacuum, search index recommendations

**Logs Cleaned**:
- System journals (30-day retention)
- JIRA application logs (30-day retention, >500MB truncated)
- Catalina logs (30-day retention)
- Tomcat access logs (30-day retention)
- catalina.out (>1GB truncated to 200MB)
- Import/export files (60-day retention)
- Temp files (7-day retention)

**Usage**:
```bash
# Standard weekly maintenance
ansible-playbook jira-maintenance.yml

# Logs only
ansible-playbook jira-maintenance.yml --tags logs

# Comprehensive monthly maintenance
ansible-playbook jira-maintenance.yml --extra-vars "comprehensive_maintenance=true"
```

**Recommended Schedule**:
- **Weekly**: Full maintenance (Sunday 5 AM)
- **Monthly**: Comprehensive with database vacuum

---

### 3. Confluence System Maintenance
**File**: `confluence-maintenance.yml`
**Target**: PCT-100 at 192.168.1.21
**Purpose**: Complete Confluence maintenance with OS updates and application log cleanup

**Features**:
- ✅ **System Updates**: Full dist-upgrade with autoremove/autoclean
- ✅ **Log Cleanup**: System journals, Confluence logs, Catalina, Tomcat logs
- ✅ **Confluence Services**: Process monitoring, HTTP/Synchrony port checks
- ✅ **Cache Cleanup**: Thumbnails (90-day), plugin cache (30-day)
- ✅ **Storage Monitoring**: Attachment and search index size tracking
- ✅ **Comprehensive Mode**: Database vacuum, search index rebuild recommendations

**Logs Cleaned**:
- System journals (30-day retention)
- Confluence application logs (30-day retention, >500MB truncated)
- Catalina logs (30-day retention)
- Tomcat access logs (30-day retention)
- catalina.out (>1GB truncated to 200MB)
- Temp files (7-day retention)
- Local backups (60-day retention)
- Thumbnails cache (90-day retention)
- Plugin cache (30-day retention)

**Usage**:
```bash
# Standard weekly maintenance
ansible-playbook confluence-maintenance.yml

# Logs only
ansible-playbook confluence-maintenance.yml --tags logs

# Comprehensive monthly maintenance
ansible-playbook confluence-maintenance.yml --extra-vars "comprehensive_maintenance=true"
```

**Recommended Schedule**:
- **Weekly**: Full maintenance (Sunday 6 AM)
- **Monthly**: Comprehensive with database vacuum

---

## Inventory Configuration

Ensure your Ansible inventory includes these hosts:

```ini
# /etc/ansible/hosts or inventory file

[mail-server]
192.168.1.30 ansible_user=root

[jira-server]
192.168.1.22 ansible_user=root

[confluence-server]
192.168.1.21 ansible_user=root
```

## Tag Reference

All playbooks support these tags:

- `always` - Runs initialization and reporting (always executed)
- `logs` - Log cleanup only
- `updates` - System package updates only
- `health` - Service health checks only
- `comprehensive` - Full comprehensive maintenance tasks

## Comprehensive Maintenance Mode

Monthly comprehensive maintenance includes additional tasks:

**HestiaCP**:
- SpamAssassin rules update
- ClamAV virus definition update
- Mail domain configuration rebuild
- Thorough APT cache cleanup

**JIRA**:
- PostgreSQL database vacuum and analyze
- Thorough APT cache cleanup
- Search index rebuild recommendations

**Confluence**:
- PostgreSQL database vacuum and analyze
- Thorough APT cache cleanup
- Search index rebuild recommendations

## Monitoring

All playbooks log results to:
- **HestiaCP**: `/var/log/ansible-hestia-maintenance.log`
- **JIRA**: `/var/log/ansible-jira-maintenance.log`
- **Confluence**: `/var/log/ansible-confluence-maintenance.log`

Check recent maintenance:
```bash
# HestiaCP
ssh root@192.168.1.30 'tail -50 /var/log/ansible-hestia-maintenance.log'

# JIRA
ssh root@192.168.1.22 'tail -50 /var/log/ansible-jira-maintenance.log'

# Confluence
ssh root@192.168.1.21 'tail -50 /var/log/ansible-confluence-maintenance.log'
```

## Cron Scheduling

Add to Ansible control node crontab (PCT-110):

```cron
# HestiaCP Mail Server - Daily logs, Weekly full, Monthly comprehensive
0 2 * * * ansible-playbook /etc/ansible/playbooks/hestia-mail-maintenance.yml --tags logs
0 4 * * 0 ansible-playbook /etc/ansible/playbooks/hestia-mail-maintenance.yml
0 4 1 * * ansible-playbook /etc/ansible/playbooks/hestia-mail-maintenance.yml --extra-vars "comprehensive_maintenance=true"

# JIRA - Weekly full, Monthly comprehensive
0 5 * * 0 ansible-playbook /etc/ansible/playbooks/jira-maintenance.yml
0 5 1 * * ansible-playbook /etc/ansible/playbooks/jira-maintenance.yml --extra-vars "comprehensive_maintenance=true"

# Confluence - Weekly full, Monthly comprehensive
0 6 * * 0 ansible-playbook /etc/ansible/playbooks/confluence-maintenance.yml
0 6 1 * * ansible-playbook /etc/ansible/playbooks/confluence-maintenance.yml --extra-vars "comprehensive_maintenance=true"
```

## Safety Features

All playbooks include:
- Pre/post disk usage reporting
- Non-destructive operations (no service restarts without explicit approval)
- Error handling with `ignore_errors` where appropriate
- Comprehensive logging and reporting
- Maintenance completion markers

## Testing

Test playbooks before scheduling:

```bash
# Check mode (dry run)
ansible-playbook hestia-mail-maintenance.yml --check

# Logs only (safe to run anytime)
ansible-playbook hestia-mail-maintenance.yml --tags logs

# Full run with verbose output
ansible-playbook hestia-mail-maintenance.yml -v
```

## Troubleshooting

### Playbook Fails on SSH Connection
```bash
# Test SSH connectivity
ansible mail-server -m ping

# Copy SSH keys if needed
ssh-copy-id root@192.168.1.30
```

### Disk Space Not Freed
```bash
# Check what's using space
ssh root@<host> 'du -sh /var/log/* | sort -h'

# Manual log cleanup
ssh root@<host> 'journalctl --vacuum-time=7d'
```

### Service Health Check Failures
```bash
# Check service status manually
ssh root@192.168.1.30 'systemctl status exim4 dovecot apache2'
ssh root@192.168.1.22 'ps aux | grep jira'
ssh root@192.168.1.21 'ps aux | grep confluence'
```

## Best Practices

1. **Run logs cleanup first** - Test with `--tags logs` before full runs
2. **Schedule during off-hours** - All playbooks designed for 2-6 AM execution
3. **Monitor first month** - Review logs daily for first month after deployment
4. **Reboot when needed** - Check `/var/run/reboot-required` after updates
5. **Database backups** - Ensure backups before comprehensive maintenance

## Support

For issues or enhancements:
1. Check maintenance logs on target systems
2. Review `/docs/ansible/` documentation
3. Test with `--check` mode first
4. Use `--tags` for targeted execution

---

**Created**: October 2025
**Maintainer**: Infrastructure Team
**Version**: 1.0
