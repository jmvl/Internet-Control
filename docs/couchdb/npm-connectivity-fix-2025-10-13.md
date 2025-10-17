# CouchDB Public Endpoint Connectivity Fix - 2025-10-13

## Issue Summary

**Problem**: CouchDB public endpoint `https://couchdb.acmea.tech/` was returning 504 Gateway Timeout errors despite successful DNS resolution, SSL certificate issuance, and internal CouchDB functionality.

**Root Cause**: Nginx Proxy Manager (NPM) was configured with incorrect `forward_scheme` value (`https` instead of `http`), causing NPM to attempt SSL handshake with CouchDB's HTTP-only backend endpoint.

**Resolution**: Fixed forward scheme configuration in NPM database and manually regenerated Nginx proxy configuration file.

---

## Infrastructure Context

### Network Topology
- **Public IP**: 94.105.107.145
- **Domain**: couchdb.acmea.tech (Cloudflare DNS, grey cloud/no proxy)
- **NPM Host**: 192.168.1.9:443 (Nginx Proxy Manager)
- **CouchDB Host**: 192.168.1.20:5984 (Docker container)
- **OPNsense Firewall**: 192.168.1.3 (handles port 443 forwarding to NPM)

### Service Details
- **CouchDB Version**: 3.5.0 (Apache CouchDB)
- **NPM Version**: 2.12.3
- **SSL Certificate**: Let's Encrypt (npm-52)
- **Certificate Domains**: couchdb.acmea.tech
- **Certificate Expiry**: 2026-01-11

---

## Diagnostic Process

### 1. Initial Symptoms
```bash
# DNS resolution working
$ dig couchdb.acmea.tech
# Returns: 94.105.107.145 (via CNAME to base.acmea.tech)

# Ping successful
$ ping 94.105.107.145
# 2-5ms response times

# HTTPS connection failing
$ curl https://couchdb.acmea.tech/
# Result: 504 Gateway Time-out
```

### 2. Configuration Analysis

**NPM Proxy Host Configuration** (`/srv/raid/config/nginx/data/nginx/proxy_host/38.conf`):
```nginx
set $forward_scheme https;  # ← INCORRECT
set $server         "192.168.1.20";
set $port           5984;
```

**Error Logs** (`/srv/raid/config/nginx/data/logs/proxy-host-38_error.log`):
```
[error] upstream timed out (110: Connection timed out) while SSL handshaking to upstream
upstream: "https://192.168.1.20:5984/"
```

**Key Finding**: NPM attempting HTTPS connection to CouchDB backend, but CouchDB listens on HTTP only.

### 3. CouchDB Verification
```bash
# Verify CouchDB responds on HTTP
$ ssh root@192.168.1.20 'curl -I http://localhost:5984'
HTTP/1.1 200 OK
Content-Type: application/json
Server: CouchDB/3.5.0 (Erlang OTP/26)
```

---

## Resolution Steps

### Step 1: Update NPM Database
NPM stores configuration in SQLite database, which generates Nginx config files on startup/change.

```bash
# Connect to NPM host
ssh root@192.168.1.9

# Update forward_scheme in database
sqlite3 /srv/raid/config/nginx/data/database.sqlite \
  "UPDATE proxy_host SET forward_scheme = 'http' WHERE id = 38;"

# Verify change
sqlite3 /srv/raid/config/nginx/data/database.sqlite \
  "SELECT id, domain_names, forward_scheme, forward_host, forward_port FROM proxy_host WHERE id = 38;"
# Output: 38|["couchdb.acmea.tech"]|http|192.168.1.20|5984
```

### Step 2: Regenerate Nginx Configuration
NPM generates Nginx configs from database via internal service. Manual regeneration required:

```bash
# Create corrected configuration file
cat > /srv/raid/config/nginx/data/nginx/proxy_host/38.conf << 'EOF'
# ------------------------------------------------------------
# couchdb.acmea.tech
# ------------------------------------------------------------

map $scheme $hsts_header {
    https   "max-age=63072000; preload";
}

server {
  set $forward_scheme http;  # ← FIXED
  set $server         "192.168.1.20";
  set $port           5984;

  listen 80;
  listen [::]:80;
  listen 443 ssl;
  listen [::]:443 ssl;

  server_name couchdb.acmea.tech;
  http2 on;

  # SSL configuration
  include conf.d/include/letsencrypt-acme-challenge.conf;
  include conf.d/include/ssl-cache.conf;
  include conf.d/include/ssl-ciphers.conf;
  ssl_certificate /etc/letsencrypt/live/npm-52/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/npm-52/privkey.pem;

  # Security
  include conf.d/include/block-exploits.conf;
  include conf.d/include/force-ssl.conf;

  # WebSocket support
  proxy_set_header Upgrade $http_upgrade;
  proxy_set_header Connection $http_connection;
  proxy_http_version 1.1;

  # Logging
  access_log /data/logs/proxy-host-38_access.log proxy;
  error_log /data/logs/proxy-host-38_error.log warn;

  location / {
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $http_connection;
    proxy_http_version 1.1;
    include conf.d/include/proxy.conf;
  }

  include /data/nginx/custom/server_proxy[.]conf;
}
EOF

# Test and reload Nginx
docker exec nginx-proxy-manager-nginx-proxy-manager-1 nginx -t
docker exec nginx-proxy-manager-nginx-proxy-manager-1 nginx -s reload
```

