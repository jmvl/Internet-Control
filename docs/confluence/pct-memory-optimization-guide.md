# PCT Container Memory Optimization Guide

## Overview
This guide provides comprehensive procedures for diagnosing and resolving memory pressure issues in Proxmox LXC containers running Java applications (Confluence, JIRA, etc.).

## Quick Reference - Memory Crisis Response

### Immediate Assessment Commands
```bash
# Check container memory configuration
ssh root@pve2 "pct config <VMID> | grep -E '(memory|swap)'"

# Check current memory usage inside container
ssh root@pve2 "pct exec <VMID> -- free -h"

# Check Docker container resource usage
ssh root@pve2 "pct exec <VMID> -- docker stats --no-stream"

# Check for swap usage (critical indicator)
ssh root@pve2 "pct exec <VMID> -- cat /proc/meminfo | grep -E '(MemTotal|MemAvailable|SwapTotal|SwapFree)'"
```

### Critical Thresholds
- **Memory Usage >85%**: Warning level, monitor closely
- **Memory Usage >95%**: Critical level, immediate action required
- **Swap Usage >50%**: Performance degradation imminent
- **Swap Usage >90%**: Severe performance impact, urgent optimization needed

## Memory Pressure Diagnosis

### Step 1: Identify Memory Consumers
```bash
# Inside the PCT container, check top memory processes
ssh root@pve2 "pct exec <VMID> -- ps aux --sort=-%mem | head -10"

# Check Java process memory specifically
ssh root@pve2 "pct exec <VMID> -- ps aux | grep java"

# Check Docker container individual usage
ssh root@pve2 "pct exec <VMID> -- docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}'"
```

### Step 2: Analyze Java Application Memory
```bash
# Check Java heap configuration (for Confluence/JIRA)
ssh root@pve2 "pct exec <VMID> -- docker exec <container_name> java -XX:+PrintFlagsFinal -version | grep -E '(HeapSize|MaxNewSize)'"

# Check garbage collection logs if available
ssh root@pve2 "pct exec <VMID> -- docker exec <container_name> find /opt -name '*.log' -path '*gc*' | head -5"

# Check JVM environment variables
ssh root@pve2 "pct exec <VMID> -- docker exec <container_name> env | grep -E '(JVM_|JAVA_)'"
```

### Step 3: Database Memory Analysis
```bash
# Check MySQL memory configuration
ssh root@pve2 "pct exec <VMID> -- docker exec mysql_docker mysql -h127.0.0.1 -uroot -p'<password>' -e \"SHOW VARIABLES LIKE '%buffer_pool_size%';\""

# Check MySQL process list for memory usage
ssh root@pve2 "pct exec <VMID> -- docker exec mysql_docker mysql -h127.0.0.1 -uroot -p'<password>' -e \"SHOW PROCESSLIST;\""

# Check MySQL status for memory-related metrics
ssh root@pve2 "pct exec <VMID> -- docker exec mysql_docker mysql -h127.0.0.1 -uroot -p'<password>' -e \"SHOW STATUS LIKE '%buffer%';\""
```

## Optimization Procedures

### Phase 1: PCT Container Resource Adjustment

#### Increase Container Memory
```bash
# Stop the container
ssh root@pve2 "pct stop <VMID>"

# Increase memory and swap (adjust values as needed)
ssh root@pve2 "pct set <VMID> --memory <NEW_MEMORY_MB> --swap <NEW_SWAP_MB>"

# Verify configuration
ssh root@pve2 "pct config <VMID> | grep -E '(memory|swap)'"

# Start the container
ssh root@pve2 "pct start <VMID>"
```

#### Memory Sizing Guidelines
| Application Stack | Recommended Base | Peak Usage | Container Size |
|------------------|------------------|------------|---------------|
| Confluence + MySQL | 8GB | 12GB | 16GB |
| JIRA + MySQL | 6GB | 10GB | 14GB |
| Small Confluence | 4GB | 6GB | 8GB |
| Development/Test | 2GB | 4GB | 6GB |

