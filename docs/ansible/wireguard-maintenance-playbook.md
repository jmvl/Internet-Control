# WireGuard VPN Server Maintenance Playbook Documentation

## Playbook Overview
**File**: `/etc/ansible/playbooks/wireguard-maintenance.yml`
**Target**: WireGuard VPN Server (wg.accelior.com - 135.181.154.169)
**Purpose**: Automated maintenance, log rotation, package updates, and health monitoring for WireGuard Easy

## Server Details
- **Hostname**: wg.accelior.com
- **IP Address**: 135.181.154.169
- **Location**: Hetzner Helsinki DC (hel1-dc2)
- **OS**: Ubuntu 20.04.6 LTS
- **Server Type**: Hetzner CX22 (2 vCPU, 4GB RAM, 20GB SSD)
- **VPN Solution**: WireGuard Easy (Docker-based)
- **VPN Network**: 10.6.6.0/24

## Playbook Structure

### Variables
```yaml
vars:
  maintenance_log: "/var/log/ansible-wireguard-maintenance.log"
  backup_dir: "/root/wireguard-backups"
  wg_data_dir: "/opt/wg-easy"
  container_name: "wg-easy"
  log_retention_days: 30
  backup_retention_days: 90
```

### Target Configuration
```yaml
hosts: wireguard-server
become: yes
```

## Task Breakdown

### 1. Maintenance Initialization
**Tasks**: Create log entry, baseline disk usage
- Creates timestamped maintenance log entries
- Records disk usage before maintenance for comparison
- Provides audit trail of all maintenance activities
- Log location: `/var/log/ansible-wireguard-maintenance.log`

### 2. Docker Log Rotation & Cleanup
**Tasks**: Truncate container logs
- **Targets**: Docker container JSON logs (`*-json.log`)
- **Method**: Truncate to zero size (preserves log file structure)
- **Additional**: Rotates application logs inside container if > 100MB
- **Impact**: Immediate disk space recovery
- **Safety**: Non-destructive, preserves log file handles

### 3. System Package Updates
**Tasks**: Update Ubuntu packages and install security updates
- **Method**: `apt update && apt upgrade safe`
- **Scope**: Security updates only (safe upgrade mode)
- **Additional**: Auto-remove unused packages, clean apt cache
- **Safety**: Non-breaking updates only
- **Reboot Detection**: Checks for `/var/run/reboot-required`

### 4. Docker Image Updates
**Tasks**: Pull latest WireGuard Easy Docker image
- **Image**: `ghcr.io/wg-easy/wg-easy:latest`
- **Method**: Force pull latest version
- **Detection**: Checks if image changed (triggers restart)
- **Safety**: Only restarts container if image actually updated

### 5. WireGuard Data Backup
**Tasks**: Backup WireGuard Easy configuration and data
- **Source**: `/opt/wg-easy` (all WireGuard Easy data)
- **Destination**: `/root/wireguard-backups/wg-easy-backup-YYYY-MM-DD.tar.gz`
- **Retention**: 90 days (automatic cleanup of old backups)
- **Contents**: All configs, keys, client data, settings
- **Format**: Gzip-compressed tar archive
- **Frequency**: Every maintenance run

### 6. WireGuard Health Checks
**Tasks**: Verify WireGuard Easy container and service health
- **Container Status**: Check Docker container state
- **Interface Status**: Verify `wg0` interface exists and is UP
- **Active Peers**: Count connected VPN clients
- **Port Checks**:
  - UDP 51820 (WireGuard VPN) listening
  - TCP 51821 (Web UI) listening
- **Firewall Status**: Verify UFW rules for WireGuard ports

### 7. Firewall Verification
**Tasks**: Ensure firewall rules are correct
- Verifies UFW allows ports 51820 and 51821
- Reports firewall status in maintenance log
- No automatic firewall modifications (safety)

### 8. Container Restart (Conditional)
**Tasks**: Restart container if Docker image was updated
- **Trigger**: Only if Docker image pull detected changes
- **Method**: Graceful restart via Docker API
- **Wait**: Polls for healthy status (up to 60 seconds)
- **Verification**: Confirms WireGuard interface is functional

### 9. Post-Maintenance Assessment
**Tasks**: Measure maintenance effectiveness
- Records disk usage after cleanup
- Captures container resource usage (CPU, memory, network)
- Provides before/after comparison
- Validates maintenance success

