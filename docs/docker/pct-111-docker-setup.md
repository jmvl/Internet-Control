# PCT Container 111 - Docker Infrastructure Documentation

## Overview
This document details the comprehensive Docker infrastructure setup running on PCT container 111 (docker debian) on Proxmox VE. This container serves as the primary Docker host for development, analytics, monitoring, and infrastructure services.

## Infrastructure Architecture

### Host Environment
- **Primary Host**: Proxmox VE (pve2) - 192.168.1.10
- **Container Type**: LXC Container (VMID: 111)
- **Container Name**: docker-debian
- **Description**: Docker running platform with Portainer, Redis/ntopng, n8n, Supabase, and network analysis tools

### Container Configuration
- **Status**: Running
- **Host IP**: 192.168.1.20
- **Resources**: 10 cores, 20 GB RAM (20,480 MB), 110GB storage, 4GB swap
- **Features**: nesting=1 (required for Docker)
- **OS Type**: Debian
- **Auto-start**: Enabled (onboot: 1)
- **Last Optimization**: September 19, 2025 - Critical memory optimization performed

### Network Configuration
- **Interface**: eth0 (veth)
- **Bridge**: vmbr0
- **IP Address**: 192.168.1.20/24
- **Gateway**: 192.168.1.3
- **MAC Address**: BC:24:11:9D:3B:6C

### Storage Configuration
- **Root Filesystem**: local-lvm:vm-111-disk-0 (110GB)
- **Mount Point**: /root/bak → /mnt/bak (backup storage)

## Docker Services Architecture

### Service Categories

#### 1. Supabase Development Stack (Primary)
**Container Prefix**: `supabase-*`
- **Database**: supabase/postgres:15.8.1.060
- **API Gateway**: Kong (custom build)
- **REST API**: postgrest/postgrest:v12.2.12
- **Authentication**: supabase/gotrue:v2.176.1
- **Storage API**: supabase/storage-api:v1.24.7
- **Realtime**: supabase/realtime:v2.34.47 (currently unhealthy)
- **Meta API**: supabase/postgres-meta:v0.89.3
- **Studio UI**: supabase/studio:2025.06.30-sha-6f5982d
- **Edge Functions**: supabase/edge-runtime:v1.67.4
- **Connection Pooler**: supabase/supavisor:2.5.6
- **Analytics**: supabase/logflare:1.14.2
- **Image Proxy**: darthsim/imgproxy:v3.8.0
- **Vector Logging**: timberio/vector:0.28.1-alpine

#### 2. Supabase Development Stack (Secondary - Archon)
**Container Prefix**: `archon-supabase-*`
- **Database**: supabase/postgres:15.8.1.060
- **Analytics**: supabase/logflare:1.14.2
- **Image Proxy**: darthsim/imgproxy:v3.8.0
- **Vector Logging**: timberio/vector:0.28.1-alpine

#### 3. Development Tools
- **n8n**: docker.n8n.io/n8nio/n8n:latest (automation platform)
- **Gotenberg**: gotenberg/gotenberg:8 (document conversion)
- **Portainer**: portainer/portainer-ce:lts (Docker management UI)
- **Portainer Agent**: portainer/agent:latest

#### 4. Database Services
- **PostgreSQL (Casino)**: postgres:15-alpine
- **ClickHouse**: clickhouse/clickhouse-server:latest
- **Redis**: redis:6.2-alpine (for ntopng)

#### 5. Monitoring & Analytics
- **Netdata**: netdata/netdata:stable (system monitoring)
- **ntopng**: ntop/ntopng:latest (network monitoring)
- **netflow2ng**: synfinatic/netflow2ng (network flow analysis)
- **pgAdmin**: dpage/pgadmin4:latest (PostgreSQL administration)

#### 6. Infrastructure Services
- **Pi-hole**: pihole/pihole:latest (DNS filtering and ad blocking)

## Service Access Information

### Web Interfaces
- **Portainer**: http://192.168.1.20:9000 (Docker management)
- **n8n**: http://n8n.accelior.com (automation workflows)
- **Supabase Studio**: http://192.168.1.20:3000 (database management)
- **ntopng**: http://192.168.1.20:3001 (network monitoring)
- **Netdata**: http://192.168.1.20:19999 (system monitoring)
- **Pi-hole**: http://192.168.1.20/admin (DNS management)
- **pgAdmin**: http://192.168.1.20:5050 (PostgreSQL management)

