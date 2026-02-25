# Agent0 AI - Deployment Documentation

## Overview

**Service**: Agent0 AI (agent0ai/agent-zero)
**Deploy Date**: 2026-01-20
**Last Updated**: 2026-02-24 (Updated to v0.9.8.2 with LiteLLM 1.81.15)
**Status**: Running
**Public URL**: https://agentzero.acmea.tech
**Version**: v0.9.8.2 (2026-02-24)

## Service Details

### Container Information

| Property | Value |
|----------|-------|
| **Container Name** | `agent-zero` |
| **Image** | `agentzero-custom:latest` (custom build with LiteLLM 1.81.11+) |
| **Base Image** | Kali Linux (kali-rolling) |
| **Docker Host** | PCT-111 (192.168.1.20) |
| **Internal Port** | 80 |
| **Published Port** | 50080, 5173-5174 |
| **SSH Port** | 22 (internal) |
| **Additional Ports** | 9000-9009 (internal) |
| **Status** | Up (healthy) |

### Access URLs

| Access Type | URL |
|-------------|-----|
| **Public** | https://agentzero.acmea.tech |
| **Internal** | http://192.168.1.20:50080 |
| **Login** | https://agentzero.acmea.tech/login |

## Infrastructure Configuration

### DNS Configuration

| Record | Type | Content | Proxy |
|--------|------|---------|-------|
| `agentzero.acmea.tech` | CNAME | `nginx.home.accelior.com` | Enabled (Cloudflare) |

### Nginx Proxy Manager (NPM) Configuration

| Property | Value |
|----------|-------|
| **Proxy Host ID** | 49 |
| **Domain** | agentzero.acmea.tech |
| **Forward Host** | 192.168.1.20 |
| **Forward Port** | 50080 |
| **Scheme** | http |
| **WebSocket** | Enabled |
| **HTTP/2** | Enabled |
| **SSL** | ✅ Let's Encrypt (Certificate ID: 64) |
| **SSL Forced** | ✅ Yes |
| **Caching** | Disabled |
| **Block Exploits** | Disabled |

### SSL Certificate Details

