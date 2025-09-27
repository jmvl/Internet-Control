# n8n Deployment Reference

## Service Overview

n8n is a workflow automation platform running as a Docker container on PCT Container 100 (192.168.1.20) with external PostgreSQL database connectivity to Supabase.

### Architecture
```
Internet → [Reverse Proxy] → PCT Container 100 (192.168.1.20:5678) → [n8n] → [Supabase PostgreSQL]
                                            ↓
                                      [Gotenberg PDF Service]
```

## Current Deployment Configuration

### Docker Compose Configuration
**Location**: `/root/n8n/docker-compose.yml`

```yaml
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    restart: always
    ports:
      - 5678:5678
    environment:
      # Core Configuration
      - N8N_ENCRYPTION_KEY=rqWlh/0WNeDu6sbKMEMbvm3onF7D7gc6
      - WEBHOOK_URL=https://n8n.accelior.com/
      - N8N_HOST=n8n.accelior.com
      - N8N_PORT=5678
      - N8N_PROTOCOL=https

      # Database Configuration
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=aws-0-eu-central-1.pooler.supabase.com
      - DB_POSTGRESDB_PORT=6543
      - DB_POSTGRESDB_DATABASE=postgres
      - DB_POSTGRESDB_USER=postgres.bbgyrvkxejtrnttoijlt
      - DB_POSTGRESDB_PASSWORD=qdjCUK1DI1x5umDG

      # Feature Flags
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true

      # System Configuration
      - GENERIC_TIMEZONE=Europe/Berlin
      - NODE_ENV=production

      # Memory Optimization (Applied 2025-09-19)
      - NODE_OPTIONS=--max-old-space-size=768
      - N8N_EXECUTIONS_DATA_MAX_AGE=168
      - N8N_EXECUTIONS_DATA_PRUNE=true
      - N8N_EXECUTIONS_DATA_PRUNE_MAX_COUNT=1000

    volumes:
      - n8n_user_data:/home/node/.n8n
    depends_on:
      - gotenberg

    # Resource Controls (Applied 2025-09-19)
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'
        reservations:
          memory: 512M
          cpus: '0.5'

  gotenberg:
    image: gotenberg/gotenberg:8
    restart: always
    command:
      - gotenberg
      - --chromium-disable-web-security
      - --chromium-allow-list=file:///**
      - --chromium-disable-routes
      - --chromium-ignore-certificate-errors-spki-list=true
      - --chromium-ignore-certificate-errors=true
      - --chromium-ignore-ssl-errors=true

    # Resource Controls (Applied 2025-09-19)
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'

volumes:
  n8n_user_data:
```

### Environment Variables Reference

#### Core Settings
| Variable | Value | Purpose |
|----------|-------|---------|
| `N8N_ENCRYPTION_KEY` | `rqWlh/0WNeDu6sbKMEMbvm3onF7D7gc6` | Encrypts sensitive data |
| `WEBHOOK_URL` | `https://n8n.accelior.com/` | Public webhook endpoint |
| `N8N_HOST` | `n8n.accelior.com` | Public hostname |
| `N8N_PROTOCOL` | `https` | Connection protocol |

#### Database Settings
| Variable | Value | Purpose |
|----------|-------|---------|
| `DB_TYPE` | `postgresdb` | Database type |
| `DB_POSTGRESDB_HOST` | `aws-0-eu-central-1.pooler.supabase.com` | Database host |
| `DB_POSTGRESDB_PORT` | `6543` | Database port |
| `DB_POSTGRESDB_DATABASE` | `postgres` | Database name |

#### Performance Settings
| Variable | Value | Purpose |
|----------|-------|---------|
| `NODE_OPTIONS` | `--max-old-space-size=768` | Node.js heap limit (768MB) |
| `N8N_EXECUTIONS_DATA_MAX_AGE` | `168` | Execution retention (hours) |
| `N8N_EXECUTIONS_DATA_PRUNE` | `true` | Enable auto-cleanup |
| `N8N_EXECUTIONS_DATA_PRUNE_MAX_COUNT` | `1000` | Max stored executions |

