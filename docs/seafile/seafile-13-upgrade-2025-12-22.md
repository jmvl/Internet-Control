# Seafile 12.0 to 13.0 Upgrade

**Date:** 2025-12-22
**Previous Version:** 12.0.14
**New Version:** 13.0.12
**Status:** Completed Successfully

---

## Overview

Upgraded Seafile Community Edition from version 12.0.14 to 13.0.12. This is a major upgrade with significant configuration changes including:

- New `.env` + `seafile-server.yml` configuration structure
- Redis replaces Memcached as cache provider
- `SERVICE_URL` and `FILE_SERVER_ROOT` removed from `seahub_settings.py` (now calculated from environment variables)
- Database and cache configurations moved to environment variables

---

## Pre-Upgrade Issue

**Problem:** Share links were generated incorrectly as:
```
http://files.accelior.com:8000/f/xxxxx
```

**Expected:**
```
https://files.accelior.com/f/xxxxx
```

**Root Cause:** `SERVICE_URL` and `FILE_SERVER_ROOT` were misconfigured in `seahub_settings.py`.

---

## Changes Made

### 1. Container Stack

| Component | Before | After |
|-----------|--------|-------|
| Seafile | `seafileltd/seafile-mc:12.0-latest` | `seafileltd/seafile-mc:13.0-latest` |
| Cache | `memcached:1.6.18` | `redis:7` |
| Database | `mariadb:10.11` | `mariadb:10.11` (unchanged) |

### 2. Configuration Files

#### New Files Created

**`.env`** - Environment configuration:
```bash
COMPOSE_FILE=seafile-server.yml
SEAFILE_IMAGE=seafileltd/seafile-mc:13.0-latest
SEAFILE_DB_IMAGE=mariadb:10.11
SEAFILE_REDIS_IMAGE=redis:7

SEAFILE_SERVER_HOSTNAME=files.accelior.com
SEAFILE_SERVER_PROTOCOL=https
TIME_ZONE=Etc/UTC
JWT_PRIVATE_KEY=<redacted>

SEAFILE_MYSQL_DB_HOST=db
SEAFILE_MYSQL_DB_USER=seafile
SEAFILE_MYSQL_DB_PASSWORD=<redacted>

CACHE_PROVIDER=redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<redacted>
```

**`seafile-server.yml`** - Docker Compose configuration:
- MariaDB with health checks
- Redis (replaces Memcached)
- Seafile 13.0 with proper environment variable mapping
- Port 8092:80 for Nginx Proxy Manager integration

#### Files Modified

**`seafile.conf`** - Removed obsolete sections:
- `[database]` section (now in `.env`)

**`seahub_settings.py`** - Removed obsolete configurations:
- `DATABASES` block
- `CACHES` block
- `SERVICE_URL`
- `FILE_SERVER_ROOT`
- `COMPRESS_CACHE_BACKEND`
- `TIME_ZONE`

Retained:
- `SECRET_KEY`
- `ALLOWED_HOSTS`
- `CSRF_TRUSTED_ORIGINS`
- `ENABLE_HTTPS`

#### Backup Files Created
- `/opt/seafile-docker/docker-compose.yml.backup-12.0`
- `/opt/seafile-docker/backup-20251222-190602.sql` (database dump ~13MB)
- `/opt/seafile-docker/seafile-data/seafile/conf/seafile.conf.bak-12.0`
- `/opt/seafile-docker/seafile-data/seafile/conf/seahub_settings.py.bak-12.0`

---

## Upgrade Procedure

### Step 1: Backup
```bash
# Database backup
docker exec seafile-mysql mysqldump -u root -p --all-databases > backup-$(date +%Y%m%d-%H%M%S).sql

# Config backup
cp docker-compose.yml docker-compose.yml.backup-12.0
```

### Step 2: Stop Services
```bash
cd /opt/seafile-docker
docker compose down
```

### Step 3: Create New Configuration Files
- Created `.env` with new environment variables
- Created `seafile-server.yml` for Docker Compose

### Step 4: Clean Obsolete Configs
- Removed `[database]` from `seafile.conf`
- Removed `DATABASES`, `CACHES`, `SERVICE_URL`, `FILE_SERVER_ROOT` from `seahub_settings.py`

### Step 5: Pull and Start
```bash
docker compose pull
docker compose up -d
```

---

## Verification

### Container Status
```
NAMES           IMAGE                               STATUS
seafile         seafileltd/seafile-mc:13.0-latest   Up (healthy)
seafile-mysql   mariadb:10.11                       Up (healthy)
seafile-redis   redis:7                             Up
```

### Web Access
```bash
curl -I https://files.accelior.com
# HTTP/2 302 (redirect to login - expected)
```

### Share Links
Now correctly generated as:
```
https://files.accelior.com/f/xxxxx
```

---

## New Features in Seafile 13.0

- **SeaDoc 2.0** - Redesigned document/notes system (disabled)
- **Thumbnail Server** - Better performance, video thumbnails
- **Metadata Server** - Extended file properties
- **Real-time Updates** - Live file changes in web UI (disabled)
- **Dark Mode** - Basic support

---

## Rollback Procedure

If rollback is needed:

```bash
cd /opt/seafile-docker

# Stop current services
docker compose down

# Restore old compose file
cp docker-compose.yml.backup-12.0 docker-compose.yml

# Restore configs
cp seafile-data/seafile/conf/seafile.conf.bak-12.0 seafile-data/seafile/conf/seafile.conf
cp seafile-data/seafile/conf/seahub_settings.py.bak-12.0 seafile-data/seafile/conf/seahub_settings.py

# Start old version
docker compose up -d
```

---

## Infrastructure Database Updates

Updated `docker_containers` table:
- `seafile`: image changed to `seafileltd/seafile-mc:13.0-latest`
- `seafile-memcached`: renamed to `seafile-redis`, image changed to `redis:7`

---

## References

- [Seafile 13.0 Changelog](https://manual.seafile.com/13.0/changelog/server-changelog/)
- [Upgrade Notes for 13.0.x](https://manual.seafile.com/latest/upgrade/upgrade_notes_for_13.0.x/)
- [Docker Upgrade Guide](https://manual.seafile.com/13.0/upgrade/upgrade_docker/)
- [Setup CE by Docker](https://manual.seafile.com/13.0/setup/setup_ce_by_docker/)

---

*Document Created: 2025-12-22*
*Upgrade Performed By: Claude Code*
