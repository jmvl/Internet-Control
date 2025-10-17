# Netdata Internet Publishing - October 10, 2025

**Date**: 2025-10-10
**Service**: Netdata Monitoring Dashboard
**URL**: https://netdata.acmea.tech
**Status**: ✅ **LIVE AND OPERATIONAL**

---

## Overview

Successfully published Netdata monitoring dashboard to the internet with full SSL/TLS encryption and proper DNS configuration.

### Service Details

| Component | Details |
|-----------|---------|
| **Public URL** | https://netdata.acmea.tech |
| **Backend Service** | Netdata v2.7.1 on 192.168.1.20:19999 |
| **Reverse Proxy** | Nginx Proxy Manager (192.168.1.9) |
| **SSL Certificate** | Let's Encrypt (valid until 2026-01-08) |
| **Certificate ID** | npm-50 (NPM database ID: 50) |
| **Proxy Host ID** | 32 (NPM database) |

---

## Architecture

### Traffic Flow

```
Internet
  ↓
home.accelior.com (Dynamic DNS via OPNsense)
  ↓ (94.105.107.145 - Current WAN IP)
netdata.acmea.tech (CNAME)
  ↓
OPNsense NAT (192.168.1.3)
  ↓ (Port 80/443 forwarding)
NPM (192.168.1.9)
  ↓ (Proxy host 32)
Netdata Container (192.168.1.20:19999)
```

### Network Components

1. **OPNsense Firewall (192.168.1.3)**
   - WAN Interface: pppoe0 (94.105.107.145)
   - NAT Rules: Forward ports 80/443 to 192.168.1.9 (NPM)
   - Dynamic DNS: Updates home.accelior.com via Cloudflare API

2. **Nginx Proxy Manager (192.168.1.9)**
   - Container: nginx-proxy-manager-nginx-proxy-manager-1
   - Listening: 0.0.0.0:80, 0.0.0.0:443
   - Config File: `/data/nginx/proxy_host/32.conf`
   - Database: SQLite at `/data/database.sqlite`

3. **Netdata Service (192.168.1.20:19999)**
   - Container: netdata (Docker host: docker-debian PCT-111)
   - Version: v2.7.1
   - Internal Port: 19999
   - Accessibility: Internal network + via NPM proxy

---

## DNS Configuration

### Cloudflare DNS Records

**Zone**: acmea.tech (Zone ID: 0eca1e8adfd8b1109320d67050d633ab)

```
netdata.acmea.tech → CNAME → home.accelior.com
  ↓
home.accelior.com → A → 94.105.107.145 (auto-updated by OPNsense DDNS)
```

**Record Details**:
- **Name**: netdata.acmea.tech
- **Type**: CNAME
- **Content**: home.accelior.com
- **Record ID**: a90f9df5d57d5c6fac384b9bbecae469
- **TTL**: Auto

### Dynamic DNS Setup

**OPNsense Dynamic DNS Service**:
- **Primary Domain**: home.accelior.com
- **Provider**: Cloudflare API v6
- **Interface**: opt1 (pppoe0)
- **Update Frequency**: Automatic on WAN IP change
- **TTL**: 30 seconds

**Why home.accelior.com?**
- OPNsense automatically updates this domain when WAN IP changes
- All subdomains should CNAME to home.accelior.com for automatic IP tracking
- base.acmea.tech points to OLD static IP (77.109.77.7) and is NOT updated

---

## SSL Certificate Configuration

### Certificate Generation

**Method**: DNS-01 Challenge via Cloudflare API

**Generation Command**:
```bash
docker exec nginx-proxy-manager-nginx-proxy-manager-1 certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /tmp/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  -d netdata.acmea.tech \
  --email admin@acmea.tech \
  --agree-tos \
  --non-interactive
```

**Certificate Details**:
- **Issuer**: Let's Encrypt
- **Subject**: CN=netdata.acmea.tech
- **Valid From**: 2025-10-10
- **Valid Until**: 2026-01-08
- **Storage Path**: `/etc/letsencrypt/live/netdata-acmea-tech/`
- **Symlink Path**: `/etc/letsencrypt/live/npm-50/` (for NPM compatibility)

### NPM Certificate Database Entry

```sql
INSERT INTO certificate (id, created_on, modified_on, provider, nice_name, domain_names, expires_on, meta)
VALUES (
  50,
  datetime('now'),
  datetime('now'),
  'letsencrypt',
  'netdata.acmea.tech',
  '["netdata.acmea.tech"]',
  '2026-01-08 08:39:23',
  '{"dns_challenge":true,"dns_provider":"cloudflare","dns_provider_credentials":"/tmp/cloudflare.ini"}'
);
```

---

## Nginx Proxy Manager Configuration

### Proxy Host Configuration

**NPM Proxy Host #32**: `/data/nginx/proxy_host/32.conf`