## Service Management

### Basic Operations
```bash
# Navigate to deployment directory
ssh root@192.168.1.20 'cd /root/n8n'

# Start services
ssh root@192.168.1.20 'cd /root/n8n && docker compose up -d'

# Stop services
ssh root@192.168.1.20 'cd /root/n8n && docker compose down'

# Restart services
ssh root@192.168.1.20 'cd /root/n8n && docker compose restart'

# View logs
ssh root@192.168.1.20 'docker logs n8n-n8n-1 -f'

# Check service status
ssh root@192.168.1.20 'docker ps | grep n8n'
```

### Configuration Updates
```bash
# Create backup before changes
ssh root@192.168.1.20 'cp /root/n8n/docker-compose.yml /root/n8n/docker-compose.yml.backup-$(date +%Y%m%d-%H%M%S)'

# Validate configuration
ssh root@192.168.1.20 'cd /root/n8n && docker compose config'

# Apply changes
ssh root@192.168.1.20 'cd /root/n8n && docker compose down && docker compose up -d'
```

### Data Management
```bash
# Backup n8n data volume
ssh root@192.168.1.20 'docker run --rm -v n8n_n8n_user_data:/data -v /root/backups:/backup alpine tar czf /backup/n8n-data-$(date +%Y%m%d).tar.gz -C /data .'

# Restore n8n data volume
ssh root@192.168.1.20 'docker run --rm -v n8n_n8n_user_data:/data -v /root/backups:/backup alpine tar xzf /backup/n8n-data-[DATE].tar.gz -C /data'

# Check data volume size
ssh root@192.168.1.20 'docker exec n8n-n8n-1 du -sh /home/node/.n8n'
```

## Network Configuration

### Port Mappings
| Internal Port | External Port | Service | Protocol |
|---------------|---------------|---------|----------|
| 5678 | 5678 | n8n Web Interface | HTTP/HTTPS |

### Access URLs
- **Public Access**: https://n8n.accelior.com
- **Direct Access**: http://192.168.1.20:5678
- **Container Access**: http://localhost:5678 (from host)

### Firewall Requirements
```bash
# Required outbound connections
# - Supabase Database: aws-0-eu-central-1.pooler.supabase.com:6543
# - External APIs: Various (webhooks, integrations)
# - Docker Registry: docker.n8n.io:443

# Required inbound connections
# - Web Interface: 0.0.0.0:5678
# - Webhook endpoints: https://n8n.accelior.com/webhook/*
```

## Database Configuration

### PostgreSQL Connection Details
- **Provider**: Supabase (managed PostgreSQL)
- **Connection Type**: Connection pooler (pgBouncer)
- **SSL**: Required
- **Connection Pool**: Shared across applications

### Database Schema
n8n automatically manages its database schema through built-in migrations.

```bash
# Check database connectivity
ssh root@192.168.1.20 'docker exec n8n-n8n-1 nc -zv aws-0-eu-central-1.pooler.supabase.com 6543'

# View n8n database tables (if psql available)
ssh root@192.168.1.20 'docker exec n8n-n8n-1 psql postgresql://postgres.bbgyrvkxejtrnttoijlt:qdjCUK1DI1x5umDG@aws-0-eu-central-1.pooler.supabase.com:6543/postgres -c "\dt"'
```

## Security Configuration

### Encryption
- **Data Encryption**: Enabled via `N8N_ENCRYPTION_KEY`
- **Database Connection**: SSL/TLS encrypted
- **Web Interface**: HTTPS via reverse proxy

### Access Control
- **Authentication**: Built-in n8n user management
- **API Access**: API key based authentication
- **Webhook Security**: Optional authentication per webhook

### Security Best Practices
```bash
# Regular security updates
ssh root@192.168.1.20 'cd /root/n8n && docker compose pull && docker compose up -d'

# Monitor for suspicious activity
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -E "(failed|error|unauthorized)"'

# Check exposed ports
ssh root@192.168.1.20 'netstat -tlnp | grep :5678'
```

