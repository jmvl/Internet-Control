# Nginx Proxy Manager to Traefik Migration Plan

**Created**: 2026-01-30
**Author**: Migration Plan
**Status**: Planning Phase

---

## Executive Summary

### Current State
- **Nginx Proxy Manager (NPM)** v2.13.6 running on pve2 LXC container (192.168.1.121:81)
- **40+ proxy hosts** configured across multiple backend services
- **56 SSL certificates** managed via Let's Encrypt + Cloudflare DNS challenge
- **Known Issue**: Docker-in-LXC networking instability requiring periodic container restarts

### Migration Goal
**Full replacement** of Nginx Proxy Manager with Traefik for:
- Improved stability (eliminate Docker-in-LXC issues)
- Dynamic service discovery (automatic routing for Docker containers)
- Infrastructure-as-code configuration (no web UI dependency)
- Better scalability for growing service count
- Native integration with Docker ecosystem

### Migration Scope
| Item | Current Count | Notes |
|------|---------------|-------|
| Proxy Hosts | 40+ | All need label conversion |
| SSL Certificates | 56 | Will reprovision via ACME |
| Backend Services | 15+ | Mix of Docker and non-Docker |
| Custom Configs | Unknown | Access lists, custom locations |

### Timeline Estimate
**6-8 weeks** for complete migration including testing and rollback procedures.

---

## Table of Contents

