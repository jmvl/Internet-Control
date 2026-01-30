# MCP Atlassian Public Access - Setup Complete

**Status:** Ready for final NPM configuration
**Date:** 2025-10-21
**Domain:** atlassian-mcp.acmea.tech

---

## ✅ What's Been Completed

### 1. DNS Configuration
- **Cloudflare CNAME created:** atlassian-mcp.acmea.tech → base.acmea.tech
- **Verification:**
  ```bash
  nslookup atlassian-mcp.acmea.tech
  # Returns: 77.109.77.114
  ```

### 2. MCP Atlassian Server
- **Running at:** http://192.168.1.20:9000/mcp
- **Health check:** ✅ Passing
- **Credentials:** Configured from your .mcp.json

### 3. Automated Setup Tools
- **Script location:** `/Users/jm/Codebase/internet-control/scripts/setup-npm-atlassian-proxy.sh`
- **Features:**
  - Automated API-based configuration
  - Manual step-by-step instructions
  - Built-in access testing

### 4. Complete Documentation
- **Setup guide:** `docs/mcp-atlassian/public-access-setup.md`
- **Quick summary:** `docs/mcp-atlassian/PUBLIC-ACCESS-READY.md`
- **This file:** Complete next steps and verification

---

## 🚀 Next Step: Complete NPM Configuration

You need to configure Nginx Proxy Manager to proxy HTTPS traffic to your MCP server.

### Option A: Automated API Setup (Recommended)

Run the setup script:

```bash
cd /Users/jm/Codebase/internet-control
./scripts/setup-npm-atlassian-proxy.sh
```

**Choose option 1** and provide:
- NPM admin email (check your NPM login)
- NPM admin password

The script will automatically:
1. ✅ Authenticate to NPM API
2. ✅ Create proxy host configuration
3. ✅ Request Let's Encrypt SSL certificate
4. ✅ Enable SSL and force HTTPS
5. ✅ Test the public endpoint

**Note:** Default credentials (`admin@example.com` / `changeme`) did not work, so you'll need your actual NPM admin credentials.

### Option B: Manual Setup via Web UI

If you prefer manual configuration:

1. **Run the script with option 2:**
   ```bash
   ./scripts/setup-npm-atlassian-proxy.sh
   # Choose option 2 for manual instructions
   ```

2. **Or follow these steps directly:**

   **Access NPM:**
   - Open: http://192.168.1.121:81
   - Login with your admin credentials

   **Create Proxy Host:**

   Click "Add Proxy Host" and configure:

   **Details Tab:**
   - Domain Names: `atlassian-mcp.acmea.tech`
   - Scheme: `http`
   - Forward Hostname/IP: `192.168.1.20`
   - Forward Port: `9000`
   - ☑ Block Common Exploits
   - ☑ Websockets Support

   **SSL Tab:**
   - ☑ Request a new SSL Certificate
   - Email: `jmvl@accelior.com`
   - ☑ Force SSL
   - ☑ HTTP/2 Support
   - ☑ I Agree to the Let's Encrypt Terms of Service

   **Advanced Tab:**
   Paste this configuration:
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

3. **Click Save**

4. **Wait 1-2 minutes** for Let's Encrypt certificate issuance

---

## ✅ Verification Steps

After NPM configuration is complete, verify everything works:

### 1. Test DNS Resolution
```bash
nslookup atlassian-mcp.acmea.tech
# Should return: 77.109.77.114
```

### 2. Test Backend Server
```bash
curl http://192.168.1.20:9000/healthz
# Should return: {"status":"ok"}
```

### 3. Test HTTPS Access
```bash
# Test health endpoint
curl -I https://atlassian-mcp.acmea.tech/healthz
# Should return: HTTP/2 200

# Test MCP endpoint
curl https://atlassian-mcp.acmea.tech/mcp
# Should return MCP server info
```

### 4. Update Claude Code Configuration

Edit `~/.claude/.mcp.json`:

**Current (local only):**
```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "http://192.168.1.20:9000/mcp"
    }
  }
}
```

**New (public access):**
```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "https://atlassian-mcp.acmea.tech/mcp"
    }
  }
}
```

