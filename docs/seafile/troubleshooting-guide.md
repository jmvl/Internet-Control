# Seafile Troubleshooting Guide

## Quick Diagnostic Commands

### Service Status Check
```bash
# Quick health check from any machine
curl -I -m 5 http://192.168.1.25:50080
# Expected: HTTP/1.1 302 Found

# From Proxmox host
ssh root@pve2 'pct exec 103 -- docker ps | grep seafile'

# Container health status
ssh root@pve2 'pct exec 103 -- docker inspect seafile | grep -A 10 Health'
```

### Log Analysis
```bash
# Recent Seahub logs
ssh root@pve2 'pct exec 103 -- docker exec seafile tail -20 /opt/seafile/logs/seahub.log'

# Recent Seafile logs
ssh root@pve2 'pct exec 103 -- docker exec seafile tail -20 /opt/seafile/logs/seafile.log'

# Container startup logs
ssh root@pve2 'pct exec 103 -- docker logs seafile --tail 30'
ssh root@pve2 'pct exec 103 -- docker logs seafile-mysql --tail 20'
```

## Common Issues and Solutions

### Issue 1: "502 Bad Gateway" Error

**Symptoms**:
- Web browser shows "502 Bad Gateway"
- Nginx is running but Seahub is not responding

**Root Cause**: Seahub service failed to start or crashed

**Diagnosis**:
```bash
# Check if Seahub processes are running
ssh root@pve2 'pct exec 103 -- docker exec seafile ps aux | grep gunicorn'

# Check Seahub startup logs
ssh root@pve2 'pct exec 103 -- docker exec seafile tail -50 /opt/seafile/logs/seahub.log'
```

**Solution**:
```bash
# Manual Seahub restart
ssh root@pve2 'pct exec 103 -- docker exec seafile /opt/seafile/seafile-server-11.0.12/seahub.sh restart'

# If restart fails, check database connectivity
ssh root@pve2 'pct exec 103 -- docker exec seafile ping seafile-mysql'

# Verify MariaDB is responding
ssh root@pve2 'pct exec 103 -- docker exec seafile-mysql mysqladmin ping -u root -pABluMBuINGsT'
```

### Issue 2: Database Connection Failures

**Symptoms**:
- Seahub logs show "Can't connect to MySQL server"
- Error code 2003 "Connection refused"

**Root Cause**: MariaDB container not ready or networking issue

**Diagnosis**:
```bash
# Check MariaDB container status
ssh root@pve2 'pct exec 103 -- docker ps | grep mysql'

# Test database connectivity
ssh root@pve2 'pct exec 103 -- docker exec seafile telnet seafile-mysql 3306'

# Check MariaDB health
ssh root@pve2 'pct exec 103 -- docker inspect seafile-mysql | grep -A 5 Health'
```

**Solution**:
```bash
# Restart MariaDB container
ssh root@pve2 'pct exec 103 -- docker restart seafile-mysql'

# Wait for database to be ready (30 seconds)
sleep 30

# Restart Seafile container
ssh root@pve2 'pct exec 103 -- docker restart seafile'

# Monitor startup process
ssh root@pve2 'pct exec 103 -- docker logs seafile -f'
```

### Issue 3: Container Won't Start After Reboot

**Symptoms**:
- PCT 103 is running but Seafile containers are stopped
- Docker containers in "Exited" state

**Root Cause**: Docker service or containers failed to auto-start

**Diagnosis**:
```bash
# Check PCT container status
ssh root@pve2 'pct list | grep 103'

# Check Docker service status
ssh root@pve2 'pct exec 103 -- systemctl status docker'

# Check container status
ssh root@pve2 'pct exec 103 -- docker ps -a | grep seafile'
```

**Solution**:
```bash
# Start Docker service if stopped
ssh root@pve2 'pct exec 103 -- systemctl start docker'

# Navigate to Seafile directory and start services
ssh root@pve2 'pct exec 103 -- bash -c "cd /opt/seafile-docker && docker compose up -d"'

# Verify startup
ssh root@pve2 'pct exec 103 -- docker ps | grep seafile'
```

### Issue 4: High Memory Usage

**Symptoms**:
- PCT container using >80% of allocated memory
- Services becoming slow or unresponsive

**Diagnosis**:
```bash
# Check PCT memory usage
ssh root@pve2 'pct exec 103 -- free -h'

# Check Docker container memory usage
ssh root@pve2 'pct exec 103 -- docker stats --no-stream | grep seafile'

# Check for memory leaks in processes
ssh root@pve2 'pct exec 103 -- docker exec seafile top -p 1'
```

**Solution**:
```bash
# Restart containers to free memory
ssh root@pve2 'pct exec 103 -- bash -c "cd /opt/seafile-docker && docker compose restart"'

# If issue persists, increase PCT memory allocation
ssh root@pve2 'pct set 103 --memory 4096'  # Increase to 4GB

# Restart PCT container to apply memory changes
ssh root@pve2 'pct reboot 103'
```

### Issue 5: Disk Space Full

**Symptoms**:
- Services failing to start
- "No space left on device" errors in logs

**Diagnosis**:
```bash
# Check disk usage
ssh root@pve2 'pct exec 103 -- df -h'

# Check Seafile directory usage
ssh root@pve2 'pct exec 103 -- du -sh /opt/seafile-docker/*'

# Check Docker system usage
ssh root@pve2 'pct exec 103 -- docker system df'
```

**Solution**:
```bash
# Clean up Docker system
ssh root@pve2 'pct exec 103 -- docker system prune -f'

# Remove old log files
ssh root@pve2 'pct exec 103 -- find /opt/seafile/logs -name "*.log.*" -mtime +30 -delete'

# If still full, expand PCT storage
ssh root@pve2 'pct resize 103 rootfs +50G'  # Add 50GB
```

