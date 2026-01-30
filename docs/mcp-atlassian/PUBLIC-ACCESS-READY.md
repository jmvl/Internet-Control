# MCP Atlassian - Public Access Setup Summary

**Status:** Ready for final configuration
**Date:** 2025-10-21
**Domain:** atlassian-mcp.acmea.tech

---

## What's Been Completed

### 1. DNS Configuration ✅
- **CNAME record created** in Cloudflare
- **Domain:** atlassian-mcp.acmea.tech → base.acmea.tech (77.109.77.114)
- **Verification:**
  ```bash
  nslookup atlassian-mcp.acmea.tech
  # Returns: 77.109.77.114
  ```

### 2. Automated Setup Script ✅
- **Script created:** `/Users/jm/Codebase/internet-control/scripts/setup-npm-atlassian-proxy.sh`
- **Capabilities:**
  - Automated API-based NPM configuration
  - Manual step-by-step instructions
  - Access testing and verification
  - SSL certificate management

### 3. Documentation ✅
- **Setup guide:** `/Users/jm/Codebase/internet-control/docs/mcp-atlassian/public-access-setup.md`
- Includes:
  - DNS configuration details
  - NPM proxy host setup (automated + manual)
  - SSL certificate configuration
  - Security recommendations
  - Troubleshooting guide
  - Network flow diagram

---

## Next Step: Complete NPM Configuration

You have two options to complete the setup:

### Option A: Automated Setup (Recommended)

Run the automated setup script:

```bash
cd /Users/jm/Codebase/internet-control
./scripts/setup-npm-atlassian-proxy.sh
```

Choose option 1 (Automated API setup) and provide:
- NPM admin email (likely: admin@example.com)
- NPM admin password

The script will:
1. Authenticate to NPM API
2. Create proxy host configuration
3. Request Let's Encrypt SSL certificate
4. Apply SSL and force HTTPS
5. Test the endpoint

### Option B: Manual Setup

If you prefer manual configuration:

1. Run the script and choose option 2:
   ```bash
   ./scripts/setup-npm-atlassian-proxy.sh
   ```

2. Follow the displayed instructions to configure via NPM web UI at http://192.168.1.121:81

---

## Configuration Details

The proxy host will be configured with:

**Details:**
- Domain: atlassian-mcp.acmea.tech
- Backend: http://192.168.1.20:9000
- WebSocket: Enabled
- Block Exploits: Enabled

**SSL:**
- Provider: Let's Encrypt
- Email: jmvl@accelior.com
- Force SSL: Yes
- HTTP/2: Yes

**Advanced Configuration:**
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

## After Configuration

### Test Access

Once NPM configuration is complete, test the endpoint:

```bash
# Test HTTPS access
curl -I https://atlassian-mcp.acmea.tech/healthz

# Test MCP endpoint
curl https://atlassian-mcp.acmea.tech/mcp
```

### Update Claude Code Configuration

Edit `~/.claude/.mcp.json` to use the public endpoint:

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "https://atlassian-mcp.acmea.tech/mcp"
    }
  }
}
```

Then restart Claude Code.

---

## Network Architecture

```
Internet
    ↓
Cloudflare DNS
  atlassian-mcp.acmea.tech → base.acmea.tech (77.109.77.114)
    ↓
OPNsense Firewall (77.109.77.114:443 → 192.168.1.9:443)
    ↓
Nginx Proxy Manager (192.168.1.9:443)
  ├── Let's Encrypt SSL/TLS termination
  ├── WebSocket upgrade support
  └── Proxy to: http://192.168.1.20:9000
        ↓
MCP Atlassian Server (192.168.1.20:9000)
  ├── Confluence: https://confluence.accelior.com
  └── Jira: https://jira.accelior.com
```

---

## Security Considerations

The current setup provides basic security:
- ✅ HTTPS with Let's Encrypt
- ✅ WebSocket support for MCP protocol
- ✅ Common exploit blocking

**Optional Security Enhancements:**

1. **IP Whitelist** - Limit access to known IPs
2. **Basic Auth** - Add password protection layer
3. **OAuth/SSO** - Enterprise authentication via Cloudflare Access

See documentation for implementation details: `/Users/jm/Codebase/internet-control/docs/mcp-atlassian/public-access-setup.md`

---

## Files Created

1. **Setup Script:**
   - `/Users/jm/Codebase/internet-control/scripts/setup-npm-atlassian-proxy.sh`

2. **Documentation:**
   - `/Users/jm/Codebase/internet-control/docs/mcp-atlassian/public-access-setup.md`
   - `/Users/jm/Codebase/internet-control/docs/mcp-atlassian/PUBLIC-ACCESS-READY.md` (this file)

3. **Deployment Files (on LXC 111: /root/mcp-atlassian/):**
   - docker-compose.yml
   - .env (with credentials)
   - manage.sh
   - README.md

---

## Quick Reference

| Component | Value |
|-----------|-------|
| Public Domain | atlassian-mcp.acmea.tech |
| Public Endpoint | https://atlassian-mcp.acmea.tech/mcp |
| Internal Endpoint | http://192.168.1.20:9000/mcp |
| NPM Admin UI | http://192.168.1.121:81 |
| Backend Server | LXC 111 (192.168.1.20) |
| Backend Port | 9000 |
| SSL Provider | Let's Encrypt |
| SSL Email | jmvl@accelior.com |

---

## Troubleshooting

If you encounter issues:

1. **DNS not resolving:**
   ```bash
   nslookup atlassian-mcp.acmea.tech
   # Should return 77.109.77.114
   ```

2. **Backend not accessible:**
   ```bash
   curl http://192.168.1.20:9000/healthz
   # Should return: {"status":"ok"}
   ```

3. **SSL certificate issues:**
   - Wait 1-2 minutes after requesting certificate
   - Check NPM logs: `docker logs -f nginx-proxy-manager-nginx-proxy-manager-1`
   - Verify domain resolves externally before requesting certificate

4. **502 Bad Gateway:**
   - Verify MCP server is running: `ssh root@pve2 "pct exec 111 -- docker ps"`
   - Check NPM can reach backend: Test from NPM host

See full troubleshooting guide in public-access-setup.md

---

**Ready to complete:** Run the setup script to finish NPM configuration and enable public access.