### 10. Comprehensive Maintenance (Monthly)
**Tasks**: Deep cleaning and integrity verification
- **Docker System Prune**: Remove unused images, containers, networks, build cache
- **Data Integrity**: Verify WireGuard configuration files exist and are valid
- **Safety**: Does NOT prune volumes (preserves client data)
- **Trigger**: Only when `comprehensive_maintenance=true`

### 11. Maintenance Reporting
**Tasks**: Generate detailed maintenance report
- **Log File**: Structured entries in maintenance log
- **Console Output**: Comprehensive summary with all metrics
- **Contents**:
  - Disk usage comparison
  - System updates applied
  - Docker image status
  - WireGuard health metrics
  - Active peer count
  - Port status verification
  - Reboot requirement notification

### 12. Completion Marker
**Tasks**: Final log entry confirming successful completion
- Timestamp for maintenance tracking
- Success indicator for monitoring systems
- Enables automated monitoring via log parsing

## Execution Modes

### Standard Mode (Default)
```bash
ansible-playbook /etc/ansible/playbooks/wireguard-maintenance.yml
```
**Includes**: All tasks, full maintenance cycle

### Logs Only
```bash
ansible-playbook /etc/ansible/playbooks/wireguard-maintenance.yml --tags "logs"
```
**Includes**: Docker log rotation and cleanup only

### Updates Only
```bash
ansible-playbook /etc/ansible/playbooks/wireguard-maintenance.yml --tags "updates"
```
**Includes**: System package updates only

### Health Check Only
```bash
ansible-playbook /etc/ansible/playbooks/wireguard-maintenance.yml --tags "health"
```
**Includes**: WireGuard health verification only

### Comprehensive Mode (Monthly)
```bash
ansible-playbook /etc/ansible/playbooks/wireguard-maintenance.yml --extra-vars "comprehensive_maintenance=true"
```
**Enhanced**: Docker system prune and data integrity verification

### Dry Run (Check Mode)
```bash
ansible-playbook /etc/ansible/playbooks/wireguard-maintenance.yml --check
```
**Action**: Preview what would be done without making changes

## Expected Results

### Disk Space Recovery
**Typical savings**:
- Docker container logs: 10MB - 500MB
- Application logs: 5MB - 100MB
- Docker image cleanup (comprehensive): 100MB - 2GB
- **Total**: 15MB - 2.5GB typical recovery

### Performance Impact
**During execution**:
- CPU usage spike (brief, during Docker operations)
- Temporary VPN interruption if container restarts (10-20 seconds)
- Network I/O for package/image updates

**Post-maintenance**:
- Reduced disk I/O (smaller log files)
- Faster Docker operations
- Maintained VPN service availability
- Up-to-date security patches

## Safety Measures

### Non-Destructive Operations
- Log truncation preserves file structure
- Docker image updates only restart if changed
- Safe package upgrades avoid breaking changes
- Backups created before any risky operations
- Volume data never pruned (client configs preserved)

### Error Handling
- `ignore_errors: yes` on risky operations
- Comprehensive logging of all failures
- Continued execution despite individual task failures
- Health verification after changes
- Automatic rollback capability via backups

### Rollback Procedures
```bash
# If WireGuard Easy fails after update:
# 1. Stop current container
docker stop wg-easy && docker rm wg-easy

# 2. Restore from backup
cd /root/wireguard-backups
tar -xzf wg-easy-backup-YYYY-MM-DD.tar.gz -C /

# 3. Start container with previous image
docker run -d --name wg-easy \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e WG_HOST=wg.accelior.com \
  -e PASSWORD_HASH='$2a$12$VU3yuon2/fEDX0Eh5d7x7.9Lnw0EXJeH9voyd2JuRFa8fohlsO3WO' \
  -v /opt/wg-easy:/etc/wireguard \
  -p 51820:51820/udp \
  -p 51821:51821/tcp \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy:14

# If system updates cause issues:
apt list --upgradable  # Check what was updated
apt-mark hold <package>  # Hold problematic packages
```

## Monitoring Integration

### Log Analysis
```bash
# Check maintenance success
grep "completed successfully" /var/log/ansible-wireguard-maintenance.log

# View recent maintenance runs
grep -A20 "Maintenance Summary" /var/log/ansible-wireguard-maintenance.log | tail -40

# Check for errors
grep -i "failed\|error" /var/log/ansible-wireguard-maintenance.log

# Monitor disk space recovery
grep "Disk usage" /var/log/ansible-wireguard-maintenance.log | tail -10
```

