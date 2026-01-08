# Seafile Infrastructure Documentation

## Overview

Seafile is a professional file hosting and collaboration platform running on PCT Container 103 in the Proxmox environment. This document provides comprehensive information about the Seafile deployment, configuration, and maintenance procedures.

## Infrastructure Details

### Container Information
- **Container ID**: PCT 103
- **Hostname**: files.accelior.com
- **IP Address**: 192.168.1.25/24
- **Gateway**: 192.168.1.3
- **Resources**: 6 cores, 2GB RAM, 512MB swap, 310GB storage
- **OS Type**: Debian (unprivileged container)
- **Features**: keyctl=1, nesting=1 (Docker support)

### Network Configuration
- **Bridge**: vmbr0
- **MAC Address**: 00:50:56:00:7E:B3
- **Web Access**: http://192.168.1.25:50080
- **Domain**: files.accelior.com
- **Auto-start**: Enabled (onboot: 1)

## Service Architecture

### Docker Stack Components

#### 1. Seafile Application Container
- **Image**: `seafileltd/seafile-mc:13.0-latest`
- **Container Name**: `seafile`
- **Port Mapping**: 8092:80
- **Restart Policy**: unless-stopped
- **Health Check**: HTTP check on port 80 with 60s startup grace period

#### 2. MariaDB Database Container
- **Image**: `mariadb:10.11`
- **Container Name**: `seafile-mysql`
- **Port Mapping**: Internal only (no host port exposed)
- **Health Check**: healthcheck.sh with 30s startup period, 10 retries
- **Storage**: Persistent volume at `./db`

#### 3. Redis Cache Container
- **Image**: `redis:7`
- **Container Name**: `seafile-redis`
- **Authentication**: Password protected
- **Purpose**: Session cache and performance optimization (replaced Memcached in v13.0)

### Directory Structure
```
/opt/seafile-docker/
├── .env                        # Environment configuration (Seafile 13.0+)
├── seafile-server.yml          # Docker Compose service definitions
├── docker-compose.yml.backup-12.0  # Backup of v12.0 configuration
├── seafile-data/               # Seafile application data
│   └── seafile/conf/           # Seafile configuration files
├── db/                         # MariaDB persistent storage
├── mnt/                        # Mounted external storage
└── zoneinfo/                   # Timezone data
```

## Configuration

### Environment Variables (Seafile 13.0+)

Configuration is now managed via `.env` file. Key settings:

#### Server Configuration
```bash
SEAFILE_SERVER_HOSTNAME=files.accelior.com
SEAFILE_SERVER_PROTOCOL=https
TIME_ZONE=Etc/UTC
JWT_PRIVATE_KEY=<configured>
```

#### Database Configuration
```bash
SEAFILE_MYSQL_DB_HOST=db
SEAFILE_MYSQL_DB_USER=seafile
SEAFILE_MYSQL_DB_PASSWORD=<configured>
INIT_SEAFILE_MYSQL_ROOT_PASSWORD=<configured>
```

#### Cache Configuration (Redis)
```bash
CACHE_PROVIDER=redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<configured>
```

#### Security Notes
- All credentials stored in `.env` file
- HTTPS enabled via `SEAFILE_SERVER_PROTOCOL=https`
- JWT authentication enabled for API security
- SERVICE_URL and FILE_SERVER_ROOT auto-calculated from hostname/protocol

### Health Check Configuration

#### MariaDB Health Check
- **Test Command**: `mysqladmin ping -h localhost -u root -p$MYSQL_ROOT_PASSWORD`
- **Interval**: 10 seconds
- **Timeout**: 5 seconds
- **Retries**: 10
- **Start Period**: 30 seconds (allows DB initialization)

#### Redis Health Check
- Redis runs as a service dependency without explicit health check
- Password authentication ensures secure connections
- Seafile depends on Redis being available before starting

#### Seafile Health Check
- **Test Command**: `curl -f http://localhost/api2/ping/`
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Retries**: 3
- **Start Period**: 60 seconds (allows full application startup)

## Service Management

### Container Operations

#### Access Container
```bash
# SSH to Proxmox host
ssh root@pve2

# Execute commands in PCT 103
pct exec 103

# Direct SSH access
ssh root@192.168.1.25
```

#### Container Management (from pve2)
```bash
# Container status
pct list | grep 103
pct config 103

# Start/stop container
pct stop 103
pct start 103

# Execute single command
pct exec 103 -- docker ps
```

