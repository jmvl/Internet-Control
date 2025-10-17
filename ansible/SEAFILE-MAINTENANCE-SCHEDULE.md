# Seafile Maintenance Automation

## Overview

Automated Seafile garbage collection and maintenance scheduled to run **bi-monthly (every 2 months)** on the 1st day at 2:00 AM.

## Purpose

- **Garbage Collection**: Remove unused storage blocks from deleted files and libraries
- **Database Optimization**: Optimize MySQL tables for better performance
- **Log Cleanup**: Truncate large container logs
- **Health Checks**: Verify Seafile container and web interface accessibility
- **Space Reclamation**: Free up disk space on files.accelior.com (PCT-103)

## Target System

- **Host**: files.accelior.com
- **IP Address**: 192.168.1.25
- **Proxmox Container**: PCT-103
- **Seafile Version**: 12.0-latest
- **Current Storage**: 305GB total, ~74% used after last GC

## Schedule

### Cron Schedule (Bi-monthly)
```cron
# Seafile Garbage Collection - Every 2 months on the 1st at 2:00 AM
0 2 1 */2 * cd /Users/jm/Codebase/internet-control/ansible && /usr/local/bin/ansible-playbook -i hosts.ini playbooks/seafile-maintenance.yml >> /var/log/seafile-maintenance.log 2>&1
```

### Installation on Control Node

Install the cron job on your local machine (where Ansible is installed):

```bash
# Open crontab editor
crontab -e

# Add the following line
0 2 1 */2 * cd /Users/jm/Codebase/internet-control/ansible && /usr/local/bin/ansible-playbook -i hosts.ini playbooks/seafile-maintenance.yml >> /var/log/seafile-maintenance.log 2>&1
```

This will run:
- **Every 2 months** (January, March, May, July, September, November)
- **On the 1st day** of the month
- **At 2:00 AM** (when system load is lowest)

## Manual Execution

### Run Full Maintenance
```bash
cd /Users/jm/Codebase/internet-control/ansible
ansible-playbook -i hosts.ini playbooks/seafile-maintenance.yml
```

### Dry-Run Only (Preview)
```bash
ansible-playbook -i hosts.ini playbooks/seafile-maintenance.yml --tags dry-run
```

### Garbage Collection Only
```bash
ansible-playbook -i hosts.ini playbooks/seafile-maintenance.yml --tags gc
```

### Database Optimization Only
```bash
ansible-playbook -i hosts.ini playbooks/seafile-maintenance.yml --tags database
```

### Check What Would Run (Dry-Run Mode)
```bash
ansible-playbook -i hosts.ini playbooks/seafile-maintenance.yml --check
```

## Maintenance Tasks

### 1. Pre-Maintenance Checks
- Verify Seafile container status
- Record disk usage before maintenance
- Record Seafile data directory size

### 2. Garbage Collection (Dry-Run)
- Preview removable blocks without deleting
- Calculate potential space savings
- Log dry-run results

### 3. Garbage Collection (Actual)
- Remove unused blocks from all repositories
- Delete blocks from deleted libraries
- Remove out-dated blocks from libraries with history limits
- Process typically takes 2-5 minutes

### 4. Database Optimization
- Optimize Repo, Branch, Commit, Block tables
- Optimize Group, SharedRepo tables
- Optimize user and notification tables
- Improve query performance

### 5. Cache Management
- Restart memcached container
- Flush old cache entries
- Reset cache state

### 6. Log Cleanup
- Truncate container logs over 100MB
- Keep logs under 50MB per container
- Prevent log disk space exhaustion

### 7. Backup Cleanup
- Remove Seafile backups older than 90 days
- Clean up old database dumps
- Free up backup storage space

### 8. Post-Maintenance Assessment
- Calculate space freed from Seafile data
- Calculate total disk space freed
- Verify Seafile container health
- Check web interface accessibility
- Generate comprehensive report

## Expected Results

Based on the manual GC run on 2025-10-13:

