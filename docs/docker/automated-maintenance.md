# Automated Docker Maintenance System

## Overview
Fully automated Docker maintenance system using Ansible CT-110 to manage PCT-111 Docker VM. Provides scheduled cleanup, security updates, and health monitoring with comprehensive logging.

## Architecture

### Components
- **Ansible CT-110** (192.168.1.25): Management container
- **Docker VM PCT-111** (192.168.1.20): Target infrastructure
- **Scheduled Automation**: Cron-based execution
- **Monitoring Integration**: Uptime Kuma compatible

### Automation Flow
```
Ansible CT-110 → SSH → Docker VM PCT-111
     ↓
Scheduled Cron Jobs → Playbook Execution → Maintenance Tasks
     ↓
Logging & Reporting → Status Monitoring → Alerting
```

## Maintenance Schedule

### Daily Operations (2:00 AM)
**Command**: `ansible-playbook docker-vm-maintenance.yml --tags "logs"`
**Duration**: 2-3 minutes
**Tasks**:
- Truncate Docker container logs
- Basic health checks
- Minimal service disruption

### Weekly Operations (Sunday 3:00 AM)
**Command**: `ansible-playbook docker-vm-maintenance.yml`
**Duration**: 10-15 minutes
**Tasks**:
- Full Docker system cleanup
- Security updates installation
- Comprehensive health verification
- Disk usage optimization

### Monthly Operations (First Sunday 4:00 AM)
**Command**: `ansible-playbook docker-vm-maintenance.yml --extra-vars "comprehensive_maintenance=true"`
**Duration**: 20-30 minutes
**Tasks**:
- Deep system analysis
- Extended cleanup procedures
- Full service verification
- Performance optimization

## Maintenance Tasks

### Docker Cleanup Operations
1. **Container Log Management**
   - Truncate JSON log files to zero size
   - Preserve log file structure
   - Immediate space recovery

2. **Resource Pruning**
   - Remove unused containers
   - Clean unused images
   - Delete unused volumes
   - Clean unused networks
   - Clear build cache

3. **System Optimization**
   - Docker daemon health check
   - Container restart if needed
   - Resource usage verification

### System Maintenance
1. **Security Updates**
   - Update package cache
   - Install security-only updates
   - Auto-remove unused packages
   - Clean package cache

2. **Health Monitoring**
   - Check critical services
   - Verify container status
   - Monitor resource usage
   - Detect reboot requirements

## Access Methods

### Via Proxmox Host
```bash
# Access Ansible container
ssh root@pve2 'pct exec 110 -- bash'

# Run maintenance manually
ssh root@pve2 'pct exec 110 -- ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml'

# Check maintenance status
ssh root@pve2 'pct exec 110 -- /usr/local/bin/check-maintenance-status.sh'
```

### Direct Commands
```bash
# View maintenance logs
ssh root@pve2 'pct exec 110 -- tail -f /var/log/ansible-maintenance.log'

# Check cron status
ssh root@pve2 'pct exec 110 -- crontab -l'

# Manual playbook execution
ssh root@pve2 'pct exec 110 -- ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml'
```

## Logging System

### Log Files
- **Maintenance Log**: `/var/log/ansible-maintenance.log`
- **Cron Execution Log**: `/var/log/ansible-cron.log`
- **Rotation**: Weekly, keep 4 weeks, compressed

### Log Analysis
```bash
# Check recent maintenance
grep "maintenance completed" /var/log/ansible-maintenance.log | tail -5

# View space recovery
grep "Disk usage" /var/log/ansible-maintenance.log | tail -10

# Look for errors
grep -i error /var/log/ansible-cron.log
```

### Sample Log Output
```
2025-09-26T08:27:15Z - Starting Docker VM maintenance
# ANSIBLE MANAGED BLOCK - MAINTENANCE RESULTS 2025-09-26T08:27:45Z
Disk usage before: /dev/mapper/pve-vm--111--disk--0  108G   42G   62G  41%
Disk usage after:  /dev/mapper/pve-vm--111--disk--0  108G   29G   75G  28%
Docker cleanup: SUCCESS
Security updates: 3 packages updated
Reboot required: NO
# END MANAGED BLOCK - MAINTENANCE RESULTS 2025-09-26T08:27:45Z
2025-09-26T08:27:45Z - Docker VM maintenance completed successfully
```

