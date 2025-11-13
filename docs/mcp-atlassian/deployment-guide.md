# MCP Atlassian Server - Deployment Guide

**Location**: LXC 111 (docker-debian) @ 192.168.1.20
**Port**: 9000
**Endpoint**: `http://192.168.1.20:9000/mcp`
**Status**: Ready for deployment (credentials needed)

## Overview

MCP Atlassian server provides AI-powered access to Confluence and Jira through the Model Context Protocol (MCP). This enables Claude Code and other MCP clients to interact with Atlassian products using natural language.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Claude Code (.mcp.json)                                    │
│  http://192.168.1.20:9000/mcp                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  LXC 111 (192.168.1.20) - Docker Container                 │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  MCP Atlassian Server (Port 9000)                     │  │
│  │  - Streamable HTTP Transport                          │  │
│  │  - OAuth Token Storage (./config)                     │  │
│  │  - Logging (./logs)                                   │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
┌──────────────────────┐  ┌──────────────────────┐
│ Confluence Server    │  │ Jira Cloud           │
│ confluence.accelior  │  │ accelior.atlassian   │
│ .com                 │  │ .net                 │
└──────────────────────┘  └──────────────────────┘
```

## Deployment Files

All files deployed to: `/root/mcp-atlassian/` on LXC 111

```
/root/mcp-atlassian/
├── docker-compose.yml    # Container orchestration
├── .env                  # Credentials and configuration
├── .env.example          # Template
├── README.md             # Detailed documentation
├── manage.sh             # Management script
├── config/               # OAuth tokens (persistent)
└── logs/                 # Application logs
```

## Quick Start

### 1. Configure Credentials

SSH into LXC 111 and edit the `.env` file:

```bash
ssh root@pve2
pct exec 111 -- bash
cd /root/mcp-atlassian
nano .env
```

**Required credentials:**

For **Confluence Server/Data Center**:
```env
CONFLUENCE_URL=https://confluence.accelior.com
CONFLUENCE_PERSONAL_TOKEN=<your_personal_access_token>
```

For **Jira Cloud**:
```env
JIRA_URL=https://accelior.atlassian.net
JIRA_USERNAME=jmvl@accelior.com
JIRA_API_TOKEN=<your_api_token>
```

### 2. Start the Server

```bash
cd /root/mcp-atlassian
./manage.sh start
```

Or manually:
```bash
docker compose up -d
```

### 3. Verify Deployment

```bash
# Check status
./manage.sh status

# Check logs
./manage.sh logs-tail

# Test health endpoint
./manage.sh health

# Or manually
curl http://localhost:9000/health
```

### 4. Configure Claude Code

Edit `~/.claude/.mcp.json`:

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "http://192.168.1.20:9000/mcp"
    }
  }
}
```

## Management Commands

The `manage.sh` script provides convenient management:

```bash
# Server control
./manage.sh start        # Start server
./manage.sh stop         # Stop server
./manage.sh restart      # Restart server
./manage.sh status       # Show status

# Monitoring
./manage.sh logs         # Follow logs
./manage.sh logs-tail    # Last 50 lines
./manage.sh health       # Health check

# Maintenance
./manage.sh update       # Update to latest image
./manage.sh config       # Edit .env file
./manage.sh clean        # Remove containers (keep data)
./manage.sh clean-all    # Remove everything (CAUTION)
```

## Generating API Tokens

### Jira Cloud API Token

1. Visit: https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Label: "MCP Atlassian Server"
4. Copy token immediately (shown only once)
5. Add to `.env` as `JIRA_API_TOKEN`

### Confluence Personal Access Token (Server/Data Center)

1. User Profile → Personal Access Tokens
2. Create token with required permissions:
   - Read access to spaces
   - Write access (if needed for page creation)
3. Copy token immediately
4. Add to `.env` as `CONFLUENCE_PERSONAL_TOKEN`

## Available Tools

Once configured, the following tools are available through Claude Code:

### Confluence Tools
- `confluence_search` - Search content using CQL
- `confluence_get_page` - Get page content by ID
- `confluence_create_page` - Create new page
- `confluence_update_page` - Update existing page
- `confluence_get_page_children` - List child pages
- `confluence_get_comments` - Get page comments
- `confluence_add_comment` - Add comment to page
- `confluence_add_label` - Add label to page
- `confluence_delete_page` - Delete page
- `confluence_get_labels` - Get page labels
- `confluence_search_user` - Search for users

