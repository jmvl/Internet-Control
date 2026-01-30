# dinero.cash Hosting Documentation

**Last Updated**: 2026-01-16
**Status**: Active - Healthy
**Location**: HestiaCP PCT 130 (192.168.1.30)

## Overview

Dinero.cash is a static website hosted on HestiaCP with the following architecture:

```
Internet → Cloudflare CDN → OPNsense → NPM (192.168.1.9) → Hestia (192.168.1.30)
          (77.109.112.226)  (192.168.1.3)  (Proxy)           (Nginx → Apache)
```

## Quick Reference

| Item | Value |
|------|-------|
| **Domain** | dinero.cash, www.dinero.cash |
| **Public IP** | 77.109.112.226 |
| **Hestia Host** | 192.168.1.30 (PCT 130) |
| **NPM Proxy** | 192.168.1.9:443 |
| **Cloudflare Zone** | dinero.cash (ID: 75cce327dde5a31e4e51f0fb1337c41b) |
| **Web Files** | `/home/dinero/web/dinero.cash/public_html/` |
| **SSL Certificate** | Let's Encrypt (via NPM) |
| **Hestia User** | dinero |

## Architecture Details

### 1. Traffic Flow

```
User Request
    ↓
Cloudflare CDN (orange cloud proxy)
    ↓
OPNsense Firewall (Port 80/443 forwarding)
    ↓
Nginx Proxy Manager (192.168.1.9)
    ├─ Proxy Host #47
    ├─ Forward scheme: https
    ├─ Forward host: 192.168.1.30
    └─ Forward port: 443
    ↓
HestiaCP Nginx (192.168.1.30:443)
    ↓
Apache Backend (192.168.1.30:8080)
    ↓
Static HTML Files
```

### 2. Server Configuration

#### HestiaCP (192.168.1.30)

**Web Stack**: Nginx (frontend) → Apache (backend)

- **Nginx Listens**: 0.0.0.0:80, 0.0.0.0:443
- **Apache Listens**: 127.0.0.1:8080 (HTTP), 127.0.0.1:8443 (HTTPS)
- **SSL Certs**: `/home/dinero/conf/web/dinero.cash/ssl/`
- **Web Root**: `/home/dinero/web/dinero.cash/public_html/`

#### Nginx Proxy Manager (192.168.1.9)

**Proxy Host #47 Configuration**:
```nginx
server_name: dinero.cash www.dinero.cash
forward_scheme: https
forward_host: 192.168.1.30
forward_port: 443
ssl: enabled (Let's Encrypt)
http2: enabled
websockets: enabled
```

Config file: `/data/nginx/proxy_host/47.conf`

### 3. DNS Configuration

#### Cloudflare DNS Records

| Type | Name | Content | Proxy | TTL |
|------|------|---------|-------|-----|
| A | dinero.cash | 77.109.112.226 | ✅ ON | 1 |
| CNAME | www.dinero.cash | dinero.cash | ✅ ON | 60 |
| CNAME | *.dinero.cash | nginx.home.accelior.com | ❌ OFF | 3600 |

**Zone ID**: `75cce327dde5a31e4e51f0fb1337c41b`

## Management Procedures

### Cloudflare DNS Management via CLI

**API Token**: Configured in environment variable `CF_API_TOKEN`
**Account**: jmvl@accelior.com

```bash
# List all zones
export CF_API_TOKEN="RZ5klBDFKSUqBSnb8lJgzuUzwbh4v5Yd8UwgpNzA"
flarectl zone list

# List DNS records for dinero.cash
flarectl dns list --zone dinero.cash

# Update DNS record
flarectl dns update --zone dinero.cash --id <record-id> --content <ip> --proxy true

# Create new DNS record
flarectl dns create --zone dinero.cash --name subdomain --type A --content 77.109.112.226 --proxy
```

### NPM Proxy Host Management

```bash
# SSH to OMV server
ssh root@192.168.1.9

# List proxy hosts
docker exec nginx-proxy-manager-nginx-proxy-manager-1 ls /data/nginx/proxy_host/

# View proxy host config
docker exec nginx-proxy-manager-nginx-proxy-manager-1 cat /data/nginx/proxy_host/47.conf

# Restart NPM
docker restart nginx-proxy-manager-nginx-proxy-manager-1
```

### HestiaCP Management

```bash
# SSH to Hestia container
ssh root@192.168.1.30

# Check web service status
systemctl status nginx
systemctl status apache2

# View Nginx configuration for dinero.cash
nginx -T | grep -A 20 "dinero.cash"

# Restart web services
systemctl restart nginx
systemctl restart apache2

# Check web logs
tail -f /var/log/nginx/domains/dinero.cash.error.log
tail -f /var/log/apache2/domains/dinero.cash.error.log
```

### Web File Management

```bash
# SSH to Hestia
ssh root@192.168.1.30

# Navigate to web root
cd /home/dinero/web/dinero.cash/public_html/

# List files
ls -lh

# Check file ownership (should be dinero:dinero)
chown -R dinero:dinero /home/dinero/web/dinero.cash/public_html/
```

## Troubleshooting

### Issue: Site Not Accessible

**Symptoms**: Connection timeout, 502 errors, or "connection refused"

**Diagnosis Steps**:

1. **Check DNS Resolution**
   ```bash
   dig +short dinero.cash
   # Should return: 77.109.112.226
   ```

2. **Test Direct Access to Hestia**
   ```bash
   curl -I http://192.168.1.30/ -H "Host: dinero.cash"
   # Should return: HTTP/1.1 200
   ```

3. **Test NPM to Hestia Connectivity**
   ```bash
   ssh root@192.168.1.9 "curl -I https://192.168.1.30/ -k -H 'Host: dinero.cash'"
   # Should return: HTTP/2 200
   ```

