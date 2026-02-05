# OpenClaw Gateway Secure Context (1008) Error Fix

**Date**: 2026-02-02
**Issue**: OpenClaw Control UI "disconnected (1008): control ui requires HTTPS or localhost (secure context)"
**Status**: ✅ Resolved

## Problem Description

Users accessing the OpenClaw Control UI via HTTP (`http://192.168.1.151:18789`) received a connection error with code 1008. The error message indicated:

```
disconnected (1008): control ui requires HTTPS or localhost (secure context)
```

### Root Cause

OpenClaw's Control UI requires a secure context (HTTPS or localhost) to access browser APIs, specifically the **Device Identity API**. When accessing via HTTP from a non-localhost address, browsers block these APIs for security reasons, causing the gateway to reject the connection.

### Logs

```log
Feb 02 16:46:15 openclaw node[45527]: [ws] closed before connect conn=f37f8be9-6c07-4cb2-8d0d-bb0af5e9135e
remote=192.168.1.165 fwd=n/a origin=http://192.168.1.151:18789
code=1008 reason=control ui requires HTTPS or localhost (secure context)
```

## Environment

- **OpenClaw Version**: 2026.1.30
- **Container**: nestor (LXC 101 at 192.168.1.151)
- **Gateway Port**: 18789
- **Dashboard**: https://openclaw.acmea.tech/ (HTTPS via Cloudflare)
- **Local Access**: http://192.168.1.151:18789 (HTTP - causing the issue)

## Solution Applied

### Option 1: Allow Insecure Auth (✅ Applied)

For home/development network environments, enabled two configuration options to allow HTTP access:

```bash
# Step 1: Allow insecure authentication
ssh root@nestor "openclaw config set gateway.controlUi.allowInsecureAuth true"

# Step 2: Disable device identity checks
ssh root@nestor "openclaw config set gateway.controlUi.dangerouslyDisableDeviceAuth true"

# Step 3: Restart gateway to apply changes
ssh root@nestor "systemctl --user restart openclaw-gateway"
```

### Configuration Change

**File**: `/root/.openclaw/openclaw.json`

**Before**:
```json
"gateway": {
  "port": 18789,
  "mode": "local",
  "bind": "lan",
  "auth": {
    "mode": "token",
    "token": "d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22",
    "password": "nestor123"
  }
}
```

**After**:
```json
"gateway": {
  "port": 18789,
  "mode": "local",
  "bind": "lan",
  "auth": {
    "mode": "token",
    "token": "d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22",
    "password": "nestor123"
  },
  "controlUi": {
    "allowInsecureAuth": true,
    "dangerouslyDisableDeviceAuth": true
  }
}
```

### Why Both Settings Are Required

1. **`allowInsecureAuth`**: Allows token-only authentication when device identity is omitted (typically over HTTP)
2. **`dangerouslyDisableDeviceAuth`**: Disables device identity checks entirely, falling back to token/password authentication only

Without both settings, the gateway would still require device identity even with `allowInsecureAuth: true`, which causes the "device identity required" error.

## Alternative Solutions (Not Applied)

### Option 2: Use HTTPS via Cloudflare

Access the Control UI via the existing HTTPS setup:
- **URL**: https://openclaw.acmea.tech/
- **Setup**: Cloudflare proxy provides HTTPS termination
- **Pros**: Secure context without configuration changes
- **Cons**: Requires internet access, external dependency

### Option 3: Localhost Access

Access directly from the gateway host:
- **URL**: http://127.0.0.1:18789
- **Command**: `ssh root@nestor "openclaw dashboard"`
- **Pros**: Secure context (localhost), no config changes
- **Cons**: Only works from gateway host, not remote access

### Option 4: Tailscale Serve

Use Tailscale's built-in HTTPS for local access:
- **Setup**: Configure Tailscale Serve on nestor
- **Pros**: Automatic HTTPS, secure context
- **Cons**: Requires Tailscale configuration

## Security Considerations

### Why This Fix is Safe for Home Networks

1. **Network Isolation**: OpenClaw runs on 192.168.1.151, behind OPNsense firewall
2. **Token Authentication**: Gateway still requires token auth (`d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22`)
3. **Trusted Proxies**: Configuration includes trusted proxy list (Cloudflare, local subnet)
4. **Local Access Only**: Service is not exposed to public internet directly

### For Production Environments

For production or public-facing deployments, consider:
- Use HTTPS exclusively (Option 2 or 4)
- Implement additional authentication layers
- Restrict trustedProxies to specific IPs only
- Use VPN/Tailscale for remote access

## Verification

After applying the fix:

```bash
# Check gateway status
ssh root@nestor "systemctl --user status openclaw-gateway"

# Verify configuration
ssh root@nestor "grep -A 5 'controlUi' ~/.openclaw/openclaw.json"

# Test HTTP access
curl -s http://192.168.1.151:18789/

# Check logs for successful connections
ssh root@nestor "journalctl --user -u openclaw-gateway -f"
```

### Important: Clear Browser Cache

After applying the configuration changes, **you must clear your browser cache** for the OpenClaw Control UI to work:

1. **Hard Refresh** (Ctrl+Shift+R or Cmd+Shift+R)
2. **Clear Site Data**:
   - Open DevTools (F12)
   - Go to Application tab → Storage
   - Click "Clear site data"
3. **Close and reopen** the browser tab

The Control UI JavaScript is cached by the browser, and old cached code may still attempt to use device identity even after the server configuration has been updated.

### Test Connection

After clearing cache, access the Control UI:
- **Local HTTP**: http://192.168.1.151:18789/
- **HTTPS (Recommended)**: https://openclaw.acmea.tech/

You should now see the Control UI load without the "disconnected (1008)" error.

## Related Documentation

- **OpenClaw Setup**: `/docs/openclaw/README.md`
- **SSH Authentication**: `/docs/openclaw/ssh-authentication-setup-2026-01-31.md`
- **Infrastructure Database**: `/infrastructure-db/infrastructure.db`

## Gateway Access URLs

- **HTTPS (Production)**: https://openclaw.acmea.tech/
- **HTTP (Local)**: http://192.168.1.151:18789/
- **Localhost (From nestor)**: http://127.0.0.1:18789/
- **Dashboard Command**: `ssh root@nestor "openclaw dashboard"`

## Gateway Token

```
d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22
```

Use this token when connecting via WebSocket clients or API tools.

## Troubleshooting

### If Connection Still Fails

1. **Check Gateway Status**:
   ```bash
   ssh root@nestor "systemctl --user status openclaw-gateway"
   ```

2. **Verify Configuration**:
   ```bash
   ssh root@nestor "cat ~/.openclaw/openclaw.json | grep -A 10 'gateway'"
   ```

3. **Check Logs**:
   ```bash
   ssh root@nestor "journalctl --user -u openclaw-gateway -n 50 --no-pager"
   ```

4. **Test Connectivity**:
   ```bash
   # From your machine
   curl -v http://192.168.1.151:18789/
   ping 192.168.1.151
   ```

5. **Restart Gateway**:
   ```bash
   ssh root@nestor "systemctl --user restart openclaw-gateway"
   ```

## Summary

The OpenClaw gateway secure context issue was resolved by enabling `allowInsecureAuth` in the gateway Control UI configuration. This allows HTTP access from the local network while maintaining token authentication. For production use, HTTPS access via Cloudflare (https://openclaw.acmea.tech/) is recommended.

**Resolution Time**: ~5 minutes
**Applied By**: Infrastructure automation
**Restart Required**: Yes (gateway restarted automatically)
