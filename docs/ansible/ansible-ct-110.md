# Ansible CT-110 Management Container

## Container Overview
**Container ID**: 110
**Hostname**: ansible-mgmt
**IP Address**: 192.168.1.25
**OS**: Debian (Proxmox LXC Container)
**Resources**: 1 CPU, 1GB RAM, 15GB Storage

## Installation Details
**Ansible Version**: 2.14.18
**Python Version**: 3.11.2
**Configuration Directory**: `/etc/ansible/`
**Playbook Directory**: `/etc/ansible/playbooks/`

## Network Configuration
```
net0: name=eth0,bridge=vmbr0,gw=192.168.1.3,hwaddr=BC:24:11:15:EE:0F,ip=192.168.1.25/24,type=veth
nameserver: 8.8.8.8
searchdomain: accelior.com
```

## SSH Configuration
**SSH Keys**:
- Ansible private key: `/root/.ssh/ansible_key`
- Authorized keys configured for root access
- StrictHostKeyChecking disabled for managed hosts

## Inventory Configuration
**Location**: `/etc/ansible/hosts`

```ini
[proxmox_containers]
docker-debian ansible_host=192.168.1.20
confluence ansible_host=192.168.1.21
jira ansible_host=192.168.1.22

[all:vars]
ansible_user=root
ansible_ssh_private_key_file=/root/.ssh/ansible_key
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

## Available Playbooks - Functional Overview

This section describes what each playbook does and when to use them, not the technical implementation details.

### Infrastructure Maintenance Playbooks

#### Docker VM Maintenance (`docker-vm-maintenance.yml`)
**Purpose**: Keeps the Docker VM (PCT-111) running smoothly and prevents disk space issues
**What it does for you**:
- Frees up disk space by cleaning Docker logs and unused containers/images
- Keeps the system secure by installing security updates
- Prevents Docker from consuming too much CPU or memory
- Tells you if something needs attention (like low disk space or failed containers)
- Tracks what was cleaned up and how much space was recovered

**When it runs**:
- Every night at 2 AM: Quick log cleanup (2-3 minutes)
- Every Sunday at 3 AM: Full maintenance (10-15 minutes)
- First Sunday of month at 4 AM: Deep cleaning (20-30 minutes)

#### Proxmox Host Maintenance (`proxmox-host-maintenance.yml`)
**Purpose**: Maintains the main Proxmox server that runs all containers and VMs
**What it does for you**:
- Keeps Proxmox system updated and secure
- Cleans up old log files to prevent disk from filling up
- Monitors hardware health (temperature, disk health, memory usage)
- Checks that all core Proxmox services are running properly
- Watches for storage space issues before they become critical
- Integrates with existing backup procedures

**When it runs**:
- Daily at 1 AM: Health checks and light cleanup (5 minutes)
- Weekly Sunday 2:30 AM: Full maintenance (15-20 minutes)
- Monthly first Sunday 1:30 AM: Comprehensive maintenance (25-30 minutes)

#### Application Container Updates

#### JIRA Maintenance (`update-jira-debian.yml`, `upgrade-jira-debian12-fixed.yml`)
**Purpose**: Keeps JIRA container updated and running smoothly
**What it does for you**:
- Updates JIRA system packages for security
- Handles Debian version upgrades safely
- Maintains JIRA database and configuration
- Verifies JIRA service is working after updates

#### Confluence Maintenance (`upgrade-confluence-ubuntu.yml`)
**Purpose**: Maintains Confluence wiki container
**What it does for you**:
- Updates Ubuntu system packages in Confluence container
- Ensures Confluence service remains available
- Handles system-level upgrades without breaking Confluence

#### System Monitoring (`system-maintenance.yml`, `system-maintenance-resilient.yml`)
**Purpose**: General system health checking across all managed containers
**What it does for you**:
- Basic: Collects system information and resource usage
- Resilient: Same as basic but continues working even if some checks fail
- Provides overview of all managed systems health at once

## Scheduled Automation

### Complete Cron Schedule
```bash
# === PROXMOX HOST MAINTENANCE ===
# Daily light maintenance at 1 AM (before Docker maintenance)
0 1 * * * /usr/bin/ansible-playbook /etc/ansible/playbooks/proxmox-host-maintenance.yml --tags "health,cleanup" >> /var/log/ansible-cron.log 2>&1

