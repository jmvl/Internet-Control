# PCT Container 501 - GitLab CE Setup

## Container Overview

**Container ID**: 501
**Hostname**: gitlab.accelior.com
**IP Address**: 192.168.1.33/24
**Status**: Running
**Platform**: Proxmox LXC Container (Debian-based)

## Container Configuration

### Hardware Allocation
- **CPU Cores**: 8
- **Memory**: 6144 MB (6 GB)
- **Swap**: 2048 MB (2 GB)
- **Storage**: 95 GB (SSD-4TB pool)
- **Network**: vmbr0 bridge (LAN)
- **Gateway**: 192.168.1.3 (OPNsense)

### Container Details
```bash
# Container configuration
arch: amd64
cores: 8
hostname: gitlab.accelior.com
memory: 6144
net0: name=eth0,bridge=vmbr0,gw=192.168.1.3,hwaddr=00:50:56:00:EA:27,ip=192.168.1.33/24,type=veth
onboot: 1
ostype: debian
rootfs: ssd-4tb:501/vm-501-disk-0.raw,size=95G
swap: 2048
```

## GitLab Installation Details

### Version Information
- **GitLab Version**: 15.2.4
- **GitLab Revision**: 5f10358b40c
- **Ruby Version**: 2.7.5p203
- **PostgreSQL Version**: 12.10
- **Redis Version**: 6.2.7
- **GitLab Shell Version**: 14.9.0

### Service Configuration
- **Web URL**: https://gitlab.accelior.com
- **SSH Port**: 2222 (non-standard for security)
- **HTTP Clone URL**: https://gitlab.accelior.com/some-group/some-project.git
- **SSH Clone URL**: ssh://git@gitlab.accelior.com:2222/some-group/some-project.git

## Running Services

### GitLab Core Services (All Running)
```
✓ alertmanager    - Monitoring and alerting
✓ crond          - Scheduled tasks
✓ gitaly         - Git RPC service
✓ gitlab-exporter - Metrics exporter
✓ gitlab-kas     - Kubernetes Agent Server
✓ gitlab-workhorse - Reverse proxy for GitLab
✓ grafana        - Monitoring dashboard
✓ logrotate      - Log management
✓ nginx          - Web server
✓ node-exporter  - System metrics
✓ postgres-exporter - Database metrics
✓ postgresql     - Database server
✓ prometheus     - Metrics collection
✓ puma           - GitLab Rails application server
✓ redis          - Cache and session store
✓ redis-exporter - Redis metrics
✓ registry       - Docker container registry
✓ sidekiq        - Background job processor
```

### System Services
```
✓ console-getty.service     - Console access
✓ container-getty@1.service - Container TTY1
✓ container-getty@2.service - Container TTY2
✓ cron.service             - System cron daemon
✓ dbus.service             - System message bus
✓ fail2ban.service         - Intrusion prevention
✓ gitlab-runner.service    - CI/CD runner
✓ gitlab-runsvdir.service  - GitLab supervision
✓ networking.service       - Network configuration
✓ ntp.service             - Time synchronization
✓ postfix.service         - Mail transport agent
✓ rsyslog.service         - System logging
✓ ssh.service             - SSH server (port 2222)
✓ swapspace.service       - Swap management
✓ zabbix-agent.service    - Monitoring agent
```

## Resource Usage

### Current Status (as of September 23, 2025)
- **Disk Usage**: 71 GB / 93 GB (80% used)
- **Memory Usage**: 2.3 GB / 6.0 GB (38% used)
- **Swap Usage**: 0 MB / 2.0 GB (0% used)
- **Uptime**: Container started at 17:28 UTC

## Network Configuration

### Access Methods
- **Web Interface**: https://gitlab.accelior.com (via reverse proxy)
- **SSH Access**: root@192.168.1.33:2222
- **Git SSH**: git@192.168.1.33:2222

### Security Features
- **Fail2Ban**: Active intrusion prevention
- **SSH**: Running on non-standard port 2222
- **SSL/TLS**: HTTPS enabled for web interface
- **Firewall**: Protected by OPNsense (192.168.1.3)

## Monitoring and Maintenance

### Built-in Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alert routing and management
- **Various Exporters**: Node, PostgreSQL, Redis metrics

### External Monitoring
- **Zabbix Agent**: Connected to central monitoring
- **Uptime Monitoring**: External health checks

## Backup and Recovery

### Repository Storage
- **Default Storage Path**: `/var/opt/gitlab/git-data/repositories`
- **Configuration**: Standard GitLab omnibus setup

### Backup Considerations
- PostgreSQL database requires consistent backup
- Git repositories stored in `/var/opt/gitlab/git-data/`
- Configuration in `/etc/gitlab/`
- SSL certificates and custom configurations

## Administrative Notes

### Last Update: September 23, 2025
- Container restarted and services verified healthy
- SSH keys configuration attempted (port 2222)
- All GitLab services operational
- Monitoring stack functional

### Known Issues
- SSH key authentication needs troubleshooting
- **CRITICAL**: Container uses Debian 9 (EOL June 2022) - security risk
- **CRITICAL**: GitLab 15.2.4 cannot be upgraded due to EOL OS
- Disk usage at 80% - monitor for space
- Proxmox storage at 94-100% capacity blocking new container creation

### Maintenance Tasks
- **PRIORITY**: Plan storage expansion for upgrade capability
- **PRIORITY**: Implement automated weekly backups
- Enhanced security monitoring via OPNsense
- Disk space monitoring and cleanup
- SSL certificate renewal monitoring

### Upgrade Status (September 2025)
- **Backup Created**: 1727134564_2025_09_23_15.2.4-ce.tar (verified)
- **Upgrade Blocked**: Storage capacity and EOL OS constraints
- **Recommended Strategy**: Storage expansion + fresh container migration
- **Documentation**: See `/docs/gitlab/gitlab-upgrade-status-report.md`

## Integration Points

### Network Dependencies
- **OPNsense**: Primary gateway and firewall
- **DNS**: gitlab.accelior.com resolution
- **Reverse Proxy**: External access routing

### Related Infrastructure
- **Proxmox Host**: PVE2 (physical server)
- **Storage**: SSD-4TB pool for performance
- **Backup Systems**: Proxmox backup integration

## Documentation History

- **Created**: September 23, 2025
- **Last Updated**: September 23, 2025
- **Next Review**: October 23, 2025