## Integration Services

### Gotenberg PDF Service
- **Purpose**: PDF generation and document conversion
- **Container**: `n8n-gotenberg-1`
- **Memory Limit**: 512MB
- **Internal Communication**: Container network

### External Integrations
- **Database**: Supabase PostgreSQL
- **Email**: Various SMTP providers via n8n nodes
- **APIs**: Webhook endpoints and REST API calls
- **File Storage**: Local volume + external cloud storage

## Performance Specifications

### Resource Allocation
| Component | CPU Limit | Memory Limit | Memory Reservation |
|-----------|-----------|--------------|-------------------|
| n8n | 1.0 core | 1GB | 512MB |
| Gotenberg | 0.5 core | 512MB | 256MB |
| **Total** | **1.5 cores** | **1.5GB** | **768MB** |

### Performance Metrics
- **Startup Time**: ~30 seconds
- **Memory Usage**: 265MB typical (26% of limit)
- **CPU Usage**: <1% typical load
- **Concurrent Workflows**: 100-500 supported
- **Response Time**: <500ms for UI operations

## Backup and Recovery

### Configuration Backup
```bash
# Backup docker-compose configuration
ssh root@192.168.1.20 'cp /root/n8n/docker-compose.yml /root/backups/n8n-config-$(date +%Y%m%d).yml'

# Backup entire n8n directory
ssh root@192.168.1.20 'tar czf /root/backups/n8n-complete-$(date +%Y%m%d).tar.gz -C /root n8n'
```

### Data Backup Strategy
1. **Database**: Handled by Supabase automatic backups
2. **Workflow Data**: Stored in database (covered above)
3. **Local Data**: Volume backup recommended weekly
4. **Configuration**: Version controlled and backed up daily

### Disaster Recovery
```bash
# Complete service restoration
ssh root@192.168.1.20 'cd /root && tar xzf /root/backups/n8n-complete-[DATE].tar.gz'
ssh root@192.168.1.20 'cd /root/n8n && docker compose up -d'

# Verify restoration
curl -I https://n8n.accelior.com/
```

## Monitoring and Logging

### Service Health Checks
```bash
# Container health
ssh root@192.168.1.20 'docker ps | grep n8n'

# Service response
curl -I https://n8n.accelior.com/

# Resource usage
ssh root@192.168.1.20 'docker stats n8n-n8n-1 --no-stream'

# Database connectivity
ssh root@192.168.1.20 'docker exec n8n-n8n-1 nc -zv aws-0-eu-central-1.pooler.supabase.com 6543'
```

### Log Management
```bash
# View recent logs
ssh root@192.168.1.20 'docker logs n8n-n8n-1 --tail 50'

# Follow logs in real-time
ssh root@192.168.1.20 'docker logs n8n-n8n-1 -f'

# Search for errors
ssh root@192.168.1.20 'docker logs n8n-n8n-1 | grep -i error'

# Export logs for analysis
ssh root@192.168.1.20 'docker logs n8n-n8n-1 > /tmp/n8n-logs-$(date +%Y%m%d).log'
```

## Development and Testing

### Local Development Setup
```bash
# Create development environment
ssh root@192.168.1.20 'cp -r /root/n8n /root/n8n-dev'
ssh root@192.168.1.20 'cd /root/n8n-dev && sed -i "s/5678:5678/5679:5678/" docker-compose.yml'
ssh root@192.168.1.20 'cd /root/n8n-dev && docker compose up -d'
```

### Testing Procedures
```bash
# API endpoint testing
curl -X GET https://n8n.accelior.com/rest/settings

# Webhook testing
curl -X POST https://n8n.accelior.com/webhook-test/test -H "Content-Type: application/json" -d '{"test": true}'

# Performance testing
ab -n 100 -c 10 https://n8n.accelior.com/
```

---

**Created**: September 19, 2025
**Last Updated**: September 19, 2025
**Deployment**: Production Active
**Next Review**: October 19, 2025