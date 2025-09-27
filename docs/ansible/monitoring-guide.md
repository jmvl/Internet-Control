# Ansible Maintenance Monitoring Guide

## Where to Find Ansible Playbook Results

This guide shows you exactly where to find maintenance results and how to monitor what Ansible is doing across your infrastructure.

## Quick Status Check

**Primary Command**: Access Ansible container and run the status dashboard:
```bash
ssh root@pve2 'pct exec 110 -- /usr/local/bin/check-ansible-status.sh'
```

**✅ NO PASSWORDS REQUIRED** - Uses Ansible SSH keys for all connections

This single command shows:
- ✅ Current cron schedule status
- 📊 Last maintenance results from all systems
- 🔍 Infrastructure connectivity health
- 📅 Next scheduled maintenance windows
- 📖 All monitoring commands (all password-free)

## Log File Locations

### Central Management Logs (Ansible CT-110)
```bash
# Main cron execution log (all playbook runs)
ssh root@pve2 'pct exec 110 -- tail -f /var/log/ansible-cron.log'

# Docker VM maintenance results (historical)
ssh root@pve2 'pct exec 110 -- tail -f /var/log/ansible-maintenance.log'
```

### Individual System Logs

#### Proxmox Host Maintenance (pve2)
```bash
# View Proxmox maintenance results
ssh root@pve2 'tail -f /var/log/ansible-proxmox-maintenance.log'

# Check recent Proxmox maintenance completions
ssh root@pve2 'grep "completed successfully" /var/log/ansible-proxmox-maintenance.log | tail -5'
```

#### OMV Storage Server Maintenance (192.168.1.9)
```bash
# View OMV maintenance results and storage health
ssh root@192.168.1.9 'tail -f /var/log/ansible-omv-maintenance.log'

# Check BTRFS scrub results
ssh root@192.168.1.9 'grep -i "btrfs\|scrub" /var/log/ansible-omv-maintenance.log | tail -10'

# Check Docker cleanup results
ssh root@192.168.1.9 'grep -i "docker cleanup" /var/log/ansible-omv-maintenance.log | tail -5'
```

#### Mail Server Maintenance (192.168.1.30)
```bash
# View mail server maintenance results
ssh root@192.168.1.30 'tail -f /var/log/ansible-mail-maintenance.log'

# Check mail queue management results
ssh root@192.168.1.30 'grep -i "queue\|ssl" /var/log/ansible-mail-maintenance.log | tail -10'
```

## Real-Time Monitoring

### Watch Live Execution
```bash
# Watch all cron executions live
ssh root@pve2 'pct exec 110 -- tail -f /var/log/ansible-cron.log'

# Watch specific system maintenance
ssh root@192.168.1.9 'tail -f /var/log/ansible-omv-maintenance.log'
```

### Check Maintenance Schedule
```bash
# View current cron schedule
ssh root@pve2 'pct exec 110 -- crontab -l | grep -A15 "INFRASTRUCTURE MAINTENANCE"'
```

## What the Results Tell You

### Successful Run Example
```
2025-09-26T01:00:15Z - Starting Proxmox host maintenance
# ANSIBLE MANAGED BLOCK - PROXMOX MAINTENANCE RESULTS 2025-09-26T01:15:30Z
System updates: 3 packages
Reboot required: NO
Storage health: OK
Service status: HEALTHY
# END MANAGED BLOCK
2025-09-26T01:15:30Z - Proxmox host maintenance completed successfully
```

### Key Metrics to Watch

#### Docker VM Maintenance
- **Space Recovery**: Look for "Disk usage before/after"
- **Container Health**: Check for "Docker cleanup: SUCCESS"
- **Updates**: Monitor "Security updates: X packages updated"

#### OMV Storage Maintenance
- **Storage Health**: Watch for "BTRFS health: OK" or "NEEDS ATTENTION"
- **Container Status**: Look for critical container restarts
- **Space Recovery**: Monitor Docker cleanup results

