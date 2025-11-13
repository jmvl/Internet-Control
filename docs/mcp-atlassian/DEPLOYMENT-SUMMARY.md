# MCP Atlassian Server - Deployment Summary

## ✅ Deployment Complete

The MCP Atlassian server has been successfully deployed to **LXC 111** (docker-debian) at `192.168.1.20`.

## 📍 Deployment Location

- **Host**: LXC 111 (Proxmox container)
- **IP Address**: 192.168.1.20
- **Port**: 9000
- **Endpoint**: `http://192.168.1.20:9000/mcp`
- **Directory**: `/root/mcp-atlassian/`

## 📦 Files Deployed

```
/root/mcp-atlassian/
├── docker-compose.yml    ✅ Container configuration
├── .env                  ⚠️  Needs credentials
├── .env.example          ✅ Template provided
├── README.md             ✅ Full documentation
├── manage.sh             ✅ Management script
├── config/               ✅ OAuth token storage (empty)
└── logs/                 ✅ Log directory (empty)
```

## 🚀 Next Steps (Required)

### 1. Add Your Atlassian Credentials

SSH into LXC 111 and edit the `.env` file:

```bash
ssh root@pve2
pct exec 111 -- bash
cd /root/mcp-atlassian
nano .env
```

**Update these values:**

```env
# For Confluence Server
CONFLUENCE_PERSONAL_TOKEN=<generate_personal_access_token>

# For Jira Cloud
JIRA_API_TOKEN=<generate_api_token_from_atlassian>
```

**How to generate tokens:**
- **Jira Cloud**: https://id.atlassian.com/manage-profile/security/api-tokens
- **Confluence Server**: User Profile → Personal Access Tokens

### 2. Start the Server

```bash
cd /root/mcp-atlassian
./manage.sh start
```

### 3. Verify It's Working

```bash
# Check status
./manage.sh status

# View logs
./manage.sh logs-tail

# Test health endpoint
./manage.sh health
```

### 4. Configure Claude Code

Edit your `~/.claude/.mcp.json`:

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "http://192.168.1.20:9000/mcp"
    }
  }
}
```

Then restart Claude Code.

## 🛠️ Quick Management Commands

```bash
# Server control
./manage.sh start        # Start server
./manage.sh stop         # Stop server
./manage.sh restart      # Restart server

# Monitoring
./manage.sh logs         # Follow logs
./manage.sh status       # Check status
./manage.sh health       # Health check

# Maintenance
./manage.sh update       # Update to latest version
./manage.sh config       # Edit configuration
```

## 🔧 Available Tools

Once running, you'll have access to 30+ Atlassian tools:

**Confluence**: search, get_page, create_page, update_page, add_comment, add_label
**Jira**: search, get_issue, create_issue, update_issue, transition_issue, add_comment

## 📚 Documentation

- **Deployment Guide**: `docs/mcp-atlassian/deployment-guide.md`
- **Docker Files**: `docker/mcp-atlassian/`
- **Server README**: `/root/mcp-atlassian/README.md` (on LXC 111)
- **GitHub**: https://github.com/sooperset/mcp-atlassian

## ⚠️ Important Notes

1. **Security**: The `.env` file contains sensitive credentials - protect it:
   ```bash
   chmod 600 /root/mcp-atlassian/.env
   ```

2. **Docker Image**: Already pulled (23.63 MB)

3. **Network**: Currently accessible only from LAN (192.168.1.x network)

4. **Filtering**: Currently configured for `INFRA` space in Confluence

## 🐛 Troubleshooting

If the server doesn't start:

```bash
# Check logs
cd /root/mcp-atlassian
./manage.sh logs-tail

# Verify credentials work
curl -u "jmvl@accelior.com:YOUR_API_TOKEN" \
  https://accelior.atlassian.net/rest/api/3/myself
```

## 🎯 Status Checklist

- [x] Docker image pulled
- [x] Files deployed to LXC 111
- [x] Configuration template created
- [x] Management scripts installed
- [x] Documentation written
- [ ] **Credentials needed** (add to `.env`)
- [ ] **Server start** (run `./manage.sh start`)
- [ ] **Claude Code config** (update `.mcp.json`)

---

**Deployed**: 2025-10-21
**Ready to start**: Yes (after adding credentials)
**Access**: http://192.168.1.20:9000/mcp
