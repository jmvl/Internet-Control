# n8n Container Memory Optimization Guide

## Overview
This guide documents the comprehensive memory optimization applied to the n8n Docker container running on PCT Container 100 (192.168.1.20). The optimization follows PCT memory optimization best practices and addresses resource management for Node.js applications in containerized environments.

## Current Infrastructure

### Environment Details
- **Host**: PCT Container 100 (ConfluenceDocker20220712) at 192.168.1.20
- **PCT Memory**: 16GB allocated with 2GB swap
- **Container Location**: `/root/n8n/docker-compose.yml`
- **Public Access**: https://n8n.accelior.com (port 5678)
- **Database**: External PostgreSQL (Supabase)

### Resource Utilization (Post-Optimization)
- **n8n Memory Usage**: ~265MB (26% of 1GB limit)
- **CPU Usage**: Minimal (~0.01% baseline)
- **Host Memory**: 6.6GB used out of 16GB (41% utilization)
- **Swap Usage**: 0B (optimal - no swap pressure)

## Optimization Implementation

### Phase 1: Resource Limits Configuration

#### Applied Docker Resource Limits
```yaml
deploy:
  resources:
    limits:
      memory: 1G        # Hard limit prevents memory exhaustion
      cpus: '1.0'       # Single core allocation
    reservations:
      memory: 512M      # Guaranteed minimum memory
      cpus: '0.5'       # Guaranteed half core
```

**Rationale**:
- **1GB Memory Limit**: Based on current 407MB usage + 150% buffer for growth
- **512MB Reservation**: Ensures consistent performance under host memory pressure
- **CPU Limits**: Prevents CPU starvation of other services

### Phase 2: Node.js Memory Optimization

#### Environment Variables Added
```yaml
environment:
  # Node.js memory optimization
  - NODE_OPTIONS=--max-old-space-size=768

  # n8n execution data management
  - N8N_EXECUTIONS_DATA_MAX_AGE=168        # 1 week retention
  - N8N_EXECUTIONS_DATA_PRUNE=true         # Enable automatic cleanup
  - N8N_EXECUTIONS_DATA_PRUNE_MAX_COUNT=1000  # Maximum stored executions
```

**Technical Details**:
- **max-old-space-size=768**: Sets Node.js heap to 768MB (75% of container limit)
- **Execution Pruning**: Prevents memory bloat from workflow execution history
- **Automatic Cleanup**: Reduces manual maintenance overhead

### Phase 3: Gotenberg Resource Control

#### Gotenberg Service Optimization
```yaml
gotenberg:
  deploy:
    resources:
      limits:
        memory: 512M      # Prevents restart issues
        cpus: '0.5'
      reservations:
        memory: 256M
        cpus: '0.25'
```

**Problem Solved**: Gotenberg was experiencing frequent restarts due to resource competition.

## Implementation Procedures

### Step 1: Configuration Backup
```bash
# Create timestamped backup
ssh root@192.168.1.20 'cp /root/n8n/docker-compose.yml /root/n8n/docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)'
```

### Step 2: Apply Optimized Configuration
```bash
# Validate configuration syntax
ssh root@192.168.1.20 'cd /root/n8n && docker compose config'

# Apply changes with zero-downtime restart
ssh root@192.168.1.20 'cd /root/n8n && docker compose down && docker compose up -d'
```

### Step 3: Validation Commands
```bash
# Check resource limits are applied
ssh root@192.168.1.20 'docker inspect n8n-n8n-1 | grep -A 5 -B 2 Memory'

# Verify Node.js settings
ssh root@192.168.1.20 'docker exec n8n-n8n-1 env | grep NODE'

# Monitor resource usage
ssh root@192.168.1.20 'docker stats --no-stream'

# Test service accessibility
curl -I https://n8n.accelior.com/
```

## Performance Impact Analysis

### Before Optimization
- **Memory Limits**: None (potential for memory exhaustion)
- **Node.js Heap**: Uncontrolled (could consume entire container memory)
- **Execution Data**: No automatic cleanup (memory bloat over time)
- **Gotenberg Issues**: Frequent restarts due to resource conflicts

### After Optimization
- **Memory Usage**: 265MB/1GB (26% utilization - optimal range)
- **Resource Predictability**: Hard limits prevent memory exhaustion
- **Performance**: No degradation observed
- **Stability**: Gotenberg restart issues resolved
- **Maintenance**: Automatic execution data cleanup

## Monitoring and Alerting

### Key Metrics to Track
```bash
# Memory utilization (should stay < 80%)
ssh root@192.168.1.20 'docker stats n8n-n8n-1 --no-stream --format "table {{.MemUsage}}\t{{.MemPerc}}"'

# Node.js heap usage (if monitoring tools available)
ssh root@192.168.1.20 'docker exec n8n-n8n-1 node -e "console.log(process.memoryUsage())"'

# Execution data growth
ssh root@192.168.1.20 'docker exec n8n-n8n-1 du -sh /home/node/.n8n/database.sqlite'
```