### Phase 2: Java Application Tuning

#### Confluence JVM Optimization
```yaml
# docker-compose.yml environment section
environment:
  # Memory allocation (adjust based on container size)
  - JVM_MINIMUM_MEMORY=3072m  # 50% of intended heap
  - JVM_MAXIMUM_MEMORY=6144m  # Target 35-40% of container memory
  - JVM_RESERVED_CODE_CACHE_SIZE=512m

  # G1GC optimization for large heaps
  - CATALINA_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1HeapRegionSize=16m -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap
```

#### JIRA JVM Optimization
```yaml
environment:
  - JVM_MINIMUM_MEMORY=2048m
  - JVM_MAXIMUM_MEMORY=4096m
  - JVM_RESERVED_CODE_CACHE_SIZE=512m
  - CATALINA_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1HeapRegionSize=8m -XX:+UseCGroupMemoryLimitForHeap
```

### Phase 3: Database Memory Optimization

#### MySQL Configuration Tuning
```yaml
# docker-compose.yml MySQL command section
command: >
  --character_set_server=utf8
  --collation-server=utf8_bin
  --transaction-isolation=READ-COMMITTED
  --default-storage-engine=INNODB
  --innodb_default_row_format=DYNAMIC
  --innodb_log_file_size=256M
  --max_allowed_packet=128M
  --innodb_buffer_pool_size=1024M  # Adjust based on available memory
  --innodb_flush_log_at_trx_commit=2
  --innodb_io_capacity=1000
  --innodb_flush_method=O_DIRECT
  --innodb_flush_neighbors=0
```

#### PostgreSQL Configuration Tuning
```bash
# For PostgreSQL-based applications
shared_buffers = 256MB          # 25% of available DB memory
effective_cache_size = 1GB      # 75% of available DB memory
work_mem = 4MB                  # Per connection
maintenance_work_mem = 64MB     # For maintenance operations
```

## Service Restart Procedures

### Safe Service Restart Sequence
```bash
# 1. Stop application services first
ssh root@pve2 "pct exec <VMID> -- bash -c 'cd /opt/<app>-docker && docker-compose down'"

# 2. Wait for graceful shutdown
sleep 30

# 3. Verify all containers stopped
ssh root@pve2 "pct exec <VMID> -- docker ps"

# 4. Start services with new configuration
ssh root@pve2 "pct exec <VMID> -- bash -c 'cd /opt/<app>-docker && docker-compose up -d'"

# 5. Monitor startup
ssh root@pve2 "pct exec <VMID> -- docker logs -f <container_name>"
```

### Validation After Restart
```bash
# Check memory usage stabilization
ssh root@pve2 "pct exec <VMID> -- free -h"

# Monitor for 5-10 minutes
ssh root@pve2 "pct exec <VMID> -- watch -n 30 'docker stats --no-stream'"

# Check application accessibility
curl -I http://<container_ip>:<port>/
```

## Monitoring and Alerting

### Performance Metrics to Track
```bash
# Memory utilization trends
ssh root@pve2 "pct exec <VMID> -- sar -r 1 5"

# Swap activity (should be minimal)
ssh root@pve2 "pct exec <VMID> -- sar -S 1 5"

# Java garbage collection frequency
ssh root@pve2 "pct exec <VMID> -- docker exec <container> jstat -gc <pid> 5s"
```

### Automated Monitoring Script
```bash
#!/bin/bash
# Save as /root/scripts/memory-monitor.sh on pve2

VMID=$1
CONTAINER_IP=$(pct exec $VMID -- ip route | grep default | awk '{print $3}')

echo "=== Memory Monitor for Container $VMID ==="
echo "Timestamp: $(date)"
echo

echo "--- PCT Container Resources ---"
pct config $VMID | grep -E '(memory|swap)'
echo

echo "--- Container Memory Usage ---"
pct exec $VMID -- free -h
echo

echo "--- Docker Container Stats ---"
pct exec $VMID -- docker stats --no-stream
echo

echo "--- Swap Activity Check ---"
SWAP_USED=$(pct exec $VMID -- free | grep Swap | awk '{print $3}')
if [ "$SWAP_USED" -gt 0 ]; then
    echo "WARNING: Swap usage detected ($SWAP_USED KB)"
else
    echo "OK: No swap usage"
fi
```

