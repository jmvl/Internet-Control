# Linkwarden Quick Setup Guide

## Manual Configuration Steps

### Step 1: Cloudflare DNS Configuration

1. Log in to Cloudflare Dashboard: https://dash.cloudflare.com
2. Select the `acmea.tech` domain
3. Go to **DNS** → **Records**
4. Click **Add record**
5. Configure the CNAME record:
   - **Type**: CNAME
   - **Name**: `link` (will create link.acmea.tech)
   - **Target**: `base.acmea.tech`
   - **Proxy status**: Proxied (orange cloud icon - ENABLED)
   - **TTL**: Auto
6. Click **Save**

### Step 2: Nginx Proxy Manager Configuration

1. Access NPM admin panel: `http://192.168.1.9:81`
2. Log in with admin credentials
3. Click **Proxy Hosts** → **Add Proxy Host**

#### Details Tab
- **Domain Names**: `link.acmea.tech`
- **Scheme**: `http`
- **Forward Hostname/IP**: `192.168.1.20`
- **Forward Port**: `3002`
- **Cache Assets**: ✓ Enabled
- **Block Common Exploits**: ✓ Enabled
- **Websockets Support**: ✓ Enabled

#### SSL Tab
- **SSL Certificate**: Request a new SSL Certificate with Let's Encrypt
- **Force SSL**: ✓ Enabled
- **HTTP/2 Support**: ✓ Enabled
- **HSTS Enabled**: ✓ Enabled
- **HSTS Subdomains**: ☐ Disabled

#### Custom Locations (Optional)
Leave empty unless specific path routing is needed.

#### Advanced (Optional)
Leave default unless specific Nginx directives are needed.

5. Click **Save**

### Step 3: Verify Configuration

1. Wait 2-3 minutes for DNS propagation
2. Access https://link.acmea.tech
3. You should see the Linkwarden login/registration page
4. Create an admin account
5. Start adding bookmarks!

## Troubleshooting

### DNS Not Resolving
```bash
# Check DNS propagation
nslookup link.acmea.tech

# Expected output should show Cloudflare IPs
```

### SSL Certificate Error
- Ensure port 80 and 443 are open on your firewall
- Verify Cloudflare proxy is enabled (orange cloud)
- Check NPM logs: `docker logs nginx-proxy-manager-nginx-proxy-manager-1`

### 502 Bad Gateway
- Verify Linkwarden is running: `ssh root@192.168.1.20 "docker compose -f /opt/linkwarden/docker-compose.yml ps"`
- Check if port 3002 is accessible: `curl http://192.168.1.20:3002`

### Connection Timeout
- Verify firewall rules allow traffic from OMV (192.168.1.9) to docker-debian (192.168.1.20) on port 3002
- Check if the container is healthy: `docker compose ps` should show "(healthy)" status

## Quick Reference

- **Local Access**: http://192.168.1.20:3002
- **Public Access**: https://link.acmea.tech
- **NPM Admin**: http://192.168.1.9:81
- **Installation Path**: /opt/linkwarden on CT 111

## Management

### Check Status
```bash
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose ps"
```

### View Logs
```bash
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose logs -f"
```

### Restart
```bash
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose restart"
```

---

**Setup Date**: 2025-10-19
