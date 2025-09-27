# Docker VM Maintenance Playbook Documentation

## Playbook Overview
**File**: `/etc/ansible/playbooks/docker-vm-maintenance.yml`
**Target**: PCT-111 Docker VM (192.168.1.20)
**Purpose**: Automated maintenance, cleanup, and monitoring of Docker infrastructure

## Playbook Structure

### Variables
```yaml
vars:
  docker_log_max_size: "100m"
  maintenance_log: "/var/log/ansible-maintenance.log"
```

### Target Configuration
```yaml
hosts: docker-debian
become: yes
```

## Task Breakdown

### 1. Maintenance Logging
**Task**: Create maintenance log entry
- Creates timestamped log entries
- Maintains audit trail of all maintenance activities
- Log location: `/var/log/ansible-maintenance.log`

### 2. Pre-Maintenance Assessment
**Task**: Check disk usage before cleanup
- Records baseline disk usage
- Enables measurement of cleanup effectiveness
- Captures root filesystem usage (`df -h /`)

### 3. Docker Log Cleanup
**Task**: Truncate Docker container log files
- Targets: `/var/lib/docker/containers/*/*-json.log`
- Method: Truncate to zero size (preserves files)
- Impact: Immediate disk space recovery
- Safety: Non-destructive, preserves log file structure

### 4. Docker System Cleanup
**Task**: Docker system cleanup - remove unused resources
- **Module**: `docker_prune`
- **Targets**:
  - Unused containers
  - Unused images
  - Unused volumes
  - Unused networks
  - Build cache
- **Safety**: Only removes truly unused resources
- **Impact**: Major disk space recovery

### 5. System Updates
**Task**: Update package cache and install security updates
- **Method**: `apt update && apt upgrade safe`
- **Scope**: Security updates only (safe upgrade)
- **Additional**: Auto-remove unused packages, clean cache
- **Safety**: Non-breaking updates only

### 6. Reboot Detection
**Task**: Check if reboot is required
- **File**: `/var/run/reboot-required`
- **Action**: Detection only (no automatic reboot)
- **Notification**: Reports requirement in summary

### 7. Post-Maintenance Assessment
**Task**: Check disk usage after cleanup
- Measures cleanup effectiveness
- Provides before/after comparison
- Validates maintenance success

### 8. Docker Health Check
**Task**: Check Docker daemon status and resource usage
- **Docker daemon status**: SystemD status check
- **Resource usage**: `docker system df`
- **Container health**: Running container status
- **Output**: Comprehensive health report

### 9. Critical Services Monitoring
**Task**: Check critical services status
- **Supabase stack**: Container status verification
- **n8n automation**: Service availability check
- **Pi-hole DNS**: Service health verification
- **Method**: Docker container filtering and status checks

### 10. Maintenance Reporting
**Task**: Log maintenance results
- **Method**: Block insertion in maintenance log
- **Content**:
  - Disk usage before/after
  - Docker cleanup results
  - Security update count
  - Reboot requirement status
- **Format**: Structured, parseable log entries

### 11. Summary Generation
**Task**: Send summary report
- **Output**: Debug message with comprehensive summary
- **Content**:
  - Timestamp and host information
  - Disk usage comparison
  - Docker cleanup statistics
  - System update results
  - Service health status
  - Reboot requirement notification

### 12. Completion Marker
**Task**: Create maintenance completion marker
- Final log entry confirming successful completion
- Timestamp for maintenance tracking
- Success indicator for monitoring systems

## Execution Modes

### Standard Mode (Default)
```bash
ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml
```
**Includes**: All tasks, full maintenance cycle

### Log Cleanup Only
```bash
ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml --tags "logs"
```
**Note**: Currently, tags need to be added to playbook tasks

### Comprehensive Mode
```bash
ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml --extra-vars "comprehensive_maintenance=true"
```
**Enhanced**: Additional deep cleaning and verification

## Expected Results