## Troubleshooting Common Issues

### Issue: High Memory Usage After Restart
**Symptoms**: Memory usage remains high despite service restart
**Cause**: Memory leaks, large heap allocation, or insufficient container memory
**Solution**:
1. Check for memory leaks with `jmap` if available
2. Reduce JVM heap size temporarily
3. Increase container memory allocation
4. Review application logs for memory-related errors

### Issue: Persistent Swap Usage
**Symptoms**: Swap usage doesn't decrease after memory optimization
**Cause**: Swapped pages not automatically returned to RAM
**Solution**:
```bash
# Force swap clearing (use with caution)
ssh root@pve2 "pct exec <VMID> -- swapoff -a && swapon -a"

# Monitor swap usage afterward
ssh root@pve2 "pct exec <VMID> -- watch -n 5 'free -h'"
```

### Issue: Out of Memory Errors
**Symptoms**: Application crashes with OOM errors
**Cause**: Insufficient memory allocation or memory leaks
**Solution**:
1. Immediately increase container memory as emergency measure
2. Reduce JVM heap size temporarily for stability
3. Analyze heap dumps if available
4. Check for memory-intensive operations in logs

### Issue: Slow Application Performance
**Symptoms**: Sluggish response times after memory optimization
**Cause**: Garbage collection overhead or inappropriate GC settings
**Solution**:
1. Monitor GC logs for excessive collection frequency
2. Adjust GC parameters (G1GC settings)
3. Ensure heap size is appropriate for workload
4. Check for database query performance issues

## Emergency Recovery Procedures

### Critical Memory Exhaustion
```bash
# 1. Immediate container memory increase
ssh root@pve2 "pct set <VMID> --memory $(($(pct config <VMID> | grep memory | cut -d' ' -f2) * 2))"

# 2. Force service restart
ssh root@pve2 "pct exec <VMID> -- docker restart <container_name>"

# 3. Monitor recovery
ssh root@pve2 "pct exec <VMID> -- watch -n 10 'free -h && echo && docker stats --no-stream'"
```

### Backup and Rollback
```bash
# Create configuration backup before changes
ssh root@pve2 "pct config <VMID> > /root/backups/pct-<VMID>-config-$(date +%Y%m%d-%H%M%S).conf"

# Create docker-compose backup
ssh root@pve2 "pct exec <VMID> -- cp /opt/<app>-docker/docker-compose.yml /opt/<app>-docker/docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)"

# Rollback procedure if issues occur
ssh root@pve2 "pct exec <VMID> -- cp /opt/<app>-docker/docker-compose.yml.backup-<timestamp> /opt/<app>-docker/docker-compose.yml"
```

## Best Practices

### Memory Allocation Guidelines
1. **Container Memory**: Allocate 1.5-2x the expected peak usage
2. **JVM Heap**: Target 35-40% of container memory for heap
3. **Database Buffer**: Allocate 15-25% of container memory for DB buffers
4. **System Overhead**: Reserve 15-20% for OS and other processes

### Monitoring Schedule
- **Real-time**: During optimization and first 24 hours
- **Daily**: First week after changes
- **Weekly**: Ongoing monitoring for trends
- **Monthly**: Comprehensive performance review

### Change Management
1. Always create configuration backups before changes
2. Implement changes during maintenance windows
3. Monitor for 48 hours after optimization
4. Document all changes in service-specific documentation
5. Set up alerting for memory thresholds

---
*Created: September 19, 2025*
*Based on Container 100 (Confluence) memory optimization intervention*
*Last Updated: September 19, 2025*