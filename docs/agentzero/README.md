# Agent0 AI - Deployment Documentation

## Overview

**Service**: Agent0 AI (agent0ai/agent-zero)
**Deploy Date**: 2026-01-20
**Last Updated**: 2026-02-12 (WebSocket connection verified - infrastructure fully operational)
**Status**: Running
**Public URL**: https://agentzero.acmea.tech
**Version**: v0.9.8 (2026-02-10)

## Service Details

### Container Information

| Property | Value |
|----------|-------|
| **Container Name** | `agent-zero` |
| **Image** | `agent0ai/agent-zero:latest` |
| **Base Image** | Kali Linux (kali-rolling) |
| **Docker Host** | PCT-111 (192.168.1.20) |
| **Internal Port** | 80 |
| **Published Port** | 50080 |
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

## Related Documentation

- [WebSocket Troubleshooting](/docs/agentzero/websocket-troubleshooting-2026-02-12.md)
- [Docker VM PCT-111](/docs/docker/pct-111-docker-setup.md)
- [NPM Configuration](/docs/npm/npm.md)
- [Infrastructure Overview](/docs/infrastructure.md)

## Database References

- **Docker Container**: agent-zero (ID in infrastructure-db)
- **NPM Proxy Host**: ID 49
- **Docker Host**: docker-host-pct111 (ID: 17)

---

*Last Updated: 2026-02-12 11:00 UTC - WebSocket connection verified and troubleshooting documented*