```nginx
# ------------------------------------------------------------
# netdata.acmea.tech
# ------------------------------------------------------------

server {
  set $forward_scheme http;
  set $server         "192.168.1.20";
  set $port           19999;

  listen 80;
  listen [::]:80;

  server_name netdata.acmea.tech;

  return 301 https://$host$request_uri;
}

server {
  set $forward_scheme http;
  set $server         "192.168.1.20";
  set $port           19999;

  listen 443 ssl http2;
  listen [::]:443 ssl http2;

  server_name netdata.acmea.tech;

  ssl_certificate /etc/letsencrypt/live/npm-50/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/npm-50/privkey.pem;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!aNULL:!MD5;
  ssl_prefer_server_ciphers on;

  add_header Strict-Transport-Security "max-age=63072000; preload" always;

  # Block Exploits
  include conf.d/include/block-exploits.conf;

  # Asset Caching
  include conf.d/include/assets.conf;

  access_log /data/logs/proxy-host-32_access.log proxy;
  error_log /data/logs/proxy-host-32_error.log warn;

  location / {
    proxy_pass http://192.168.1.20:19999;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_buffering off;
    proxy_read_timeout 300;
  }
}
```

### Database Configuration

**NPM Database**: `/data/database.sqlite`

```sql
-- Proxy Host Record (ID: 32)
UPDATE proxy_host SET
  certificate_id = 50,
  ssl_forced = 1,
  hsts_enabled = 1,
  hsts_subdomains = 0,
  http2_support = 1
WHERE id = 32;
```

---

## Deployment Steps Summary

### 1. Service Discovery
```bash
# Located Netdata container on 192.168.1.20:19999
ssh root@192.168.1.10 'pct exec 111 -- docker ps --filter name=netdata'
```

### 2. DNS Configuration
```bash
# Updated Cloudflare DNS to use dynamic DNS domain
# Changed: netdata.acmea.tech → base.acmea.tech
# To: netdata.acmea.tech → home.accelior.com
```

### 3. SSL Certificate Generation
```bash
# Installed certbot-dns-cloudflare plugin
docker exec npm pip install certbot-dns-cloudflare==3.2.0

# Generated certificate using DNS-01 challenge
docker exec npm certbot certonly --dns-cloudflare ...

# Created symlink for NPM compatibility
docker exec npm ln -s /etc/letsencrypt/live/netdata-acmea-tech /etc/letsencrypt/live/npm-50
```

### 4. NPM Configuration
```bash
# Added certificate to NPM database
sqlite3 /data/database.sqlite < certificate-insert.sql

# Created manual nginx configuration
# Updated proxy_host database record with certificate_id
```

### 5. Verification
```bash
# Tested DNS resolution
dig +short netdata.acmea.tech
# Returns: home.accelior.com → 94.105.107.145

# Verified SSL certificate
openssl s_client -connect netdata.acmea.tech:443 -servername netdata.acmea.tech

# Tested service accessibility
curl -s https://netdata.acmea.tech | head -5
# Returns: Netdata HTML page
```

---

## Troubleshooting & Lessons Learned

### Issue 1: Wrong WAN IP in DNS
**Problem**: base.acmea.tech pointed to old static IP (77.109.77.7)
**Current WAN IP**: 94.105.107.145 (dynamic, changes with ISP)
**Solution**: Changed netdata.acmea.tech to CNAME to home.accelior.com (auto-updated by OPNsense DDNS)

### Issue 2: HTTP-01 ACME Challenge Failure
**Problem**: Apache on base domain redirecting ACME challenge requests to HTTPS
**Error**: `Invalid response from https://netdata.acmea.tech/.well-known/acme-challenge/`
**Solution**: Used DNS-01 challenge with Cloudflare API instead

### Issue 3: NPM Version Compatibility
**Problem**: Upgrading certbot to 5.1.0 broke NPM web UI login
**Error**: "Cannot read properties of undefined (reading 'replaceAll')"
**Solution**: Downgraded certbot back to 3.2.0 (NPM-compatible version)

### Issue 4: OPNsense NAT Rules Confusion
**Problem**: Initially thought port forwarding was misconfigured
**Reality**: NAT rules were correct all along - issue was DNS pointing to wrong IP
**Verification**:
```bash
pfctl -s nat | grep -E "(80|443)"
# Showed correct forwarding to <omv> (192.168.1.9)
```

### Issue 5: Certificate Mismatch
**Problem**: NPM serving wrong certificate (cloud.leleux.me) initially
**Cause**: Nginx configuration not reloaded after manual certificate setup
**Solution**:
```bash
docker exec npm nginx -s reload
```

---

## Testing & Verification

### DNS Resolution
```bash
# Verify DNS chain
dig +short netdata.acmea.tech
# Expected: home.accelior.com → 94.105.107.145

# Verify DNS propagation
dig @1.1.1.1 netdata.acmea.tech
dig @8.8.8.8 netdata.acmea.tech
```