### Database Connections
- **Supabase PostgreSQL**: 192.168.1.20:54322
- **Casino PostgreSQL**: 192.168.1.20:5432
- **ClickHouse**: 192.168.1.20:8123 (HTTP), 192.168.1.20:9000 (native)
- **Redis**: 192.168.1.20:6379

### API Endpoints
- **Supabase API**: http://192.168.1.20:8000
- **Supabase Auth**: http://192.168.1.20:9999
- **PostgREST**: http://192.168.1.20:3000

## Performance Metrics

### Current Resource Usage
- **Total Container Memory**: 4.1 GiB / 20 GiB (20.5% utilization)
- **Available Memory**: 15 GiB free
- **Swap Usage**: 0 GiB / 4 GiB (0% - excellent)
- **Buffer/Cache**: 2.7 GiB
- **CPU Cores**: 10 cores available

### Memory Distribution by Service Category
- **Supabase Stack**: ~1.5GB (primary memory consumer)
- **ClickHouse**: ~800MB (database analytics)
- **n8n**: ~400MB (workflow automation)
- **Monitoring Stack**: ~300MB (Netdata, ntopng)
- **Other Services**: ~1GB (miscellaneous containers)

### Memory Optimization History

#### September 19, 2025 - Critical Memory Crisis Resolution
**Issue**: Container experiencing severe memory pressure with critical swap usage
- **Original Configuration**: 16GB RAM, 512MB swap
- **Original Usage**: 99.8% swap utilization (511MB/512MB critical)
- **Performance Impact**: System instability, service crashes, host swap pressure

**Root Cause Analysis**:
- **Service Overload**: 28+ Docker containers running simultaneously
- **Memory Intensive Stack**: Multiple Supabase instances, ClickHouse, analytics services
- **Insufficient Swap**: Only 512MB swap for 16GB memory allocation
- **Host Impact**: Contributing to 2.1GB host swap usage

**Optimization Actions Performed**:
1. **PCT Container Resource Increase**:
   - Memory: 16,416MB → 20,480MB (+4GB)
   - Swap: 512MB → 4,096MB (+3.5GB, 8x increase)

2. **Service Analysis**:
   - Identified memory-intensive services (Logflare, ClickHouse, Supabase)
   - Confirmed all services are actively used and necessary
   - No service consolidation required

**Results Achieved**:
- **Memory Utilization**: Reduced from critical to 20.5% (healthy level)
- **Swap Elimination**: Reduced from 99.8% to 0% (complete resolution)
- **Host Impact**: Reduced host swap usage from 2.1GB to 1.6GB
- **Service Stability**: All 28+ containers running stably
- **Performance**: Eliminated memory pressure and service interruptions
- **Headroom**: 15GB available memory for peak usage and expansion

## Service Management

### SSH Access
```bash
# Access Proxmox host
ssh root@pve2

# Access Docker LXC container
pct exec 111

# Direct container access
ssh root@192.168.1.20
```

### Container Management
```bash
# Container control (on pve2)
pct list                    # List all LXC containers
pct config 111             # View Docker container config
pct exec 111               # Execute commands in LXC container
pct stop 111               # Stop container
pct start 111              # Start container

# Resource monitoring
pct exec 111 -- free -h    # Check memory usage
pct exec 111 -- docker stats --no-stream  # Docker resource usage
```

### Docker Service Management
```bash
# Docker overview
docker ps                  # List running containers
docker ps -a               # List all containers (including stopped)
docker images              # List available images
docker system df           # Docker disk usage

# Container operations
docker logs <container_name>    # View container logs
docker restart <container_name> # Restart specific service
docker stop <container_name>    # Stop specific service
docker start <container_name>   # Start specific service

# Bulk operations
docker restart $(docker ps -q)  # Restart all running containers
docker stop $(docker ps -q)     # Stop all running containers
```

### Service-Specific Management