# Weekly full maintenance - Sunday at 2:30 AM (between DR config and Docker maintenance)
30 2 * * 0 /usr/bin/ansible-playbook /etc/ansible/playbooks/proxmox-host-maintenance.yml >> /var/log/ansible-cron.log 2>&1

# Monthly comprehensive maintenance - First Sunday at 1:30 AM
30 1 1-7 * 0 /usr/bin/ansible-playbook /etc/ansible/playbooks/proxmox-host-maintenance.yml --extra-vars "comprehensive_maintenance=true" >> /var/log/ansible-cron.log 2>&1

# === DOCKER VM MAINTENANCE ===
# Daily log cleanup at 2 AM (after Proxmox maintenance)
0 2 * * * /usr/bin/ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml --tags "logs" >> /var/log/ansible-cron.log 2>&1

# Weekly full maintenance - Sunday at 3 AM (after Proxmox maintenance)
0 3 * * 0 /usr/bin/ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml >> /var/log/ansible-cron.log 2>&1

# Monthly comprehensive maintenance - First Sunday at 4 AM (after Proxmox maintenance)
0 4 1-7 * 0 /usr/bin/ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml --extra-vars "comprehensive_maintenance=true" >> /var/log/ansible-cron.log 2>&1
```

### Maintenance Schedule Coordination
The schedule is carefully coordinated to prevent conflicts:
1. **1:00-1:30 AM**: Proxmox host maintenance (daily health checks)
2. **2:00-2:30 AM**: Existing disaster recovery backups (external system)
3. **2:30-3:00 AM**: Docker VM maintenance (weekly) and Proxmox full maintenance (weekly)
4. **3:00-4:00 AM**: Full backup cycle (external system)
5. **4:00+ AM**: Monthly comprehensive maintenance (first Sunday only)

### Log Management
**Docker VM Maintenance Log**: `/var/log/ansible-maintenance.log` (on Ansible CT)
**Proxmox Host Maintenance Log**: `/var/log/ansible-proxmox-maintenance.log` (on Proxmox host)
**Cron Execution Log**: `/var/log/ansible-cron.log` (on Ansible CT)
**Log Rotation**: Configured via `/etc/logrotate.d/ansible-maintenance`
- Weekly rotation
- Keep 4-8 weeks of logs (8 weeks for Proxmox, 4 weeks for Docker)
- Compress old logs
- Handles both Docker VM and Proxmox host logs

## Management Commands

### Manual Playbook Execution
```bash
# Access Ansible CT
ssh root@pve2 'pct exec 110 -- bash'

# === DOCKER VM MAINTENANCE ===
# Run Docker VM maintenance manually
ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml

# Run with specific tags
ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml --tags "logs"

# Run with extra variables
ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml --extra-vars "comprehensive_maintenance=true"

# === PROXMOX HOST MAINTENANCE ===
# Run full Proxmox maintenance
ansible-playbook /etc/ansible/playbooks/proxmox-host-maintenance.yml

# Run light maintenance (health checks and cleanup only)
ansible-playbook /etc/ansible/playbooks/proxmox-host-maintenance.yml --tags "health,cleanup"

# Run comprehensive maintenance
ansible-playbook /etc/ansible/playbooks/proxmox-host-maintenance.yml --extra-vars "comprehensive_maintenance=true"

# Check mode (preview what would be done)
ansible-playbook /etc/ansible/playbooks/proxmox-host-maintenance.yml --check
```

### Status Monitoring
```bash
# Check comprehensive maintenance status
/usr/local/bin/check-maintenance-status.sh

# === DOCKER VM MAINTENANCE LOGS ===
# View Docker VM maintenance logs
tail -f /var/log/ansible-maintenance.log

