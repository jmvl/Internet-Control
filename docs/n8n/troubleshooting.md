# n8n Troubleshooting Guide

## Quick Diagnostic Commands

### Service Status Check
```bash
# Basic health check
curl -I https://n8n.accelior.com/

# Container status
ssh root@192.168.1.20 'docker ps | grep n8n'

# Resource usage
ssh root@192.168.1.20 'docker stats n8n-n8n-1 --no-stream'

# Service logs (last 50 lines)
ssh root@192.168.1.20 'docker logs n8n-n8n-1 --tail 50'

# Database connectivity
ssh root@192.168.1.20 'docker exec n8n-n8n-1 nc -zv aws-0-eu-central-1.pooler.supabase.com 6543'
```

### Resource Monitoring
```bash
# Memory usage trend
ssh root@192.168.1.20 'watch -n 10 "docker stats n8n-n8n-1 --no-stream --format \"table {{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}\""'

# PCT container resources
ssh root@pve2 'pct config 100 | grep -E "(memory|swap)"'

# Host memory status
ssh root@192.168.1.20 'free -h'
```

## Common Issues and Solutions

### Issue 1: Service Won't Start

#### Symptoms
- Container exits immediately after startup
- "Connection refused" when accessing web interface
- Docker logs show database connection errors

#### Diagnostic Steps
```bash
# Check container startup logs
ssh root@192.168.1.20 'docker logs n8n-n8n-1'

# Verify docker-compose configuration
ssh root@192.168.1.20 'cd /root/n8n && docker compose config'

# Test database connectivity
ssh root@192.168.1.20 'docker run --rm postgres:latest psql postgresql://postgres.bbgyrvkxejtrnttoijlt:qdjCUK1DI1x5umDG@aws-0-eu-central-1.pooler.supabase.com:6543/postgres -c "SELECT 1"'
```

#### Solutions
```bash
# Restart with clean state
ssh root@192.168.1.20 'cd /root/n8n && docker compose down -v && docker compose up -d'

# Check for port conflicts
ssh root@192.168.1.20 'netstat -tlnp | grep :5678'

# Restore from backup if configuration corrupted
ssh root@192.168.1.20 'cd /root/n8n && cp docker-compose.yml.backup-[LATEST] docker-compose.yml && docker compose up -d'
```

### Issue 2: High Memory Usage

#### Symptoms
- Memory usage >80% of 1GB limit
- Slow workflow execution
- Container restart due to OOM

#### Diagnostic Steps
```bash
# Check current memory usage
ssh root@192.168.1.20 'docker stats n8n-n8n-1 --no-stream'

# Check Node.js heap usage
ssh root@192.168.1.20 'docker exec n8n-n8n-1 node -e "console.log(JSON.stringify(process.memoryUsage(), null, 2))"'

# Check execution data size
ssh root@192.168.1.20 'docker exec n8n-n8n-1 du -sh /home/node/.n8n'

# Check for memory leaks in logs
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -i "memory\|heap\|out of memory"'
```

#### Solutions
```bash
# Force execution data cleanup
ssh root@192.168.1.20 'docker exec n8n-n8n-1 rm -f /home/node/.n8n/database.sqlite-wal /home/node/.n8n/database.sqlite-shm'

# Restart container to clear memory
ssh root@192.168.1.20 'cd /root/n8n && docker compose restart n8n'

# Temporary memory increase (emergency)
ssh root@192.168.1.20 'cd /root/n8n && docker compose down'
# Edit docker-compose.yml to increase memory limit temporarily
ssh root@192.168.1.20 'cd /root/n8n && docker compose up -d'

# Check for problematic workflows
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -E "workflow.*error|execution.*failed" | tail -20'
```

### Issue 3: Database Connection Problems

#### Symptoms
- "Cannot connect to database" errors
- Workflows not saving
- Authentication failures

#### Diagnostic Steps
```bash
# Test raw database connection
ssh root@192.168.1.20 'docker exec n8n-n8n-1 nc -zv aws-0-eu-central-1.pooler.supabase.com 6543'

# Check database credentials
ssh root@192.168.1.20 'docker exec n8n-n8n-1 env | grep DB_'

# Test with psql if available
ssh root@192.168.1.20 'docker run --rm postgres:latest psql postgresql://postgres.bbgyrvkxejtrnttoijlt:qdjCUK1DI1x5umDG@aws-0-eu-central-1.pooler.supabase.com:6543/postgres -c "\l"'
```

