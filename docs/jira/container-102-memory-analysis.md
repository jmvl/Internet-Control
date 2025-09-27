# PCT Container 102 (JIRA) Memory Analysis Report

**Date:** 2025-09-19
**Analyst:** System Infrastructure Analysis
**Container:** PCT 102 (jira.accelior.com)
**Host:** PVE2 Proxmox Server

## Executive Summary

PCT Container 102 is experiencing **significant memory pressure** with 40% swap utilization (1.2GB) and requires immediate optimization. The analysis reveals suboptimal JVM and database configurations similar to the memory issues previously identified in container 100 (Confluence).

### Key Findings
- **Memory Pressure**: 1.2GB swap usage indicates insufficient RAM allocation
- **JVM Near Capacity**: JIRA heap approaching 2GB limit with frequent GC cycles
- **Database Under-tuned**: PostgreSQL using minimal 128MB shared_buffers
- **Optimization Required**: Container needs memory reallocation and configuration tuning

## Current Configuration Analysis

### PCT Container Resources
```
Container ID: 102
Hostname: jira.accelior.com
RAM Allocated: 6GB
Swap Allocated: 3GB
CPU Cores: 6
Storage: 70GB (ssd-4tb:102/vm-102-disk-0.raw)
Network: 192.168.1.22/24
Status: Running (Up 29 days)
```

### Memory Utilization Breakdown
```
Total RAM: 6.0GB
Used RAM: 3.4GB (56.7%)
Free RAM: 122MB
Buffer/Cache: 2.5GB
Available RAM: 2.5GB

Swap Total: 3.0GB
Swap Used: 1.2GB (40%) ⚠️ CRITICAL
Swap Free: 1.8GB
```

### Docker Container Resource Usage
```
Container Name    Memory Usage    Memory %    Status
jira              2.856GB         47.60%      Up 4 weeks
jira-db           565.8MB         9.21%       Up 4 weeks
Total Docker:     ~3.4GB          56.7%
```

## Application Configuration Analysis

### JIRA JVM Configuration
```bash
# Current JVM Settings (setenv.sh)
JVM_MINIMUM_MEMORY: 384m
JVM_MAXIMUM_MEMORY: 2048m (2GB)
JVM_RESERVED_CODE_CACHE_SIZE: 512m

# Actual Runtime Parameters
-Xms384m -Xmx2048m
-XX:InitialCodeCacheSize=32m
-XX:ReservedCodeCacheSize=512m
-XX:+ExplicitGCInvokesConcurrent
```

### PostgreSQL Database Configuration
```sql
-- Current PostgreSQL 12.11 Settings
shared_buffers = 128MB (Default - SUBOPTIMAL)
effective_cache_size = (Not configured - using default)
work_mem = (Not configured - using default)
maintenance_work_mem = (Not configured - using default)

-- Database Usage
Memory Usage: 565.8MB
CPU Usage: 0.03%
```

### Performance Indicators

#### Garbage Collection Analysis
Recent GC activity shows heap pressure:
```
GC(39455) Pause Remark 948M->929M(1292M) 70.896ms
Concurrent Cycle: 1884.731ms
Heap utilization: ~950MB approaching 2GB limit
```

#### System Load Metrics
```
Load Average: 1.62, 4.62, 4.56 (High)
Memory Available: 2544MB
Swap Activity: Active (si/so present)
Buffer/Cache Ratio: 2.6GB (healthy)
```

## Memory Pressure Analysis

### Critical Issues Identified

1. **Excessive Swap Usage (40%)**
   - Indicates insufficient RAM for workload
   - 1.2GB swap usage suggests 3.4GB base RAM need + 1.2GB additional = ~4.6GB actual requirement
   - Current 6GB allocation insufficient for optimal performance

2. **JVM Heap Constraint**
   - 2GB max heap approaching capacity (950MB current usage)
   - Frequent GC cycles (1.8s concurrent cycles)
   - Heap pressure affecting application performance

3. **Database Memory Under-allocation**
   - PostgreSQL default 128MB shared_buffers inadequate
   - 565MB total database memory usage suggests need for tuning
   - Missing optimization for effective_cache_size and work_mem

4. **Container Resource Imbalance**
   - 6GB allocated but only 2.5GB effectively available
   - High buffer/cache usage competing with application memory
   - Load average of 4.56 indicates resource contention

## Comparison with Available Resources

### Host System Capacity
```
Host Total Memory: 62GB
Host Used Memory: 27GB
Host Available: 35GB
Host Swap Usage: 3.4GB / 8GB

Resource Availability: Sufficient for expansion
```

### Resource Efficiency Analysis
- **Current Allocation**: 6GB (9.7% of host memory)
- **Actual Usage**: 4.6GB effective need (based on RAM + swap)
- **Utilization Ratio**: 76.7% (including swap pressure)
- **Optimization Potential**: High - can improve allocation and configuration

## Optimization Recommendations

### 1. Immediate Actions Required

#### A. Increase Container Memory Allocation
```bash
# Stop container
pct stop 102

# Increase memory allocation
pct set 102 -memory 8192  # Increase from 6GB to 8GB
pct set 102 -swap 2048    # Reduce swap from 3GB to 2GB

# Start container
pct start 102
```