### Step 3: Verification
```bash
# Test API endpoint
$ curl -s https://couchdb.acmea.tech/ | jq .
{
  "couchdb": "Welcome",
  "version": "3.5.0",
  "git_sha": "11f0d3643",
  "uuid": "222fc45254c49d6662ff3a4cc8fa6f66",
  "features": [
    "access-ready",
    "partitioned",
    "pluggable-storage-engines",
    "reshard",
    "scheduler"
  ],
  "vendor": {
    "name": "The Apache Software Foundation"
  }
}

# Test web interface
$ curl -I https://couchdb.acmea.tech/_utils/
HTTP/2 200
server: openresty
content-type: text/html
```

---

## Technical Analysis

### Why NPM Had HTTPS Backend Configuration

1. **NPM Web UI Defaults**: When creating a proxy host through NPM web interface, the forward scheme dropdown defaults to `https` if SSL is enabled for the public endpoint.

2. **Confusion Between Frontend and Backend SSL**:
   - **Frontend SSL** (internet → NPM): Always HTTPS with Let's Encrypt certificate
   - **Backend SSL** (NPM → CouchDB): Should match backend service configuration
   - CouchDB by default listens on HTTP port 5984 (HTTPS requires additional configuration)

3. **Configuration Persistence**: NPM stores settings in SQLite database (`/srv/raid/config/nginx/data/database.sqlite`), which persists across container restarts and config regenerations.

### NPM Configuration Architecture

