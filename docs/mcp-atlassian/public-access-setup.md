# MCP Atlassian - Public Access Setup

**Domain:** `atlassian-mcp.acmea.tech`
**Internal Endpoint:** `http://192.168.1.20:9000/mcp`

---

## Step 1: DNS Configuration ✅ COMPLETED

CNAME record created in Cloudflare:
- **Record:** `atlassian-mcp.acmea.tech`
- **Type:** CNAME
- **Target:** `base.acmea.tech`
- **Proxy:** OFF (DNS only)
- **TTL:** Auto

Verify:
```bash
nslookup atlassian-mcp.acmea.tech
# Should resolve to 77.109.77.114 (base.acmea.tech)
```

---

## Step 2: Nginx Proxy Manager Configuration

### Automated Setup (Recommended)

A setup script is available to automate or guide the NPM configuration:

```bash
cd /Users/jm/Codebase/internet-control
./scripts/setup-npm-atlassian-proxy.sh
```

The script provides three options:
1. **Automated API setup** - Requires admin credentials, fully automated
2. **Manual instructions** - Step-by-step guide for UI configuration
3. **Test access** - Verify the configuration is working

### Manual Setup Instructions

#### Access NPM

1. Open: http://192.168.1.121:81
2. Login with admin credentials

#### Create Proxy Host

**Details Tab:**
```
Domain Names:
  atlassian-mcp.acmea.tech

Scheme: http
Forward Hostname / IP: 192.168.1.20
Forward Port: 9000

☐ Cache Assets
☑ Block Common Exploits
☑ Websockets Support
☐ Access List (optional - for security)
```

**SSL Tab:**
```
☑ SSL Certificate: Request a new SSL Certificate with Let's Encrypt
  Email Address: jmvl@accelior.com
  ☑ Force SSL
  ☑ HTTP/2 Support
  ☐ HSTS Enabled (optional)
  ☑ I Agree to the Let's Encrypt Terms of Service
```

**Advanced Tab (Optional):**
```nginx
# Increase timeouts for long-running MCP operations
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
proxy_connect_timeout 75s;

# WebSocket support
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

# Standard headers
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

# Large request body support (for Confluence page uploads)
client_max_body_size 100M;
```

---

## Step 3: Verify Configuration

### Test Internal Access

From NPM host (192.168.1.9):
```bash
curl -v http://192.168.1.20:9000/healthz
# Should return: {"status":"ok"}
```

### Test SSL Certificate

```bash
# Wait 1-2 minutes for Let's Encrypt validation
sleep 120

# Test HTTPS
curl -I https://atlassian-mcp.acmea.tech/healthz
# Should return: HTTP/2 200
```

### Test MCP Endpoint

```bash
curl https://atlassian-mcp.acmea.tech/healthz
# Should return: {"status":"ok"}
```

---

## Step 4: Update Claude Code Configuration

### For Public Access (Remote Usage)

Edit `~/.claude/.mcp.json`:

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "https://atlassian-mcp.acmea.tech/mcp"
    }
  }
}
```

### For Internal Access (LAN Usage)

Keep using:
```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "http://192.168.1.20:9000/mcp"
    }
  }
}
```

---

## Security Considerations

### Option 1: IP Whitelist (Recommended)

Create an Access List in NPM:
1. Go to "Access Lists" → "Add Access List"
2. Name: "MCP Atlassian - Allowed IPs"
3. Add allowed IPs:
   - Your home IP
   - Your office IP
   - VPN endpoints
4. Apply to the proxy host

### Option 2: Basic Authentication

Add to Advanced tab:
```nginx
auth_basic "MCP Atlassian Access";
auth_basic_user_file /data/nginx/custom/mcp-atlassian.htpasswd;
```

Create password file on NPM host:
```bash
docker exec -it nginx-proxy-manager-nginx-proxy-manager-1 sh
cd /data/nginx/custom
echo "admin:$(openssl passwd -apr1 your_password)" > mcp-atlassian.htpasswd
```

### Option 3: OAuth/SSO (Advanced)

Use Cloudflare Access or OAuth2 Proxy for enterprise SSO.

---

## Monitoring

### Check Access Logs

```bash
# On NPM host
docker logs -f nginx-proxy-manager-nginx-proxy-manager-1 | grep atlassian-mcp
```

### Monitor MCP Server

```bash
# On LXC 111
ssh root@pve2
pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh logs'
```

---

## Troubleshooting

### SSL Certificate Issues

```bash
# Check certificate status in NPM UI
# Or test with:
openssl s_client -connect atlassian-mcp.acmea.tech:443 -servername atlassian-mcp.acmea.tech

# Force renewal (if needed)
# In NPM UI: Edit proxy host → SSL → Request New Certificate
```

### 502 Bad Gateway

```bash
# Check MCP server is running
curl http://192.168.1.20:9000/healthz

# Check NPM can reach backend
docker exec -it nginx-proxy-manager-nginx-proxy-manager-1 curl http://192.168.1.20:9000/healthz

# Restart MCP server if needed
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh restart'"
```

### Connection Timeouts

- Check Advanced configuration has correct timeout values
- Verify WebSocket support is enabled
- Check firewall rules between NPM and LXC 111

---

## Network Flow

```
Internet
    ↓
Cloudflare DNS (atlassian-mcp.acmea.tech → 77.109.77.114)
    ↓
OPNsense Firewall (77.109.77.114:443 → 192.168.1.9:443)
    ↓
Nginx Proxy Manager (192.168.1.9:443)
    ↓ (proxies to)
MCP Atlassian Server (192.168.1.20:9000)
    ↓ (authenticates with)
Confluence (confluence.accelior.com)
Jira (jira.accelior.com)
```

---

## Quick Commands

```bash
# Check DNS
dig atlassian-mcp.acmea.tech +short

# Test HTTPS
curl -I https://atlassian-mcp.acmea.tech/healthz

# Test MCP endpoint
curl https://atlassian-mcp.acmea.tech/mcp

# View NPM logs
ssh root@192.168.1.9 "docker logs -f nginx-proxy-manager-nginx-proxy-manager-1"

# View MCP logs
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh logs-tail'"
```

---

**Setup Date:** 2025-10-21
**Domain:** atlassian-mcp.acmea.tech
**SSL:** Let's Encrypt (Auto-renewal)
**Backend:** http://192.168.1.20:9000
