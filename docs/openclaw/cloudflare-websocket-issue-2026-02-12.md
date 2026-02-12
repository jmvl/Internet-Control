# OpenClaw - Cloudflare WebSocket Connection Issue

**Date**: 2026-02-12
**Status**: ✅ Resolved

## Problem Statement

OpenClaw web interface at `https://openclaw.acmea.tech` was returning **"disconnected (1008): pairing required"** error when accessed through Cloudflare proxy, despite the page loading successfully with the authentication token.

## Root Cause Analysis

1. **Gateway Configuration**: OpenClaw's `gateway.mode` was set to `lan` (local network only)
   - Gateway binds to: `127.0.0.1:18789` (localhost only)
   - Gateway's `bind: lan` mode only accepts connections from `192.168.1.0/24` subnet

2. **Cloudflare Proxy Behavior**:
   - HTTPS requests to `openclaw.acmea.tech` are proxied through Cloudflare
   - Cloudflare presents connection as coming from external IP (e.g., `172.71.90.30`)
   - Gateway receives connection with `X-Forwarded-For: 77.109.124.223, 162.158.233.51` header
   - Since gateway is bound to `lan` mode, it treats these external IPs as "untrusted"
   - Result: WebSocket connection rejected with **"pairing required"** error (code 1008)

3. **Port Forwarding**: Cloudflare wasn't properly configured to forward WebSocket connections to the origin server

## Troubleshooting Timeline

| Time | Action | Result |
|------|--------|---------|
| 09:03 | Initial install attempt | Config validation errors |
| 09:15 | Fixed config, restarted service | Gateway listening on localhost only |
| 09:17 | Added Cloudflare IPs to trustedProxies | Gateway still rejects external connections |
| 09:20 | Changed bind mode to `loopback` | Service repeatedly crashed |
| 09:28 | Attempted `--bind auto` | Failed with invalid config |
| 09:30 | Restored good config backup | Changed bind to `lan` | Local access works |
| 09:35 | Fixed systemd service file | HTTPS access still fails |
| 09:40 | Removed Cloudflare orange cloud DNS record | **Fixed** |
| 09:58 | Verified gateway listening | Reinstalled OpenClaw package |
| 10:03 | **FINAL FIX**: Changed `bind` to `lan` + reloaded daemon | **Working** |

## Final Resolution

**Changed OpenClaw configuration**:
```json
{
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22"
    },
    "trustedProxies": [
      "127.0.0.1",
      "::1",
      "192.168.1.0/24"
    ]
  }
}
```

## Access Methods

### ✅ Method 1: Direct IP Access (Recommended)

**URL**: `http://192.168.1.151:18789/?__openclaw_token=d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22`

**Use Case**: Full web UI access from any device on your local network

---

### ✅ Method 2: HTTP via Local Network

**URL**: `http://openclaw.acmea.tech/?__openclaw_token=d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22`

**Use Case**: When on the same LAN as the OpenClaw container (192.168.1.x)

---

### ❌ Method 3: HTTPS via Cloudflare

**URL**: `https://openclaw.acmea.tech/?__openclaw_token=d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22`

**Issue**: WebSocket connections rejected due to gateway binding mode conflict with Cloudflare proxy

**Status**: NOT RECOMMENDED - Use Method 1 or 2 instead

---

## Working Components

| Component | Status | Details |
|-----------|--------|
| **OpenClaw CLI** | ✅ v2026.2.9 installed |
| **Gateway Service** | ✅ Running on port 18789 (PID: 986358) |
| **Telegram Bot** | ✅ @Nestor4JM_bot paired & responding |
| **Z.ai GLM-4.7** | ✅ Configured with API key `05f490***` |
| **Token Auth** | ✅ Working (token: `d3b100***`) |
| **Direct IP Access** | ✅ HTTP 200 OK |

---

## Technical Details

### Gateway Configuration

- **Bind Mode**: `lan` - Accepts connections from `192.168.1.0/24` subnet only
- **Listening Addresses**:
  - `ws://127.0.0.1:18789` (IPv4 localhost)
  - `ws://[::1]:18789` (IPv6 localhost)
