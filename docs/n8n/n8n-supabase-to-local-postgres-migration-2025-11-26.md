# n8n Database Migration: Supabase to Local PostgreSQL - November 26, 2025

## Overview

Migrated n8n's database from Supabase Cloud to a self-hosted PostgreSQL container running in the same docker-compose stack. This eliminates external database dependency and reduces latency.

## Migration Summary

| Attribute | Before | After |
|-----------|--------|-------|
| Database Host | aws-0-eu-central-1.pooler.supabase.com | postgres (local container) |
| Database Port | 6543 (Supabase pooler) | 5432 (standard PostgreSQL) |
| Database Name | postgres | n8n |
| Database User | postgres.bbgyrvkxejtrnttoijlt | n8n |
| PostgreSQL Version | Supabase managed | 16-alpine |
| Latency | ~50ms (external) | <1ms (local) |

## Data Migrated

- **Workflows**: 71 workflows preserved
- **Credentials**: 17 credentials (encrypted with same key)
- **Executions**: 537 execution records
- **Users, Tags, Settings**: All preserved

## New Architecture

```
┌─────────────────────────────────────────────────┐
│  LXC 111 (docker-debian) on pve2                │
│                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    │
│  │   n8n-n8n-1     │───►│  n8n-postgres   │    │
│  │  (port 5678)    │    │  (port 5432)    │    │
│  │   n8n:1.113.1   │    │ postgres:16     │    │
│  └─────────────────┘    └─────────────────┘    │
│          │                      │              │
│          ▼                      ▼              │
│  ┌─────────────────┐    ┌─────────────────┐    │
│  │ n8n_n8n_user_   │    │ n8n_postgres_   │    │
│  │    data (vol)   │    │    data (vol)   │    │
│  └─────────────────┘    └─────────────────┘    │
└─────────────────────────────────────────────────┘
```

## Configuration Files

### Location
```
/home/n8n_compose/
├── docker-compose.yml           # Updated with postgres service
├── docker-compose.yml.backup-supabase  # Backup of old config
├── .env.backup-supabase         # Backup of old env
├── n8n_backup.dump              # Database backup (11MB)
└── .env                         # (not used, vars in compose)
```

### docker-compose.yml (Current)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: n8n-postgres
    restart: always
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=jLLkxRB2mGxYHqVOeh1fTfy3o3gQfrZ
    volumes:
      - n8n_postgres_data:/var/lib/postgresql/data
      - /home/n8n_compose:/backup
    networks:
      - default
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n -d n8n"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: docker.n8n.io/n8nio/n8n:1.113.1
    container_name: n8n-n8n-1
    restart: always
    user: node
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "5678:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=jLLkxRB2mGxYHqVOeh1fTfy3o3gQfrZ
      - GENERIC_TIMEZONE=Europe/Berlin
      - WEBHOOK_URL=https://n8n.accelior.com/
      - N8N_PROTOCOL=https
      - N8N_HOST=n8n.accelior.com
      - N8N_PORT=5678
      - N8N_ENCRYPTION_KEY=rqWlh/0WNeDu6sbKMEMbvm3onF7D7gc6
      - NODE_ENV=production
      - N8N_EXECUTIONS_DATA_PRUNE=true
      - N8N_EXECUTIONS_DATA_MAX_AGE=168
      - N8N_EXECUTIONS_DATA_PRUNE_MAX_COUNT=1000
      - N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true
      - N8N_PROXY_HOPS=1
      - NODE_OPTIONS=--max-old-space-size=768
    volumes:
      - n8n_n8n_user_data:/home/node/.n8n
    networks:
      - default

  gotenberg:
    image: gotenberg/gotenberg:8
    container_name: n8n-gotenberg-1
    restart: always
    networks:
      - default

volumes:
  n8n_n8n_user_data:
    external: true
  n8n_postgres_data:

networks:
  default:
    external: true
    name: n8n_default
```

## Critical Configuration Notes

### Encryption Key (MUST NOT CHANGE)
```
N8N_ENCRYPTION_KEY=rqWlh/0WNeDu6sbKMEMbvm3onF7D7gc6
```
This key encrypts all stored credentials. Changing it will make credentials unreadable.

### Database Credentials
```
POSTGRES_USER=n8n
POSTGRES_PASSWORD=jLLkxRB2mGxYHqVOeh1fTfy3o3gQfrZ
POSTGRES_DB=n8n
```

## Service Management

### Check Status
```bash
ssh root@pve2 'pct exec 111 -- docker compose -f /home/n8n_compose/docker-compose.yml ps'
```

### View Logs
```bash
# n8n logs
ssh root@pve2 'pct exec 111 -- docker logs n8n-n8n-1 -f'

