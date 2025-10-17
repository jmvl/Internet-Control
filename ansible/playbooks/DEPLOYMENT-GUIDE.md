# Deployment Guide - Enhanced Ansible Playbooks

## Quick Start

These playbooks add **OS updates and comprehensive log cleanup** to your HestiaCP, JIRA, and Confluence systems.

## Step 1: Copy Playbooks to Ansible Container

```bash
# From your local machine
scp ansible/playbooks/*.yml root@pve2:/tmp/

# SSH to Proxmox
ssh root@pve2

# Copy to Ansible container (PCT-110)
pct exec 110 -- mkdir -p /etc/ansible/playbooks
pct push 110 /tmp/hestia-mail-maintenance.yml /etc/ansible/playbooks/
pct push 110 /tmp/jira-maintenance.yml /etc/ansible/playbooks/
pct push 110 /tmp/confluence-maintenance.yml /etc/ansible/playbooks/
```

## Step 2: Update Ansible Inventory

```bash
# SSH into Ansible container
pct exec 110 -- bash

# Edit inventory file
vi /etc/ansible/hosts

# Add or verify these entries:
[mail-server]
192.168.1.30 ansible_user=root ansible_ssh_private_key_file=/root/.ssh/id_rsa

[jira-server]
192.168.1.22 ansible_user=root ansible_ssh_private_key_file=/root/.ssh/id_rsa

[confluence-server]
192.168.1.21 ansible_user=root ansible_ssh_private_key_file=/root/.ssh/id_rsa
```

## Step 3: Test SSH Connectivity

```bash
# From Ansible container (PCT-110)
ansible mail-server -m ping
ansible jira-server -m ping
ansible confluence-server -m ping

# If SSH fails, copy keys:
ssh-copy-id root@192.168.1.30
ssh-copy-id root@192.168.1.22
ssh-copy-id root@192.168.1.21
```

## Step 4: Test Playbooks (Dry Run)

```bash
# Test HestiaCP playbook
ansible-playbook /etc/ansible/playbooks/hestia-mail-maintenance.yml --check

# Test JIRA playbook
ansible-playbook /etc/ansible/playbooks/jira-maintenance.yml --check

# Test Confluence playbook
ansible-playbook /etc/ansible/playbooks/confluence-maintenance.yml --check
```

## Step 5: Run Initial Maintenance (Log Cleanup Only)

Safe to run during business hours - only cleans logs:

```bash
# HestiaCP - Clean logs only
ansible-playbook /etc/ansible/playbooks/hestia-mail-maintenance.yml --tags logs

# JIRA - Clean logs only
ansible-playbook /etc/ansible/playbooks/jira-maintenance.yml --tags logs

# Confluence - Clean logs only
ansible-playbook /etc/ansible/playbooks/confluence-maintenance.yml --tags logs
```

## Step 6: Schedule Automated Maintenance

```bash
# From Ansible container, edit crontab
crontab -e

# Add these lines:
# HestiaCP Mail Server Maintenance
0 2 * * * /usr/bin/ansible-playbook /etc/ansible/playbooks/hestia-mail-maintenance.yml --tags logs > /var/log/cron-hestia-logs.log 2>&1
0 4 * * 0 /usr/bin/ansible-playbook /etc/ansible/playbooks/hestia-mail-maintenance.yml > /var/log/cron-hestia-full.log 2>&1
0 4 1 * * /usr/bin/ansible-playbook /etc/ansible/playbooks/hestia-mail-maintenance.yml --extra-vars "comprehensive_maintenance=true" > /var/log/cron-hestia-comprehensive.log 2>&1

# JIRA System Maintenance
0 5 * * 0 /usr/bin/ansible-playbook /etc/ansible/playbooks/jira-maintenance.yml > /var/log/cron-jira-full.log 2>&1
0 5 1 * * /usr/bin/ansible-playbook /etc/ansible/playbooks/jira-maintenance.yml --extra-vars "comprehensive_maintenance=true" > /var/log/cron-jira-comprehensive.log 2>&1

# Confluence System Maintenance
0 6 * * 0 /usr/bin/ansible-playbook /etc/ansible/playbooks/confluence-maintenance.yml > /var/log/cron-confluence-full.log 2>&1
0 6 1 * * /usr/bin/ansible-playbook /etc/ansible/playbooks/confluence-maintenance.yml --extra-vars "comprehensive_maintenance=true" > /var/log/cron-confluence-comprehensive.log 2>&1
```