#### Solutions
```bash
# Restart container to refresh connections
ssh root@192.168.1.20 'cd /root/n8n && docker compose restart n8n'

# Check for network issues
ssh root@192.168.1.20 'ping -c 4 aws-0-eu-central-1.pooler.supabase.com'

# Verify SSL certificate issues
ssh root@192.168.1.20 'openssl s_client -connect aws-0-eu-central-1.pooler.supabase.com:6543 -servername aws-0-eu-central-1.pooler.supabase.com'

# Reset database connection pool
ssh root@192.168.1.20 'cd /root/n8n && docker compose down && sleep 30 && docker compose up -d'
```

### Issue 4: Gotenberg Service Issues

#### Symptoms
- Gotenberg container constantly restarting
- PDF generation failures in workflows
- "Service unavailable" errors for document conversion

#### Diagnostic Steps
```bash
# Check Gotenberg container status
ssh root@192.168.1.20 'docker ps | grep gotenberg'

# View Gotenberg logs
ssh root@192.168.1.20 'docker logs n8n-gotenberg-1'

# Check resource usage
ssh root@192.168.1.20 'docker stats n8n-gotenberg-1 --no-stream'
```

#### Solutions
```bash
# Restart Gotenberg service
ssh root@192.168.1.20 'cd /root/n8n && docker compose restart gotenberg'

# Check for resource constraints
ssh root@192.168.1.20 'docker inspect n8n-gotenberg-1 | grep -A 5 -B 2 Memory'

# Temporary disable if blocking n8n startup
ssh root@192.168.1.20 'cd /root/n8n && docker compose up -d n8n'
```

### Issue 5: Webhook Failures

#### Symptoms
- Webhooks return 404 or 500 errors
- External services cannot reach n8n webhooks
- Webhook URLs not responding

#### Diagnostic Steps
```bash
# Test webhook endpoint internally
ssh root@192.168.1.20 'curl -I http://localhost:5678/webhook-test/test'

# Check reverse proxy configuration
curl -I https://n8n.accelior.com/webhook-test/test

# Check webhook logs
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep webhook'

# Verify n8n webhook configuration
ssh root@192.168.1.20 'docker exec n8n-n8n-1 env | grep WEBHOOK'
```

#### Solutions
```bash
# Restart n8n service
ssh root@192.168.1.20 'cd /root/n8n && docker compose restart n8n'

# Check webhook URL configuration
ssh root@192.168.1.20 'docker exec n8n-n8n-1 env | grep N8N_HOST'

# Test direct container access
ssh root@192.168.1.20 'curl -X POST http://192.168.1.20:5678/webhook-test/test -H "Content-Type: application/json" -d "{\"test\": true}"'
```

### Issue 6: Performance Degradation

#### Symptoms
- Slow workflow execution
- High CPU usage
- Unresponsive web interface

#### Diagnostic Steps
```bash
# Monitor resource usage
ssh root@192.168.1.20 'docker stats n8n-n8n-1'

# Check for CPU throttling
ssh root@192.168.1.20 'docker exec n8n-n8n-1 cat /sys/fs/cgroup/cpu/cpu.stat'

# Analyze workflow execution times
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -E "execution.*took|workflow.*completed" | tail -10'

# Check for memory pressure
ssh root@192.168.1.20 'free -h && cat /proc/meminfo | grep -E "(MemAvailable|SwapTotal)"'
```

#### Solutions
```bash
# Restart container to clear accumulated state
ssh root@192.168.1.20 'cd /root/n8n && docker compose restart n8n'

# Clear execution history
ssh root@192.168.1.20 'docker exec n8n-n8n-1 find /home/node/.n8n -name "*.sqlite*" -exec ls -lh {} \;'

# Check for problematic workflows
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -E "error|timeout|failed" | tail -20'
```

## Emergency Procedures

### Complete Service Recovery
```bash
# Step 1: Stop all services
ssh root@192.168.1.20 'cd /root/n8n && docker compose down'

# Step 2: Clear any corrupted containers
ssh root@192.168.1.20 'docker system prune -f'

# Step 3: Restore known good configuration
ssh root@192.168.1.20 'cd /root/n8n && cp docker-compose.yml.backup-[LATEST] docker-compose.yml'

# Step 4: Start services with extended timeout
ssh root@192.168.1.20 'cd /root/n8n && docker compose up -d --wait --wait-timeout 120'

# Step 5: Verify recovery
curl -I https://n8n.accelior.com/
ssh root@192.168.1.20 'docker logs n8n-n8n-1 --tail 20'
```

### PCT Container Recovery
```bash
# If entire PCT container is unresponsive
ssh root@pve2 'pct stop 100'
ssh root@pve2 'pct start 100'

# Wait for container to fully boot
sleep 60

# Verify services auto-start
ssh root@192.168.1.20 'docker ps | grep n8n'

# Manual service restart if needed
ssh root@192.168.1.20 'cd /root/n8n && docker compose up -d'
```