### Jira Tools
- `jira_search` - Search issues using JQL
- `jira_get_issue` - Get issue details
- `jira_create_issue` - Create new issue
- `jira_update_issue` - Update existing issue
- `jira_delete_issue` - Delete issue
- `jira_add_comment` - Add comment to issue
- `jira_transition_issue` - Change issue status
- `jira_get_all_projects` - List all projects
- `jira_get_project_issues` - Get project's issues
- `jira_add_worklog` - Log work on issue
- `jira_link_to_epic` - Link issue to epic
- `jira_create_issue_link` - Link two issues
- `jira_get_transitions` - Get available transitions
- `jira_batch_create_issues` - Create multiple issues
- `jira_create_sprint` - Create new sprint
- `jira_get_agile_boards` - List Agile boards

## Configuration Options

### Space/Project Filtering

Limit access to specific spaces or projects in `.env`:

```env
CONFLUENCE_SPACES_FILTER=INFRA,DEV,DOC
JIRA_PROJECTS_FILTER=VID,INFRA
```

### Read-Only Mode

Disable all write operations:

```env
READ_ONLY_MODE=true
```

### Tool Whitelisting

Enable only specific tools:

```env
ENABLED_TOOLS=confluence_search,confluence_get_page,jira_search,jira_get_issue
```

### SSL Configuration

For self-signed certificates:

```env
CONFLUENCE_SSL_VERIFY=false
JIRA_SSL_VERIFY=false
```

## Troubleshooting

### Server Not Starting

```bash
# Check logs
./manage.sh logs-tail

# Check Docker status
docker compose ps

# Verify .env file
cat .env | grep -v "^#" | grep -v "^$"
```

### Authentication Errors

Test credentials manually:

```bash
# Test Jira
curl -u "email@company.com:api_token" \
  https://accelior.atlassian.net/rest/api/3/myself

# Test Confluence
curl -u "your_username:personal_token" \
  https://confluence.accelior.com/rest/api/space
```

### Connection Refused

```bash
# Verify server is listening
ss -tlnp | grep 9000

# Check firewall
iptables -L -n | grep 9000

# Test from host
curl -v http://192.168.1.20:9000/health
```

### Enable Debug Logging

Edit `.env`:

```env
MCP_VERY_VERBOSE=true
MCP_LOGGING_STDOUT=true
```

Then restart:

```bash
./manage.sh restart
./manage.sh logs
```

## Network Access

### Internal Access (Current)
- Endpoint: `http://192.168.1.20:9000/mcp`
- Accessible from: LAN only

### Optional: Public Access

To expose via Nginx Proxy Manager (192.168.1.9):

1. Create proxy host:
   - Domain: `mcp-atlassian.acmea.tech`
   - Forward to: `192.168.1.20:9000`
   - SSL: Enable Let's Encrypt

2. Add authentication:
   - Access List with username/password
   - Or IP whitelist

3. Update Cloudflare DNS:
   - CNAME: `mcp-atlassian` → `base.acmea.tech`

## Security Considerations

1. **Protect credentials**:
   ```bash
   chmod 600 /root/mcp-atlassian/.env
   ```

2. **Use API tokens**: Never use account passwords

3. **Regular token rotation**: Update tokens periodically

4. **Network isolation**: Consider firewall rules for production

5. **OAuth token backup**: The `./config` directory contains OAuth tokens

## Backup & Recovery

### Backup OAuth Tokens

```bash
# From LXC 111
cd /root/mcp-atlassian
tar czf mcp-atlassian-backup-$(date +%Y%m%d).tar.gz config/ .env
```

### Restore

```bash
# Extract backup
tar xzf mcp-atlassian-backup-YYYYMMDD.tar.gz

# Restart server
./manage.sh restart
```

## Monitoring

### Health Check

```bash
# Manual check
curl http://192.168.1.20:9000/health

# Via management script
./manage.sh health
```

### Log Monitoring

```bash
# Real-time logs
./manage.sh logs

# Last 50 lines
./manage.sh logs-tail

# Search logs
docker compose logs | grep ERROR
```

## Updates

### Update to Latest Version

```bash
cd /root/mcp-atlassian
./manage.sh update
```

This will:
1. Pull the latest image
2. Restart the container
3. Preserve configuration and OAuth tokens

## Resources

- **GitHub**: https://github.com/sooperset/mcp-atlassian
- **Docker Image**: ghcr.io/sooperset/mcp-atlassian:latest
- **Local Docs**: `/root/mcp-atlassian/README.md`

## Support

For issues:
1. Check logs: `./manage.sh logs-tail`
2. Verify credentials in `.env`
3. Test API tokens manually
4. GitHub Issues: https://github.com/sooperset/mcp-atlassian/issues

---

**Deployment Date**: 2025-10-21
**Deployed By**: Claude Code via deployment automation
**Infrastructure**: Proxmox LXC 111 (Debian 12) @ 192.168.1.20