#### Mail Server Maintenance
- **Queue Health**: Check "Queue size: X messages"
- **SSL Status**: Monitor "SSL status: OK" or "NEEDS_ATTENTION"
- **Service Health**: Verify "Core services: HEALTHY"

#### Proxmox Host Maintenance
- **System Updates**: Track security patch installations
- **Hardware Health**: Monitor temperature and disk health
- **Service Status**: Ensure all PVE services are healthy

## Troubleshooting Failed Runs

### If Maintenance Fails
```bash
# Check last cron errors
ssh root@pve2 'pct exec 110 -- grep -i error /var/log/ansible-cron.log | tail -10'

# Test individual playbook manually
ssh root@pve2 'pct exec 110 -- ansible-playbook /etc/ansible/playbooks/omv-storage-maintenance.yml --check'

# Verify host connectivity
ssh root@pve2 'pct exec 110 -- ansible all -m ping'
```

### Common Issues and Solutions

#### SSH Connection Problems
```bash
# Test SSH connectivity
ssh root@pve2 'pct exec 110 -- ssh root@192.168.1.9 hostname'

# Re-copy SSH keys if needed
ssh root@pve2 'pct exec 110 -- cat /root/.ssh/ansible_key.pub' | ssh root@192.168.1.9 'cat >> ~/.ssh/authorized_keys'
```

#### Log File Missing
```bash
# Create missing log files
ssh root@192.168.1.9 'touch /var/log/ansible-omv-maintenance.log'
ssh root@192.168.1.30 'touch /var/log/ansible-mail-maintenance.log'
```

## Maintenance Schedule Overview

### Daily (Automatic)
- **1:00 AM**: Proxmox health checks and light cleanup
- **2:00 AM**: Docker VM log truncation and cleanup
- **2:30 AM**: OMV storage health monitoring

### Weekly (Every Sunday)
- **2:30 AM**: Proxmox full system maintenance
- **3:00 AM**: Docker VM comprehensive maintenance
- **3:30 AM**: OMV storage full maintenance (BTRFS scrubs)
- **4:00 AM**: Mail server maintenance (queue cleanup, SSL checks)

### Monthly (First Sunday)
- **1:30 AM**: Proxmox comprehensive maintenance
- **4:30 AM**: OMV comprehensive storage maintenance

## Integration with Monitoring

### Uptime Kuma Integration
The OMV server runs Uptime Kuma (http://192.168.1.9:3010) which can monitor:
- Ansible maintenance completion status
- Service health after maintenance
- Log file growth and rotation

### Manual Health Checks
```bash
# Quick infrastructure health check
ssh root@pve2 'pct exec 110 -- ansible all -m ping | grep SUCCESS | wc -l'

# Check all maintenance log sizes (should rotate properly)
ssh root@pve2 'pct exec 110 -- ls -la /var/log/ansible*'
ssh root@192.168.1.9 'ls -la /var/log/ansible*'
ssh root@192.168.1.30 'ls -la /var/log/ansible*'
```

## Emergency Procedures

### Disable Automatic Maintenance
```bash
# Temporarily disable all cron jobs
ssh root@pve2 'pct exec 110 -- crontab -l > /tmp/cron-backup && crontab -r'

# Re-enable later
ssh root@pve2 'pct exec 110 -- crontab /tmp/cron-backup'
```

### Force Manual Maintenance
```bash
# Run specific system maintenance immediately
ssh root@pve2 'pct exec 110 -- ansible-playbook /etc/ansible/playbooks/omv-storage-maintenance.yml'
ssh root@pve2 'pct exec 110 -- ansible-playbook /etc/ansible/playbooks/mail-server-maintenance.yml'
```

---

**Remember**: Maintenance runs automatically. This guide helps you monitor results and troubleshoot if needed. The system is designed to maintain itself while keeping you informed of all activities.

**Last Updated**: 2025-09-26
**Automation Status**: Fully operational across 6 systems
**Next Review**: After first week of automated runs