1. [Current Infrastructure Assessment](#current-infrastructure-assessment)
2. [Why Traefik? Benefits Comparison](#why-traefik-benefits-comparison)
3. [Migration Architecture](#migration-architecture)
4. [Phase-by-Phase Implementation](#phase-by-phase-implementation)
5. [Service Migration Details](#service-migration-details)
6. [Configuration Reference](#configuration-reference)
7. [Rollback Procedures](#rollback-procedures)
8. [Risk Assessment](#risk-assessment)
9. [Post-Migration Tasks](#post-migration-tasks)

---

## Current Infrastructure Assessment

### NPM Deployment Details

**Container Configuration**:
```yaml
Container: nginx-proxy-manager-nginx-proxy-manager-1
Image: jc21/nginx-proxy-manager:latest (v2.13.6)
Host: pve2 LXC container (PCT 121)
IP: 192.168.1.121
Ports: 80:80, 81:81, 443:443
Volumes:
  - npm_data:/data (11MB - configurations)
  - npm_letsencrypt:/etc/letsencrypt (222KB - SSL certificates)
Database: SQLite (448KB, 44 proxy hosts)
```

**Network Flow**:
```
Internet → OPNsense Firewall (192.168.1.3)
         → Port Forward 80/443 to 192.168.1.121
         → NPM Container
         → Backend Services (192.168.1.20, 192.168.1.9, etc.)
```

### Known Issues

1. **Docker-in-LXC Instability**
   - Port forwarding failures after container restarts
   - Requires full LXC restart: `pct stop 121 && pct start 121`
   - Workaround documented in troubleshooting logs

2. **SSL Certificate Management**
   - 56 certificates requiring manual renewal intervention
   - Some certificates not auto-renewing properly

3. **Scalability**
   - Each new service requires manual NPM web UI configuration
   - No automatic service discovery

### Service Categories Configured in NPM

#### 1. Mail Services (Hestia - 192.168.1.30:8443)
- mail.accelior.com
- mail.acmea.tech
- webmail.acmea.tech

#### 2. Container Services (192.168.1.20)
- Portainer (portainer.acmea.tech:9443)
- Immich (immich.acmea.tech:2283)
- Calibre-Web (books.acmea.tech:8083)
- Uptime Kuma (uptime.acmea.tech:3010)
- n8n (n8n.acmea.tech:5678)
- Netdata (netdata.acmea.tech:19999)

#### 3. Storage Services (192.168.1.9)
- Radicale (radicale.acmea.tech:5232)
- Seafile (seafile.acmea.tech)

#### 4. Infrastructure Management
- Proxmox (pve2.home.accelior.com:8006)
- OPNsense (opnsense.home.accelior.com:443)
- Pi-hole (pihole.home.accelior.com:80)

---

## Why Traefik? Benefits Comparison

### Feature Comparison

| Feature | Nginx Proxy Manager | Traefik | Winner |
|---------|---------------------|---------|--------|
| Web UI | Yes | Optional (Dashboard) | NPM |
| Docker Integration | Manual | Native, automatic | Traefik |
| Service Discovery | Manual | Dynamic (Docker/K8s) | Traefik |
| SSL Automation | Let's Encrypt (HTTP/DNS) | Let's Encrypt (multiple) | Tie |
| Configuration | Web UI + Database | Code (labels/YAML) | Traefik |
| Scalability | Manual per-service | Automatic | Traefik |
| Middleware | Basic | Advanced (auth, rate-limit, etc.) | Traefik |
| Protocol Support | HTTP/HTTPS | HTTP/HTTPS/TCP/gRPC/WebSocket | Traefik |
| Monitoring | Basic | Native Prometheus + OpenTelemetry | Traefik |
| Learning Curve | Low | Moderate | NPM |

### Key Traefik Advantages

1. **Infrastructure as Code**
   ```yaml
   # Service defines its own routing via labels
   labels:
     - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
     - "traefik.http.services.myapp.loadbalancer.server.port=8080"
   ```

2. **Zero-Downtime Service Addition**
   - Start new container with labels
   - Traefik automatically detects and routes
   - No manual proxy configuration

3. **Advanced Middleware**
   ```yaml
   middlewares:
     rate-limit:
       rateLimit:
         average: 100
         burst: 50
     auth:
       basicAuth:
         users:
           - "admin:$apr1$..."
   ```

4. **Native Multi-Protocol Support**
   - HTTP/HTTPS with automatic TLS
   - TCP with SNI routing
   - WebSocket without special config
   - gRPC with automatic protocol detection

---

## Migration Architecture

### Target Architecture

```
Internet → OPNsense Firewall (192.168.1.3)
         → Port Forward 80/443 to 192.168.1.20 (Traefik host)
         → Traefik Container (Docker on 192.168.1.20)
         → Backend Services (automatic routing via labels)
```

### Parallel Migration Setup

**Phase 2-3: Both proxies running**
```
Internet → OPNsense
         ├─→ 80/443 → 192.168.1.20 (Traefik) [Migrated Services]
         └─→ 8081/4443 → 192.168.1.121 (NPM) [Unmigrated Services]
```

**DNS Strategy**:
- Migrated services: Cloudflare DNS → 192.168.1.20
- Unmigrated services: Cloudflare DNS → 192.168.1.121
- Gradual cutover per service

---

## Phase-by-Phase Implementation

### Phase 0: Pre-Migration Assessment (READ-ONLY)
**Duration**: 2 days
**Goal**: Complete inventory and documentation

#### Tasks

1. **Export NPM Database**
   ```bash
   ssh root@192.168.1.121
   docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
     sqlite3 /data/npm.db .dump > /tmp/npm-backup-$(date +%Y%m%d).sql
   ```

2. **Document All Proxy Hosts**
   - For each host, record:
     - Domain name
     - Backend IP and port
     - SSL certificate status
     - Custom Nginx locations
     - Access lists / authentication
     - Cache settings
     - Advanced features (streaming, WebSocket support)

3. **Create Service Inventory**
   ```markdown
   | Domain | Backend | Port | SSL | Auth | Custom Config | Priority |
   |--------|---------|------|-----|------|---------------|----------|
   ```

4. **Identify Migration Complexity**
   - Simple: Standard HTTP/HTTPS, no auth
   - Medium: Basic auth, custom paths
   - Complex: Custom NGINX config, streaming, non-Docker backends

#### Deliverables
- [ ] `docs/npm/npm-traefik-migration-inventory.md` - Complete service inventory
- [ ] `docs/npm/npm-backup-YYYYMMDD.sql` - Database export
- [ ] `docs/npm/npm-migration-complexity-assessment.md` - Complexity breakdown

---

### Phase 1: Traefik Foundation Setup
**Duration**: 3 days
**Goal**: Deploy Traefik alongside NPM

#### 1.1 Create Traefik Docker Stack

**Location**: `/docker/traefik/` on 192.168.1.20

**File**: `docker-compose.yml`
```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v2.11
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    ports:
      - "80:80"     # HTTP
      - "443:443"   # HTTPS
      - "8080:8080" # Dashboard (internal only)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./acme.json:/acme.json
      - ./dynamic-config.yml:/dynamic-config.yml:ro
      - ./logs:/logs
    networks:
      - proxy
    environment:
      - CF_API_TOKEN=${CF_API_TOKEN}
      - TZ=America/New_York
    labels:
      # Traefik Dashboard
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.home.accelior.com`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.tls.certresolver=cloudflare"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=traefik-auth"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=${TRAEFIK_BASIC_AUTH}"
      # Global redirect to HTTPS
      - "traefik.http.routers.http-catchall.rule=hostregexp(`{host:.+}`)"
      - "traefik.http.routers.http-catchall.entrypoints=web"
      - "traefik.http.routers.http-catchall.middlewares=redirect-to-https"
      - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"

networks:
  proxy:
    external: true
```

#### 1.2 Static Configuration

**File**: `traefik.yml`
```yaml
global:
  checkNewVersion: true
  sendAnonymousUsage: false

api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true

  websecure:
    address: ":443"
    http:
      tls:
        certResolver: cloudflare
        domains:
          - main: "acmea.tech"
            sans:
              - "*.acmea.tech"
          - main: "accelior.com"
            sans:
              - "*.accelior.com"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: proxy
    swarmMode: false

  file:
    filename: "/dynamic-config.yml"
    watch: true

certificatesResolvers:
  cloudflare:
    acme:
      email: jmvl@accelior.com
      storage: "/acme.json"
      dnsChallenge:
        provider: cloudflare
        delayBeforeCheck: 30
        resolvers:
          - "1.1.1.1:53"
          - "1.0.0.1:53"
      keyType: RSA4096

# Logging
log:
  level: INFO
  filePath: "/logs/traefik.log"
  format: json

accessLog:
  filePath: "/logs/access.log"
  format: json
  fields:
    headers:
      defaultMode: keep
```

#### 1.3 Dynamic Configuration

**File**: `dynamic-config.yml`
```yaml
http:
  middlewares:
    # Security Headers
    secure-headers:
      headers:
        sslRedirect: true
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        forceSTSHeader: true
        frameDeny: true
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "no-referrer"
        customFrameOptionsValue: "SAMEORIGIN"

    # Rate Limiting
    rate-limit:
      rateLimit:
        average: 100
        burst: 50
        period: 1m

    # Basic Auth Template
    auth-admin:
      basicAuth:
        users:
          - "admin:$apr1$H6uskkkW$IgXLP6ewTrSuBkTrqE8wj/"

    # Strip Prefix
    strip-api:
      stripPrefix:
        prefixes:
          - "/api"
        forceSlash: false

tls:
  options:
    default:
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
```

#### 1.4 Environment Setup

**File**: `.env`
```bash
# Cloudflare API Token (from existing .env.local)
CF_API_TOKEN=RZ5klBDFKSUqBSnb8lJgzuUzwbh4v5Yd8UwgpNzA

# Basic Auth for Traefik Dashboard
# Generate with: htpasswd -nb admin yourpassword
TRAEFIK_BASIC_AUTH=admin:$apr1$...

# Timezone
TZ=America/New_York
```

#### 1.5 Initial Setup Commands

```bash
# On 192.168.1.20

# Create directory structure
mkdir -p /docker/traefik
cd /docker/traefik

# Create acme.json with secure permissions
touch acme.json
chmod 600 acme.json

# Create logs directory
mkdir -p logs
chmod 755 logs

# Create Docker network (if not exists)
docker network create proxy --driver bridge 2>/dev/null || true

# Copy configuration files (docker-compose.yml, traefik.yml, etc.)

# Start Traefik
docker-compose up -d

# Check logs
docker-compose logs -f traefik
```

#### 1.6 DNS Setup for Traefik Dashboard

```bash
# Using flarectl
flarectl dns create \
  --zone accelior.com \
  --name traefik.home \
  --type A \
  --content 192.168.1.20 \
  --proxy
```

#### Verification Checklist
- [ ] Traefik container running: `docker ps | grep traefik`
- [ ] Dashboard accessible: https://traefik.home.accelior.com
- [ ] No errors in logs: `docker logs traefik`
- [ ] Docker provider active in dashboard
- [ ] ACME file created and valid JSON
- [ ] Cloudflare DNS challenge working
- [ ] Wildcard certificates provisioned

---

### Phase 2: Parallel Operation Setup
**Duration**: 2 days
**Goal**: Run NPM and Traefik simultaneously for gradual migration

#### 2.1 Reconfigure NPM Ports

**On 192.168.1.121**, update `/srv/npm-docker/docker-compose.yml`:
```yaml
ports:
  - "8081:80"    # Was 80:80
  - "81:81"      # Management UI unchanged
  - "4443:443"   # Was 443:443
```

```bash
# Restart NPM with new ports
ssh root@192.168.1.121
cd /srv/npm-docker
docker-compose down
docker-compose up -d
```

#### 2.2 Update OPNsense NAT Rules

**Firewall → NAT → Port Forward**

**Current Rules** (modify):
| Interface | Protocol | External | Internal | Target | Action |
|-----------|----------|----------|----------|--------|--------|
| WAN | TCP | 80 | 80 | 192.168.1.121 | **Change to 192.168.1.20** |
| WAN | TCP | 443 | 443 | 192.168.1.121 | **Change to 192.168.1.20** |

**New Temporary Rules** (add):
| Interface | Protocol | External | Internal | Target | Description |
|-----------|----------|----------|----------|--------|-------------|
| WAN | TCP | 8081 | 8081 | 192.168.1.121 | NPM HTTP (temporary) |
| WAN | TCP | 4443 | 4443 | 192.168.1.121 | NPM HTTPS (temporary) |

**Result**:
- Port 80/443 → Traefik (192.168.1.20)
- Port 8081/4443 → NPM (192.168.1.121) - fallback

#### 2.3 Test Parallel Operation

```bash
# Test Traefik
curl -I https://traefik.home.accelior.com

# Test NPM on new ports
curl -I http://nginx.home.accelior.com:8081
curl -I https://nginx.home.accelior.com:4443

# Both should work
```

#### Verification Checklist
- [ ] NPM accessible on ports 8081/4443
- [ ] NPM management UI still on port 81
- [ ] Traefik responding on 80/443
- [ ] Existing NPM services still functional
- [ ] No conflicts between proxies

---

### Phase 3: Service Migration
**Duration**: 4-6 weeks (10 services/week)
**Goal**: Migrate all 40+ services from NPM to Traefik

#### Migration Template

**For each Docker service**, update its `docker-compose.yml`:

**Before** (no proxy config):
```yaml
services:
  myapp:
    image: myapp:latest
    ports:
      - "8080:8080"
    networks:
      - default
```

**After** (Traefik labels):
```yaml
services:
  myapp:
    image: myapp:latest
    # Remove port exposure from host (optional)
    # ports:
    #   - "8080:8080"
    networks:
      - proxy  # Connect to Traefik network
    labels:
      # Enable Traefik
      - "traefik.enable=true"
      # Router configuration
      - "traefik.http.routers.myapp.rule=Host(`myapp.acmea.tech`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls=true"
      - "traefik.http.routers.myapp.tls.certresolver=cloudflare"
      # Service configuration
      - "traefik.http.services.myapp.loadbalancer.server.port=8080"
      # Network
      - "traefik.docker.network=proxy"

networks:
  proxy:
    external: true
    name: proxy
```

#### Service Migration Waves

**Wave 1: Critical Internal Services** (Week 1)
| Service | Domain | Backend | Port | Priority |
|---------|--------|---------|------|----------|
| Portainer | portainer.acmea.tech | 192.168.1.20 | 9443 | Critical |
| Uptime Kuma | uptime.acmea.tech | 192.168.1.20 | 3010 | Critical |
| Netdata | netdata.acmea.tech | 192.168.1.20 | 19999 | High |

**Wave 2: Public Services** (Week 2)
| Service | Domain | Backend | Port | Priority |
|---------|--------|---------|------|----------|
| Immich | immich.acmea.tech | 192.168.1.20 | 2283 | High |
| Calibre-Web | books.acmea.tech | 192.168.1.20 | 8083 | Medium |
| Radicale | radicale.acmea.tech | 192.168.1.9 | 5232 | Medium |

**Wave 3: Mail Services** (Week 3)
| Service | Domain | Backend | Port | Priority |
|---------|--------|---------|------|----------|
| Hestia Mail | mail.accelior.com | 192.168.1.30 | 8443 | High |
| Hestia Mail | mail.acmea.tech | 192.168.1.30 | 8443 | High |
| Webmail | webmail.acmea.tech | 192.168.1.30 | 8443 | High |

**Wave 4: Infrastructure** (Week 4)
| Service | Domain | Backend | Port | Priority |
|---------|--------|---------|------|----------|
| Proxmox | pve2.home.accelior.com | 192.168.1.2 | 8006 | Medium |
| OPNsense | opnsense.home.accelior.com | 192.168.1.3 | 443 | Medium |
| Pi-hole | pihole.home.accelior.com | 192.168.1.5 | 80 | Low |

**Waves 5-14**: Remaining services (3-4 per week)

#### Per-Service Migration Procedure

1. **Add Traefik Labels**
   - Edit service's docker-compose.yml
   - Add labels per template
   - Add to `proxy` network
   - Recreate container: `docker-compose up -d`

2. **Verify Traefik Detection**
   - Check Traefik Dashboard: https://traefik.home.accelior.com
   - Confirm service appears in HTTP routers
   - Check for configuration errors

3. **Test Service Locally**
   ```bash
   # Add to /etc/hosts temporarily
   echo "192.168.1.20 myapp.acmea.tech" >> /etc/hosts

   # Test HTTPS
   curl -I https://myapp.acmea.tech

   # Verify SSL certificate
   openssl s_client -connect myapp.acmea.tech:443 -servername myapp.acmea.tech
   ```

4. **Update Cloudflare DNS**
   ```bash
   # Get current record
   RECORD_ID=$(flarectl dns list --zone acmea.tech | grep myapp | awk '{print $1}')

   # Update to point to Traefik host
   flarectl dns update --zone acmea.tech --id $RECORD_ID --content "192.168.1.20"
   ```

5. **Full End-to-End Test**
   - Access from external network (cellular)
   - Verify SSL certificate valid
   - Test all service functionality
   - Check for broken links or features

6. **Document Migration**
   - Mark as migrated in inventory
   - Note any special configurations
   - Record any issues encountered

7. **Remove from NPM** (after 48 hours of stable operation)
   - Log into NPM: https://nginx.home.accelior.com:81
   - Delete proxy host configuration
   - Keep SSL certificates as backup

#### Verification Checklist (Per Service)
- [ ] Traefik labels added to docker-compose.yml
- [ ] Container connected to `proxy` network
- [ ] Service appears in Traefik dashboard
- [ ] SSL certificate provisioned via Cloudflare
- [ ] Service accessible via domain through Traefik
- [ ] All service features functional
- [ ] No errors in service logs
- [ ] No errors in Traefik logs
- [ ] 48 hours stable operation
- [ ] Removed from NPM (backup retained)

---

### Phase 4: Advanced Configuration Migration
**Duration**: 1 week
**Goal**: Handle special cases and advanced features

#### 4.1 Basic Authentication

**For services with NPM access lists**, use Traefik middleware:

**Generate password hash**:
```bash
# Apache format
htpasswd -nb admin mypassword

# Or using openssl
openssl passwd -apr1 mypassword
```

**Add to service labels**:
```yaml
labels:
  - "traefik.http.middlewares.myapp-auth.basicauth.users=admin:\$apr1\$..."
  - "traefik.http.routers.myapp.middlewares=myapp-auth"
```

#### 4.2 Custom Paths and Prefixes

**For services with custom NGINX locations**:

```yaml
labels:
  # Path-based routing
  - "traefik.http.routers.myapp-api.rule=Host(`myapp.acmea.tech`) && PathPrefix(`/api`)"
  - "traefik.http.middlewares.myapp-strip.stripprefix.prefixes=/api"
  - "traefik.http.routers.myapp-api.middlewares=myapp-strip"
```

#### 4.3 Rate Limiting

```yaml
labels:
  - "traefik.http.middlewares.myapp-rate.ratelimit.average=100"
  - "traefik.http.middlewares.myapp-rate.ratelimit.burst=50"
  - "traefik.http.routers.myapp.middlewares=myapp-rate,secure-headers"
```

#### 4.4 Non-Docker Services

**For services not running in Docker**, use Traefik file provider:

**Add to `dynamic-config.yml`**:
```yaml
http:
  routers:
    proxmox:
      rule: "Host(`pve2.home.accelior.com`)"
      entryPoints:
        - "websecure"
      tls:
        certResolver: cloudflare
      service: proxmox

  services:
    proxmox:
      loadBalancer:
        servers:
          - url: "https://192.168.1.2:8006"
        passHostHeader: true
        serverTransports:
          - "insecureSkipVerify: true"  # For self-signed certs
```

#### 4.5 WebSocket Support

Traefik handles WebSockets automatically - no special config needed.

#### 4.6 TCP Services

For non-HTTP services (SSH, databases, etc.):

**Add to `dynamic-config.yml`**:
```yaml
tcp:
  routers:
    mysql:
      rule: "HostSNI(`mysql.home.accelior.com`)"
      entryPoints:
        - "mysql-secure"
      tls:
        passthrough: true
      service: mysql

  services:
    mysql:
      loadBalancer:
        servers:
          - address: "192.168.1.20:3306"
```

---

### Phase 5: DNS Cutover Completion
**Duration**: 1 week (parallel with Phase 3)
**Goal**: All DNS records pointing to Traefik

#### Bulk DNS Update Strategy

```bash
#!/bin/bash
# migrate-dns-to-traefik.sh

TRAEFIK_IP="192.168.1.20"
ZONE="acmea.tech"

# List all A records
flarectl dns list --zone $ZONE | grep -v "192.168.1.20" | grep -v "192.168.1.121" | while read line; do
  ID=$(echo $line | awk '{print $1}')
  NAME=$(echo $line | awk '{print $2}')
  TYPE=$(echo $line | awk '{print $3}')

  if [ "$TYPE" = "A" ]; then
    echo "Updating $NAME to $TRAEFIK_IP"
    flarectl dns update --zone $ZONE --id $ID --content "$TRAEFIK_IP"
    sleep 2  # Rate limiting
  fi
done
```

#### DNS Verification

```bash
# Check propagation
for domain in $(cat services-list.txt); do
  echo "Checking $domain"
  dig +short $domain
  sleep 1
done
```

---

### Phase 6: NPM Decommissioning
**Duration**: 1 week
**Goal**: Final verification and NPM shutdown

#### 6.1 Pre-Shutdown Checklist

- [ ] All 40+ services verified on Traefik
- [ ] DNS fully propagated (wait 7 days after last change)
- [ ] No errors in Traefik logs for 48 hours
- [ ] All SSL certificates valid and auto-renewing
- [ ] Monitoring tools (Uptime Kuma) showing all green
- [ ] Team notified of cutover
- [ ] Backup procedures documented

#### 6.2 Final Data Backup

```bash
ssh root@192.168.1.121

# Backup NPM data
cd /srv/npm-docker
tar -czf /root/npm-backup-final-$(date +%Y%m%d).tar.gz .

# Backup database separately
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  sqlite3 /data/npm.db .dump > /root/npm-db-final-$(date +%Y%m%d).sql

# Copy backup to storage
scp /root/npm-backup-final-*.tar.gz root@192.168.1.9:/backups/npm/
```

#### 6.3 Stop NPM Container

```bash
ssh root@192.168.1.121

# Stop NPM
cd /srv/npm-docker
docker-compose down

# Disable auto-start
systemctl disable npm-docker  # If exists
```

#### 6.4 Update OPNsense NAT Rules

**Remove temporary NPM rules**:
| Interface | Protocol | External | Internal | Target | Action |
|-----------|----------|----------|----------|--------|--------|
| WAN | TCP | 8081 | 8081 | 192.168.1.121 | **DELETE** |
| WAN | TCP | 4443 | 4443 | 192.168.1.121 | **DELETE** |

**Verify final rules**:
- Port 80/443 → 192.168.1.20 (Traefik) ONLY

#### 6.5 Update Infrastructure Database

```bash
sqlite3 /Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db

-- Mark NPM as deprecated
UPDATE services
SET status = 'deprecated',
    updated_at = CURRENT_TIMESTAMP
WHERE service_name = 'Nginx Proxy Manager';

-- Add Traefik
INSERT INTO services (service_name, service_type, endpoint_url, port, status, description, documentation_url)
VALUES (
    'Traefik',
    'proxy',
    'https://traefik.home.accelior.com',
    443,
    'healthy',
    'Cloud-native reverse proxy with automatic SSL and service discovery',
    'https://doc.traefik.io/traefik/'
);

-- Update NPM container
UPDATE docker_containers
SET status = 'stopped',
    updated_at = CURRENT_TIMESTAMP
WHERE container_name LIKE '%nginx-proxy-manager%';
```

#### 6.6 Decommission LXC Container (Optional)

```bash
# On pve2
pct stop 121
pct destroy 121

# Or keep for backup
pct stop 121
# Keep for 30 days before destroy
```

---

## Configuration Reference

### Docker Label Quick Reference

#### Basic HTTP Router
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.acmea.tech`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.services.myapp.loadbalancer.server.port=8080"
```

#### With SSL
```yaml
labels:
  - "traefik.http.routers.myapp.tls=true"
  - "traefik.http.routers.myapp.tls.certresolver=cloudflare"
```

#### With Middleware
```yaml
labels:
  - "traefik.http.routers.myapp.middlewares=auth,rate-limit,secure-headers"
```

#### Multiple Domains
```yaml
labels:
  - "traefik.http.routers.myapp.rule=Host(`myapp.acmea.tech`) || Host(`www.myapp.acmea.tech`)"
```

#### Path-Based Routing
```yaml
labels:
  - "traefik.http.routers.myapp-api.rule=Host(`myapp.acmea.tech`) && PathPrefix(`/api`)"
```

### Middleware Reference

| Middleware | Purpose | Example |
|------------|---------|---------|
| `basicAuth` | Password protection | `users: ["admin:$apr1$..."]` |
| `rateLimit` | Rate limiting | `average: 100, burst: 50` |
| `stripPrefix` | Remove path prefix | `prefixes: ["/api"]` |
| `headers` | Add/modify headers | `CustomHeader: value` |
| `redirectScheme` | HTTPS redirect | `scheme: https` |
| `ipWhiteList` | IP filtering | `sourceRange: ["192.168.1.0/24"]` |
| `compress` | Response compression | `{}`
| `circuitBreaker` | Fault tolerance | `expression: NetworkErrorRatio() > 0.5` |

### Traefik Dashboard Access

**URL**: https://traefik.home.accelior.com

**Features**:
- View all HTTP/TCP routers
- View all services
- View all middlewares
- View certificate status
- Real-time metrics
- Search and filter

---

## Rollback Procedures

### Immediate Rollback (Service Level)

**If a migrated service fails**:

1. **Revert DNS**
   ```bash
   flarectl dns update --zone acmea.tech --id $RECORD_ID --content "192.168.1.121"
   ```

2. **Remove Traefik Labels** (optional, for isolation)
   ```bash
   # Edit docker-compose.yml
   # Comment out all traefik.* labels
   docker-compose up -d
   ```

3. **Verify Service Through NPM**
   - Access service via NPM
   - Check functionality

### Partial Rollback (Multiple Services)

**If multiple services have issues**:

1. **Update OPNsense NAT**
   - Forward 80/443 back to 192.168.1.121 (NPM)
   - Keep Traefik running for diagnosis

2. **Restart NPM**
   ```bash
   ssh root@192.168.1.121
   cd /srv/npm-docker
   docker-compose up -d
   ```

3. **Restore Proxy Hosts** (if deleted)
   ```bash
   # Use backup SQL
   sqlite3 /data/npm.db < npm-backup.sql
   ```

### Full Rollback

**If migration is critically flawed**:

1. **Complete NAT Reversion**
   - 80/443 → 192.168.1.121 (NPM)
   - Stop Traefik: `docker-compose down`

2. **DNS Mass Reversion**
   ```bash
   for record in $(flarectl dns list --zone acmea.tech | awk '{print $1}'); do
     flarectl dns update --zone acmea.tech --id $record --content "192.168.1.121"
   done
   ```

3. **Analyze Failure**
   - Review Traefik logs
   - Check certificate issues
   - Identify configuration errors

4. **Plan Retry**
   - Address root cause
   - Update migration plan
   - Retry in smaller batches

---

## Risk Assessment

### High Risk Items

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| SSL provisioning failure | Medium | High | Test with low-priority domains; parallel operation |
| Service-specific routing breaks | Low | Medium | Document custom configs before migration |
| Traefik misconfiguration | Low | High | Thorough testing in Phase 1; quick rollback |
| Cloudflare rate limiting | Low | Low | Stagger certificate requests |
| DNS propagation delays | Medium | Low | 48-hour verification period |
| Lost NPM configurations | Low | High | Complete backup before migration |

### Medium Risk Items

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Middleware complexity | Medium | Low | Use pre-configured middlewares |
| Non-Docker services | N/A | Medium | Use file provider; document separately |
| Team learning curve | Low | Low | Documentation; gradual migration |
| Performance degradation | Low | Medium | Monitor during migration |

### Low Risk Items

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Traefik resource usage | Low | Low | Monitor container metrics |
| Configuration drift | Low | Low | Git-based config management |

---

## Post-Migration Tasks

### 1. Monitoring and Observability

**Set up Traefik metrics**:
```yaml
# In traefik.yml
metrics:
  prometheus:
    entryPoint: metrics
    addEntryPointsLabels: true
    addServicesLabels: true

# Add metrics entrypoint
entryPoints:
  metrics:
    address: ":9090"
```

**Configure Prometheus scrape** (if using):
```yaml
- job_name: 'traefik'
  static_configs:
    - targets: ['traefik:9090']
```

### 2. Log Management

**Configure log rotation** (`/etc/logrotate.d/traefik`):
```
/docker/traefik/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 traefik traefik
    sharedscripts
    postrotate
        docker-compose -f /docker/traefik/docker-compose.yml exec traefik kill -USR1 1
    endscript
}
```

### 3. Backup Procedures

**Automated backups** (`/root/backup-traefik.sh`):
```bash
#!/bin/bash
BACKUP_DIR="/backups/traefik"
DATE=$(date +%Y%m%d)

mkdir -p $BACKUP_DIR

# Backup configuration
tar -czf $BACKUP_DIR/traefik-config-$DATE.tar.gz /docker/traefik/*.yml /docker/traefik/.env

# Backup ACME certificates
cp /docker/traefik/acme.json $BACKUP_DIR/acme-$DATE.json
chmod 600 $BACKUP_DIR/acme-$DATE.json

# Keep last 30 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
find $BACKUP_DIR -name "acme-*.json" -mtime +30 -delete
```

**Add to crontab**:
```
0 2 * * * /root/backup-traefik.sh
```

### 4. Documentation Updates

**Create/update documentation**:
- `/docs/traefik/README.md` - Main Traefik documentation
- `/docs/traefik/add-new-service.md` - How to add new service
- `/docs/traefik/troubleshooting.md` - Common issues and solutions
- `/docs/traefik/migration-summary.md` - What changed in migration

### 5. Runbook Updates

**Update operational procedures**:
- How to check service routing
- How to add middleware
- How to troubleshoot SSL issues
- How to access dashboard
- Emergency rollback steps

### 6. Team Training

**Knowledge sharing**:
- Traefik basics and architecture
- Label-based configuration
- Dashboard usage
- Common operations
- Troubleshooting techniques

---

## Success Criteria

### Migration Complete When:
- [ ] All 40+ services accessible through Traefik
- [ ] All SSL certificates valid and auto-renewing
- [ ] Zero manual intervention for new Docker services
- [ ] Traefik dashboard showing all routes correctly
- [ ] Uptime Kuma showing 100% service availability
- [ ] NPM fully stopped and data backed up
- [ ] Infrastructure database updated
- [ ] Complete documentation in `/docs/traefik/`
- [ ] Team trained on Traefik operations
- [ ] 30 days of stable operation

---

## Appendix A: Service Inventory Template

```markdown
| # | Domain | Backend | Port | SSL | Auth | Complexity | Wave | Status |
|---|--------|---------|------|-----|------|------------|-------|--------|
| 1 | portainer.acmea.tech | 192.168.1.20 | 9443 | Yes | Basic | Simple | 1 | Pending |
| 2 | uptime.acmea.tech | 192.168.1.20 | 3010 | Yes | None | Simple | 1 | Pending |
| ... | | | | | | | |
```

**Status Values**: Pending, In Progress, Migrated, Verified, Complete

**Complexity Values**:
- **Simple**: Standard HTTP/HTTPS, no auth
- **Medium**: Basic auth, custom paths
- **Complex**: Custom NGINX, streaming, non-Docker

---

## Appendix B: Troubleshooting

### Service Not Appearing in Traefik Dashboard

1. **Check labels**:
   ```bash
   docker inspect myapp | grep -A 20 traefik
   ```

2. **Verify network**:
   ```bash
   docker network inspect proxy | grep myapp
   ```

3. **Check Traefik logs**:
   ```bash
   docker logs traefik | grep myapp
   ```

### SSL Certificate Not Provisioning

1. **Check ACME file**:
   ```bash
   cat /docker/traefik/acme.json | jq .
   ```

2. **Verify Cloudflare token**:
   ```bash
   echo $CF_API_TOKEN | cut -c1-10
   ```

3. **Test DNS challenge**:
   ```bash
   dig _acme-challenge.myapp.acmea.tech TXT
   ```

### High Priority Issues

1. **Traefik not responding**
   - Check container status: `docker ps | grep traefik`
   - Check logs: `docker logs traefik --tail 100`
   - Verify ports not in use: `netstat -tulpn | grep -E ':(80|443)'`

2. **Service routing to wrong backend**
   - Verify service labels
   - Check for duplicate router names
   - Inspect Traefik dashboard routing table

3. **Certificate warnings**
   - Check certificate expiration in dashboard
   - Verify Cloudflare DNS records
   - Check ACME file for errors

---

## Appendix C: Useful Commands

### Traefik Management
```bash
# View real-time logs
docker logs -f traefik

# Restart Traefik
docker-compose restart traefik

# Reload configuration (no downtime)
docker kill -HUP traefik

# Check certificate status
cat /docker/traefik/acme.json | jq '.cloudflare.Certificates[] | {domain: .domain.notAfter}'
```

### Docker Operations
```bash
# Find containers with Traefik labels
docker ps --format "{{.Names}}" | xargs -I {} docker inspect {} | grep -A 10 traefik

# Connect container to proxy network
docker network connect proxy myapp

# Test label syntax
docker inspect myapp | jq '.[0].Config.Labels'
```

### DNS Operations
```bash
# List all DNS records
flarectl dns list --zone acmea.tech

# Update record
flarectl dns update --zone acmea.tech --id RECORD_ID --content "192.168.1.20"

# Create new record
flarectl dns create --zone acmea.tech --name myapp --type A --content "192.168.1.20" --proxy
```

---

## Appendix D: Resources

### Official Documentation
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Traefik Docker Provider](https://doc.traefik.io/traefik/providers/docker/)
- [Traefik Let's Encrypt](https://doc.traefik.io/traefik/https/acme/)

### Community Resources
- [Traefik Community Forum](https://community.traefik.io/)
- [Awesome Traefik](https://github.com/traefik/awesome-traefik)
- [Traefik GitHub](https://github.com/traefik/traefik)

### Migration References
- [Migration from Nginx to Traefik](https://medium.com/@disane1987/migrating-from-nginx-proxy-manager-to-traefik-334e8f2e1319)
- [NPM vs Traefik Comparison](https://blog.lrvt.de/nginx-proxy-manager-versus-traefik/)

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-01-30 | Initial migration plan created | Migration Planning |

---

**Next Steps**:
1. Review and approve this plan
2. Complete Phase 0 (inventory)
3. Begin Phase 1 (Traefik setup)
4. Execute migration per timeline