| Property | Value |
|----------|-------|
| **Certificate ID** | 64 |
| **Provider** | Let's Encrypt |
| **Domain** | agentzero.acmea.tech |
| **Issued** | 2026-01-20 |
| **Expires** | 2026-04-20 |
| **Auto-Renew** | Yes (Let's Encrypt) |

## Docker Host: PCT-111

**Hostname**: docker-host-pct111
**IP Address**: 192.168.1.20
**Type**: LXC container on pve2
**Purpose**: Docker platform hosting Supabase, n8n, and various AI/services

## What is Agent0 AI?

Agent0 AI is a security research and AI automation tool based on Kali Linux. It provides:

- **AI-Powered Security Testing**: Automated penetration testing capabilities
- **Kali Linux Tools**: Full suite of Kali security tools
- **Web Interface**: Browser-based management UI
- **Containerized Deployment**: Isolated environment for safe testing

### Image Labels

```
org.opencontainers.image.title: Kali Linux (kali-rolling branch)
org.opencontainers.image.description: Official Kali Linux container image
org.opencontainers.image.vendor: OffSec
org.opencontainers.image.version: 2025.09.21
```

## Custom Docker Image

**Why Custom Image?** The official `agent0ai/agent-zero:latest` image ships with LiteLLM version 1.79.3, which lacks the native `zai` provider (added in LiteLLM 1.81.0). The custom image ensures the Z.ai GLM-4.7 provider works correctly.

**Dockerfile**: `/opt/agentzero/Dockerfile` on PCT-111
```dockerfile
# Custom Agent Zero image with upgraded LiteLLM
# v0.9.8.2 - Updated 2026-02-24

FROM agent0ai/agent-zero:v0.9.8.2

# Upgrade LiteLLM to 1.81.11+ to get zai provider support
RUN /opt/venv-a0/bin/pip install --upgrade "litellm>=1.81.10"

# Verify zai provider exists
RUN ls -la /opt/venv-a0/lib/python3.12/site-packages/litellm/llms/ | grep -i zai
```

**Rebuild Custom Image** (when upstream updates):
```bash
ssh root@192.168.1.20
cd /opt/agentzero
docker build -t agentzero-custom:latest .
docker compose up -d
```

## Maintenance

### View Logs
```bash
ssh root@192.168.1.20
docker logs -f agent-zero
```

### Restart Container
```bash
ssh root@192.168.1.20
docker restart agent-zero
```

### Update Image
```bash
ssh root@192.168.1.20
cd /path/to/docker-compose
docker-compose pull agent-zero
docker-compose up -d agent-zero
```

## Security Notes

- **Internal SSH**: Port 22 is exposed internally only
- **Kali Linux**: Contains security tools - use responsibly
- **Network Isolation**: Runs in Docker container on isolated network
- **Access Control**: Consider enabling NPM access list for production use

## Troubleshooting

### WebSocket Connection Issues

If the UI shows "connecting... waiting for handshake":

1. **Close all Agent Zero tabs** - Multiple tabs can cause WebSocket conflicts
2. **Clear browser cache** or use **Incognito/Private mode**
3. **Try direct access**: `http://192.168.1.20:50080`

**Note**: The infrastructure has been verified as fully operational (HTTP 200 from all access points). This is a client-side caching issue.

See [WebSocket Troubleshooting](/docs/agentzero/websocket-troubleshooting-2026-02-12.md) for full diagnostic details.

### "Backend Appears Disconnected" Error

If the UI shows "backend appears to be disconnected" or "Cannot read properties of undefined (reading 'running')":

**Cause**: Stale CSRF token in browser cache after container restart. The `runtime_id` changes on restart, invalidating the cached token.

**Fix**: Clear browser site data for agentzero.acmea.tech:
1. Open Chrome DevTools (F12) → Application → Storage → Clear site data
2. Or use Incognito/Private mode
3. Or hard refresh: `Cmd+Shift+R` (Mac) / `Ctrl+Shift+R` (Windows)

See [CSRF Token Cache Issue](/docs/troubleshooting/2026-02-23-agentzero-csrf-token-cache-issue.md) for full details.

### Chat Session History Not Visible After Update

If chat sessions disappear from the sidebar after a Docker update:

**Cause**: Same CSRF token cache issue - WebSocket state sync fails, so UI cannot receive session list.

**Important**: **NO DATA LOSS** - all sessions are preserved on the Docker volume at `/mnt/docker/volumes/agent-zero-data/usr/chats/`.

**Fix**: Same as above - clear browser cache or use incognito mode.

See [Session History UI Issue](/docs/troubleshooting/2026-02-25-agentzero-session-history-ui-issue.md) for full investigation details.

## LLM Configuration

Agent Zero uses a dual-LLM configuration:

| Model | Provider | Model ID | Purpose |
|-------|----------|----------|---------|
| **Chat Model** | Z.ai Native API | `glm-4.7` | High-quality conversations |
| **Utility Model** | OpenRouter | `stepfun/step-3.5-flash:free` | Utility tasks (free tier) |
| **Embedding Model** | HuggingFace | `sentence-transformers/all-MiniLM-L6-v2` | Text embeddings |

See [OpenRouter Integration](/docs/agentzero/openrouter-integration-2026-02-13.md) for detailed configuration and troubleshooting.

## Related Documentation

- [OpenRouter Integration](/docs/agentzero/openrouter-integration-2026-02-13.md)
- [WebSocket Troubleshooting](/docs/agentzero/websocket-troubleshooting-2026-02-12.md)
- [CSRF Token Cache Issue](/docs/troubleshooting/2026-02-23-agentzero-csrf-token-cache-issue.md)
- [Docker VM PCT-111](/docs/docker/pct-111-docker-setup.md)
- [NPM Configuration](/docs/npm/npm.md)
- [Infrastructure Overview](/docs/infrastructure.md)

## Database References

- **Docker Container**: agent-zero (ID in infrastructure-db)
- **NPM Proxy Host**: ID 49
- **Docker Host**: docker-host-pct111 (ID: 17)

---

*Last Updated: 2026-02-24 - Updated to v0.9.8.2 with LiteLLM 1.81.15*