4. **Check iptables Rules**
   ```bash
   ssh root@192.168.1.30 "iptables -L INPUT -n -v | grep -E '(80|443)'"
   # Ensure no REJECT rules blocking ports 80/443
   ```

5. **Check Cloudflare Proxy Status**
   ```bash
   flarectl dns list --zone dinero.cash
   # Verify PROXIED column shows "true" for dinero.cash
   ```

### Issue: Stale fail2ban Chain Blocking Ports

**Symptoms**: Connections to ports 80/443 refused despite Nginx running

**Diagnosis**:
```bash
ssh root@192.168.1.30 "iptables -L -n -v | grep fail2ban"
# Look for: fail2ban-WEB chain with REJECT rules
```

**Fix**:
```bash
ssh root@192.168.1.30 "iptables -D INPUT 2 && iptables -F fail2ban-WEB && iptables -X fail2ban-WEB"
```

### Issue: SSL Certificate Errors

**Symptoms**: Browser warnings about self-signed certificates

**Diagnosis**:
```bash
# Check SSL certificate
echo | openssl s_client -connect dinero.cash:443 -servername dinero.cash 2>&1 | grep -E "(subject|issuer)"
```

**Expected Output**:
```
subject=CN = dinero.cash
issuer=C = US, O = Let's Encrypt, CN = E7
```

**Resolution**:
- Cloudflare proxy must be **ON** (orange cloud) for Universal SSL to work
- NPM handles Let's Encrypt certificates for the origin
- Update DNS: `flarectl dns update --zone dinero.cash --id <id> --proxy true`

### Issue: HTTP to HTTPS Redirect Not Working

**Diagnosis**:
```bash
curl -I http://dinero.cash/
# Should return: 301 Moved Permanently
# Location: https://dinero.cash/
```

**Fix**: Ensure NPM proxy host has "Force SSL" enabled

## Monitoring

### Health Checks

```bash
# Check site availability
curl -Ik https://dinero.cash/ | head -5
# Expected: HTTP/2 200

# Check SSL certificate expiry
echo | openssl s_client -connect dinero.cash:443 -servername dinero.cash 2>&1 | grep "notAfter"

# Check response time
time curl -s -o /dev/null -w "%{http_code}\n" https://dinero.cash/
```

### Log Files

| Service | Log Location |
|---------|--------------|
| Hestia Nginx | `/var/log/nginx/domains/dinero.cash.*.log` |
| Hestia Apache | `/var/log/apache2/domains/dinero.cash.*.log` |
| NPM | `/data/logs/proxy-host-47_*.log` (in container) |

## Website Information

### Pages
- **index.html** - Main page (58KB)
- **users.html** - Users page
- **agents.html** - Agents page

### Assets
- **Location**: `/home/dinero/web/dinero.cash/public_html/assets/`
- **Count**: 96 assets (icons, images, stylesheets)
- **Ownership**: `dinero:dinero`

### Asset Path Cleanup (2026-01-16)

Website was previously hosted at `/dinero.cash` with hashed asset names (e.g., `assets/images/hero-bg-1a2b3c.webp`). During migration to www.dinero.cash:
- ✅ All asset references updated to use friendly names
- ✅ 96 assets copied with descriptive filenames
- ✅ jQuery and other dependencies fixed
- ✅ Site verified working on localhost:8080 before production deployment

## Related Services

### Service Dependencies (from Infrastructure Database)

```
dinero.cash Website (service #74)
├── Nginx Proxy Manager (service #22) - HARD dependency
├── Cloudflare DNS (service #76) - HARD dependency
└── HestiaCP Control Panel (service #52) - HARD dependency
```

### Infrastructure Database References

| Table | ID | Description |
|-------|-----|-------------|
| `services` | 74 | dinero.cash Website |
| `services` | 22 | Nginx Proxy Manager |
| `services` | 76 | Cloudflare DNS |
| `services` | 52 | HestiaCP Control Panel |
| `hosts` | 13 | HestiaCP Container (PCT 130) |
| `hosts` | 18 | Docker Host OMV (NPM) |
| `service_dependencies` | - | dinero.cash → NPM, Cloudflare, HestiaCP |

## Migration History

### 2024-08-28: Initial Hestia Setup
- dinero.cash domain added to HestiaCP
- User "dinero" created
- Initial files uploaded

### 2026-01-16: Production Deployment
- Website cleaned and migrated from `/dinero.cash` to `/www.dinero.cash`
- Fixed stale fail2ban-WEB iptables chain blocking ports 80/443
- Updated Cloudflare DNS from old Hetzner IP (46.4.228.169) to home (77.109.112.226)
- Enabled Cloudflare proxy (orange cloud)
- Configured NPM reverse proxy (#47)
- Updated infrastructure database with services and dependencies

## Maintenance Schedule

| Task | Frequency | Notes |
|------|-----------|-------|
| SSL certificate renewal | Automatic (Let's Encrypt) | NPM handles renewal |
| DNS monitoring | Ongoing | Cloudflare provides alerts |
| Backup verification | Weekly | Verify Hestia backups |
| Log review | Monthly | Check for anomalies |

## Contacts

| Role | Contact |
|------|---------|
| Infrastructure Admin | jmvl@accelior.com |
| Cloudflare Account | jmvl@accelior.com |
| HestiaCP Access | https://192.168.1.30:8083 |

## Additional Resources

- **HestiaCP Documentation**: `/docs/hestia/hestia.md`
- **Infrastructure Database**: `/infrastructure-db/infrastructure.db`
- **Nginx Proxy Manager**: https://nginx.home.accelior.com
- **OPNsense Firewall**: https://192.168.1.3