#### Supabase Stack
```bash
# Navigate to Supabase directory
cd /root/supabase

# View Supabase services
docker compose ps

# Restart Supabase stack
docker compose restart

# View logs
docker compose logs -f supabase-db
docker compose logs -f supabase-auth
```

#### n8n Automation
```bash
# n8n container management
docker logs n8n-n8n-1 -f
docker restart n8n-n8n-1

# Access n8n CLI (if needed)
docker exec -it n8n-n8n-1 n8n --help
```

#### Monitoring Services
```bash
# Netdata monitoring
docker logs netdata
curl http://192.168.1.20:19999/api/v1/info

# ntopng network monitoring
docker logs ntopng
docker restart ntopng ntopng-redis
```

## Service Configuration

### Environment Variables
Key environment configurations for major services:

#### Supabase Configuration
```bash
# Database configuration
POSTGRES_PASSWORD=<configured>
POSTGRES_DB=postgres

# API Gateway (Kong)
KONG_HTTP_PORT=8000
KONG_HTTPS_PORT=8443

# Authentication (GoTrue)
GOTRUE_SITE_URL=http://192.168.1.20:3000
GOTRUE_API_HOST=0.0.0.0
GOTRUE_API_PORT=9999
```

#### n8n Configuration
```bash
# n8n workflow automation
N8N_HOST=n8n.accelior.com
N8N_PORT=5678
N8N_PROTOCOL=https
```

### Volume Mounts
Critical data persistence locations:

#### Supabase Data
- **Database**: Docker volume `supabase_db_data`
- **Storage**: Docker volume `supabase_storage_data`
- **Configuration**: Local bind mounts in `/root/supabase/`

#### Application Data
- **n8n Workflows**: Docker volume `n8n_data`
- **Portainer Config**: Docker volume `portainer_data`
- **Pi-hole Config**: Docker volumes `pihole_etc`, `pihole_dnsmasq`

## Networking Architecture

### Docker Networks
- **Default Bridge**: Most services use Docker's default bridge network
- **Custom Networks**: Some services may use compose-defined networks
- **Host Networking**: Some monitoring services use host networking

### Port Mapping Strategy
- **Web Services**: 3000-3999 range
- **APIs**: 8000-8999 range
- **Databases**: 5000-5999 range
- **Monitoring**: 9000+ range

### External Access
Services accessible from the network:
- **Development tools** (Portainer, n8n, Supabase Studio)
- **Monitoring services** (Netdata, ntopng)
- **Infrastructure services** (Pi-hole)

## Security Considerations

### Container Security
- **LXC Nesting**: Enabled for Docker support (required)
- **Privilege Escalation**: Containers run with appropriate privileges
- **Network Isolation**: Services isolated within Docker networks
- **Resource Limits**: Memory and CPU limits enforced by LXC

### Service Security
- **Database Access**: PostgreSQL services isolated to container network
- **API Authentication**: Supabase handles authentication and authorization
- **Web Interface Access**: Admin interfaces protected by network segmentation
- **Secrets Management**: Environment variables and Docker secrets

### Network Security
- **Internal Network**: 192.168.1.0/24 private network
- **Firewall Rules**: OPNsense provides network-level filtering
- **Service Discovery**: Internal DNS resolution within Docker networks
- **External Access**: Controlled through reverse proxy and firewall rules

## Backup Strategy

### Container-Level Backups
- **LXC Snapshots**: Proxmox container snapshots for full system backup
- **Configuration Backup**: `/root/bak` mount point for configuration storage

### Service-Level Backups
- **Database Backups**: PostgreSQL dumps for Supabase and application databases
- **Application Data**: Docker volume backups for persistent data
- **Configuration Files**: Docker compose files and environment configurations

### Backup Procedures
```bash
# LXC container snapshot (on pve2)
pct snapshot 111 "backup-$(date +%Y%m%d-%H%M%S)" --description "Manual backup"

# PostgreSQL backup
docker exec supabase-db pg_dumpall -U postgres > /mnt/bak/supabase-backup-$(date +%Y%m%d).sql

# Docker volume backup
docker run --rm -v supabase_db_data:/data -v /mnt/bak:/backup alpine tar czf /backup/supabase-volumes-$(date +%Y%m%d).tar.gz /data
```

