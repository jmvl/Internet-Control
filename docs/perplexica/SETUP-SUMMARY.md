# External Access Setup Summary

## Completed Configuration

### 1. Perplexica External Access
**URL**: https://perplexica.acmea.tech

**DNS Configuration**:
- ✅ Cloudflare DNS A record created
- Domain: perplexica.acmea.tech
- IP: 135.181.154.169 (proxied via Cloudflare)
- Record ID: Created on 2025-10-09

**NPM Proxy Host**:
- ✅ Database entry created (ID: 34)
- Forward: 192.168.1.20:3000
- Features: WebSocket ✓, HTTP/2 ✓, Block Exploits ✓

**Status**: ⏳ Awaiting final verification
- DNS propagated (showing Cloudflare IPs)
- NPM configuration complete
- Requires external network test

---

### 2. Nginx Proxy Manager External Access
**URL**: https://nginx.acmea.tech

**DNS Configuration**:
- ✅ Cloudflare DNS A record created
- Domain: nginx.acmea.tech
- IP: 135.181.154.169 (proxied via Cloudflare)
- Record ID: 5aa34063224a65e4eab5443df0ea5047

**NPM Proxy Host**:
- ⏳ Requires setup on OMV server
- Setup script: `/tmp/setup-npm-self-proxy.sh`
- Forward: 192.168.1.9:81 (NPM admin interface)

---

## Manual Steps Required

### Complete NPM Self-Proxy Setup

SSH into OMV server and run:

```bash
ssh root@192.168.1.9

# Download and run setup script
cat > /tmp/setup-npm-self-proxy.sh << 'EOF'
#!/bin/bash
echo "Setting up NPM self-referential proxy for nginx.acmea.tech..."

docker cp nginx-proxy-manager-nginx-proxy-manager-1:/data/database.sqlite /tmp/npm.db

cat > /tmp/add_npm_proxy.sql << 'EOSQL'
INSERT INTO proxy_host (
  created_on, modified_on, owner_user_id, is_deleted,
  domain_names, forward_host, forward_port, access_list_id,
  certificate_id, ssl_forced, caching_enabled, block_exploits,
  advanced_config, meta, allow_websocket_upgrade, http2_support,
  forward_scheme, enabled, hsts_enabled, hsts_subdomains
) VALUES (
  datetime('now'), datetime('now'), 1, 0,
  '["nginx.acmea.tech"]', '192.168.1.9', 81, 0,
  0, 0, 0, 1,
  '', '{"letsencrypt_agree":false,"dns_challenge":false}', 1, 1,
  'http', 1, 0, 0
);

SELECT id, domain_names, forward_host, forward_port
FROM proxy_host
WHERE domain_names LIKE '%nginx.acmea.tech%';
EOSQL

sqlite3 /tmp/npm.db < /tmp/add_npm_proxy.sql
docker cp /tmp/npm.db nginx-proxy-manager-nginx-proxy-manager-1:/data/database.sqlite
docker restart nginx-proxy-manager-nginx-proxy-manager-1

echo "✓ NPM proxy host created for nginx.acmea.tech"
EOF

chmod +x /tmp/setup-npm-self-proxy.sh
/tmp/setup-npm-self-proxy.sh
```

---

## Testing

### Test DNS Resolution

```bash
# Check perplexica DNS
dig +short perplexica.acmea.tech
# Expected: Cloudflare IPs (172.67.x.x, 104.21.x.x)

# Check nginx DNS
dig +short nginx.acmea.tech
# Expected: Cloudflare IPs (172.67.x.x, 104.21.x.x)
```

### Test External Access

From an external network (not your LAN):

```bash
# Test Perplexica
curl -I https://perplexica.acmea.tech

# Test NPM Admin
curl -I https://nginx.acmea.tech
```

Or use a browser:
- https://perplexica.acmea.tech (Perplexica search interface)
- https://nginx.acmea.tech (NPM admin login)

---

## Configuration Details

### Cloudflare Settings

**Zone**: acmea.tech (0eca1e8adfd8b1109320d67050d633ab)
**API Token**: RZ5klBDFKSUqBSnb8lJgzuUzwbh4v5Yd8UwgpNzA

**DNS Records**:
| Subdomain | Type | Content | Proxied | Status |
|-----------|------|---------|---------|--------|
| perplexica | A | 135.181.154.169 | ✅ Yes | ✅ Active |
| nginx | A | 135.181.154.169 | ✅ Yes | ✅ Active |

### NPM Proxy Hosts

| Domain | Forward To | Port | WebSocket | HTTP/2 | SSL |
|--------|------------|------|-----------|--------|-----|
| perplexica.acmea.tech | 192.168.1.20 | 3000 | ✅ | ✅ | Cloudflare |
| nginx.acmea.tech | 192.168.1.9 | 81 | ✅ | ✅ | Cloudflare |

### Firewall Requirements

**OPNsense Port Forwarding** (verify these exist):
```
WAN:80 → 192.168.1.9:80 (HTTP)
WAN:443 → 192.168.1.9:443 (HTTPS)
```

---

## Optional: Add Let's Encrypt Certificates

To use NPM's Let's Encrypt instead of Cloudflare SSL:

1. Access NPM: http://192.168.1.9:81 (internal) or https://nginx.acmea.tech (after setup)
2. Navigate to: SSL Certificates → Add SSL Certificate
3. Configure for each domain:
   - Domain: perplexica.acmea.tech
   - Email: admin@acmea.tech
   - Use DNS Challenge: No
   - Agree to Terms: ✅
4. Edit Proxy Hosts and link certificates
5. Enable "Force SSL" and "HSTS"

---

## Troubleshooting

### DNS Not Resolving

```bash
# Check Cloudflare status
dig perplexica.acmea.tech @1.1.1.1

# Clear local DNS cache (macOS)
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

### 502 Bad Gateway

```bash
# Check Perplexica is running
ssh root@192.168.1.20 "docker ps | grep perplexica"

# Check NPM is running
ssh root@192.168.1.9 "docker ps | grep nginx"

# Restart services
ssh root@192.168.1.20 "cd /opt/perplexica && docker compose restart"
ssh root@192.168.1.9 "docker restart nginx-proxy-manager-nginx-proxy-manager-1"
```

### Can't Access NPM Admin

```bash
# Verify proxy host exists
ssh root@192.168.1.9 "docker cp nginx-proxy-manager-nginx-proxy-manager-1:/data/database.sqlite /tmp/npm.db && sqlite3 /tmp/npm.db 'SELECT domain_names FROM proxy_host WHERE domain_names LIKE \"%nginx.acmea.tech%\";'"

# Check NPM logs
ssh root@192.168.1.9 "docker logs nginx-proxy-manager-nginx-proxy-manager-1 --tail 50"
```

---

## Documentation

**Complete documentation**:
- `/docs/perplexica/perplexica-external-access.md` - Full Perplexica setup guide
- `/docs/perplexica/perplexica-installation.md` - Initial installation docs

**Key Scripts**:
- `/tmp/cloudflare-dns-setup.sh` - Automated Cloudflare DNS setup
- `/tmp/setup-npm-self-proxy.sh` - NPM self-referential proxy setup

---

## Next Steps

1. ✅ Cloudflare DNS configured
2. ✅ NPM database prepared
3. ⏳ Run NPM self-proxy setup script on OMV server
4. ⏳ Test external access from internet-connected device
5. ⏳ Optional: Configure Let's Encrypt certificates in NPM UI
6. ⏳ Add to Uptime Kuma monitoring

---

**Setup Date**: 2025-10-09
**Configured By**: Claude Code
**Status**: Ready for final testing