### Disk Space Recovery
**Typical savings**:
- Docker logs: 50MB - 2GB
- Unused images: 1GB - 10GB
- Build cache: 500MB - 5GB
- **Total**: 2GB - 15GB typical recovery

### Performance Impact
**During execution**:
- CPU usage spike (Docker operations)
- Temporary container interruptions
- Network I/O for updates

**Post-maintenance**:
- Reduced disk I/O
- Faster Docker operations
- Improved container startup times

## Safety Measures

### Non-Destructive Operations
- Log truncation preserves file structure
- Docker prune only removes unused resources
- Safe upgrades avoid breaking changes
- No automatic container restarts

### Error Handling
- `ignore_errors: yes` on risky operations
- Comprehensive logging of all failures
- Continued execution despite individual task failures
- Status verification after each major operation

### Rollback Procedures
```bash
# If Docker daemon issues occur:
systemctl restart docker

# If containers fail to start:
docker-compose up -d  # For compose-managed containers
docker start <container_name>  # For individual containers

# If system updates cause issues:
apt list --upgradable  # Check what was updated
apt-mark hold <package>  # Hold problematic packages
```

## Monitoring Integration

### Log Analysis
```bash
# Check maintenance success
grep "completed successfully" /var/log/ansible-maintenance.log

# View space recovered
grep -A5 -B5 "Disk usage" /var/log/ansible-maintenance.log

# Check for errors
grep -i "failed\|error" /var/log/ansible-maintenance.log
```

### Uptime Kuma Integration
**Monitoring Points**:
- Playbook execution success/failure
- Maintenance completion timestamps
- Critical service availability post-maintenance
- Disk usage thresholds

**Webhook Integration**:
```bash
# Add to playbook for external monitoring
- name: Notify monitoring system
  uri:
    url: "http://192.168.1.9:3010/api/push/maintenance_webhook"
    method: POST
    body_format: json
    body:
      status: "{{ 'success' if ansible_failed_task is not defined else 'failed' }}"
      timestamp: "{{ ansible_date_time.iso8601 }}"
```

## Customization Options

### Variable Overrides
```bash
# Custom log location
--extra-vars "maintenance_log=/custom/path/maintenance.log"

# Skip specific operations
--skip-tags "docker_cleanup,system_updates"

# Dry run mode (check only)
--check --diff
```

### Conditional Execution
```yaml
# Add to tasks for conditional execution
when: comprehensive_maintenance is defined and comprehensive_maintenance|bool

# Skip on specific conditions
when: ansible_facts['memtotal_mb'] > 2048  # Skip if low memory
```

## Troubleshooting

### Common Issues

1. **Docker Permission Issues**
   ```bash
   # Fix: Ensure ansible user in docker group
   usermod -aG docker ansible
   ```

2. **Disk Space Full**
   ```bash
   # Emergency cleanup before playbook
   docker system prune -f
   apt clean
   ```

3. **Network Connectivity**
   ```bash
   # Verify target host connectivity
   ansible docker-debian -m ping
   ```

4. **Service Dependencies**
   ```bash
   # Check critical services manually
   docker ps --filter "status=running"
   ```

### Performance Optimization

**Large Environments**:
- Run during low-traffic periods
- Use `--forks` for parallel execution
- Consider staged rollouts for multiple hosts

**Resource Constraints**:
- Monitor memory usage during execution
- Implement cleanup size limits
- Add resource usage checks

## Best Practices

### Scheduling
- **Daily**: Log cleanup only (minimal impact)
- **Weekly**: Full maintenance cycle
- **Monthly**: Comprehensive maintenance with extended checks

### Testing
- Test playbook on non-production first
- Use `--check` mode for dry runs
- Verify critical services after execution

### Documentation
- Update playbook comments for any modifications
- Document custom variables and their purposes
- Maintain change log for playbook versions

---

**Playbook Version**: 1.0
**Last Updated**: 2025-09-26
**Compatible**: Ansible 2.14+, Docker 20.10+
**Target OS**: Debian 11/12, Ubuntu 20.04+