```
┌─────────────────────────────────────────────────────────┐
│ NPM Configuration Flow                                  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. Web UI/API                                          │
│     └─> Writes to database.sqlite                       │
│                                                          │
│  2. Backend Service (Node.js)                           │
│     └─> Reads database.sqlite                           │
│     └─> Generates Nginx configs from Jinja2 templates  │
│     └─> Writes to /data/nginx/proxy_host/*.conf        │
│                                                          │
│  3. Nginx Process                                       │
│     └─> Loads generated configs                         │
│     └─> Proxies traffic to backends                     │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Key Files**:
- **Database**: `/data/database.sqlite` (persistent storage)
- **Template**: `/app/templates/proxy_host.conf` (Jinja2 template)
- **Generated Configs**: `/data/nginx/proxy_host/*.conf` (auto-generated)

### SSL/TLS Configuration Layers

**Client → NPM (Public Internet)**:
```
HTTPS (TLS 1.3)
Certificate: Let's Encrypt (npm-52)
Domain: couchdb.acmea.tech
Port: 443
```

**NPM → CouchDB (Internal Network)**:
```
HTTP (no encryption)
Host: 192.168.1.20
Port: 5984
Scheme: http  ← CRITICAL SETTING
```

**Security Consideration**: Internal traffic is unencrypted but isolated within private network (192.168.1.0/24). For enhanced security, CouchDB could be configured with SSL, but this is typically unnecessary for internal-only communication.

---

## Future Prevention Measures

### 1. Configuration Validation Checklist
When adding new NPM proxy hosts:
- [ ] Verify backend service protocol (HTTP vs HTTPS)
- [ ] Test backend connectivity: `curl http://backend-ip:port/`
- [ ] Match NPM forward scheme to backend protocol
- [ ] Test public endpoint after configuration
- [ ] Monitor error logs for SSL handshake timeouts

### 2. Monitoring Alerts
Add Uptime Kuma checks for:
- **Endpoint availability**: https://couchdb.acmea.tech/
- **Expected response**: Check for `"couchdb": "Welcome"` in JSON
- **Response time**: Alert if > 2000ms
- **SSL certificate expiry**: Alert 14 days before expiration

### 3. Documentation Requirements
For each new public endpoint:
- Document forward scheme configuration
- Note SSL requirements (frontend vs backend)
- Include connectivity test commands
- Record NPM proxy host ID for troubleshooting

### 4. NPM Backup Strategy
```bash
# Backup NPM database before major changes
ssh root@192.168.1.9 'cp /srv/raid/config/nginx/data/database.sqlite \
  /srv/raid/config/nginx/data/database.sqlite.backup-$(date +%Y%m%d)'
```

---

## Related Services

### CouchDB Configuration
**Docker Compose** (on 192.168.1.20):
```yaml
services:
  couchdb:
    image: couchdb:latest
    ports:
      - "5984:5984"
    environment:
      COUCHDB_USER: admin
      COUCHDB_PASSWORD: ${COUCHDB_PASSWORD}
    volumes:
      - couchdb-data:/opt/couchdb/data
```

**Access Points**:
- **Internal HTTP**: http://192.168.1.20:5984/
- **Public HTTPS**: https://couchdb.acmea.tech/
- **Web Interface**: https://couchdb.acmea.tech/_utils/

### SSL Certificate Management
**Certificate Details**:
- **Provider**: Let's Encrypt
- **NPM Certificate ID**: npm-52
- **Issue Date**: 2025-10-13 15:13:46 GMT
- **Expiry Date**: 2026-01-11 15:13:45 GMT
- **Auto-renewal**: Managed by NPM Certbot integration

**Certificate Files** (inside NPM container):
```
/etc/letsencrypt/live/npm-52/
├── cert.pem       -> ../../archive/npm-52/cert1.pem
├── chain.pem      -> ../../archive/npm-52/chain1.pem
├── fullchain.pem  -> ../../archive/npm-52/fullchain1.pem
└── privkey.pem    -> ../../archive/npm-52/privkey1.pem
```

---

## Troubleshooting Guide

### Symptom: 504 Gateway Timeout

**Diagnostic Steps**:
```bash
# 1. Check NPM error logs
ssh root@192.168.1.9 'tail -50 /srv/raid/config/nginx/data/logs/proxy-host-38_error.log'

# Look for:
# - "SSL handshaking to upstream" → Forward scheme mismatch
# - "Connection refused" → Wrong port or backend down
# - "Connection timed out" → Network/firewall issue
```

```bash
# 2. Verify backend connectivity from NPM host
ssh root@192.168.1.9 'curl -I http://192.168.1.20:5984/'
# Expected: HTTP/1.1 200 OK

# 3. Check NPM configuration
ssh root@192.168.1.9 'cat /srv/raid/config/nginx/data/nginx/proxy_host/38.conf | grep forward_scheme'
# Expected: set $forward_scheme http;

# 4. Verify database configuration
ssh root@192.168.1.9 'sqlite3 /srv/raid/config/nginx/data/database.sqlite \
  "SELECT forward_scheme, forward_host, forward_port FROM proxy_host WHERE domain_names LIKE \"%couchdb%\";"'
```

### Symptom: SSL Certificate Errors

**Diagnostic Steps**:
```bash
# Check certificate validity
openssl s_client -connect couchdb.acmea.tech:443 -servername couchdb.acmea.tech < /dev/null 2>/dev/null | \
  openssl x509 -noout -dates -subject

# Verify certificate files exist
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  ls -la /etc/letsencrypt/live/npm-52/'

# Check NPM certificate renewal logs
ssh root@192.168.1.9 'docker logs nginx-proxy-manager-nginx-proxy-manager-1 | grep -i "npm-52"'
```

### Symptom: Connection Refused

**Diagnostic Steps**:
```bash
# 1. Verify CouchDB container running
ssh root@192.168.1.20 'docker ps --filter "name=couchdb"'

# 2. Check CouchDB port binding
ssh root@192.168.1.20 'netstat -tlnp | grep 5984'

# 3. Test CouchDB from Docker host
ssh root@192.168.1.20 'curl -I http://localhost:5984/'

# 4. Check Docker network connectivity
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  curl -I http://192.168.1.20:5984/ --connect-timeout 5'
```

---

## Maintenance Procedures

### Updating CouchDB Configuration

If changing CouchDB to HTTPS (not recommended for internal use):

1. Configure CouchDB SSL in Docker Compose
2. Update NPM database:
   ```bash
   sqlite3 /srv/raid/config/nginx/data/database.sqlite \
     "UPDATE proxy_host SET forward_scheme = 'https' WHERE id = 38;"
   ```
3. Regenerate Nginx config or restart NPM
4. Update this documentation

### NPM Configuration Changes

**Recommended Method** (through NPM Web UI):
1. Access NPM at https://nginx.home.accelior.com/
2. Navigate to Proxy Hosts → couchdb.acmea.tech
3. Edit → Details → Forward Scheme → Select "http"
4. Save and test

**Emergency Method** (direct database edit):
```bash
# Backup database
ssh root@192.168.1.9 'cp /srv/raid/config/nginx/data/database.sqlite{,.emergency-backup}'

# Update configuration
ssh root@192.168.1.9 'sqlite3 /srv/raid/config/nginx/data/database.sqlite "UPDATE proxy_host SET forward_scheme = \"http\" WHERE id = 38;"'

# Restart NPM to regenerate configs
ssh root@192.168.1.9 'docker restart nginx-proxy-manager-nginx-proxy-manager-1'

# Wait for startup and test
sleep 15
curl -I https://couchdb.acmea.tech/
```

---

## References

### Documentation
- **CouchDB Official**: https://docs.couchdb.org/
- **NPM GitHub**: https://github.com/NginxProxyManager/nginx-proxy-manager
- **Infrastructure Overview**: `/docs/infrastructure.md`

### Related Incidents
- None (first documented issue for this service)

### Team Contacts
- **Infrastructure Owner**: System Administrator
- **CouchDB Service Owner**: Development Team
- **Monitoring**: Uptime Kuma (https://uptime.home.accelior.com/)

---

## Incident Timeline

**2025-10-13 16:12:04** - CouchDB proxy host created in NPM (ID: 38)
**2025-10-13 16:12:24** - First 504 errors logged (wrong port 5884)
**2025-10-13 16:20:xx** - Port corrected to 5984, but forward_scheme remained https
**2025-10-13 16:24:07** - SSL handshake timeout errors begin
**2025-10-13 16:33:13** - Database updated with correct forward_scheme (http)
**2025-10-13 16:46:xx** - Manual Nginx config regeneration
**2025-10-13 16:47:00** - Service fully operational

**Total Downtime**: ~35 minutes
**Root Cause**: Configuration error (forward_scheme mismatch)
**Resolution**: Database update + manual config regeneration

---

## Change Log

| Date | Author | Change |
|------|--------|--------|
| 2025-10-13 | Claude Code | Initial documentation after incident resolution |

---

## Appendices

### A. NPM Database Schema (proxy_host table)
```sql
CREATE TABLE proxy_host (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_on DATETIME NOT NULL,
    modified_on DATETIME NOT NULL,
    owner_user_id INTEGER NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    domain_names TEXT NOT NULL,           -- JSON array
    forward_host VARCHAR(255) NOT NULL,
    forward_port INTEGER NOT NULL,
    access_list_id INTEGER NOT NULL DEFAULT 0,
    certificate_id INTEGER NOT NULL DEFAULT 0,
    ssl_forced BOOLEAN NOT NULL DEFAULT 0,
    caching_enabled BOOLEAN NOT NULL DEFAULT 0,
    block_exploits BOOLEAN NOT NULL DEFAULT 0,
    advanced_config TEXT,
    meta TEXT,                            -- JSON object
    allow_websocket_upgrade BOOLEAN NOT NULL DEFAULT 0,
    http2_support BOOLEAN NOT NULL DEFAULT 0,
    forward_scheme VARCHAR(10) NOT NULL,  -- 'http' or 'https'
    enabled BOOLEAN NOT NULL DEFAULT 1,
    locations TEXT,                       -- JSON array
    hsts_enabled BOOLEAN NOT NULL DEFAULT 0,
    hsts_subdomains BOOLEAN NOT NULL DEFAULT 0
);
```

### B. Useful Commands Reference
```bash
# NPM container management
docker ps --filter "name=nginx-proxy-manager"
docker logs nginx-proxy-manager-nginx-proxy-manager-1 --tail 100
docker exec nginx-proxy-manager-nginx-proxy-manager-1 nginx -t
docker exec nginx-proxy-manager-nginx-proxy-manager-1 nginx -s reload
docker restart nginx-proxy-manager-nginx-proxy-manager-1

# CouchDB container management
ssh root@192.168.1.20 'docker ps --filter "name=couchdb"'
ssh root@192.168.1.20 'docker logs couchdb --tail 100'
ssh root@192.168.1.20 'curl http://localhost:5984/_up'

# NPM database queries
ssh root@192.168.1.9 'sqlite3 /srv/raid/config/nginx/data/database.sqlite \
  "SELECT id, domain_names, forward_scheme, forward_host, forward_port, enabled FROM proxy_host;"'

# Log monitoring
ssh root@192.168.1.9 'tail -f /srv/raid/config/nginx/data/logs/proxy-host-38_*.log'

# SSL certificate check
curl -vI https://couchdb.acmea.tech/ 2>&1 | grep -E "subject|expire|issuer"
```