### Data Recovery
```bash
# Restore from backup if data corruption suspected
ssh root@192.168.1.20 'docker compose down'
ssh root@192.168.1.20 'docker volume rm n8n_n8n_user_data'
ssh root@192.168.1.20 'docker run --rm -v n8n_n8n_user_data:/data -v /root/backups:/backup alpine tar xzf /backup/n8n-data-[DATE].tar.gz -C /data'
ssh root@192.168.1.20 'cd /root/n8n && docker compose up -d'
```

## Performance Monitoring

### Real-time Monitoring Script
```bash
#!/bin/bash
# Save as /root/scripts/n8n-monitor.sh

echo "=== n8n Service Monitor ==="
echo "Timestamp: $(date)"
echo

echo "--- Container Status ---"
ssh root@192.168.1.20 'docker ps | grep n8n'
echo

echo "--- Resource Usage ---"
ssh root@192.168.1.20 'docker stats n8n-n8n-1 --no-stream'
echo

echo "--- Service Health ---"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://n8n.accelior.com/)
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✓ Web interface accessible (HTTP $HTTP_STATUS)"
else
    echo "✗ Web interface error (HTTP $HTTP_STATUS)"
fi

echo "--- Database Connectivity ---"
ssh root@192.168.1.20 'docker exec n8n-n8n-1 nc -zv aws-0-eu-central-1.pooler.supabase.com 6543' 2>&1 | grep -q "succeeded" && echo "✓ Database connection OK" || echo "✗ Database connection failed"

echo "--- Memory Analysis ---"
MEMORY_USAGE=$(ssh root@192.168.1.20 'docker stats n8n-n8n-1 --no-stream --format "{{.MemPerc}}"' | sed 's/%//')
if (( $(echo "$MEMORY_USAGE > 80" | bc -l) )); then
    echo "⚠ High memory usage: $MEMORY_USAGE%"
elif (( $(echo "$MEMORY_USAGE > 60" | bc -l) )); then
    echo "△ Moderate memory usage: $MEMORY_USAGE%"
else
    echo "✓ Normal memory usage: $MEMORY_USAGE%"
fi

echo "--- Recent Errors ---"
ERROR_COUNT=$(ssh root@192.168.1.20 'docker logs n8n-n8n-1 --since 1h | grep -i error | wc -l')
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "⚠ $ERROR_COUNT errors in last hour"
    ssh root@192.168.1.20 'docker logs n8n-n8n-1 --since 1h | grep -i error | tail -3'
else
    echo "✓ No errors in last hour"
fi
```

### Automated Alerting
```bash
# Add to cron for regular monitoring
# crontab -e
# */15 * * * * /root/scripts/n8n-monitor.sh | grep -E "(✗|⚠)" && /root/scripts/alert-send.sh "n8n Alert"
```

## Log Analysis

### Error Pattern Identification
```bash
# Common error patterns
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -E "ERROR|FATAL|failed|timeout" | sort | uniq -c | sort -rn'

# Memory-related issues
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -E "memory|heap|allocation|oom" | tail -10'

# Database issues
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -E "database|connection|sql|postgres" | tail -10'

# Performance issues
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -E "slow|timeout|performance|took.*ms" | tail -10'
```

### Log Export for Analysis
```bash
# Export logs with timestamp
ssh root@192.168.1.20 'docker logs n8n-n8n-1 --timestamps > /tmp/n8n-debug-$(date +%Y%m%d-%H%M%S).log'

# Export recent logs only
ssh root@192.168.1.20 'docker logs n8n-n8n-1 --since 24h --timestamps > /tmp/n8n-recent-$(date +%Y%m%d).log'

# Export and compress for analysis
ssh root@192.168.1.20 'docker logs n8n-n8n-1 --timestamps | gzip > /root/logs/n8n-full-$(date +%Y%m%d).log.gz'
```

## Contact and Escalation

### Internal Escalation
1. **Level 1**: Restart container services
2. **Level 2**: Restart PCT container
3. **Level 3**: Restore from backup
4. **Level 4**: Contact infrastructure team

### External Dependencies
- **Database**: Supabase support (if database issues persist)
- **DNS/Proxy**: Check reverse proxy configuration
- **Network**: ISP or datacenter network issues

### Documentation References
- Container Optimization Guide: `/docs/n8n/container-optimization-guide.md`
- Deployment Reference: `/docs/n8n/deployment-reference.md`
- PCT Memory Guide: `/docs/confluence/pct-memory-optimization-guide.md`

---

**Created**: September 19, 2025
**Last Updated**: September 19, 2025
**Scope**: Production n8n deployment on PCT Container 100
**Emergency Contact**: Infrastructure team via standard procedures