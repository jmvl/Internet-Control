# Cloudflare DNS Configuration for Linkwarden

**Date**: 2025-10-19
**Domain**: link.acmea.tech
**Target**: base.acmea.tech (resolves to 77.109.77.114)

## Current Status

✅ **Infrastructure Database**: Updated with Linkwarden service (ID: 60)
✅ **Linkwarden Containers**: Running and healthy on 192.168.1.20:3002
✅ **NPM Proxy Host**: Configured (ID: 40) and ready
⚠️ **Cloudflare DNS**: NOT YET CONFIGURED - Manual step required

## Required DNS Configuration

### Step 1: Access Cloudflare Dashboard

1. Navigate to: https://dash.cloudflare.com
2. Log in with your Cloudflare credentials
3. Select the **acmea.tech** domain

### Step 2: Create CNAME Record

Navigate to **DNS** → **Records** and add:

```
Type:          CNAME
Name:          link
Content:       base.acmea.tech
Proxy status:  Proxied (🟠 orange cloud ENABLED)
TTL:           Auto
```

**Visual Guide:**
```
┌─────────────────────────────────────────────────┐
│ Add DNS record                                  │
├─────────────────────────────────────────────────┤
│ Type: [CNAME ▼]                                 │
│                                                 │
│ Name: [link              ] .acmea.tech          │
│                                                 │
│ Target: [base.acmea.tech                    ]   │
│                                                 │
│ Proxy status: [🟠 Proxied]  ← MUST BE ENABLED  │
│                                                 │
│ TTL: [Auto ▼]                                   │
│                                                 │
│          [Cancel]  [Save]                       │
└─────────────────────────────────────────────────┘
```

### Step 3: Verify DNS Record

After saving, verify the record appears in your DNS records list:

```
link.acmea.tech    CNAME    base.acmea.tech    Auto    🟠 Proxied
```

## DNS Propagation Check

After creating the DNS record, verify propagation:

### From Your Local Machine
```bash
# Check DNS resolution
nslookup link.acmea.tech

# Expected output should show Cloudflare IPs (not 77.109.77.114 directly)
# Example: 104.21.x.x or 172.67.x.x
```

### From Pi-hole DNS Server
```bash
ssh root@192.168.1.5 "dig link.acmea.tech +short"
```

**Note**: DNS propagation typically takes 1-5 minutes with Cloudflare.

## NPM Configuration Status

The Nginx Proxy Manager has been pre-configured with the following settings:

```yaml
Proxy Host ID: 40
Domain Names: link.acmea.tech
Forward to: http://192.168.1.20:3002

Settings:
  ✓ Cache Assets: Enabled
  ✓ Block Common Exploits: Enabled
  ✓ Websockets Support: Enabled
  ✓ HTTP/2 Support: Enabled
  ✗ SSL Certificate: Not yet configured (requires DNS first)
  ✗ Force SSL: Not yet enabled (requires certificate)
```

### NPM Database Entry Details
```sql
INSERT INTO proxy_host VALUES (
    40,                           -- ID
    '["link.acmea.tech"]',       -- domain_names
    '192.168.1.20',              -- forward_host
    3002,                         -- forward_port
    0,                            -- certificate_id (to be updated)
    0,                            -- ssl_forced (to be enabled)
    1,                            -- caching_enabled
    1,                            -- block_exploits
    1,                            -- allow_websocket_upgrade
    1,                            -- http2_support
    'http',                       -- forward_scheme
    1                             -- enabled
);
```

## SSL Certificate Configuration (After DNS)

Once DNS is propagating correctly:

### Option 1: Via NPM Web UI (Recommended)

1. Access NPM admin panel: http://192.168.1.9:81
2. Go to **Proxy Hosts**
3. Find **link.acmea.tech** (ID: 40)
4. Click **Edit**
5. Go to **SSL** tab
6. Select: **Request a new SSL Certificate**
7. Provider: **Let's Encrypt**
8. Email: Your email address
9. Check boxes:
   - ✓ Force SSL
   - ✓ HTTP/2 Support
   - ✓ HSTS Enabled
10. Click **Save**

### Option 2: Via Database Update

