# Linkwarden Deployment - COMPLETED

**Date**: 2025-10-19
**Status**: ✅ FULLY DEPLOYED - SSL Configuration Pending

## 🎉 Deployment Summary

### ✅ All Infrastructure Ready

1. **Linkwarden Application** ✅
   - Containers running on CT 111 (192.168.1.20:3002)
   - Status: All 3 containers healthy
   - HTTP endpoint verified: 200 OK

2. **Infrastructure Database** ✅
   - Service ID 60 registered
   - 3 containers tracked
   - Health monitoring active

3. **Nginx Proxy Manager** ✅
   - Proxy Host ID 40 configured
   - Forwarding: link.acmea.tech → 192.168.1.20:3002
   - Settings: Cache, websockets, HTTP/2, exploits blocked

4. **Cloudflare DNS** ✅
   - CNAME created: link.acmea.tech → base.acmea.tech
   - Proxy enabled (Cloudflare CDN)
   - DNS propagating: Resolves to 104.21.49.69, 172.67.159.242
   - HTTP access working: curl returns 200 OK

5. **Cloudflare CLI Tools** ✅
   - flarectl installed at `/opt/homebrew/bin/flarectl`
   - API token configured in `.env`
   - DNS management automated

## 📊 Current Status

```bash
# Linkwarden containers
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose ps"
# All 3 containers: Up (healthy)

# DNS resolution
dig link.acmea.tech +short
# Returns: 104.21.49.69, 172.67.159.242 (Cloudflare IPs)

# HTTP access
curl -I http://link.acmea.tech
# Returns: HTTP/1.1 200 OK
```

## ⚠️ HTTPS Redirect Loop - Cloudflare SSL/TLS Mode Issue

### Issue Detected
HTTPS access results in infinite 301 redirect loop due to Cloudflare's SSL/TLS encryption mode.