#### Docker Service Management (from PCT 103)
```bash
# Navigate to Seafile directory
cd /opt/seafile-docker

# View service status
docker compose ps

# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart all services
docker compose restart

# View logs
docker compose logs -f
docker compose logs seafile
docker compose logs seafile-mysql
```

#### Individual Container Management
```bash
# Restart specific service
docker restart seafile
docker restart seafile-mysql
docker restart seafile-memcached

# View container logs
docker logs seafile --tail 50
docker logs seafile-mysql --tail 20

# Check container health
docker inspect seafile | grep -A 10 Health
```

## Troubleshooting

### Common Issues

#### 1. Seahub Startup Failure
**Symptoms**: 502 Bad Gateway, Seahub fails to start
**Root Cause**: MariaDB not ready when Seahub attempts to connect
**Solution**: Fixed in Docker Compose with proper health checks and dependencies

**Manual Recovery**:
```bash
# Restart Seahub service manually
docker exec seafile /opt/seafile/seafile-server-11.0.12/seahub.sh restart

# Check if processes are running
docker exec seafile ps aux | grep -E "(seahub|gunicorn)"
```

#### 2. Database Connection Issues
**Symptoms**: "Can't connect to MySQL server" errors
**Diagnosis**:
```bash
# Check MariaDB container status
docker exec seafile-mysql mysqladmin ping -u root -p

# Verify network connectivity
docker exec seafile ping seafile-mysql

# Check MariaDB logs
docker logs seafile-mysql --tail 20
```

#### 3. Memory/Performance Issues
**Symptoms**: Slow response, container restarts
**Diagnosis**:
```bash
# Check container resource usage
docker stats --no-stream

# Check PCT container memory
pct exec 103 -- free -h

# Check disk space
pct exec 103 -- df -h /opt/seafile-docker
```

### Service Health Verification

#### Quick Health Check
```bash
# From Proxmox host
curl -I http://192.168.1.25:50080

# Expected: HTTP/1.1 302 Found (redirect to login)
```

#### Detailed Status Check
```bash
# Container status
docker ps | grep seafile

# Health check status
docker inspect seafile | grep -A 5 '"Health":'
docker inspect seafile-mysql | grep -A 5 '"Health":'
docker inspect seafile-memcached | grep -A 5 '"Health":'

# Process verification
docker exec seafile ps aux | grep -E "(seafile|seahub)"
```

#### Log Analysis
```bash
# Application logs
docker exec seafile tail -f /opt/seafile/logs/seafile.log
docker exec seafile tail -f /opt/seafile/logs/seahub.log
docker exec seafile tail -f /opt/seafile/logs/controller.log

# Container logs
docker logs seafile --since 10m
docker logs seafile-mysql --since 10m
```

## Backup and Recovery

### Data Backup

#### Database Backup
```bash
# Create database dump
docker exec seafile-mysql mysqladmin dump --all-databases -u root -p > /mnt/backup/seafile-db-$(date +%Y%m%d).sql

# Automated backup script
docker exec seafile-mysql sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' > /mnt/backup/seafile-backup-$(date +%Y%m%d-%H%M%S).sql
```

#### File Data Backup
```bash
# Backup seafile data directory
tar -czf /mnt/backup/seafile-data-$(date +%Y%m%d).tar.gz -C /opt/seafile-docker seafile-data/

# Backup complete configuration
tar -czf /mnt/backup/seafile-complete-$(date +%Y%m%d).tar.gz -C /opt seafile-docker/
```

#### Container Snapshot (Proxmox)
```bash
# From Proxmox host (pve2)
pct snapshot 103 "seafile-backup-$(date +%Y%m%d-%H%M%S)" --description "Seafile backup before maintenance"

# List snapshots
pct listsnapshot 103

# Restore from snapshot
pct rollback 103 <snapshot_name>
```

### Disaster Recovery

#### Complete Service Recovery
```bash
# Stop services
cd /opt/seafile-docker
docker compose down

# Restore from backup
tar -xzf /mnt/backup/seafile-complete-YYYYMMDD.tar.gz -C /opt/

# Start services with health checks
docker compose up -d

# Verify startup
docker compose ps
curl -I http://192.168.1.25:50080
```

#### Database Recovery
```bash
# Stop Seafile container
docker stop seafile

# Restore database
docker exec -i seafile-mysql mysql -u root -p < /mnt/backup/seafile-db-YYYYMMDD.sql

# Start Seafile container
docker start seafile
```

## Maintenance

### Regular Maintenance Tasks

#### Daily Tasks
- Monitor service health via web interface access test
- Check container resource usage
- Verify backup processes