## Maintenance Schedule Summary

| Time | System | Task | Impact |
|------|--------|------|--------|
| **Daily 2:00 AM** | HestiaCP | Log cleanup only | Minimal |
| **Sunday 4:00 AM** | HestiaCP | Full maintenance + OS updates | Low |
| **Sunday 5:00 AM** | JIRA | Full maintenance + OS updates | Low |
| **Sunday 6:00 AM** | Confluence | Full maintenance + OS updates | Low |
| **1st Sunday 4:00 AM** | HestiaCP | Comprehensive (SpamAssassin, ClamAV) | Medium |
| **1st Sunday 5:00 AM** | JIRA | Comprehensive (DB vacuum) | Medium |
| **1st Sunday 6:00 AM** | Confluence | Comprehensive (DB vacuum) | Medium |

## Monitoring Results

### Check Last Maintenance Run

```bash
# HestiaCP
ssh root@192.168.1.30 'tail -100 /var/log/ansible-hestia-maintenance.log'

# JIRA
ssh root@192.168.1.22 'tail -100 /var/log/ansible-jira-maintenance.log'

# Confluence
ssh root@192.168.1.21 'tail -100 /var/log/ansible-confluence-maintenance.log'
```

### Check Disk Space Savings

```bash
# Before/after comparison from maintenance logs
ssh root@192.168.1.30 "grep -A 3 'Disk Usage' /var/log/ansible-hestia-maintenance.log | tail -6"
```

### Verify Cron Execution

```bash
# From Ansible container
tail -f /var/log/cron-*.log
```

## Expected Results

### First Run (Log Cleanup)

**HestiaCP**: Expect 500MB - 2GB freed
- System journals, Apache logs, Nginx logs, mail logs

**JIRA**: Expect 1GB - 5GB freed
- Application logs, Catalina logs, catalina.out truncation

**Confluence**: Expect 1GB - 5GB freed
- Application logs, Catalina logs, thumbnail cache

### Weekly Maintenance

- OS packages updated (5-50 packages typical)
- All logs rotated and cleaned
- Service health verified
- 500MB - 2GB disk space freed per system

### Monthly Comprehensive

- Database vacuum/analyze
- SpamAssassin rules updated (HestiaCP)
- ClamAV definitions updated (HestiaCP)
- Additional 200-500MB freed via APT cache cleanup

## Troubleshooting

### Playbook Fails: "Host unreachable"
```bash
# Test SSH from Ansible container
ssh root@192.168.1.30 'echo Connection OK'

# If fails, copy SSH key
ssh-copy-id root@192.168.1.30
```

### Playbook Fails: "Permission denied"
```bash
# Ensure root access
ssh root@192.168.1.30 'id'

# Should show: uid=0(root) gid=0(root)
```

### Logs Not Cleaned
```bash
# Run with verbose mode
ansible-playbook hestia-mail-maintenance.yml --tags logs -v

# Check for errors in output
```

### Reboot Required After Updates
```bash
# Check if reboot needed
ssh root@192.168.1.30 'test -f /var/run/reboot-required && echo REBOOT_NEEDED'

# Schedule reboot during maintenance window
ssh root@192.168.1.30 'reboot'
```

## Safety Notes

1. **No automatic service restarts** - Playbooks check service status but don't restart automatically
2. **Non-destructive log cleanup** - Only removes old rotated logs, truncates large active logs
3. **Database safety** - Vacuum operations are read-heavy, safe for production
4. **Reboot detection** - Playbooks detect but don't automatically reboot

## Rollback Procedure

If issues occur after maintenance:

```bash
# Check what changed
ssh root@<host> 'grep installed /var/log/dpkg.log | tail -20'

# Review maintenance log
ssh root@<host> 'tail -200 /var/log/ansible-*-maintenance.log'

# Restore from Proxmox backup if needed
ssh root@pve2 '/root/disaster-recovery/restore-container.sh PCT-<number>'
```

## Next Steps

After successful deployment:

1. **Week 1**: Monitor logs daily, verify disk space freed
2. **Week 2-4**: Review maintenance summaries weekly
3. **Month 2**: Adjust retention periods if needed
4. **Optional**: Deploy Semaphore web UI for easier management

---

**Deployment Date**: October 2025
**Status**: Ready for production
**Support**: Check README.md for detailed usage