### Uptime Kuma Integration
**Monitoring Points**:
- Playbook execution success/failure
- Maintenance completion timestamps
- WireGuard service availability post-maintenance
- Active peer count monitoring
- Disk usage thresholds

**Webhook Integration** (optional):
```yaml
- name: Notify monitoring system
  uri:
    url: "http://192.168.1.9:3010/api/push/wireguard_maintenance"
    method: POST
    body_format: json
    body:
      status: "{{ 'success' if ansible_failed_task is not defined else 'failed' }}"
      timestamp: "{{ ansible_date_time.iso8601 }}"
      active_peers: "{{ active_peers.stdout }}"
```

## Customization Options

### Variable Overrides
```bash
# Custom log location
--extra-vars "maintenance_log=/custom/path/maintenance.log"

# Custom backup retention
--extra-vars "backup_retention_days=60"

# Skip specific operations
--skip-tags "docker,updates"
```

### Conditional Execution
```yaml
# Add to tasks for conditional execution
when: comprehensive_maintenance is defined and comprehensive_maintenance|bool

# Skip on specific conditions
when: ansible_facts['memtotal_mb'] > 2048
```

## Ansible Inventory Configuration

### Add WireGuard Server to Inventory
**File**: `/etc/ansible/hosts`

```ini
[wireguard-server]
wg.accelior.com ansible_host=135.181.154.169

[wireguard-server:vars]
ansible_user=root
ansible_ssh_private_key_file=/root/.ssh/wireguard_key
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

### SSH Key Setup
```bash
# On Ansible management container (CT-110)
# 1. Generate SSH key for WireGuard server
ssh-keygen -t ed25519 -f /root/.ssh/wireguard_key -N ""

# 2. Copy public key to WireGuard server
ssh-copy-id -i /root/.ssh/wireguard_key root@135.181.154.169

# 3. Test connectivity
ansible wireguard-server -m ping
```

## Scheduled Automation

### Recommended Cron Schedule
Add to Ansible management container (CT-110) crontab:

```bash
# === WIREGUARD VPN SERVER MAINTENANCE ===

# Daily log rotation at 3:30 AM
30 3 * * * /usr/bin/ansible-playbook /etc/ansible/playbooks/wireguard-maintenance.yml --tags "logs" >> /var/log/ansible-cron.log 2>&1

# Weekly full maintenance - Sunday at 5 AM (after other infrastructure)
0 5 * * 0 /usr/bin/ansible-playbook /etc/ansible/playbooks/wireguard-maintenance.yml >> /var/log/ansible-cron.log 2>&1

# Monthly comprehensive maintenance - First Sunday at 5:30 AM
30 5 1-7 * 0 /usr/bin/ansible-playbook /etc/ansible/playbooks/wireguard-maintenance.yml --extra-vars "comprehensive_maintenance=true" >> /var/log/ansible-cron.log 2>&1
```

### Schedule Coordination
The schedule is coordinated with other infrastructure maintenance:
1. **1:00-2:30 AM**: Proxmox and Docker maintenance
2. **2:30-4:00 AM**: OMV storage maintenance
3. **3:30 AM**: WireGuard log rotation (daily)
4. **5:00 AM**: WireGuard full maintenance (weekly)
5. **5:30 AM**: WireGuard comprehensive (first Sunday)

### Logrotate Configuration
**File**: `/etc/logrotate.d/ansible-wireguard` (on Ansible CT-110)

```bash
/var/log/ansible-wireguard-maintenance.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
```

## Troubleshooting

### Common Issues

#### 1. Container Not Restarting After Update
**Symptoms**: Container stops but doesn't restart

**Diagnosis**:
```bash
# Check container status
ansible wireguard-server -m shell -a "docker ps -a | grep wg-easy"

# Check logs
ansible wireguard-server -m shell -a "docker logs wg-easy --tail 50"
```

**Solutions**:
```bash
# Manually start container
ansible wireguard-server -m shell -a "docker start wg-easy"

# If configuration issue, restore from backup
# See Rollback Procedures above
```

#### 2. VPN Clients Lose Connection
**Symptoms**: Clients disconnect during maintenance

**Diagnosis**:
```bash
# Check WireGuard interface
ansible wireguard-server -m shell -a "docker exec wg-easy wg show"

