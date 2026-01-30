# n8n Service Documentation

## Overview

This directory contains comprehensive documentation for the n8n workflow automation platform deployed across two environments:

| Environment | URL | Host | n8n Version |
|-------------|-----|------|-------------|
| **Staging** | https://n8n.accelior.com | 192.168.1.20 (docker-host-pct111) | **2.4.6** |
| **Production** | https://n8n.acmea.tech | 135.181.154.169 (Hetzner VPS) | **2.4.6** |

Both instances use self-hosted PostgreSQL 16 databases and have been optimized for memory efficiency and production stability.

## Service Status

- **Staging Status**: ✅ **Active** (Upgraded January 28, 2026)
- **Production Status**: ✅ **Active** (Upgraded January 28, 2026)
- **PostgreSQL Version**: 16-alpine
- **Last Migration**: January 28, 2026 (n8n 1.x/2.1.4 → 2.4.6)

## Quick Reference

### Staging Environment (n8n.accelior.com)
```bash
# Check service status
ssh root@192.168.1.20 'cd /home/n8n_compose && docker compose ps'

# View resource usage
ssh root@192.168.1.20 'docker stats n8n-n8n-1 n8n-postgres --no-stream'

# Restart services
ssh root@192.168.1.20 'cd /home/n8n_compose && docker compose restart'

# View logs
ssh root@192.168.1.20 'docker logs n8n-n8n-1 -f'
```

### Production Environment (n8n.acmea.tech)
```bash
# Check service status
ssh root@135.181.154.169 'docker ps --filter "name=n8n"'

# View resource usage
ssh root@135.181.154.169 'docker stats n8n-n8n-1 n8n-postgres --no-stream'

# View logs
ssh root@135.181.154.169 'docker logs n8n-n8n-1 -f'
```

### Health Checks
```bash
# Staging accessibility
curl -s https://n8n.accelior.com/healthz

# Production accessibility
curl -s https://n8n.acmea.tech/healthz

# Database connectivity (staging)
ssh root@192.168.1.20 'docker exec n8n-postgres pg_isready -U n8n -d n8n'

# Database connectivity (production)
ssh root@135.181.154.169 'docker exec n8n-postgres pg_isready -U n8n -d n8n'
```

## Documentation Structure

### 📖 [n8n 2.4.6 Upgrade (January 28, 2026)](./n8n-2.4.6-upgrade-2026-01-28.md)
**Purpose**: Complete upgrade documentation from 1.x/2.1.x to 2.4.6
**Use Cases**:
- Understanding upgrade procedures and breaking changes
- Rollback procedures if needed
- Migration reference for future upgrades

### 📖 [Container Optimization Guide](./container-optimization-guide.md)
**Purpose**: Comprehensive memory optimization implementation
**Use Cases**:
- Understanding applied performance optimizations
- Implementing similar optimizations on other services
- Troubleshooting memory-related issues
- Capacity planning and resource management

### 📖 [Deployment Reference](./deployment-reference.md)
**Purpose**: Complete deployment configuration and management
**Use Cases**:
- Service deployment and configuration
- Environment variable reference
- Network and security configuration
- Backup and recovery procedures

### 📖 [Troubleshooting Guide](./troubleshooting.md)
**Purpose**: Diagnostic procedures and issue resolution
**Use Cases**:
- Resolving service issues
- Performance diagnostics
- Emergency recovery procedures
- Monitoring and alerting setup

### 📖 [Database Migration (2025-11-26)](./n8n-supabase-to-local-postgres-migration-2025-11-26.md)
**Purpose**: Migration from Supabase to local PostgreSQL
**Use Cases**:
- Understanding current database architecture
- Database backup and restore procedures
- Rollback to Supabase if needed
- Database management commands

## Current Configuration Highlights

### Resource Optimization (Applied 2025-09-19)
- **Memory Limit**: 1GB (current usage: ~265MB)
- **CPU Limit**: 1.0 core
- **Node.js Heap**: 768MB max (`--max-old-space-size=768`)
- **Execution Retention**: 168 hours with automatic pruning
- **Gotenberg Memory**: 512MB (resolved restart issues)

### Key Features
- **Local Database**: Self-hosted PostgreSQL 16 (migrated from Supabase 2025-11-26)
- **Community Packages**: Enabled for AI tool usage
- **Automatic Cleanup**: Execution data pruning enabled
- **Production Mode**: Optimized Node.js environment
- **PDF Generation**: Integrated Gotenberg service