## Monitoring Integration

### Status Monitoring
**Script**: `/usr/local/bin/check-maintenance-status.sh`
**Output**: Last maintenance run, recent cron activity, current Docker status

### Uptime Kuma Integration
**Recommended Monitors**:
1. **Docker VM Health**: http://192.168.1.20:2376/version (Docker API)
2. **Maintenance Success**: File monitor on `/var/log/ansible-maintenance.log`
3. **Critical Services**: Container health checks
4. **Disk Space**: Threshold monitoring on Docker VM

### Alerting Conditions
- Maintenance failure (playbook exit code != 0)
- Disk usage above 80% after cleanup
- Critical container failures
- Security updates requiring reboot

## Performance Impact

### Resource Usage During Maintenance
- **CPU**: Temporary spike during Docker operations
- **Memory**: Minimal additional usage
- **Disk I/O**: High during cleanup operations
- **Network**: Updates and package downloads

### Service Availability
- **Container Restarts**: Individual containers as needed
- **Service Interruption**: Minimal (< 30 seconds typical)
- **Zero-Downtime**: Most services continue running
- **Recovery**: Automatic container restart

## Customization Options

### Schedule Modification
```bash
# Edit crontab in Ansible CT
crontab -e

# Custom maintenance frequency
0 4 * * 1,3,5  # Monday, Wednesday, Friday at 4 AM
```

### Playbook Customization
```bash
# Skip specific tasks
ansible-playbook docker-vm-maintenance.yml --skip-tags "system_updates"

# Custom variables
ansible-playbook docker-vm-maintenance.yml --extra-vars "docker_log_max_size=50m"
```

### Notification Integration
```yaml
# Add to playbook for Slack/Discord notifications
- name: Send completion notification
  uri:
    url: "{{ webhook_url }}"
    method: POST
    body_format: json
    body:
      text: "Docker maintenance completed on {{ inventory_hostname }}"
```

## Emergency Procedures

### Maintenance Failure Recovery
```bash
# Check failure reason
tail -50 /var/log/ansible-cron.log

# Manual service restart
systemctl restart docker

# Container recovery
docker ps -a --filter "status=exited"
docker restart $(docker ps -aq --filter "status=exited")
```

### Disable Automation
```bash
# Temporarily disable cron jobs
crontab -l > /tmp/cron-backup
crontab -r

# Re-enable later
crontab /tmp/cron-backup
```

### Manual Maintenance
```bash
# Full manual execution
ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml -v

# Step-by-step execution
ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml --step
```

## Security Considerations

### SSH Key Management
- Private keys stored securely in `/root/.ssh/`
- Key permissions: 600 (root only)
- No password authentication
- Keys rotate annually

### Network Security
- Ansible CT on internal network only
- No external internet access required
- Firewall rules via OPNsense
- Container isolation maintained

### Privilege Management
- Root access required for Docker operations
- Ansible user with sudo privileges
- Limited scope to Docker VM only
- Audit trail in logs

## Best Practices

### Scheduling
- Run during low-traffic periods
- Avoid overlapping with backup windows
- Consider time zone implications
- Plan around critical business hours

### Testing
- Test playbook changes in development
- Use `--check` mode for validation
- Verify critical services post-maintenance
- Monitor resource usage patterns

### Documentation
- Keep playbooks version controlled
- Document all customizations
- Maintain change logs
- Update procedures regularly

## Troubleshooting Guide

### Common Issues
1. **SSH Connection Failures**: Check SSH service and keys
2. **Docker Permission Issues**: Verify user group membership
3. **Disk Space Full**: Run emergency cleanup manually
4. **Container Start Failures**: Check Docker daemon status

### Debug Commands
```bash
# Test connectivity
ansible docker-debian -m ping

# Verbose playbook execution
ansible-playbook docker-vm-maintenance.yml -vvv

# Check Docker system
docker system info
docker system events --since 1h
```

---

**System Status**: Production Ready
**Last Updated**: 2025-09-26
**Next Review**: Monthly maintenance cycle
**Contact**: Infrastructure team via documentation