### SSL Certificate Validation
```bash
# Check certificate details
openssl s_client -connect netdata.acmea.tech:443 -servername netdata.acmea.tech 2>/dev/null | openssl x509 -noout -subject -issuer -dates

# Verify certificate in NPM
docker exec npm openssl x509 -in /etc/letsencrypt/live/npm-50/fullchain.pem -noout -subject
```

### Service Accessibility
```bash
# Test HTTP redirect to HTTPS
curl -I http://netdata.acmea.tech
# Expected: 301 redirect to https://

# Test HTTPS service
curl -s https://netdata.acmea.tech | head -5
# Expected: Netdata HTML page

# Test from external network
curl -I https://netdata.acmea.tech
# Expected: HTTP/2 200 OK (or 400 for HEAD requests)
```

### Backend Connectivity
```bash
# Test Netdata directly
curl -s http://192.168.1.20:19999 | head -5

# Test from NPM host
ssh root@192.168.1.9 'curl -I http://192.168.1.20:19999'

# Verify container status
ssh root@192.168.1.10 'pct exec 111 -- docker ps --filter name=netdata'
```

---

## Maintenance

### Certificate Renewal

**Auto-Renewal**: Certbot will automatically renew 30 days before expiration

**Manual Renewal**:
```bash
# Renew certificate
docker exec npm certbot renew --dns-cloudflare

# Reload nginx
docker exec npm nginx -s reload

# Verify new expiration date
docker exec npm openssl x509 -in /etc/letsencrypt/live/npm-50/fullchain.pem -noout -dates
```

### DNS Updates

**Automatic**: OPNsense DDNS updates home.accelior.com when WAN IP changes

**Verify DDNS Status**:
```bash
# Check OPNsense dynamic DNS service
ssh root@opnsense 'configctl dyndns status'

# Verify current WAN IP
ssh root@opnsense 'ifconfig pppoe0 | grep inet'
```

### NPM Configuration Updates

**Reload Configuration**:
```bash
# Test nginx configuration
docker exec npm nginx -t

# Reload nginx
docker exec npm nginx -s reload
```

**Backup Configuration**:
```bash
# Backup nginx config
docker cp npm:/data/nginx/proxy_host/32.conf /backup/netdata-npm-config-$(date +%Y%m%d).conf

# Backup database
docker exec npm sqlite3 /data/database.sqlite ".backup /data/database-backup-$(date +%Y%m%d).sqlite"
```

---

## Security Considerations

### Access Control

**Current**: Public access (no authentication)
**Recommendation**: Consider adding NPM access list or basic authentication

**Add Authentication** (if needed):
```bash
# Via NPM web UI:
# 1. Edit proxy host #32
# 2. Go to "Access" tab
# 3. Enable "Access List"
# 4. Create new access list with basic auth
```

### SSL/TLS Configuration

- ✅ TLS 1.2 and 1.3 only
- ✅ Strong cipher suites
- ✅ HSTS enabled (max-age=63072000)
- ✅ Automatic security headers via NPM

### Firewall Rules

**OPNsense**:
- ✅ Port forwarding limited to ports 80/443
- ✅ Traffic restricted to NPM (192.168.1.9)
- ✅ No direct external access to Netdata

---

## Future Improvements

### 1. Authentication
- [ ] Add NPM access list for basic authentication
- [ ] Consider OAuth integration if available

### 2. Monitoring
- [ ] Add to Uptime Kuma for availability monitoring
- [ ] Configure SSL certificate expiration alerts

### 3. Performance
- [ ] Consider enabling NPM caching for static assets
- [ ] Evaluate CDN integration if external usage increases

### 4. Automation
- [ ] Create automated certificate renewal verification script
- [ ] Set up DNS update monitoring/alerting

---

## Related Documentation

- **Netdata Update Log**: `/docs/netdata/netdata-update-2025-10-10.md`
- **NPM Configuration**: Container 192.168.1.9
- **OPNsense DDNS**: `home.accelior.com` setup
- **Infrastructure Overview**: `/docs/infrastructure.md`

---

## Quick Reference

### Service URLs
- **Public HTTPS**: https://netdata.acmea.tech
- **Direct Access**: http://192.168.1.20:19999 (internal only)
- **NPM Web UI**: http://192.168.1.9:81

### Key Files
- **NPM Config**: `/data/nginx/proxy_host/32.conf`
- **SSL Certificate**: `/etc/letsencrypt/live/npm-50/`
- **NPM Database**: `/data/database.sqlite`

### Important IPs
- **Netdata**: 192.168.1.20:19999
- **NPM**: 192.168.1.9:80/443
- **OPNsense**: 192.168.1.3
- **WAN IP**: 94.105.107.145 (dynamic)

---

**Status**: ✅ **DEPLOYMENT SUCCESSFUL**
**Last Verified**: 2025-10-10 09:01 CEST
**Next Review**: Check certificate renewal on 2025-12-10
