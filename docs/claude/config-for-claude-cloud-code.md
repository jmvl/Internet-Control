# Claude Code MCP Server Configuration Guide

**Date**: 2025-10-21
**Status**: ✅ Working Configuration
**Purpose**: Configure MCP servers for both Claude Desktop and claude.ai/code (web)

## Overview

This guide documents the working configuration for connecting Model Context Protocol (MCP) servers to Claude Desktop and claude.ai/code. It covers both remote cloud-based MCP servers and self-hosted Docker-based servers.

---

## Table of Contents

1. [Current Working Configuration](#current-working-configuration)
2. [Understanding MCP Server Types](#understanding-mcp-server-types)
3. [Configuration File Location](#configuration-file-location)
4. [Troubleshooting](#troubleshooting)
5. [Installation Requirements](#installation-requirements)
6. [Server Details](#server-details)

---

## Current Working Configuration

**File**: `/Users/jm/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "context7": {
      "command": "mcp-remote",
      "args": [
        "https://mcp.context7.com/mcp"
      ]
    },
    "supabase": {
      "command": "mcp-remote",
      "args": [
        "https://mcp.supabase.com/mcp?project_ref=olctruqznjsfsjbputzx"
      ]
    },
    "mcp-atlassian": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "--stop-timeout",
        "5",
        "-e",
        "CONFLUENCE_URL=https://confluence.accelior.com",
        "-e",
        "CONFLUENCE_PERSONAL_TOKEN=${CONFLUENCE_PERSONAL_TOKEN}",
        "-e",
        "JIRA_URL=https://jira.accelior.com",
        "-e",
        "JIRA_USERNAME=maya-product",
        "-e",
        "JIRA_PERSONAL_TOKEN=${JIRA_PERSONAL_TOKEN}",
        "-e",
        "JIRA_SSL_VERIFY=false",
        "-e",
        "ENABLED_TOOLS=jira_get_issue,jira_search,jira_create_issue,jira_add_comment,jira_get_all_projects,jira_update_issue,jira_transition_issue,jira_link_to_epic,jira_create_issue_link,jira_get_transitions,confluence_create_page,confluence_update_page,confluence_get_page,confluence_search,confluence_delete_page,confluence_get_page_children,confluence_add_comment,confluence_get_comments,confluence_add_label,confluence_get_labels",
        "-e",
        "MCP_VERBOSE=true",
        "ghcr.io/sooperset/mcp-atlassian:latest"
      ]
    }
  }
}
```

---

## Understanding MCP Server Types

### Remote HTTP Servers (Recommended for Web Compatibility)

**Characteristics:**
- Hosted in the cloud
- Accessible via HTTPS endpoints
- Work with both Claude Desktop and claude.ai/code (web)
- No local dependencies required (except `mcp-remote`)

**Configuration Pattern:**
```json
{
  "command": "mcp-remote",
  "args": ["https://server-url.com/mcp"]
}
```

**Examples:**
- Context7: `https://mcp.context7.com/mcp`
- Supabase: `https://mcp.supabase.com/mcp?project_ref=<your-ref>`

### Local Docker Servers

**Characteristics:**
- Run locally via Docker containers
- More control over configuration and credentials
- **Only work with Claude Desktop** (not claude.ai/code web)
- Reliable for complex session management

**Configuration Pattern:**
```json
{
  "command": "docker",
  "args": ["run", "-i", "--rm", ...]
}
```

### stdio Servers (Not Recommended for Remote)

**Characteristics:**
- Run local Node.js/Python processes
- Use `npx` or direct command execution
- **Only work with Claude Desktop** (not claude.ai/code web)
- Can have dependency issues with `npx`

**Why We Avoid:**
- `npx mcp-remote` has broken dependencies (see troubleshooting)
- Not compatible with claude.ai/code web interface

---

## Configuration File Location

### macOS
```
/Users/<username>/Library/Application Support/Claude/claude_desktop_config.json
```

### Windows
```
%APPDATA%\Claude\claude_desktop_config.json
```

### Linux
```
~/.config/Claude/claude_desktop_config.json
```

---

## Installation Requirements

### 1. Install mcp-remote Globally

**Required for remote HTTP servers to work properly:**

```bash
npm install -g mcp-remote@latest
```

**Why Global Installation?**
- `npx mcp-remote` has a broken dependency (`strict-url-sanitise`)
- Global installation bypasses the `npx` cache issues
- More reliable connection to remote MCP servers

**Verify Installation:**
```bash
which mcp-remote
# Should output: /Users/<username>/.nvm/versions/node/vX.X.X/bin/mcp-remote

mcp-remote --version
# Should output version number (e.g., 0.1.29)
```

### 2. Docker (for local MCP servers)

**Required for Docker-based servers like mcp-atlassian:**

```bash
# Verify Docker is installed
docker --version

# Test Docker is running
docker ps
```

---

## Server Details

### Context7 MCP Server

**Purpose**: Up-to-date library documentation and code examples

**Configuration:**
```json
{
  "command": "mcp-remote",
  "args": ["https://mcp.context7.com/mcp"]
}
```

**Features:**
- Resolve library IDs
- Search documentation
- Get version-specific code examples
- No authentication required

**Usage in Claude:**
```
@context7 search for Next.js documentation
```

---

### Supabase MCP Server

**Purpose**: Interact with Supabase projects (database, auth, storage, etc.)

**Configuration:**
```json
{
  "command": "mcp-remote",
  "args": [
    "https://mcp.supabase.com/mcp?project_ref=olctruqznjsfsjbputzx"
  ]
}
```

**Features:**
- Execute SQL queries
- Apply migrations
- List tables and extensions
- Get project logs and advisors
- Deploy Edge Functions
- OAuth 2.0 authentication (browser-based)

**Authentication:**
1. Type `/mcp` in Claude Desktop
2. Click "Authenticate" next to Supabase
3. Browser opens → Login with Supabase account
4. Grant permissions
5. Token auto-refreshes

**Usage in Claude:**
```
@supabase list all tables in the public schema
@supabase execute SQL: SELECT * FROM users LIMIT 10
```

---

### MCP-Atlassian (JIRA & Confluence)

**Purpose**: Interact with JIRA issues and Confluence pages

**Deployment:**
- **Production Server**: `https://atlassian-mcp.acmea.tech/mcp` (requires session management)
- **Local Docker**: Runs container locally with credentials

**Why Docker Instead of Remote:**
The remote server at `https://atlassian-mcp.acmea.tech/mcp` requires session management that `mcp-remote` doesn't handle properly:
```
Error: Bad Request: Missing session ID
```

**Configuration (Local Docker):**
```json
{
  "command": "docker",
  "args": [
    "run", "-i", "--rm", "--stop-timeout", "5",
    "-e", "CONFLUENCE_URL=https://confluence.accelior.com",
    "-e", "CONFLUENCE_PERSONAL_TOKEN=<token>",
    "-e", "JIRA_URL=https://jira.accelior.com",
    "-e", "JIRA_USERNAME=maya-product",
    "-e", "JIRA_PERSONAL_TOKEN=<token>",
    "-e", "JIRA_SSL_VERIFY=false",
    "-e", "ENABLED_TOOLS=jira_get_issue,jira_search,...",
    "-e", "MCP_VERBOSE=true",
    "ghcr.io/sooperset/mcp-atlassian:latest"
  ]
}
```

**JIRA Features:**
- Search issues with JQL
- Create/update issues
- Add comments
- Transition issue status
- Link to epics
- Get all projects

**Confluence Features:**
- Search pages (CQL support)
- Create/update/delete pages
- Get page content (Markdown or HTML)
- Manage comments and labels
- Navigate page hierarchies

**Usage in Claude:**
```
@mcp-atlassian search JIRA for issues assigned to me
@mcp-atlassian create a new task in project VID
@mcp-atlassian search Confluence for "API documentation"
```

---

## Troubleshooting

### Issue: "Server disconnected" Error

**Symptoms:**
```
Error [ERR_MODULE_NOT_FOUND]: Cannot find module 'strict-url-sanitise'
Server disconnected. For troubleshooting guidance, please visit...
```

**Cause:**
- `npx mcp-remote` has a broken dependency
- npm cache corruption

**Solution:**
```bash
# Install mcp-remote globally (bypasses npx)
npm install -g mcp-remote@latest

# Update config to use global installation
# Change from:
{
  "command": "npx",
  "args": ["mcp-remote", "https://..."]
}

# To:
{
  "command": "mcp-remote",
  "args": ["https://..."]
}
```

### Issue: "Required field 'command' missing"

**Symptoms:**
```json
{
  "code": "invalid_type",
  "expected": "string",
  "received": "undefined",
  "path": ["mcpServers", "context7", "command"],
  "message": "Required"
}
```

**Cause:**
- Using HTTP `transport` field (web format) instead of `command` field (desktop format)

**Solution:**
```bash
# ❌ Wrong (web format):
{
  "transport": "http",
  "url": "https://mcp.context7.com/mcp"
}

# ✅ Correct (desktop format):
{
  "command": "mcp-remote",
  "args": ["https://mcp.context7.com/mcp"]
}
```

### Issue: Atlassian MCP "Missing session ID"

**Symptoms:**
```
Error POSTing to endpoint (HTTP 400):
{"jsonrpc":"2.0","id":"server-error","error":{"code":-32600,"message":"Bad Request: Missing session ID"}}
```

**Cause:**
- The remote Atlassian MCP server requires session management
- `mcp-remote` doesn't support this protocol

**Solution:**
Use Docker configuration instead of remote HTTP:
```bash
# ❌ Doesn't work:
{
  "command": "mcp-remote",
  "args": ["https://atlassian-mcp.acmea.tech/mcp"]
}

# ✅ Works:
{
  "command": "docker",
  "args": ["run", "-i", "--rm", ...]
}
```

### Testing Connections Manually

**Test Context7:**
```bash
mcp-remote https://mcp.context7.com/mcp
# Should output: "Connected to remote server using StreamableHTTPClientTransport"
```

**Test Supabase:**
```bash
mcp-remote https://mcp.supabase.com/mcp?project_ref=olctruqznjsfsjbputzx
# Should connect successfully
```

**Test Atlassian (will fail - expected):**
```bash
mcp-remote https://atlassian-mcp.acmea.tech/mcp
# Expected error: "Missing session ID"
# Use Docker configuration instead
```

---

## Checking Logs

### Log Location
```
/Users/<username>/Library/Logs/Claude/
```

### Important Log Files
- `mcp.log` - Main MCP connection log
- `mcp-server-context7.log` - Context7 specific logs
- `mcp-server-supabase.log` - Supabase specific logs
- `mcp-server-mcp-atlassian.log` - Atlassian specific logs

### Reading Logs
```bash
# View main MCP log
tail -f ~/Library/Logs/Claude/mcp.log

# Check for errors
grep -i "error" ~/Library/Logs/Claude/mcp.log

# Check specific server
tail -f ~/Library/Logs/Claude/mcp-server-context7.log
```

---

## Verifying Configuration

### In Claude Desktop

After restarting Claude Desktop:

```
/mcp
```

**Expected Output:**
```
✓ context7 (connected)
✓ supabase (connected)
✓ mcp-atlassian (connected)
```

### Test Each Server

```
@context7 help
@supabase help
@mcp-atlassian help
```

---

## Web vs Desktop Compatibility

| Server | Claude Desktop | claude.ai/code (web) |
|--------|---------------|----------------------|
| **context7** (via mcp-remote) | ✅ Works | ✅ Works |
| **supabase** (via mcp-remote) | ✅ Works | ✅ Works |
| **mcp-atlassian** (Docker) | ✅ Works | ❌ Desktop only |
| **mcp-atlassian** (Remote) | ❌ Session error | ❌ Session error |

**Key Takeaway:**
- For claude.ai/code web usage, only `mcp-remote` compatible servers work
- Docker and stdio servers only work with Claude Desktop
- Your Atlassian MCP server needs session management, so use Docker locally

---

## Migration Path for Web Usage

If you need claude.ai/code web compatibility:

### Option A: Use Pre-Built Remote MCP Servers
Replace local servers with cloud equivalents:
```bash
claude mcp add --transport http context7 https://mcp.context7.com/mcp
claude mcp add --transport http supabase https://mcp.supabase.com/mcp
```

### Option B: Deploy Your Own Remote MCP Server
Deploy Docker containers to cloud infrastructure:

**Deployment Options:**
1. **Railway**: `https://railway.app`
2. **Fly.io**: `https://fly.io`
3. **Render**: `https://render.com`
4. **DigitalOcean App Platform**
5. **AWS/GCP/Azure**

**Example (Railway):**
```bash
# Deploy Atlassian MCP to Railway
railway init
railway up

# Get URL
railway domain
# Output: https://your-app.railway.app

# Configure in Claude
{
  "command": "mcp-remote",
  "args": ["https://your-app.railway.app/mcp"]
}
```

---

## Security Best Practices

### 1. Never Commit Credentials
```bash
# ❌ Bad - credentials in config
"CONFLUENCE_PERSONAL_TOKEN=MzE0NDc3ODgwNDI4..."

# ✅ Better - use environment variables (when supported)
"CONFLUENCE_PERSONAL_TOKEN=${CONFLUENCE_TOKEN}"
```

### 2. Use OAuth When Available
- Supabase: OAuth 2.0 browser flow (no manual tokens)
- Context7: No authentication required (public endpoint)

### 3. Rotate Tokens Regularly
- JIRA personal tokens
- Confluence personal tokens
- Supabase access tokens

### 4. Use HTTPS Only
```bash
# ✅ Always use HTTPS
https://mcp.context7.com/mcp

# ❌ Never use HTTP
http://mcp.context7.com/mcp
```

---

## References

- [Anthropic Claude Code MCP Documentation](https://docs.claude.com/en/docs/claude-code/mcp)
- [Model Context Protocol Specification](https://modelcontextprotocol.io)
- [Claude Code Sandboxing Article](https://www.anthropic.com/engineering/claude-code-sandboxing)
- [Supabase Remote MCP Announcement](https://supabase.com/blog/remote-mcp-server)
- [Context7 Documentation](https://context7.com)
- [mcp-remote GitHub](https://github.com/modelcontextprotocol/mcp-remote)

---

## Change Log

### 2025-10-21
- ✅ Fixed `ERR_MODULE_NOT_FOUND` error by installing `mcp-remote` globally
- ✅ Updated configuration to use global `mcp-remote` instead of `npx`
- ✅ Kept Atlassian MCP as Docker due to session management requirements
- ✅ Verified all three servers connect successfully
- ✅ Documented hybrid approach (remote + Docker)

---

## Related Files

- **MCP Server Deployment**: `/root/mcp-atlassian/docker-compose.yml` (on docker host 192.168.1.20)
- **Environment Config**: `/root/mcp-atlassian/.env` (on docker host)
- **Infrastructure Database**: `/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db`
- **Setup Documentation**: `/docs/mcp-atlassian/SETUP-COMPLETE-NEXT-STEPS.md`

---

**Maintained by**: JM
**Last Updated**: 2025-10-21
**Status**: Production Ready ✅