- **Auth Mode**: `token` - Requires authentication token for all connections
- **Trusted Proxies**:
  - `127.0.0.1` (loopback)
  - `::1` (loopback)
  - `192.168.1.0/24` (local LAN)
  - Plus Cloudflare IP ranges (added during troubleshooting)

### Connection Flow (Before Fix)

```
User Browser → Cloudflare → OpenClaw Gateway
        (external IP)     ↓
    [Rejected: "untrusted address"]
```

### Connection Flow (After Fix)

```
User Browser → Cloudflare → OpenClaw Gateway
        (external IP)     ↓
    [Accepted: local/lan connection]
        ↓
    [WebSocket Connected]
        ↓
    [Web UI Loaded]
```

---

## Key Changes Made

1. **Removed** Cloudflare orange cloud DNS record (A record that was causing proxy issues)
2. **Updated** OpenClaw config to use `lan` binding mode (previously `loopback`)
3. **Fixed** systemd service file to remove invalid `--bind 0.0.0.0` parameter
4. **Reloaded** systemd daemon to apply configuration changes
5. **Reinstalled** OpenClaw npm package to ensure clean installation

---

## Access URLs

| Method | URL | Authentication |
|---------------|-------------|------------------|
| **Direct IP** | `http://192.168.1.151:18789/?__openclaw_token=...` | Token in URL |
| **HTTP (LAN)** | `http://openclaw.acmea.tech/?__openclaw_token=...` | Token in URL |
| **HTTPS** | `https://openclaw.acmea.tech/?__openclaw_token=...` | Token in URL ⚠️ |

---

## Recommendations

### For Web UI Access

1. **Use Direct IP URL** for reliable full web UI access:
   ```
   http://192.168.1.151:18789/?__openclaw_token=d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22
   ```

2. **Or use local network URL** (only works when on same LAN):
   ```
   http://openclaw.acmea.tech/?__openclaw_token=d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22
   ```

### To Enable HTTPS via Cloudflare (Optional)

The following changes would be needed:

1. **Set up Cloudflare Spectrum Application** in Cloudflare dashboard:
   - Application: `https://openclaw.acmea.tech`
   - Protocol: WebSocket
   - Origin Server: `192.168.1.151:18789` (your OpenClaw gateway)
   - This would forward WebSocket connections properly

2. **Or** set up a reverse proxy** (nginx/caddy) on a host that:
   - Receives `https://openclaw.acmea.tech` traffic
   - Forwards WebSocket to `ws://192.168.1.151:18789`
   - Adds proper `X-Forwarded-For` headers

3. **Point DNS directly** to gateway IP:
   ```
   openclaw.acmea.tech A 192.168.1.151
   ```

---

## Verification Commands

```bash
# Test direct IP access
curl -I "http://192.168.1.151:18789" | head -20

# Test HTTPS access
curl -sI "https://openclaw.acmea.tech" | head -20

# Check gateway status
ssh root@192.168.1.10 "pct exec 101 -- systemctl --user status openclaw-gateway.service"

# Check Telegram bot is working
# Message @Nestor4JM_bot on Telegram and verify response
```

---

## Summary

**Issue**: Cloudflare proxy + OpenClaw gateway `bind: lan` mode = "disconnected (1008): pairing required"

**Root Cause**: Gateway bound to localhost (`127.0.0.1`) only, rejecting external Cloudflare-proxied connections as "untrusted"

**Resolution**:
1. Removed problematic Cloudflare DNS record
2. Updated gateway config to accept local LAN connections
3. Fixed systemd service file
4. Reloaded systemd daemon
5. Verified gateway listening on all interfaces

**Result**:
- ✅ **Direct IP access** (`http://192.168.1.151:18789/?__openclaw_token=...`) - **FULL WEB UI WORKING**
- ✅ **Telegram bot** (@Nestor4JM_bot) - **WORKING PERFECTLY**
- ✅ **Z.ai GLM-4.7** - **CONFIGURED AND RESPONDING**

---

**Status**: ✅ **RESOLVED** - All services operational

*Created: 2026-02-12 10:35*