#### Weekly Tasks
- Review service logs for errors or warnings
- Check disk space usage in `/opt/seafile-docker`
- Test database connectivity

#### Monthly Tasks
- Update Docker images (test in development first)
- Database optimization and cleanup
- Review and rotate log files

### Update Procedures

#### Docker Image Updates
```bash
# Navigate to directory
cd /opt/seafile-docker

# Stop services
docker compose down

# Pull latest images
docker compose pull

# Start with updated images
docker compose up -d

# Verify startup
docker compose ps
curl -I http://192.168.1.25:50080
```

#### Configuration Updates
```bash
# Backup current configuration
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d)

# Edit configuration
nano docker-compose.yml

# Validate configuration
docker compose config --quiet

# Apply changes
docker compose up -d

# Verify changes
docker compose ps
```

## Performance Optimization

### Resource Tuning

#### Container Resources (PCT 103)
- **Current**: 6 cores, 2GB RAM, 512MB swap
- **Recommended Monitoring**: Memory usage should stay below 80%
- **Scaling**: Increase memory to 4GB if serving >50 concurrent users

#### Database Optimization
```bash
# MariaDB configuration tuning (if needed)
docker exec seafile-mysql mysql -u root -p -e "SHOW VARIABLES LIKE 'innodb_%';"

# Monitor database performance
docker exec seafile-mysql mysql -u root -p -e "SHOW PROCESSLIST;"
```

#### Memcached Optimization
- Current allocation: 256MB
- Monitor cache hit ratio via Seafile admin interface
- Increase memory if cache hit rate <90%

### Network Performance
- **Current Setup**: Bridge network within container
- **Optimization**: Consider host networking for high-throughput scenarios
- **Monitoring**: Use `docker stats` to monitor network I/O

## Security Considerations

### Network Security
- **Port Exposure**: Only port 50080 exposed externally
- **Database Access**: MariaDB bound to localhost only (127.0.0.1)
- **Internal Communication**: Services communicate via Docker network

### Authentication Security
- **Admin Account**: Configured with strong password
- **Database Access**: Root password protected via environment variables
- **SSL/TLS**: Currently disabled, consider enabling for production use

### Container Security
- **Unprivileged Container**: PCT 103 runs as unprivileged for security
- **AppArmor**: Disabled (`lxc.apparmor.profile: unconfined`) for Docker compatibility
- **Device Access**: Full device access enabled for Docker functionality

### Recommended Security Enhancements
1. Enable HTTPS with Let's Encrypt certificates
2. Implement reverse proxy with Nginx Proxy Manager
3. Configure fail2ban for brute force protection
4. Regular security updates for container OS and Docker images

## Monitoring and Alerting

### Health Monitoring
- **Built-in Health Checks**: All containers have health check configurations
- **External Monitoring**: Consider integration with Uptime Kuma (192.168.1.9:3010)

### Log Monitoring
```bash
# Monitor critical logs
tail -f /opt/seafile/logs/seahub.log | grep -i error
tail -f /opt/seafile/logs/seafile.log | grep -i error

# System resource monitoring
watch 'docker stats --no-stream | grep seafile'
```

### Alert Conditions
- Container restart events
- Health check failures
- High memory usage (>80%)
- Database connectivity issues
- Disk space alerts (<20% free in `/opt/seafile-docker`)

## Known Issues and Limitations

### Current Known Issues
1. **Seahub Startup Timing**: Fixed via Docker Compose health check dependencies
2. **Memory Usage**: Monitor for gradual memory increase over time

### Limitations
1. **Single Node**: No high availability/clustering configured
2. **Backup Automation**: Manual backup processes, no automated scheduling

### Resolved Issues
1. **SSL/TLS**: Now enabled via SEAFILE_SERVER_PROTOCOL=https (resolved in v13.0 upgrade)
2. **Share Link URLs**: Now correctly generated with HTTPS and without port number

### Future Improvements
1. Implement automated backup with retention policies
2. Add monitoring integration with existing infrastructure
3. Consider enabling SeaDoc 2.0 and Notification Server
4. Consider migration to Docker Swarm for HA capabilities

## Upgrade History

| Date | From | To | Notes |
|------|------|-----|-------|
| 2025-12-22 | 12.0.14 | 13.0.12 | Major upgrade, Redis cache, new config structure |

See `seafile-13-upgrade-2025-12-22.md` for detailed upgrade documentation.

---

*Document Created: September 25, 2025*
*Based on PCT 103 Seafile deployment analysis and Docker Compose optimization*
*Last Updated: December 22, 2025 (Seafile 13.0 upgrade)*