#!/bin/bash
# Docker VM Log Rotation Setup Script

echo "=== Docker VM Log Rotation Setup ==="

# 1. Configure Docker daemon log rotation
echo "Configuring Docker daemon logging..."
ssh root@docker 'cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF'

# 2. Set up logrotate for existing container logs
echo "Setting up logrotate for container logs..."
ssh root@docker 'cat > /etc/logrotate.d/docker-containers << EOF
/var/lib/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    sharedscripts
    postrotate
        /bin/kill -USR1 $(cat /var/run/docker.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
EOF'

# 3. Set up system log rotation
echo "Configuring system log rotation..."
ssh root@docker 'cat > /etc/logrotate.d/system-logs << EOF
/var/log/syslog {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 syslog adm
}

/var/log/daemon.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 syslog adm
}

/var/log/kern.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 640 syslog adm
}
EOF'

# 4. Create cleanup cron job
echo "Setting up daily cleanup cron job..."
ssh root@docker 'cat > /etc/cron.daily/docker-cleanup << EOF
#!/bin/bash
# Docker container and image cleanup

# Remove stopped containers older than 24h
docker container prune -f --filter "until=24h"

# Remove unused images older than 7 days
docker image prune -a -f --filter "until=168h"

# Remove unused volumes
docker volume prune -f

# Remove unused networks
docker network prune -f

# Clean up old log files manually (fallback)
find /var/lib/docker/containers -name "*.log" -size +500M -mtime +7 -exec truncate -s 100M {} \;

# Force logrotate
/usr/sbin/logrotate -f /etc/logrotate.d/docker-containers
EOF'

# Make cleanup script executable
ssh root@docker 'chmod +x /etc/cron.daily/docker-cleanup'

# 5. Immediate cleanup of large logs
echo "Performing immediate cleanup of large log files..."
ssh root@docker 'find /var/lib/docker/containers -name "*.log" -size +500M -exec truncate -s 100M {} \; -print'

echo "Checking current log sizes after truncation..."
ssh root@docker 'du -sh /var/lib/docker/containers /var/log'

echo "Restarting Docker daemon to apply new log settings..."
ssh root@docker 'systemctl restart docker'

echo "=== Log Rotation Setup Complete ==="
echo
echo "Configuration Summary:"
echo "- Docker logs: Max 100MB per file, 3 files per container"
echo "- System logs: Daily rotation, 7 days retention"
echo "- Container logs: Daily logrotate with compression"
echo "- Daily cleanup: Removes old containers, images, volumes"
echo "- Large logs truncated to 100MB"
echo
echo "To manually run cleanup: ssh root@docker '/etc/cron.daily/docker-cleanup'"