After obtaining certificate (will have a new certificate ID):

```bash
# SSH to OMV
ssh root@192.168.1.9

# Update proxy_host to use certificate
docker exec nginx-proxy-manager-nginx-proxy-manager-1 sqlite3 /data/database.sqlite \
  "UPDATE proxy_host SET certificate_id = <NEW_CERT_ID>, ssl_forced = 1 WHERE id = 40"

# Restart NPM
docker restart nginx-proxy-manager-nginx-proxy-manager-1
```

## Testing After Configuration

### 1. Check DNS Resolution
```bash
nslookup link.acmea.tech
# Should return Cloudflare IPs
```

### 2. Test HTTP Access (Before SSL)
```bash
curl -I http://link.acmea.tech
# Should return 200 OK or 301/302 redirect
```

### 3. Test HTTPS Access (After SSL)
```bash
curl -I https://link.acmea.tech
# Should return 200 OK
```

### 4. Browser Test
Open https://link.acmea.tech in a browser:
- Should load Linkwarden login/registration page
- SSL certificate should be valid (Let's Encrypt)
- No security warnings

## Traffic Flow Diagram

```
User Browser
    ↓
Cloudflare CDN (77.109.77.114)
    ↓ (CNAME: link.acmea.tech → base.acmea.tech)
Your Public IP
    ↓ (Port Forward: 80/443)
OPNsense Firewall (192.168.1.3)
    ↓
OMV - Nginx Proxy Manager (192.168.1.9:80/443)
    ↓ (Proxy: link.acmea.tech → 192.168.1.20:3002)
docker-debian CT 111 (192.168.1.20)
    ↓ (Port 3002)
Linkwarden Container
```

## Troubleshooting

### DNS Not Resolving
```bash
# Check if CNAME was created
dig link.acmea.tech CNAME +short

# Should return: base.acmea.tech
```

### Connection Timeout
1. Verify Cloudflare proxy is enabled (orange cloud)
2. Check firewall rules allow inbound 80/443
3. Verify NPM is running: `ssh root@192.168.1.9 "docker ps | grep nginx-proxy"`

### SSL Certificate Request Fails
Common causes:
- DNS not fully propagated (wait 5-10 minutes)
- Port 80/443 not accessible from internet
- Rate limit hit (Let's Encrypt: 5 certs/week/domain)

Solutions:
```bash
# Verify ports are open from outside
curl -I http://base.acmea.tech

# Check NPM logs
ssh root@192.168.1.9 "docker logs nginx-proxy-manager-nginx-proxy-manager-1 --tail 100"
```

### 502 Bad Gateway
```bash
# Verify Linkwarden is running
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose ps"

# Check NPM can reach Linkwarden
ssh root@192.168.1.9 "curl -I http://192.168.1.20:3002"
```

## Quick Reference Commands

```bash
# Check Linkwarden status
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose ps"

# Check NPM status
ssh root@192.168.1.9 "docker ps | grep nginx-proxy"

# View NPM logs
ssh root@192.168.1.9 "docker logs -f nginx-proxy-manager-nginx-proxy-manager-1"

# Restart NPM
ssh root@192.168.1.9 "docker restart nginx-proxy-manager-nginx-proxy-manager-1"

# Test DNS
nslookup link.acmea.tech

# Test connectivity
curl -I http://192.168.1.20:3002
```

## Next Steps Checklist

- [ ] Create CNAME record in Cloudflare: `link` → `base.acmea.tech`
- [ ] Enable Cloudflare proxy (orange cloud)
- [ ] Wait 2-5 minutes for DNS propagation
- [ ] Verify DNS resolution: `nslookup link.acmea.tech`
- [ ] Request SSL certificate via NPM web UI (http://192.168.1.9:81)
- [ ] Enable "Force SSL" in NPM
- [ ] Test HTTPS access: `https://link.acmea.tech`
- [ ] Create admin account in Linkwarden
- [ ] Install browser extension
- [ ] Start saving bookmarks!

---

**Configuration Date**: 2025-10-19
**NPM Proxy Host ID**: 40
**Status**: Waiting for Cloudflare DNS configuration