# PostgreSQL logs
ssh root@pve2 'pct exec 111 -- docker logs n8n-postgres -f'
```

### Restart Stack
```bash
ssh root@pve2 'pct exec 111 -- docker compose -f /home/n8n_compose/docker-compose.yml restart'
```

### Database Access
```bash
# Connect to PostgreSQL
ssh root@pve2 'pct exec 111 -- docker exec -it n8n-postgres psql -U n8n -d n8n'

# Quick queries
ssh root@pve2 'pct exec 111 -- docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM workflow_entity;"'
```

## Backup Procedures

### Database Backup
```bash
# Create backup
ssh root@pve2 'pct exec 111 -- docker exec n8n-postgres pg_dump -U n8n -d n8n -F c -f /backup/n8n_backup_$(date +%Y%m%d).dump'

# Verify backup
ssh root@pve2 'pct exec 111 -- ls -lh /home/n8n_compose/n8n_backup*.dump'
```

### Restore from Backup
```bash
# Stop n8n
ssh root@pve2 'pct exec 111 -- docker compose -f /home/n8n_compose/docker-compose.yml stop n8n'

# Restore (WARNING: destroys existing data)
ssh root@pve2 'pct exec 111 -- docker exec n8n-postgres psql -U n8n -d n8n -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"'
ssh root@pve2 'pct exec 111 -- docker exec n8n-postgres pg_restore -U n8n -d n8n --no-owner --no-acl /backup/n8n_backup.dump'

# Start n8n
ssh root@pve2 'pct exec 111 -- docker compose -f /home/n8n_compose/docker-compose.yml up -d n8n'
```

## Rollback to Supabase (Emergency)

If local PostgreSQL fails and you need to revert to Supabase:

```bash
# Restore old configuration
ssh root@pve2 'pct exec 111 -- cp /home/n8n_compose/docker-compose.yml.backup-supabase /home/n8n_compose/docker-compose.yml'

# Stop and remove local postgres
ssh root@pve2 'pct exec 111 -- docker compose -f /home/n8n_compose/docker-compose.yml down'

# Start with Supabase config
ssh root@pve2 'pct exec 111 -- docker compose -f /home/n8n_compose/docker-compose.yml up -d'
```

**Note**: This requires the Supabase project to still exist and be accessible.

## Migration Steps Performed

1. **Backed up Supabase database** (11MB dump file)
2. **Created new docker-compose.yml** with postgres service
3. **Deployed postgres:16-alpine** container with healthcheck
4. **Restored database** using pg_restore (15 warnings about Supabase-specific extensions - ignored)
5. **Updated n8n** to connect to local postgres
6. **Verified** 71 workflows, 17 credentials, 537 executions accessible

## Known Issues

### pg_restore Warnings (Ignored)
The following Supabase-specific extensions were not restored (not needed by n8n):
- pgsodium
- pg_graphql
- pgjwt
- supabase_vault
- RLS policies for `authenticated` role

These are Supabase-specific features not used by n8n.

## Benefits of Migration

1. **No external dependency** - Database is local
2. **Lower latency** - <1ms vs ~50ms
3. **No Supabase costs** - Self-hosted
4. **Full control** - Can tune PostgreSQL settings
5. **Simpler backup** - Standard pg_dump/pg_restore
6. **Offline capability** - Works without internet

## Monitoring

### Health Checks
```bash
# Check postgres health
ssh root@pve2 'pct exec 111 -- docker exec n8n-postgres pg_isready -U n8n -d n8n'

# Check n8n health
curl -s https://n8n.accelior.com/healthz
```

### Database Size
```bash
ssh root@pve2 'pct exec 111 -- docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT pg_size_pretty(pg_database_size('\''n8n'\''));"'
```

---

**Migration Date**: November 26, 2025
**Performed By**: Claude Code
**Documentation**: /docs/n8n/n8n-supabase-to-local-postgres-migration-2025-11-26.md