- **Blocks Removed**: ~9,500+ blocks per run
- **Space Freed**: ~25-30GB per run
- **Disk Usage Reduction**: ~10% (from 84% to 74%)
- **Duration**: 2-5 minutes for GC + 1-2 minutes for optimization
- **Downtime**: None (online GC with MySQL backend)

## Monitoring

### Check Last Maintenance Run
```bash
ssh root@192.168.1.25 'tail -50 /var/log/ansible-seafile-maintenance.log'
```

### View Maintenance History
```bash
ssh root@192.168.1.25 'cat /var/log/ansible-seafile-maintenance.log | grep "=== Seafile maintenance"'
```

### Check Current Disk Usage
```bash
ssh root@192.168.1.10 'pct exec 103 -- df -h / | tail -1'
```

### Check Seafile Data Size
```bash
ssh root@192.168.1.10 'pct exec 103 -- docker exec seafile du -sh /shared/seafile/seafile-data'
```

## Logs and Reports

### Maintenance Log Location
- **Local Control Node**: `/var/log/seafile-maintenance.log`
- **Seafile Server**: `/var/log/ansible-seafile-maintenance.log`

### Log Contents
- Maintenance start/completion timestamps
- Disk usage before/after
- Seafile data directory size changes
- Blocks removed count
- Database optimization results
- Cache restart status
- Log cleanup actions
- Backup cleanup summary
- Health check results

## Troubleshooting

### If Maintenance Fails

1. **Check Ansible connectivity**:
   ```bash
   ansible seafile-server -i hosts.ini -m ping
   ```

2. **Check Seafile container status**:
   ```bash
   ssh root@192.168.1.10 'pct exec 103 -- docker ps --filter name=seafile'
   ```

3. **Check Seafile logs**:
   ```bash
   ssh root@192.168.1.10 'pct exec 103 -- docker logs seafile --tail 50'
   ```

4. **Run maintenance manually with verbose output**:
   ```bash
   ansible-playbook -i hosts.ini playbooks/seafile-maintenance.yml -vvv
   ```

### If GC Times Out

The playbook has a 30-minute timeout for GC. If your Seafile instance is very large:

1. Increase timeout in the playbook:
   ```yaml
   timeout: 3600  # 60 minutes
   ```

2. Or run GC manually inside the container:
   ```bash
   ssh root@192.168.1.10 'pct exec 103 -- docker exec seafile /scripts/gc.sh'
   ```

### If Database Optimization Fails

Check MySQL credentials and container status:
```bash
ssh root@192.168.1.10 'pct exec 103 -- docker ps --filter name=mysql'
ssh root@192.168.1.10 'pct exec 103 -- docker logs seafile-mysql --tail 20'
```

## Best Practices

1. **Regular Schedule**: Run bi-monthly to prevent excessive storage accumulation
2. **Monitor Space**: Check disk usage trends after each maintenance run
3. **Review Logs**: Check maintenance logs monthly for anomalies
4. **Test Changes**: Always test playbook changes with `--check` first
5. **Backup First**: Ensure Seafile backups are current before major changes
6. **Off-Peak Hours**: Schedule during low-traffic periods (2:00 AM)

## Integration with Other Maintenance

This playbook complements other infrastructure maintenance:
- **Docker VM Maintenance**: Weekly (docker-vm-maintenance.yml)
- **JIRA Maintenance**: Monthly (jira-maintenance.yml)
- **Confluence Maintenance**: Monthly (confluence-maintenance.yml)
- **Seafile Maintenance**: **Bi-monthly** (this playbook)

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-10-13 | 1.0 | Initial creation with GC, DB optimization, log cleanup |

## Contact

For issues or questions about Seafile maintenance:
- Check Seafile manual: https://manual.seafile.com/
- Review playbook: `ansible/playbooks/seafile-maintenance.yml`
- Check logs: `/var/log/ansible-seafile-maintenance.log`

---

**Last Updated**: 2025-10-13
**Next Scheduled Run**: First day of next bi-monthly cycle (check `crontab -l`)
