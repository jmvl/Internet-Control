# MCP Atlassian Server Deployment

Production deployment of the MCP Atlassian server for AI-powered Confluence and Jira integration.

## Quick Start

### 1. Initial Setup

```bash
# Clone or navigate to this directory
cd /root/mcp-atlassian

# Copy environment file and configure credentials
cp .env.example .env
nano .env

# Create required directories
mkdir -p config logs
```

### 2. Configuration

Edit `.env` file with your Atlassian credentials:

**For Confluence Cloud + Jira Cloud:**
```env
CONFLUENCE_URL=https://confluence.accelior.com
CONFLUENCE_USERNAME=your.email@company.com
CONFLUENCE_API_TOKEN=your_api_token

JIRA_URL=https://accelior.atlassian.net
JIRA_USERNAME=your.email@company.com
JIRA_API_TOKEN=your_api_token
```

**For Server/Data Center:**
```env
CONFLUENCE_URL=https://confluence.your-company.com
CONFLUENCE_PERSONAL_TOKEN=your_pat

JIRA_URL=https://jira.your-company.com
JIRA_PERSONAL_TOKEN=your_pat
```

### 3. Deploy

```bash
# Pull latest image
docker-compose pull

# Start server
docker-compose up -d

# Check logs
docker-compose logs -f

# Verify health
curl http://localhost:9000/health
```

## Access Methods

### Single-User Mode (Direct Authentication)

The server runs on **port 9000** with streamable-HTTP transport:

- **Endpoint**: `http://192.168.1.20:9000/mcp`
- **Authentication**: Configured via environment variables in `.env`

Configure in Claude Code's `.mcp.json`:

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "url": "http://192.168.1.20:9000/mcp"
    }
  }
}
```

### Multi-User Mode (OAuth 2.0)

For multi-user scenarios, each user provides their own token:

```json
{
  "mcpServers": {
    "mcp-atlassian-service": {
      "url": "http://192.168.1.20:9000/mcp",
      "headers": {
        "Authorization": "Bearer <USER_OAUTH_ACCESS_TOKEN>"
      }
    }
  }
}
```

## OAuth 2.0 Setup (Optional)

For multi-user authentication with automatic token refresh:

```bash
# Run OAuth setup wizard
docker-compose run --rm -p 8080:8080 mcp-atlassian --oauth-setup -v

# Follow the wizard instructions
# Then update .env with OAuth credentials
```

## Available Tools

### Confluence Tools
- `confluence_search` - Search content using CQL
- `confluence_get_page` - Get page content
- `confluence_create_page` - Create new page
- `confluence_update_page` - Update existing page
- `confluence_get_page_children` - Get child pages
- `confluence_get_comments` - Get page comments
- `confluence_add_comment` - Add comment
- `confluence_add_label` - Add label

### Jira Tools
- `jira_search` - Search issues using JQL
- `jira_get_issue` - Get issue details
- `jira_create_issue` - Create new issue
- `jira_update_issue` - Update issue
- `jira_add_comment` - Add comment
- `jira_transition_issue` - Change issue status
- `jira_get_all_projects` - List all projects
- `jira_get_project_issues` - Get project issues
- `jira_add_worklog` - Add work log
- `jira_link_to_epic` - Link to epic
- `jira_create_issue_link` - Create issue link

## Management Commands

```bash
# Start server
docker-compose up -d

# Stop server
docker-compose down

# Restart server
docker-compose restart

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f mcp-atlassian

# Check status
docker-compose ps

# Update to latest version
docker-compose pull
docker-compose up -d

# Remove containers and volumes (CAUTION: deletes OAuth tokens)
docker-compose down -v
```

## Filtering & Access Control

### Space/Project Filtering

Limit access to specific spaces or projects:

```env
# In .env file
CONFLUENCE_SPACES_FILTER=INFRA,DEV,DOC
JIRA_PROJECTS_FILTER=PROJ,DEV,SUPPORT
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

## Troubleshooting

### Check Server Health

```bash
curl http://localhost:9000/health
docker-compose logs -f
```

### Authentication Issues

1. **Verify credentials**:
   ```bash
   # Test Jira connection
   curl -u "email@company.com:api_token" \
     https://your-company.atlassian.net/rest/api/3/myself

   # Test Confluence connection
   curl -u "email@company.com:api_token" \
     https://your-company.atlassian.net/wiki/rest/api/space
   ```

2. **Check environment variables**:
   ```bash
   docker-compose exec mcp-atlassian env | grep -E "JIRA|CONFLUENCE"
   ```

### SSL Certificate Issues

For self-signed certificates:

```env
CONFLUENCE_SSL_VERIFY=false
JIRA_SSL_VERIFY=false
```

### Enable Debug Logging

```env
MCP_VERY_VERBOSE=true
MCP_LOGGING_STDOUT=true
```

## Network Access

The server listens on **port 9000**:
- Internal access: `http://192.168.1.20:9000/mcp`
- Can be exposed via Nginx Proxy Manager for external access

### Optional: Public Access via NPM

Create proxy host in Nginx Proxy Manager (192.168.1.9):
- Domain: `mcp-atlassian.acmea.tech`
- Forward to: `192.168.1.20:9000`
- Enable SSL certificate
- Add access control as needed

## File Structure

```
/root/mcp-atlassian/
├── docker-compose.yml    # Docker Compose configuration
├── .env                  # Environment variables (credentials)
├── .env.example          # Template for .env
├── config/               # OAuth tokens and config (persistent)
├── logs/                 # Application logs
└── README.md             # This file
```

## Security Notes

1. **Protect `.env` file**: Contains sensitive credentials
   ```bash
   chmod 600 .env
   ```

2. **Use API tokens, not passwords**: Generate API tokens in Atlassian settings

3. **Regular token rotation**: Update tokens periodically

4. **Network isolation**: Consider firewall rules if exposing externally

5. **OAuth tokens**: Stored in `./config` directory - backup and protect

## API Token Generation

### Jira/Confluence Cloud

1. Go to: https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Label it (e.g., "MCP Atlassian Server")
4. Copy token immediately (shown only once)

### Server/Data Center (Personal Access Token)

1. User Profile → Personal Access Tokens
2. Create token with appropriate permissions
3. Copy token immediately

## Resources

- GitHub: https://github.com/sooperset/mcp-atlassian
- Docker Hub: https://github.com/orgs/sooperset/packages/container/package/mcp-atlassian
- Documentation: [Project README](https://github.com/sooperset/mcp-atlassian/blob/main/README.md)

## Support

For issues or questions:
- GitHub Issues: https://github.com/sooperset/mcp-atlassian/issues
- Check logs: `docker-compose logs -f`