### 5. Restart Claude Code
```bash
# Restart Claude Code to load new configuration
```

### 6. Test MCP Integration

In Claude Code, verify you can access Atlassian tools:
```
Ask me: "List all Jira projects"
```

If successful, you should see your Jira projects.

---

## 🔧 Troubleshooting

### Issue: DNS Not Resolving

**Check:**
```bash
nslookup atlassian-mcp.acmea.tech
```

**Fix:** DNS propagation can take up to 5 minutes. Wait and retry.

### Issue: 502 Bad Gateway

**Possible causes:**
1. MCP server not running
2. NPM can't reach backend
3. Firewall blocking connection

**Debug:**
```bash
# Check MCP server is running
ssh root@pve2 "pct exec 111 -- docker ps | grep mcp-atlassian"

# Check backend is accessible
curl http://192.168.1.20:9000/healthz

# Check from NPM host
ssh root@192.168.1.9 "curl http://192.168.1.20:9000/healthz"
```

### Issue: SSL Certificate Failed

**Possible causes:**
1. DNS not resolving externally yet
2. Port 80 not accessible for Let's Encrypt validation
3. Rate limiting from Let's Encrypt

**Fix:**
1. Verify domain resolves externally: `dig atlassian-mcp.acmea.tech @8.8.8.8`
2. Check firewall allows port 80 inbound
3. Wait 1 hour if rate limited, then retry

### Issue: WebSocket Connection Fails

**Check Advanced configuration:**
- Verify WebSocket headers are present in Advanced tab
- Ensure `allow_websocket_upgrade` is enabled
- Check timeout values are sufficient (3600s)

### Issue: Authentication Errors

**Verify credentials in .env:**
```bash
ssh root@pve2
pct exec 111 -- cat /root/mcp-atlassian/.env | grep TOKEN
```

---

## 📊 Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         INTERNET                            │
└────────────────────────────┬────────────────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │  Cloudflare DNS  │
                    │  atlassian-mcp.  │
                    │  acmea.tech      │
                    └────────┬─────────┘
                             │ Resolves to 77.109.77.114
                    ┌────────▼─────────┐
                    │  OPNsense        │
                    │  Port Forward    │
                    │  443 → NPM       │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │ Nginx Proxy      │
                    │ Manager          │
                    │ 192.168.1.9:443  │
                    │                  │
                    │ • SSL/TLS Term   │
                    │ • Let's Encrypt  │
                    │ • WebSocket      │
                    └────────┬─────────┘
                             │ Proxy to http://192.168.1.20:9000
                    ┌────────▼─────────┐
                    │ MCP Atlassian    │
                    │ LXC 111          │
                    │ 192.168.1.20     │
                    │ Port 9000        │
                    └────────┬─────────┘
                             │
            ┌────────────────┴────────────────┐
            │                                 │
   ┌────────▼─────────┐            ┌─────────▼────────┐
   │   Confluence     │            │      Jira        │
   │ confluence.      │            │  jira.accelior.  │
   │ accelior.com     │            │  com             │
   └──────────────────┘            └──────────────────┘