## Performance Metrics

### Resource Utilization
| Metric | Current | Limit | Utilization |
|--------|---------|--------|-------------|
| Memory | 265MB | 1GB | 26% |
| CPU | <1% | 100% | Minimal |
| Storage | Variable | Host-dependent | Monitor |

### Service Specifications
- **Startup Time**: ~30 seconds
- **Response Time**: <500ms typical
- **Concurrent Workflows**: 100-500 supported
- **Database Latency**: <1ms (local PostgreSQL)

## Monitoring and Maintenance

### Regular Checks (Recommended)
- **Daily**: Service health and resource usage
- **Weekly**: Log analysis and error patterns
- **Monthly**: Performance review and optimization opportunities
- **Quarterly**: Backup validation and disaster recovery testing

### Automated Monitoring
```bash
# Setup monitoring script (from troubleshooting guide)
chmod +x /root/scripts/n8n-monitor.sh
echo "*/15 * * * * /root/scripts/n8n-monitor.sh" | crontab -
```

### Alert Thresholds
- **Memory >80%**: Warning level
- **Memory >95%**: Critical intervention required
- **Service Down**: Immediate action required
- **Database Disconnection**: Check external dependencies

## Integration Points

### Related Services
- **PostgreSQL**: Local database container (n8n-postgres)
- **Reverse Proxy**: HTTPS termination and routing
- **Pi-hole**: DNS resolution and filtering
- **Backup System**: Proxmox-based backup strategy

### Network Dependencies
- **Inbound**: Web interface (port 5678)
- **Internal**: PostgreSQL database (port 5432, container network)
- **Internal**: Gotenberg PDF service communication

## Security Considerations

### Access Control
- **Web Interface**: n8n built-in authentication
- **API Access**: API key authentication
- **Database**: Local container network (isolated)
- **Network**: Firewall rules and reverse proxy

### Data Protection
- **Encryption**: Sensitive data encrypted via `N8N_ENCRYPTION_KEY`
- **Backup**: Configuration and data backup procedures
- **Audit**: Workflow execution logging and monitoring

## Development and Testing

### Development Environment
- **Location**: Can be created at `/root/n8n-dev`
- **Port**: 5679 (to avoid conflicts with production)
- **Database**: Shared with production (use with caution)

### Testing Procedures
- **Configuration Validation**: `docker compose config`
- **Health Checks**: Automated via monitoring scripts
- **Performance Testing**: Load testing via external tools

## Support and Escalation

### Self-Service Resources
1. **Troubleshooting Guide**: Common issues and solutions
2. **Container Logs**: Real-time diagnostics
3. **Resource Monitoring**: Performance metrics
4. **Configuration Backup**: Rollback capabilities

### Escalation Path
1. **Level 1**: Restart services using documented procedures
2. **Level 2**: Apply troubleshooting guide procedures
3. **Level 3**: Restore from backup or emergency procedures
4. **Level 4**: Infrastructure team consultation

## Change Management

### Configuration Changes
1. **Backup Current**: Always create timestamped backup
2. **Validate Syntax**: Use `docker compose config`
3. **Apply Changes**: Use documented restart procedures
4. **Monitor**: 48-hour observation period
5. **Document**: Update this documentation

### Update Procedures
```bash
# Update n8n container image
ssh root@pve2 'pct exec 111 -- docker compose -f /home/n8n_compose/docker-compose.yml pull'
ssh root@pve2 'pct exec 111 -- docker compose -f /home/n8n_compose/docker-compose.yml up -d'

# Verify update
ssh root@pve2 'pct exec 111 -- docker logs n8n-n8n-1 --tail 20'
```

## Related Documentation

### Infrastructure Guides
- **PCT Memory Optimization**: `/docs/confluence/pct-memory-optimization-guide.md`
- **Docker Management**: `/docs/docker/`
- **Proxmox Backup**: `/docs/proxmox/backup-procedures.md`

### Network Architecture
- **Infrastructure Overview**: `/docs/infrastructure.md`
- **Network Architecture**: `/docs/architecture.md`
- **Security Framework**: `/docs/security/`

---

**Documentation Status**: ✅ Complete
**Last Review**: January 28, 2026
**Next Review**: As needed for future n8n versions
**Maintainer**: Infrastructure Team
**Version**: 2.1.0