### Issue 6: SSL/HTTPS Configuration Issues

**Symptoms**:
- HTTPS not working
- Certificate errors

**Current State**: HTTPS is disabled in current configuration

**Solution**:
```bash
# Enable HTTPS in Docker Compose
ssh root@pve2 'pct exec 103 -- nano /opt/seafile-docker/docker-compose.yml'

# Uncomment HTTPS port and set SSL environment variables:
# ports:
#   - "443:443"
# environment:
#   - SEAFILE_SERVER_LETSENCRYPT=true

# Restart services
ssh root@pve2 'pct exec 103 -- bash -c "cd /opt/seafile-docker && docker compose up -d"'
```

## Emergency Recovery Procedures

### Complete Service Recovery
```bash
# Stop all services
ssh root@pve2 'pct exec 103 -- bash -c "cd /opt/seafile-docker && docker compose down"'

# Backup current state
ssh root@pve2 'pct exec 103 -- cp -r /opt/seafile-docker /opt/seafile-docker.backup-$(date +%Y%m%d)'

# Start services with fresh initialization
ssh root@pve2 'pct exec 103 -- bash -c "cd /opt/seafile-docker && docker compose up -d"'

# Monitor startup process
ssh root@pve2 'pct exec 103 -- docker compose logs -f'
```

### Database Recovery from Backup
```bash
# Stop Seafile service
ssh root@pve2 'pct exec 103 -- docker stop seafile'

# Access MariaDB container
ssh root@pve2 'pct exec 103 -- docker exec -it seafile-mysql mysql -u root -p'

# Restore from backup file
ssh root@pve2 'pct exec 103 -- docker exec -i seafile-mysql mysql -u root -pABluMBuINGsT < /mnt/backup/seafile-backup-YYYYMMDD.sql'

# Start Seafile service
ssh root@pve2 'pct exec 103 -- docker start seafile'
```

### Container Recovery from Proxmox Snapshot
```bash
# List available snapshots
ssh root@pve2 'pct listsnapshot 103'

# Stop container
ssh root@pve2 'pct stop 103'

# Restore from snapshot
ssh root@pve2 'pct rollback 103 <snapshot_name> --force'

# Start container
ssh root@pve2 'pct start 103'
```

## Performance Troubleshooting

### Slow Response Times

**Diagnosis**:
```bash
# Check system load
ssh root@pve2 'pct exec 103 -- top'

# Check database performance
ssh root@pve2 'pct exec 103 -- docker exec seafile-mysql mysql -u root -p -e "SHOW PROCESSLIST;"'

# Check network connectivity
ping 192.168.1.25
```

**Solutions**:
```bash
# Restart services
ssh root@pve2 'pct exec 103 -- bash -c "cd /opt/seafile-docker && docker compose restart"'

# Increase Memcached memory (if needed)
# Edit docker-compose.yml to change: memcached -m 512

# Optimize database
ssh root@pve2 'pct exec 103 -- docker exec seafile-mysql mysqlcheck --optimize --all-databases -u root -p'
```

### High CPU Usage

**Diagnosis**:
```bash
# Check process CPU usage
ssh root@pve2 'pct exec 103 -- docker stats --no-stream'

# Check individual container processes
ssh root@pve2 'pct exec 103 -- docker exec seafile top'
```

**Solutions**:
```bash
# Increase CPU allocation for PCT
ssh root@pve2 'pct set 103 --cores 8'  # Increase to 8 cores

# Restart container to apply changes
ssh root@pve2 'pct reboot 103'
```

## Monitoring and Alerting Setup

### Health Check Script
Create a monitoring script to check Seafile health:

```bash
#!/bin/bash
# /root/scripts/check-seafile.sh

SEAFILE_URL="http://192.168.1.25:50080"
ALERT_EMAIL="admin@accelior.com"

# Check HTTP response
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $SEAFILE_URL)

if [ "$HTTP_STATUS" != "302" ]; then
    echo "ALERT: Seafile not responding properly. HTTP Status: $HTTP_STATUS"
    # Send email alert or log to monitoring system
    logger "SEAFILE ALERT: Service not responding, HTTP status $HTTP_STATUS"
else
    echo "OK: Seafile responding normally"
fi

# Check container status
CONTAINER_COUNT=$(ssh root@pve2 'pct exec 103 -- docker ps | grep seafile | wc -l')
if [ "$CONTAINER_COUNT" -lt 3 ]; then
    echo "ALERT: Not all Seafile containers are running"
    logger "SEAFILE ALERT: Only $CONTAINER_COUNT/3 containers running"
fi
```

### Log Rotation Setup
```bash
# Setup logrotate for Seafile logs
ssh root@pve2 'pct exec 103 -- cat > /etc/logrotate.d/seafile << EOF
/opt/seafile/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    create 644 root root
    postrotate
        docker restart seafile
    endscript
}
EOF'
```

## Contact and Escalation

### Internal Team Contacts
- **Primary Admin**: info@accelior.com
- **Infrastructure Team**: Available via standard channels

### External Resources
- **Seafile Documentation**: https://manual.seafile.com/
- **Docker Compose Reference**: https://docs.docker.com/compose/
- **MariaDB Troubleshooting**: https://mariadb.org/documentation/

### Escalation Procedures
1. **Level 1**: Apply solutions from this guide
2. **Level 2**: Check Proxmox host resources and network connectivity
3. **Level 3**: Consider container snapshot rollback
4. **Level 4**: Full infrastructure team involvement for hardware issues

---

*Created: September 25, 2025*
*Troubleshooting guide for Seafile deployment on PCT 103*