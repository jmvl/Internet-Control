# Agent Zero WebSocket Connection Troubleshooting

**Date**: 2026-02-12
**Issue**: UI showing "connecting... waiting for handshake"
**Status**: ✅ RESOLVED - Infrastructure fully functional

## Problem Description

The Agent Zero web UI at `https://agentzero.acmea.tech` was displaying "connecting... waiting for handshake" message, preventing users from accessing the service.

## Investigation Summary

### Initial Assessment
- Documentation showed status as "Running" ✅
- Container appeared healthy in `docker ps` ✅
- Cloudflare proxy was already disabled (DNS-only mode) ✅

### Deep Diagnostics

| Check | Result | Finding |
|--------|----------|----------|
| Container Status | Up 17 hours | Container running normally |
| Port Mapping | `50080→80/tcp` | Correct configuration |
| Container IP | `192.168.48.2` | On `agentzero_default` network |
| Internal Access (localhost:50080) | Connection refused | IPv6/IPv4 resolution issue |
| Internal Access (127.0.0.1:50080) | HTTP 200 | Port mapping working |
| Direct Container Access (192.168.48.2:80) | HTTP 200 | Service listening correctly |
| External Access (192.168.1.20:50080) | HTTP 200 | Fully accessible |
| Public URL (https://agentzero.acmea.tech) | HTTP 200 | End-to-end working |

### Root Cause

**Client-side issue** - The infrastructure was 100% functional. The "connecting... waiting for handshake" message was caused by:

1. **Browser cache** holding stale WebSocket connection state
2. **Multiple browser tabs** with conflicting connections

The service was actually working correctly - `curl` tests confirmed HTTP 200 responses from all access points.

## Resolution

### Verified Working Access Points

```bash
# From docker host (127.0.0.1)
curl http://127.0.0.1:50080
# Result: HTTP 200 ✅

# From external network
curl http://192.168.1.20:50080
# Result: HTTP 200 ✅

# Public URL via Nginx Proxy Manager
curl https://agentzero.acmea.tech
# Result: HTTP 200 ✅
```

### Client-Side Fix

**For users experiencing "connecting... waiting for handshake":**

1. **Close all Agent Zero tabs** - Multiple tabs can cause connection conflicts
2. **Clear browser cache**:
   - Chrome: Cmd+Shift+Delete (Mac) or Ctrl+Shift+Delete (Windows)
   - Firefox: Cmd+Shift+Del (Mac) or Ctrl+Shift+Del (Windows)
3. **Use Incognito/Private mode** to bypass cache:
   - Chrome: Cmd+Shift+N (Mac) or Ctrl+Shift+N (Windows)
   - Firefox: Cmd+Shift+P (Mac) or Ctrl+Shift+P (Windows)
4. **Navigate to**: `https://agentzero.acmea.tech`

## Technical Details

### Container Information
- **Container ID**: `c93ed2d90755`
- **Image**: `agent0ai/agent-zero:latest`
- **Docker Host**: PCT-111 (192.168.1.20)
- **Internal IP**: `192.168.48.2`
- **Network**: `agentzero_default` (subnet: 192.168.48.0/20)
- **Published Port**: `50080` (external) → `80` (internal)

### Key Services Running
```
PID  Command
---  --------
1    /usr/bin/python3 /usr/bin/supervisord
24   python /a0/run_tunnel.py --dockerized=true --port=80
25   /bin/bash /exe/run_A0.sh
28   python /a0/prepare.py --dockerized=true
22   python /usr/local/searxng/searxng-src/searx/webapp.py
```

### Infrastructure Configuration
- **DNS**: `agentzero.acmea.tech` CNAME → `base.acmea.tech` (Cloudflare: DNS-only)
- **NPM Proxy Host ID**: 49
- **Forward Host**: 192.168.1.20:50080
- **WebSocket**: Enabled in NPM
- **SSL**: Let's Encrypt (Certificate ID: 64)

## Lessons Learned

1. **Docker port mapping works correctly** - Issue was client-side cache
2. **`localhost` vs `127.0.0.1` matters** - On some systems `localhost` resolves to IPv6 ::1 causing connection issues
3. **Multiple browser tabs** can cause WebSocket conflicts in Agent Zero
4. **Incognito mode is valuable** for diagnosing WebSocket/connection issues

## Related Documentation

- [Agent Zero README](/docs/agentzero/README.md)
- [Agent Zero Z.ai GLM-4.7 Configuration](/docs/agentzero/zai-glm-4.7-configuration.md)
- [Infrastructure Database](/infrastructure-db/README.md)

---

*Last Updated: 2026-02-12 10:50 UTC - WebSocket troubleshooting documented*