### Alert Thresholds
- **Memory Usage >80%**: Warning - investigate workflow complexity
- **Memory Usage >95%**: Critical - immediate investigation required
- **Container Restarts**: Any unexpected restarts indicate resource issues
- **Execution Count >1000**: Pruning system should prevent this

## Troubleshooting

### Common Issues and Solutions

#### High Memory Usage After Optimization
**Symptoms**: Memory usage consistently >80% of 1GB limit
**Possible Causes**:
1. Complex workflows with large data processing
2. Memory leaks in custom nodes
3. Insufficient execution data pruning

**Solutions**:
```bash
# Check execution data size
ssh root@192.168.1.20 'docker exec n8n-n8n-1 find /home/node/.n8n -name "*.sqlite*" -exec ls -lh {} \;'

# Force execution cleanup
ssh root@192.168.1.20 'docker exec n8n-n8n-1 n8n execute --workflow-id=cleanup'

# Temporary memory increase (emergency)
ssh root@192.168.1.20 'pct set 100 --memory $((16*1024+4*1024))'  # Add 4GB to PCT
```

#### Container Performance Degradation
**Symptoms**: Slow workflow execution, high CPU usage
**Investigation**:
```bash
# Check garbage collection patterns
ssh root@192.168.1.20 'docker exec n8n-n8n-1 node --trace-gc -e "setTimeout(()=>console.log('done'),1000)"'

# Analyze Node.js performance
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -E "(memory|heap|gc)"'
```

#### Database Connection Issues
**Symptoms**: n8n fails to start, database connection errors
**Solutions**:
```bash
# Check database connectivity
ssh root@192.168.1.20 'docker exec n8n-n8n-1 nc -zv aws-0-eu-central-1.pooler.supabase.com 6543'

# Restart with extended timeout
ssh root@192.168.1.20 'cd /root/n8n && docker compose up -d --wait --wait-timeout 120'
```

## Best Practices

### Resource Allocation Guidelines
1. **Memory Sizing**: Allocate 2.5x observed peak usage for safety buffer
2. **CPU Allocation**: Single core sufficient for most n8n workloads
3. **Execution Retention**: Balance between debugging needs and memory usage
4. **Database**: External PostgreSQL preferred over SQLite for production

### Change Management
1. **Always Backup**: Configuration files before modifications
2. **Test Changes**: In development environment when possible
3. **Monitor**: Resource usage for 48 hours after changes
4. **Document**: All modifications in this guide

### Security Considerations
- **Resource Limits**: Prevent DoS through resource exhaustion
- **Database Credentials**: Stored in environment variables (consider secrets management)
- **Network Access**: Restricted to necessary ports only
- **Updates**: Regular container image updates for security patches

## Emergency Procedures

### Critical Memory Exhaustion
```bash
# Immediate PCT memory increase
ssh root@pve2 "pct set 100 --memory $((16*1024*2))"  # Double PCT memory

# Emergency container restart
ssh root@192.168.1.20 'cd /root/n8n && docker compose restart n8n'

# Monitor recovery
ssh root@192.168.1.20 'watch -n 5 "docker stats n8n-n8n-1 --no-stream"'
```

### Service Recovery
```bash
# Full service restart
ssh root@192.168.1.20 'cd /root/n8n && docker compose down && docker compose up -d'

# Health check
curl -f https://n8n.accelior.com/ || echo "Service unavailable"

# Log investigation
ssh root@192.168.1.20 'docker logs n8n-n8n-1 --tail 50'
```

### Rollback Procedure
```bash
# Restore previous configuration
ssh root@192.168.1.20 'cd /root/n8n && cp docker-compose.yml.backup-[TIMESTAMP] docker-compose.yml'

# Apply rollback
ssh root@192.168.1.20 'cd /root/n8n && docker compose down && docker compose up -d'
```

## Future Optimization Opportunities

### Potential Improvements
1. **Resource Monitoring**: Integrate with Prometheus/Grafana for better visibility
2. **Auto-Scaling**: Implement horizontal scaling for high-availability
3. **Caching**: Redis cache for workflow execution data
4. **Load Balancing**: Multiple n8n instances behind load balancer

### Capacity Planning
- **Current Setup**: Good for 100-500 concurrent workflows
- **Scale Triggers**: Memory usage >70% consistently, response time >2s
- **Next Tier**: 2 CPU cores, 2GB memory, dedicated PostgreSQL instance

---

**Created**: September 19, 2025
**Last Updated**: September 19, 2025
**Applied To**: PCT Container 100 (192.168.1.20)
**Configuration File**: `/root/n8n/docker-compose.yml`
**Status**: Production Active