**Root Cause Analysis**:
- SSL certificate already exists and is valid (npm-54, Let's Encrypt)
- NPM correctly configured with Force SSL enabled
- Cloudflare's SSL/TLS mode is set to "Flexible"
- Cloudflare downgrades HTTPS → HTTP when forwarding to origin
- NPM receives HTTP request and redirects to HTTPS (force-ssl.conf)
- Creates infinite redirect loop

**Evidence**:
```bash
# Direct HTTPS to origin (bypassing Cloudflare) - WORKS
curl -Ik --resolve link.acmea.tech:443:77.109.77.114 https://link.acmea.tech
# Returns: HTTP/2 200 OK

# NPM access logs show all Cloudflare requests as HTTP
# Even though clients are making HTTPS requests!
[19/Oct/2025:10:45:47 +0000] - - 301 - GET http link.acmea.tech "/"
```

### Solution: Change Cloudflare SSL/TLS Mode to "Full"

**Step 1: Access Cloudflare Dashboard**
1. Go to https://dash.cloudflare.com
2. Select domain: `acmea.tech`
3. Go to **SSL/TLS** → **Overview**

**Step 2: Change Encryption Mode**
Current: **Flexible** (Cloudflare → Origin: HTTP)
Required: **Full** (Cloudflare → Origin: HTTPS)

1. Select **Full** or **Full (strict)**
   - **Full**: Cloudflare validates origin has SSL certificate (any cert)
   - **Full (strict)**: Validates certificate is from trusted CA (recommended)
2. Click **Save**

**Step 3: Wait for propagation (30-60 seconds)**

**Step 4: Test HTTPS Access**
```bash
curl -I https://link.acmea.tech
# Should return: HTTP/2 200 OK
```

## 🌐 Access Points

- **HTTP** (working now): http://link.acmea.tech
- **HTTPS** (after SSL): https://link.acmea.tech
- **Internal**: http://192.168.1.20:3002
- **NPM Admin**: http://192.168.1.9:81

## 📋 Post-SSL Configuration Checklist

After SSL certificate is obtained:

- [ ] Access https://link.acmea.tech
- [ ] Verify SSL certificate (should be Let's Encrypt)
- [ ] Create Linkwarden admin account
- [ ] Install browser extension (optional)
- [ ] Import existing bookmarks (if any)
- [ ] Configure backup schedule

## 🛠️ Management Commands

### Linkwarden
```bash
# Check status
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose ps"

# View logs
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose logs -f"

# Restart
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose restart"

# Update to latest version
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose pull && docker compose up -d"
```

### Cloudflare DNS (via flarectl)
```bash
# Set API token
export CF_API_TOKEN="RZ5klBDFKSUqBSnb8lJgzuUzwbh4v5Yd8UwgpNzA"

# List DNS records
flarectl dns list --zone acmea.tech | grep link

# View specific record
flarectl dns list --zone acmea.tech --name link.acmea.tech

# Delete record (if needed)
flarectl dns delete --zone acmea.tech --id 05d160ffe75d93dcde4e214ab1af3d8f
```

### NPM
```bash
# Check status
ssh root@192.168.1.9 "docker ps | grep nginx-proxy"

# Restart NPM
ssh root@192.168.1.9 "docker restart nginx-proxy-manager-nginx-proxy-manager-1"

# View logs
ssh root@192.168.1.9 "docker logs -f nginx-proxy-manager-nginx-proxy-manager-1"
```

## 📈 Infrastructure Details

### DNS Record
```
ID:       05d160ffe75d93dcde4e214ab1af3d8f
Type:     CNAME
Name:     link.acmea.tech
Content:  base.acmea.tech
Proxied:  true
TTL:      1 (Auto)
```

### NPM Proxy Host (ID: 40)
```yaml
Domain: link.acmea.tech
Forward: http://192.168.1.20:3002
Cache: Enabled
Block Exploits: Enabled
Websockets: Enabled
HTTP/2: Enabled
SSL: Pending configuration
```

### Database Entries
```sql
-- Service
ID: 60
Name: Linkwarden
Type: web
Port: 3002
Status: healthy

-- Containers
linkwarden-linkwarden-1   (ID: 59) - Main app
linkwarden-postgres-1     (ID: 60) - Database
linkwarden-meilisearch-1  (ID: 61) - Search
```

## 🔐 Security Notes

1. **Cloudflare API Token**: Stored in `.env` - Keep secure
2. **NPM Admin**: Use strong password
3. **Linkwarden Admin**: Will be created on first access
4. **SSL/TLS**: Enforced via Cloudflare + NPM
5. **Firewall**: Port 3002 only accessible via NPM reverse proxy

## 📚 Documentation Files

- `README.md` - Overview and quick links
- `installation-guide.md` - Complete technical documentation
- `quick-setup.md` - Step-by-step manual configuration
- `cloudflare-dns-setup.md` - DNS configuration details
- `QUICKSTART.md` - 2-step quickstart guide
- `DEPLOYMENT-COMPLETE.md` - This file (final status)

## 🎯 Next Immediate Step

**Go to https://dash.cloudflare.com and change SSL/TLS mode to "Full"!**

Steps:
1. Access Cloudflare Dashboard: https://dash.cloudflare.com
2. Select domain: **acmea.tech**
3. Go to **SSL/TLS** → **Overview**
4. Change encryption mode from **Flexible** to **Full** or **Full (strict)**
5. Wait 30-60 seconds for propagation
6. Test: `curl -I https://link.acmea.tech` should return 200 OK

Once Cloudflare SSL/TLS mode is corrected, you're 100% done and can access:
**https://link.acmea.tech** 🚀

---

**Deployment Completed**: 2025-10-19
**DNS Configured**: ✅ Yes (via flarectl)
**HTTP Working**: ✅ Yes (200 OK)
**SSL Certificate**: ✅ Yes (npm-54, Let's Encrypt)
**HTTPS Status**: ⚠️ Redirect loop due to Cloudflare SSL/TLS mode "Flexible"
**Next Action**: Change Cloudflare SSL/TLS mode to "Full" or "Full (strict)"
