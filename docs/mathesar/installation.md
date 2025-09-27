# Mathesar Installation Documentation

## Overview

Mathesar is a web-based interface for PostgreSQL databases that provides a spreadsheet-like UI for database management. This document covers the complete installation and configuration process on the Docker VM (192.168.1.20).

## Installation Summary

- **Installation Date**: September 17, 2025
- **Location**: Docker VM (192.168.1.20)
- **Access URL**: http://192.168.1.20:8080
- **Status**: ✅ Working (bypassing Caddy reverse proxy)

## Architecture

### Container Stack
```
Mathesar Stack:
├── mathesar_service (Main application)
├── mathesar_db (PostgreSQL database)
└── caddy-reverse-proxy (Web server - currently bypassed)
```

### Network Configuration
- **Service Port**: 8000 (internal)
- **External Port**: 8080 (mapped directly to service)
- **Database Port**: 5432 (internal only)
- **Project Directory**: `/root/mathesar-project/`

## Installation Process

### 1. Initial Setup
```bash
# Create project directory
mkdir -p /root/mathesar-project
cd /root/mathesar-project

# Download official docker-compose.yml
wget https://raw.githubusercontent.com/mathesar-foundation/mathesar/0.5.0/docker-compose.yml
```

### 2. Configuration Files

#### Environment Configuration (.env)
```bash
DOMAIN_NAME=:8080
POSTGRES_DB=mathesar_django
POSTGRES_USER=mathesar
POSTGRES_PASSWORD=mathesar_secure_password
POSTGRES_HOST=mathesar_db
POSTGRES_PORT=5432
ALLOWED_HOSTS=*
DEBUG=false
```

#### Port Modifications
- **Original**: Port 80:80 (conflicted with nginx)
- **Modified**: Port 8080:80 (to avoid conflicts)

### 3. Deployment

#### Standard Deployment (with Caddy)
```bash
cd /root/mathesar-project
docker compose up -d
```

#### Current Working Deployment (Direct Service)
```bash
# Stop Caddy proxy
docker compose stop caddy-reverse-proxy

# Run service directly on port 8080
docker compose run --rm -p 8080:8000 service bash -c "python manage.py runserver 0.0.0.0:8000"
```

## Troubleshooting Issues Encountered

### 1. Connection Refused Error
**Problem**: External access failed with "connection refused" on port 8080.

**Root Cause**: Initial DOMAIN_NAME configuration issues and Caddy proxy conflicts.

**Solutions Applied**:
- Fixed DOMAIN_NAME format from `:8080` to proper hostname
- Verified container configuration (correctly using `expose` not `ports`)
- Identified Caddy automatic HTTPS redirect as blocking factor

### 2. HTTPS Redirect Loop
**Problem**: Caddy automatically redirected HTTP to HTTPS (308 Permanent Redirect), but port 443 wasn't accessible externally.

**Root Cause**: Caddy's default behavior forces HTTPS for security.

**Solution**: Bypassed Caddy and ran service directly for HTTP-only access.

### 3. Port Conflicts
**Problem**: Default port 80 conflicted with existing nginx services.

**Solution**: Modified docker-compose.yml to use port 8080 instead.

## Current Working Configuration

### Active Services
```bash
# Check service status
docker ps | grep mathesar

# Direct service access (current method)
docker compose run --rm -p 8080:8000 service bash -c "python manage.py runserver 0.0.0.0:8000"
```

### Access Information
- **URL**: http://192.168.1.20:8080
- **Initial Setup**: Required on first access
- **Admin Account**: Create during setup process

### Service Health Checks
```bash
# Test connectivity
curl -I http://192.168.1.20:8080

# Check container logs
docker logs mathesar_service

# Verify database connectivity
docker exec mathesar_db pg_isready -d mathesar_django -U mathesar
```

## Integration with Infrastructure

### No Port Conflicts
- **Port 8080**: Successfully isolated from other services
- **No conflicts with**: Supabase (8000/8443), n8n (5678), Portainer (9443), etc.

### Network Isolation
- Uses dedicated Docker network: `mathesar-project_default`
- Internal PostgreSQL database (no external exposure)
- Proper container-to-container communication

### Persistent Storage
```
/root/mathesar-project/msar/
├── pgdata/     (PostgreSQL data)
├── media/      (User uploaded files)
├── static/     (Static web assets)
├── secrets/    (Application secrets)
└── caddy/      (Caddy certificates - currently unused)
```

## Next Steps

### 1. Complete Initial Setup
- Access http://192.168.1.20:8080
- Create admin user account
- Configure initial database connections

### 2. Production Configuration (Optional)
- Resolve Caddy HTTPS redirect issues for proper reverse proxy
- Configure domain-based access if needed
- Set up SSL certificates for HTTPS access

### 3. Backup Strategy
- Include Mathesar data in existing Proxmox backup procedures
- Document database backup/restore procedures
- Test disaster recovery processes

## Maintenance Commands

### Start/Stop Services
```bash
cd /root/mathesar-project

# Standard method (with Caddy - currently problematic)
docker compose up -d
docker compose down

# Current working method (direct service)
docker compose run --rm -p 8080:8000 service bash -c "python manage.py runserver 0.0.0.0:8000"
```

### Updates
```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose down && docker compose up -d
```

### Database Operations
```bash
# Access database directly
docker exec -it mathesar_db psql -U mathesar -d mathesar_django

# Backup database
docker exec mathesar_db pg_dump -U mathesar mathesar_django > mathesar_backup.sql

# Restore database
docker exec -i mathesar_db psql -U mathesar -d mathesar_django < mathesar_backup.sql
```

## Security Considerations

### Current Security Status
- **Database**: Internal access only (good)
- **Web Access**: HTTP only (consider HTTPS for production)
- **Authentication**: Application-level user management
- **Network**: Isolated Docker network

### Recommended Improvements
1. **Enable HTTPS**: Resolve Caddy configuration for SSL
2. **Database Security**: Regular password rotation
3. **Access Control**: Integrate with existing authentication systems
4. **Firewall Rules**: Restrict access to known IP ranges

## Lessons Learned

### Configuration Best Practices
1. **Always test actual URLs** - Don't assume HTTP status codes mean working access
2. **Document port conflicts early** - Check existing services before deployment
3. **Understand reverse proxy behavior** - Caddy's HTTPS redirect needs proper configuration
4. **Use direct service access for testing** - Bypass proxies to isolate issues

### Docker Networking Insights
- Container `expose` vs `ports` configuration is critical for reverse proxies
- DOMAIN_NAME format significantly affects Caddy behavior
- Direct service binding can bypass proxy issues for testing

## Related Documentation

- [Docker Containers Overview](../docker-containers-overview.md)
- [Docker Maintenance](../docker/docker-maintenance.md)
- [Infrastructure Overview](../infrastructure.md)
- [Nginx Proxy Manager](../npm/npm.md)