# Verify firewall
ansible wireguard-server -m shell -a "ufw status | grep 51820"
```

**Solutions**:
- Maintenance window should be during low-usage hours
- Container restart is brief (10-20 seconds)
- Clients automatically reconnect

#### 3. Backup Failures
**Symptoms**: Backup task fails or backups missing

**Diagnosis**:
```bash
# Check backup directory
ansible wireguard-server -m shell -a "ls -lh /root/wireguard-backups/"

# Check disk space
ansible wireguard-server -m shell -a "df -h /"
```

**Solutions**:
```bash
# Create backup directory manually
ansible wireguard-server -m shell -a "mkdir -p /root/wireguard-backups"

# Clean old backups to free space
ansible wireguard-server -m shell -a "find /root/wireguard-backups -mtime +90 -delete"
```

#### 4. Network Connectivity Issues
**Symptoms**: Ansible can't reach WireGuard server

**Diagnosis**:
```bash
# Test connectivity from Ansible CT
ansible wireguard-server -m ping

# Test SSH directly
ssh -i /root/.ssh/wireguard_key root@135.181.154.169
```

**Solutions**:
```bash
# Verify SSH key permissions
chmod 600 /root/.ssh/wireguard_key

# Check Hetzner firewall allows your IP
# Use Hetzner Cloud Console if needed
```

### Performance Optimization

**Large Log Files**:
- Increase log rotation frequency
- Monitor disk space trends
- Adjust retention periods if needed

**Slow Package Updates**:
- Use nearby Ubuntu mirrors
- Schedule updates during low-traffic periods
- Consider caching proxy for apt packages

**Docker Image Pull Timeouts**:
- Check network bandwidth
- Increase timeout values in playbook
- Pull image manually during off-hours

## Best Practices

### Scheduling
- **Daily**: Log rotation only (minimal impact)
- **Weekly**: Full maintenance cycle with updates
- **Monthly**: Comprehensive maintenance with deep cleaning

### Testing
- Test playbook on staging/test environment first
- Use `--check` mode for dry runs
- Verify VPN connectivity after maintenance
- Monitor client connections during execution

### Documentation
- Update playbook comments for any modifications
- Document custom variables and their purposes
- Maintain change log for playbook versions
- Keep inventory and SSH keys documented

### Security
- Rotate SSH keys periodically
- Use strong passwords for WireGuard Easy web UI
- Monitor maintenance logs for anomalies
- Keep backup directory secure (0700 permissions)

## Maintenance Impact

### Service Downtime
- **Log Rotation**: No downtime
- **Package Updates**: No downtime
- **Docker Image Update**: 10-20 seconds if container restarts
- **Comprehensive Mode**: 10-30 seconds if container restarts

### Resource Usage
- **CPU**: Brief spikes during Docker operations
- **Memory**: Minimal (Ansible overhead)
- **Disk I/O**: Moderate during backup creation
- **Network**: Moderate for image pulls/updates

### Client Impact
- **Active Connections**: Brief interruption if container restarts
- **Reconnection**: Automatic (WireGuard clients reconnect)
- **Data Loss**: None (all client configs preserved)

## Integration Points

**Uptime Kuma**: Monitor playbook execution status
**Backup Strategy**: 90-day retention with daily backups
**Alerting**: Cron failures logged and monitored
**Documentation**: Comprehensive procedures in `/docs/wireguard/`

## Success Criteria

### Maintenance is Successful When:
- ✅ All tasks complete without critical errors
- ✅ WireGuard interface is UP and functional
- ✅ Active peers reconnect successfully
- ✅ Disk space is recovered from logs
- ✅ Backup created successfully
- ✅ Security updates applied (if available)
- ✅ Container is healthy and responsive
- ✅ Ports 51820 and 51821 are listening

### Warning Conditions:
- ⚠️ Reboot required after updates (manual intervention needed)
- ⚠️ Disk usage > 80% after cleanup
- ⚠️ Backup directory approaching size limits
- ⚠️ Container restart failed (requires investigation)

### Failure Conditions:
- ❌ WireGuard interface not responding
- ❌ No active peers after maintenance
- ❌ Ports not listening
- ❌ Backup creation failed
- ❌ Data integrity check failed

---

**Playbook Version**: 1.0
**Last Updated**: 2025-10-09
**Compatible**: Ansible 2.14+, Docker 20.10+, Ubuntu 20.04+
**Target**: WireGuard Easy (wg-easy) Docker deployment
