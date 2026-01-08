# Happy Server Installation & Configuration

**Date**: 2026-01-04
**Host**: docker-debian (192.168.1.20, LXC 111)
**Status**: Running, Healthy

## Overview

Happy Server is an open-source, self-hosted synchronization backend for Claude Code that enables:
- **End-to-end encrypted** session synchronization across devices
- **Mobile/web remote control** of Claude Code sessions via the `happy-coder` CLI
- **Zero-knowledge architecture** - server stores only encrypted blobs
- **Push notifications** when Claude Code tasks complete

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Happy Server Stack                        │
├─────────────────────────────────────────────────────────────┤
│  happy-server (3005)     │  Main API + WebSocket sync       │
│  happy-postgres (5435)   │  PostgreSQL 16 - session data    │
│  happy-redis (6380)      │  Redis 7 - real-time sync        │
│  happy-minio (9010/9011) │  S3 storage for encrypted blobs  │
└─────────────────────────────────────────────────────────────┘
```

## Service Details

| Service | Container | Port | Health |
|---------|-----------|------|--------|
| happy-server | `happy-server` | 3005 (API), 9091 (metrics) | `https://happy.acmea.tech/health` |

## Public URL

- **HTTPS**: https://happy.acmea.tech
- **DNS**: CNAME `happy.acmea.tech` → `base.acmea.tech` (Cloudflare, DNS-only)
- **SSL**: Let's Encrypt cert (ID: 60, expires 2026-04-04)
- **NPM Proxy Host ID**: 45

| Service | Container | Port | Health |
|---------|-----------|------|--------|
| PostgreSQL 16 | `happy-postgres` | 5435 | `pg_isready` |
| Redis 7 | `happy-redis` | 6380 | - |
| MinIO | `happy-minio` | 9010 (S3), 9011 (Console) | - |

## Installation Location

```bash
# Server source
/opt/happy-server/

# Docker Compose
/opt/happy-server/docker-compose.yml

# Prisma schema
/opt/happy-server/prisma/schema.prisma
```

## CLI Installation (Local Workstation)

```bash
# Install globally
npm install -g happy-coder

# Configure server URL (use HTTPS public URL)
export HAPPY_SERVER_URL=https://happy.acmea.tech

# Authenticate
happy auth login --force

# Run diagnostics
happy doctor
```

## Key Features

### Remote Claude Code Control
```bash
# Start Claude with mobile control
happy

# With permission bypass (sandbox only)
happy --yolo

# Resume previous session
happy --resume
```

### Additional Modes
```bash
# Codex mode
happy codex

# Gemini mode (Agent Client Protocol)
happy gemini

# Daemon mode (background service)
happy daemon start
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check (returns `{"status":"ok"}`) |
| `GET /` | Welcome message |
| `POST /v1/auth/request` | Terminal authentication request |
| `GET :9091/metrics` | Prometheus metrics |

## Database Schema Highlights

The Prisma schema manages:
- **Accounts** - Public key auth, GitHub OAuth, profile info
- **Sessions** - Encrypted Claude Code conversations
- **Machines** - Registered devices with daemon state
- **Artifacts** - Encrypted binary storage
- **UserFeedItem** - Activity feed
- **ServiceAccountToken** - Encrypted API vendor tokens

## Environment Variables

```bash
NODE_ENV=production
PORT=3005
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/happy
REDIS_URL=redis://redis:6379
S3_HOST=minio
S3_PORT=9000
S3_USE_SSL=false
S3_ACCESS_KEY=minioadmin
S3_SECRET_KEY=minioadmin
S3_BUCKET=happy
HANDY_MASTER_SECRET=change-this-to-a-secure-secret-key
METRICS_ENABLED=true
METRICS_PORT=9090
```

## Monitoring

### Prometheus Metrics
```bash
curl http://192.168.1.20:9091/metrics
```

Key metrics:
- `prisma_client_queries_total` - Database query count
- `prisma_pool_connections_*` - Connection pool stats

### Container Health
```bash
ssh root@192.168.1.10 'pct exec 111 -- docker ps | grep happy'
```

## Security Considerations

1. **Change `HANDY_MASTER_SECRET`** from default before production use
2. **Update MinIO credentials** from `minioadmin/minioadmin`
3. Consider adding reverse proxy with TLS termination
4. All data is E2E encrypted - server cannot read content

## References

- **GitHub (Server)**: https://github.com/slopus/happy-server
- **GitHub (CLI)**: https://github.com/slopus/happy-cli
- **NPM Package**: https://www.npmjs.com/package/happy-coder
- **Documentation**: https://happy.engineering/
- **Cloud Service**: https://happy-api.slopus.com (free, equally secure)

## Related Services

- Depends on: `happy-postgres` (hard), `happy-redis` (soft), `happy-minio` (soft)
- Infrastructure DB: Host ID 12, Service IDs 68-71