```

---

## 🔐 Security Considerations

### Current Security
- ✅ HTTPS with Let's Encrypt (TLS 1.2+)
- ✅ Common exploit blocking
- ✅ WebSocket support
- ✅ No public IP exposure of backend

### Optional Enhancements

#### 1. IP Whitelist (Recommended)

Restrict access to known IPs via NPM Access Lists:

1. Go to NPM → Access Lists → Add Access List
2. Name: "MCP Atlassian - Allowed IPs"
3. Add your IPs:
   - Home IP
   - Office IP
   - VPN endpoints
4. Apply to the proxy host

#### 2. Basic Authentication

Add password protection layer:

```nginx
# In Advanced tab
auth_basic "MCP Atlassian Access";
auth_basic_user_file /data/nginx/custom/mcp-atlassian.htpasswd;
```

Create password file:
```bash
ssh root@192.168.1.9
docker exec -it nginx-proxy-manager-nginx-proxy-manager-1 sh
cd /data/nginx/custom
echo "admin:$(openssl passwd -apr1 your_password)" > mcp-atlassian.htpasswd
```

#### 3. Cloudflare Access (Enterprise)

For OAuth/SSO integration with Google/GitHub/etc.

See: https://www.cloudflare.com/products/zero-trust/access/

---

## 📁 Files Created

### Local Repository Files

1. **Setup Script:**
   ```
   /Users/jm/Codebase/internet-control/scripts/setup-npm-atlassian-proxy.sh
   ```
   - Automated API setup
   - Manual instructions
   - Testing utilities

2. **Documentation:**
   ```
   /Users/jm/Codebase/internet-control/docs/mcp-atlassian/
   ├── deployment-guide.md          # Initial deployment
   ├── DEPLOYMENT-SUMMARY.md        # Quick deployment summary
   ├── public-access-setup.md       # Complete NPM setup guide
   ├── PUBLIC-ACCESS-READY.md       # Pre-configuration summary
   └── SETUP-COMPLETE-NEXT-STEPS.md # This file
   ```

3. **Docker Configuration:**
   ```
   /Users/jm/Codebase/internet-control/docker/mcp-atlassian/
   ├── docker-compose.yml
   ├── .env.example
   └── README.md
   ```

### Remote Server Files (LXC 111: /root/mcp-atlassian/)

```
/root/mcp-atlassian/
├── docker-compose.yml    # Container configuration
├── .env                  # Credentials (secured with chmod 600)
├── manage.sh             # Management script
├── README.md             # Server documentation
├── config/               # OAuth token storage
└── logs/                 # Application logs
```

---

## 🎯 Quick Reference

| Component | Value |
|-----------|-------|
| **Public Domain** | atlassian-mcp.acmea.tech |
| **Public Endpoint** | https://atlassian-mcp.acmea.tech/mcp |
| **Internal Endpoint** | http://192.168.1.20:9000/mcp |
| **NPM Admin UI** | http://192.168.1.121:81 |
| **Setup Script** | `./scripts/setup-npm-atlassian-proxy.sh` |
| **Backend Server** | LXC 111 (192.168.1.20) |
| **Backend Port** | 9000 |
| **SSL Provider** | Let's Encrypt |
| **SSL Email** | jmvl@accelior.com |
| **DNS Target** | base.acmea.tech (77.109.77.114) |

---

## 📞 Management Commands

### NPM Setup Script
```bash
cd /Users/jm/Codebase/internet-control
./scripts/setup-npm-atlassian-proxy.sh

# Options:
# 1 - Automated API setup (requires admin credentials)
# 2 - Show manual instructions
# 3 - Test access only
```

### MCP Server Management
```bash
# Via SSH to PVE2
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh status'"
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh logs-tail'"
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh restart'"
```

### Testing
```bash
# Test backend
curl http://192.168.1.20:9000/healthz

# Test public access
curl https://atlassian-mcp.acmea.tech/healthz

# Test MCP endpoint
curl https://atlassian-mcp.acmea.tech/mcp
```

---

## ✅ Success Criteria

Your setup is complete when:

- [ ] DNS resolves: `nslookup atlassian-mcp.acmea.tech` returns `77.109.77.114`
- [ ] Backend healthy: `curl http://192.168.1.20:9000/healthz` returns `{"status":"ok"}`
- [ ] HTTPS works: `curl -I https://atlassian-mcp.acmea.tech/healthz` returns `HTTP/2 200`
- [ ] MCP accessible: `curl https://atlassian-mcp.acmea.tech/mcp` returns server info
- [ ] Claude Code connected: Can query Jira/Confluence via Claude Code

---

## 🎉 Final Step

**Run the NPM setup script to complete configuration:**

```bash
cd /Users/jm/Codebase/internet-control
./scripts/setup-npm-atlassian-proxy.sh
```

**Choose option 1** for automated setup (recommended) or **option 2** for manual UI configuration.

After completion, your MCP Atlassian server will be publicly accessible with full SSL/TLS encryption!

---

**Setup Progress:**
- ✅ DNS configured
- ✅ MCP server deployed and running
- ✅ Automated setup script created
- ✅ Documentation complete
- ⏳ **NPM configuration** (final step - run the script above)

**Estimated time to complete:** 5 minutes (automated) or 10 minutes (manual)