# Check recent Docker maintenance runs
grep "Docker VM maintenance completed" /var/log/ansible-maintenance.log | tail -5

# === PROXMOX HOST MAINTENANCE LOGS ===
# View Proxmox maintenance logs (on Proxmox host)
ssh root@pve2 'tail -f /var/log/ansible-proxmox-maintenance.log'

# Check recent Proxmox maintenance runs
ssh root@pve2 'grep "Proxmox host maintenance completed" /var/log/ansible-proxmox-maintenance.log | tail -5'

# === GENERAL MONITORING ===
# Check cron execution logs
tail -f /var/log/ansible-cron.log

# Test connectivity to all managed hosts
ansible all -m ping

# Check Proxmox host status specifically
ansible pve2 -m shell -a "uptime && df -h / && pvesm status"
```

### Container Management via Proxmox
```bash
# Access container console
ssh root@pve2 'pct exec 110 -- bash'

# Start/Stop container
ssh root@pve2 'pct start 110'
ssh root@pve2 'pct stop 110'

# Check container status
ssh root@pve2 'pct list | grep 110'
```

## Maintenance Procedures

### Daily Operations
- Automated log cleanup at 2 AM
- Monitor cron execution logs
- Verify Docker VM health via status scripts

### Weekly Operations
- Full maintenance cycle every Sunday 3 AM
- Review maintenance logs for issues
- Check disk space trends on Docker VM

### Monthly Operations
- Comprehensive maintenance first Sunday 4 AM
- Review and update playbooks as needed
- Verify backup and recovery procedures

## Security Configuration

### SSH Security
- Root access configured with key-based authentication
- Private keys stored securely in `/root/.ssh/`
- Known hosts configured for managed containers
- StrictHostKeyChecking disabled for automation (container network)

### Access Control
- Container isolated on internal bridge network (vmbr0)
- No external internet access required
- Management access via Proxmox host only
- Firewall rules inherit from OPNsense configuration

## Troubleshooting

### Common Issues
1. **SSH Key Issues**: Verify `/root/.ssh/ansible_key` permissions (600)
2. **Host Unreachable**: Check container network connectivity
3. **Playbook Failures**: Review logs in `/var/log/ansible-cron.log`
4. **Cron Not Running**: Verify crontab with `crontab -l`

### Recovery Procedures
```bash
# Restart Ansible container
ssh root@pve2 'pct restart 110'

# Reset SSH configuration
ssh root@pve2 'pct exec 110 -- chmod 600 /root/.ssh/ansible_key'

# Test inventory connectivity
ssh root@pve2 'pct exec 110 -- ansible all -m ping'

# Manual maintenance run
ssh root@pve2 'pct exec 110 -- ansible-playbook /etc/ansible/playbooks/docker-vm-maintenance.yml'
```

### Log Analysis
```bash
# Check last maintenance run
grep "maintenance completed" /var/log/ansible-maintenance.log | tail -5

# Look for errors
grep -i error /var/log/ansible-cron.log

# Check disk space trends
grep "Disk usage" /var/log/ansible-maintenance.log | tail -10
```

## Performance Metrics

**Container Resource Usage**:
- CPU: Minimal (only during playbook execution)
- Memory: ~200MB average, 1GB allocated
- Storage: ~2GB used of 15GB allocated
- Network: Internal bridge only, no external traffic

**Maintenance Impact**:
- Daily log cleanup: ~2-3 minutes
- Weekly full maintenance: ~10-15 minutes
- Monthly comprehensive: ~20-30 minutes
- Docker VM downtime: Minimal (containers restart as needed)

## Integration Points

**Uptime Kuma Monitoring**: Add Ansible job monitoring
**Backup Strategy**: Container included in Proxmox backup schedule
**Alerting**: Cron failures logged to syslog, monitored by infrastructure
**Documentation**: Full procedures documented in `/docs/ansible/`

---

**Last Updated**: 2025-09-26
**Container Health**: Operational
**Automation Status**: Fully configured with scheduled maintenance
**Next Review**: Monthly review scheduled