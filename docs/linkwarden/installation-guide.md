# Linkwarden Installation Guide

**Date**: 2025-10-19
**Container**: CT 111 (docker-debian)
**IP Address**: 192.168.1.20
**Local Port**: 3002
**Public URL**: https://link.acmea.tech

## Overview

Linkwarden is a self-hosted, collaborative bookmark manager with full-text search, automatic archiving, and tagging capabilities.

## Installation Details

### Container Platform
- **Host**: docker-debian (CT 111)
- **Proxmox Host**: pve2
- **Installation Path**: `/opt/linkwarden`
- **Internal Port**: 3000 (container)
- **External Port**: 3002 (host)

### Docker Compose Stack

The stack consists of three services:

1. **PostgreSQL 16 Alpine** - Database backend
2. **MeiliSearch v1.12.8** - Full-text search engine
3. **Linkwarden Latest** - Main application

### Configuration Files

**docker-compose.yml**:
```yaml
services:
  postgres:
    image: postgres:16-alpine
    env_file: .env
    restart: always
    volumes:
      - ./pgdata:/var/lib/postgresql/data

  linkwarden:
    env_file: .env
    environment:
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@postgres:5432/postgres
    restart: always
    image: ghcr.io/linkwarden/linkwarden:latest
    ports:
      - 3002:3000
    volumes:
      - ./data:/data/data
    depends_on:
      - postgres
      - meilisearch

  meilisearch:
    image: getmeili/meilisearch:v1.12.8
    restart: always
    env_file:
      - .env
    volumes:
      - ./meili_data:/meili_data
```

**.env** (secrets stored securely on server):
```bash
# NextAuth Configuration
NEXTAUTH_URL=http://localhost:3000/api/v1/auth
NEXTAUTH_SECRET=<generated>

# Database Configuration
POSTGRES_PASSWORD=<generated>

# MeiliSearch Configuration
MEILI_MASTER_KEY=<generated>
```

### Port Assignment

Port 3002 was selected because:
- Port 3000: In use by Perplexica
- Port 3001: Already allocated
- Port 3002: Available

## Deployment Steps

### 1. Pull Docker Images
```bash
cd /opt/linkwarden
docker compose pull
```

### 2. Start Services
```bash
docker compose up -d
```

### 3. Verify Status
```bash
docker compose ps
```

Expected output:
```
NAME                       STATUS
linkwarden-linkwarden-1    Up (healthy)
linkwarden-meilisearch-1   Up
linkwarden-postgres-1      Up
```

## Network Configuration

### Internal Access
- Direct URL: `http://192.168.1.20:3002`

### External Access Configuration

#### Step 1: Cloudflare DNS
Create a CNAME record in Cloudflare:
- **Type**: CNAME
- **Name**: link
- **Target**: base.acmea.tech
- **Proxy Status**: Proxied (orange cloud)
- **TTL**: Auto

#### Step 2: Nginx Proxy Manager (NPM)
Configure reverse proxy on NPM (http://192.168.1.9:81):

**Proxy Host Configuration**:
- **Domain Names**: link.acmea.tech
- **Scheme**: http
- **Forward Hostname/IP**: 192.168.1.20
- **Forward Port**: 3002
- **Cache Assets**: Enabled
- **Block Common Exploits**: Enabled
- **Websockets Support**: Enabled

**SSL Configuration**:
- **SSL Certificate**: Let's Encrypt
- **Force SSL**: Enabled
- **HTTP/2 Support**: Enabled
- **HSTS Enabled**: Enabled
- **HSTS Subdomains**: Disabled

## Data Persistence

### Volume Mounts
- `./pgdata` - PostgreSQL database files
- `./data` - Linkwarden application data
- `./meili_data` - MeiliSearch index data

### Backup Recommendations
```bash
# Stop containers
cd /opt/linkwarden
docker compose down

# Backup data
tar -czf linkwarden-backup-$(date +%Y%m%d).tar.gz pgdata/ data/ meili_data/ .env docker-compose.yml

# Restart containers
docker compose up -d
```

## Management Commands

### View Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f linkwarden
docker compose logs -f postgres
docker compose logs -f meilisearch
```

### Restart Services
```bash
docker compose restart
```

### Update to Latest Version
```bash
docker compose pull
docker compose up -d
```

### Stop Services
```bash
docker compose down
```

## Health Monitoring

### Container Health Check
```bash
docker compose ps
```

### Application Health
Access the application at `http://192.168.1.20:3002` to verify:
- Web interface loads
- Can create an account
- Can add bookmarks
- Search functionality works

## Troubleshooting

### Container Won't Start
1. Check port conflicts:
   ```bash
   netstat -tulpn | grep 3002
   ```

2. Check logs:
   ```bash
   docker compose logs linkwarden
   ```

### Database Connection Issues
1. Verify PostgreSQL is running:
   ```bash
   docker compose ps postgres
   ```

2. Check database logs:
   ```bash
   docker compose logs postgres
   ```

### Search Not Working
1. Verify MeiliSearch is running:
   ```bash
   docker compose ps meilisearch
   ```

2. Check MeiliSearch logs:
   ```bash
   docker compose logs meilisearch
   ```

## Security Considerations

1. **Secrets Management**: All sensitive credentials are stored in `.env` file
2. **Network Isolation**: Containers communicate via Docker network
3. **SSL/TLS**: Enforced via Nginx Proxy Manager
4. **Firewall**: Port 3002 only accessible from internal network

## Resource Usage

Expected resource consumption:
- **CPU**: Low (~1-2% idle, ~5-10% under load)
- **Memory**: ~500MB total for all containers
- **Disk**: Grows with bookmark data and archives

## Links

- **Official Documentation**: https://docs.linkwarden.app
- **GitHub Repository**: https://github.com/linkwarden/linkwarden
- **Docker Hub**: https://ghcr.io/linkwarden/linkwarden

## Maintenance Schedule

- **Weekly**: Check container health and logs
- **Monthly**: Review disk usage and backup data
- **Quarterly**: Update to latest version

---

**Installation Date**: 2025-10-19
**Installed By**: Automated deployment via Claude Code
**Status**: Active and healthy
