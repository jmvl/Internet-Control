# MCP Atlassian - Claude Code Configuration

**Updated:** 2025-10-21
**Server Location:** LXC 111 (192.168.1.20:9000)

---

## Current Configuration

The `.mcp.json` file has been updated to use the persistent Docker-based MCP Atlassian server running on LXC 111.

### File Location

```bash
~/.claude/.mcp.json
```

### Current Configuration

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/jm/Codebase"
      ]
    },
    "mcp-atlassian": {
      "url": "http://192.168.1.20:9000/mcp"
    }
  }
}
```

---

## Configuration Options

### 1. Internal Access (Current)

**Use this when:** On your local network (192.168.1.x)

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "http://192.168.1.20:9000/mcp"
    }
  }
}
```

**Pros:**
- Faster (no TLS overhead)
- No external dependencies
- Direct connection to server

**Cons:**
- Only works on local network
- Not accessible remotely

### 2. Public Access (After NPM Setup)

**Use this when:** Need remote access or external connectivity

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "https://atlassian-mcp.acmea.tech/mcp"
    }
  }
}
```

**Pros:**
- Works from anywhere
- Encrypted (TLS/SSL)
- Public internet access

**Cons:**
- Requires NPM configuration to be completed
- Slightly higher latency (TLS + proxy)
- Depends on external DNS/SSL

### 3. Legacy Docker Run (Previous)

**Not recommended** - Previous configuration that spawned a new container each time:

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "CONFLUENCE_URL=https://confluence.accelior.com",
        "-e", "CONFLUENCE_PERSONAL_TOKEN=...",
        "ghcr.io/sooperset/mcp-atlassian:latest"
      ]
    }
  }
}
```

**Why not recommended:**
- Slower startup (spawns new container each time)
- Higher resource usage
- No persistent state
- More complex credential management

---

## Server Management

### Check Server Status

```bash
# Test health endpoint
curl http://192.168.1.20:9000/healthz
# Should return: {"status":"ok"}

# Via SSH
ssh root@pve2 "pct exec 111 -- docker ps | grep mcp-atlassian"
```

### Restart Server

```bash
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh restart'"
```

### View Logs

```bash
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh logs-tail'"
```

### Update Server

```bash
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh update'"
```

---

## Credentials

Credentials are stored in the `.env` file on LXC 111:

```bash
/root/mcp-atlassian/.env
```

The credentials are the same as your previous `.mcp.json` configuration:

- **Confluence URL:** https://confluence.accelior.com
- **Confluence Token:** (stored securely in .env)
- **Jira URL:** https://jira.accelior.com
- **Jira Username:** maya-product
- **Jira Token:** (stored securely in .env)

**Security:** The .env file is protected with `chmod 600` permissions.

---

## Available Tools

The MCP server provides access to these tools:

### Jira Tools

- `jira_get_issue` - Get issue details
- `jira_search` - Search issues using JQL
- `jira_create_issue` - Create new issue
- `jira_update_issue` - Update issue
- `jira_add_comment` - Add comment
- `jira_transition_issue` - Change issue status
- `jira_get_transitions` - Get available transitions
- `jira_link_to_epic` - Link to epic
- `jira_create_issue_link` - Create issue link
- `jira_get_all_projects` - List all projects

### Confluence Tools

- `confluence_search` - Search content using CQL
- `confluence_get_page` - Get page content
- `confluence_create_page` - Create new page
- `confluence_update_page` - Update existing page
- `confluence_delete_page` - Delete page
- `confluence_get_page_children` - Get child pages
- `confluence_add_comment` - Add comment
- `confluence_get_comments` - Get page comments
- `confluence_add_label` - Add label
- `confluence_get_labels` - Get page labels

---

## Testing the Connection

After updating `.mcp.json`, restart Claude Code and test:

### Test Jira Connection

```
Ask Claude: "List all Jira projects"
```

Expected response: List of your Jira projects

### Test Confluence Connection

```
Ask Claude: "Search Confluence for pages in the INFRA space"
```

Expected response: Search results from Confluence

---

## Troubleshooting

### Issue: Connection Refused

**Symptom:** Claude Code can't connect to MCP server

**Check:**
```bash
# Verify server is running
curl http://192.168.1.20:9000/healthz

# Check Docker container
ssh root@pve2 "pct exec 111 -- docker ps | grep mcp-atlassian"
```

**Fix:**
```bash
# Restart server if needed
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh restart'"
```

### Issue: Authentication Errors

**Symptom:** MCP connects but Jira/Confluence requests fail

**Check:**
```bash
# Verify credentials in .env
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && cat .env | grep TOKEN'"
```

**Fix:**
- Regenerate tokens if expired
- Update .env file with new tokens
- Restart server

### Issue: Slow Performance

**Symptom:** MCP responses are slow

**Possible causes:**
1. Network latency to Confluence/Jira
2. Large responses
3. Server resource constraints

**Debug:**
```bash
# Check server logs
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && ./manage.sh logs-tail'"

# Check container resources
ssh root@pve2 "pct exec 111 -- docker stats mcp-atlassian --no-stream"
```

### Issue: Tools Not Available

**Symptom:** Some Jira/Confluence tools don't appear in Claude Code

**Check:**
```bash
# Verify ENABLED_TOOLS in .env
ssh root@pve2 "pct exec 111 -- bash -c 'cd /root/mcp-atlassian && cat .env | grep ENABLED_TOOLS'"
```

**Fix:**
- Ensure all required tools are listed in ENABLED_TOOLS
- Restart server after changes

---

## Migration Notes

### From Previous Configuration

**Before (Local Docker Run):**
- New container spawned each request
- Credentials in .mcp.json
- Slower startup
- No persistent state

**After (Persistent Server):**
- Single running container
- Credentials in server .env
- Fast responses
- Persistent state
- Better resource usage

**Benefits:**
- ⚡ Faster responses (no container startup)
- 🔒 Better credential security (not in .mcp.json)
- 💾 Persistent state and caching
- 📊 Centralized logging
- 🔧 Easier management (manage.sh script)

---

## Related Documentation

- **Deployment Guide:** `docs/mcp-atlassian/deployment-guide.md`
- **Public Access Setup:** `docs/mcp-atlassian/public-access-setup.md`
- **Server README:** `docker/mcp-atlassian/README.md`
- **Next Steps:** `docs/mcp-atlassian/SETUP-COMPLETE-NEXT-STEPS.md`

---

**Configuration Status:**
- ✅ Server deployed on LXC 111
- ✅ `.mcp.json` configured for internal access
- ✅ Health check passing
- ✅ Credentials configured
- ⏳ Public access (optional - requires NPM setup)

**Current Endpoint:** http://192.168.1.20:9000/mcp
**Public Endpoint (after NPM):** https://atlassian-mcp.acmea.tech/mcp