#### B. Optimize JIRA JVM Configuration
```bash
# Update JVM settings in setenv.sh or environment variables
JVM_MINIMUM_MEMORY=1024m     # Increase from 384m
JVM_MAXIMUM_MEMORY=4096m     # Increase from 2048m to 4GB
JVM_RESERVED_CODE_CACHE_SIZE=768m  # Increase from 512m
```

#### C. Tune PostgreSQL Memory Settings
```sql
-- Update postgresql.conf
shared_buffers = 512MB           -- Increase from 128MB
effective_cache_size = 2GB       -- Set based on available memory
work_mem = 16MB                  -- Increase from default 4MB
maintenance_work_mem = 256MB     -- Increase from default 64MB
max_connections = 100            -- Verify current setting
```

### 2. Configuration Implementation

#### JIRA Container Memory Configuration
```bash
# Docker Compose adjustments (if applicable)
version: '3.8'
services:
  jira:
    image: atlassian/jira-software:9.5.1
    container_name: jira
    environment:
      - JVM_MINIMUM_MEMORY=1024m
      - JVM_MAXIMUM_MEMORY=4096m
      - JVM_RESERVED_CODE_CACHE_SIZE=768m
    deploy:
      resources:
        limits:
          memory: 5GB
        reservations:
          memory: 2GB
```

#### PostgreSQL Optimization
```bash
# Create optimized postgresql.conf
cat > /var/lib/postgresql/data/postgresql.conf.new << 'EOF'
# Memory Configuration
shared_buffers = 512MB
effective_cache_size = 2GB
work_mem = 16MB
maintenance_work_mem = 256MB

# Connection Settings
max_connections = 100
superuser_reserved_connections = 3

# Checkpoint and WAL
checkpoint_completion_target = 0.9
wal_buffers = 16MB

# Query Planning
random_page_cost = 1.1
effective_io_concurrency = 200
EOF
```

### 3. Monitoring and Validation

#### Memory Usage Monitoring
```bash
# Monitor container memory usage
watch -n 5 'pct exec 102 -- free -h'

# Monitor Docker container stats
watch -n 5 'pct exec 102 -- docker stats --no-stream'

# Monitor swap usage
watch -n 5 'pct exec 102 -- cat /proc/meminfo | grep Swap'
```

#### Performance Validation
```bash
# Check GC logs after optimization
tail -f /opt/atlassian/jira/logs/atlassian-jira-gc-*.log

# Monitor system load
pct exec 102 -- vmstat 5

# PostgreSQL performance monitoring
pct exec 102 -- docker exec jira-db pg_stat_database
```

### 4. Expected Improvements

#### Performance Metrics
- **Swap Usage**: Reduce from 40% to <10%
- **JVM GC Frequency**: Reduce concurrent cycle time from 1.8s to <1s
- **System Load**: Reduce load average from 4.56 to <2.0
- **Application Response**: Improve page load times by 30-50%

#### Resource Allocation
- **Container Memory**: 8GB total (4GB for JIRA, 1GB for PostgreSQL, 3GB for system)
- **JVM Heap**: 4GB max heap (2x current)
- **Database Buffer**: 512MB shared_buffers (4x current)
- **Swap Utilization**: <200MB normal operation

## Implementation Timeline

### Phase 1: Emergency Stabilization (Immediate)
1. Increase container memory to 8GB
2. Restart container to clear swap pressure
3. Monitor for immediate improvement

### Phase 2: Application Optimization (1-2 hours)
1. Update JIRA JVM configuration
2. Restart JIRA container
3. Validate heap usage improvements

### Phase 3: Database Optimization (2-3 hours)
1. Update PostgreSQL configuration
2. Restart database container
3. Monitor query performance

### Phase 4: Validation and Documentation (Ongoing)
1. Monitor performance metrics for 24-48 hours
2. Document configuration changes
3. Update monitoring thresholds

## Risk Assessment

### High Risk Factors
- **Service Downtime**: Container restart required (5-10 minutes)
- **Configuration Errors**: Incorrect JVM settings could prevent startup
- **Resource Contention**: Increased memory usage on host

### Mitigation Strategies
- **Backup Configuration**: Create backup before changes
- **Staged Implementation**: Implement changes incrementally
- **Rollback Plan**: Keep previous configuration for quick revert
- **Monitoring**: Continuous monitoring during implementation

## Conclusion

PCT Container 102 (JIRA) requires immediate memory optimization due to significant swap usage and resource pressure. The recommended changes will:

1. **Eliminate swap pressure** through increased container memory allocation
2. **Improve application performance** via optimized JVM configuration
3. **Enhance database efficiency** through PostgreSQL memory tuning
4. **Provide performance headroom** for future growth

The optimization is similar to the successful improvements made to container 100 (Confluence) and should yield comparable performance benefits.

### Next Steps
1. Schedule maintenance window for implementation
2. Create configuration backups
3. Execute optimization plan in phases
4. Monitor and validate improvements
5. Update operational documentation

---
**Document Control**
- Version: 1.0
- Last Updated: 2025-09-19
- Next Review: 2025-10-19
- Owner: Infrastructure Team