## Maintenance Schedule

### Regular Tasks
- **Daily**: Monitor container resource usage and service health
- **Weekly**: Review service logs and performance metrics
- **Monthly**: Update Docker images and perform security patches
- **Quarterly**: Full backup verification and disaster recovery testing

### Service-Specific Maintenance
- **Supabase**: Database maintenance, log rotation, backup verification
- **ClickHouse**: Query performance analysis, data retention policies
- **n8n**: Workflow optimization, credential rotation
- **Monitoring**: Alert threshold tuning, dashboard updates

## Troubleshooting

### Common Issues

#### High Memory Usage
**Symptoms**: Container memory usage >80% or swap usage
**Diagnosis**:
```bash
# Check container memory
pct exec 111 -- free -h
# Check Docker container usage
pct exec 111 -- docker stats --no-stream
# Identify memory-intensive containers
pct exec 111 -- docker stats --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" --no-stream | sort -k3 -hr
```

#### Service Startup Issues
**Symptoms**: Containers failing to start or staying in restart loop
**Diagnosis**:
```bash
# Check container status
docker ps -a
# Check container logs
docker logs <container_name> --tail 50
# Check resource constraints
docker inspect <container_name> | grep -A 10 "Resources"
```

#### Network Connectivity Issues
**Symptoms**: Services unable to communicate or external access failing
**Diagnosis**:
```bash
# Check Docker networks
docker network ls
docker network inspect bridge
# Test container connectivity
docker exec <container_name> ping <target_service>
# Check port bindings
docker port <container_name>
```

### Emergency Recovery Procedures

#### Memory Crisis Response
```bash
# Immediate memory relief
docker stop $(docker ps -q --filter "label=priority=low")
# Check memory after stopping non-critical services
free -h
# Restart only essential services
docker start supabase-db supabase-kong n8n-n8n-1
```

#### Service Recovery
```bash
# Stop all services
docker stop $(docker ps -q)
# Start services in dependency order
docker start supabase-db
sleep 30
docker start supabase-kong supabase-auth supabase-rest
sleep 30
docker start n8n-n8n-1 portainer
```

#### Container Recovery
```bash
# If container becomes unresponsive
pct stop 111
sleep 10
pct start 111
# Wait for services to initialize
sleep 60
# Verify critical services
docker ps | grep -E "(supabase|n8n|portainer)"
```

## Performance Optimization

### Resource Allocation Guidelines
- **Memory**: Maintain <70% utilization for optimal performance
- **CPU**: Monitor load average, should stay below core count
- **Storage**: Keep container storage <80% full
- **Swap**: Should remain at 0% under normal conditions

### Service Optimization

#### Database Optimization
- **PostgreSQL**: Regular VACUUM and ANALYZE operations
- **ClickHouse**: Query optimization and partition management
- **Redis**: Memory usage monitoring and key expiration policies

#### Application Optimization
- **n8n**: Workflow execution monitoring and optimization
- **Supabase**: API performance monitoring and query optimization
- **Analytics**: Log retention policies and data archival

### Monitoring and Alerting
- **Resource Usage**: Set alerts for memory >80%, CPU >80%
- **Service Health**: Monitor container restart counts and health checks
- **Performance Metrics**: Track response times and error rates
- **Capacity Planning**: Monitor growth trends for scaling decisions

## Known Issues

### Current Status
1. **Realtime Service**: supabase-realtime currently showing as unhealthy ⚠️
2. **Gotenberg Service**: Experiencing restart issues (Restarting status) ⚠️
3. **Memory Usage**: ✅ **RESOLVED** - Optimized to 20.5% utilization (was 99.8% swap)

### Monitoring Alerts
- **Container Memory**: Alert if usage >16GB (80% of 20GB)
- **Swap Usage**: Alert if any swap is used (should remain at 0%)
- **Service Health**: Alert on container restart loops or health check failures
- **Host Impact**: Monitor contribution to overall host resource usage

---
*Created: September 19, 2025*
*Based on PCT Container 111 comprehensive analysis and memory optimization*
*Last Updated: September 19, 2025*