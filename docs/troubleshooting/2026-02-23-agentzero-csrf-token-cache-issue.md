# Agent Zero CSRF Token Cache Issue

**Date**: 2026-02-23
**Issue**: UI showing "backend appears to be disconnected" - Cannot read properties of undefined (reading 'running')
**Status**: RESOLVED

## Problem Description

After updating Agent Zero to v0.9.8.1 and restarting the container, the web UI showed "backend appears to be disconnected" error:

```
Connection Error
Error sending message (backend appears to be disconnected): Cannot read properties of undefined (reading 'running')
```

## Investigation Summary

### Initial Symptoms
- Container running healthy (Up 17 minutes)
- Health endpoint returning `{"error": null}`
- WebSocket connections being accepted
- OpenRouter API responding with HTTP 200
- All backend services in RUNNING state

### Logs Showed Warning
```
Warning: WebSocket CSRF validation failed for /state_sync: csrf_token not initialized
```

### Root Cause Analysis

1. **Backend verification** - All components working:
   - Container: Up and healthy
   - LiteLLM: Could call OpenRouter API successfully
   - Socket.IO: Polling endpoint returning valid session
   - API keys: Present in both environment and settings.json

2. **Frontend state sync failing** - The CSRF token validation was failing because:
   - Agent Zero uses `runtime_id` to generate CSRF tokens
   - `runtime_id` changes every time the container restarts
   - Browser had cached the old CSRF token from previous session
   - State sync WebSocket messages were being rejected

3. **The fix** - Clearing browser cache/cookies forced the browser to:
   - Fetch a fresh CSRF token
   - Establish a new WebSocket session with valid token
   - State sync started working immediately

## Resolution

### Client-Side Fix (Required after container restarts)

**Option 1: Clear Site Data (Recommended)**
1. Open Chrome DevTools (F12)
2. Go to **Application** tab
3. Click **Storage** → **Clear site data**
4. Refresh the page

**Option 2: Incognito/Private Mode**
- Chrome: `Cmd+Shift+N` (Mac) / `Ctrl+Shift+N` (Windows)
- Navigate to https://agentzero.acmea.tech

**Option 3: Hard Refresh with Cache Clear**
- Chrome: `Cmd+Shift+R` (Mac) / `Ctrl+Shift+R` (Windows)
- Sometimes requires multiple attempts

## Technical Details

### How Agent Zero CSRF Works

1. **Runtime ID Injection** - Server injects `runtime_id` into HTML template:
   ```html
   <script>
   globalThis.runtimeInfo = {
       id: "{{runtime_id}}",
       ...
   };
   </script>
   ```

2. **CSRF Token Fetching** - Frontend calls `getCsrfToken()` which:
   - Reads from cookie named after the `runtime_id`
   - Returns null if cookie not found or `runtime_id` changed
   - Triggers warning: "csrf_token not initialized"

3. **WebSocket Auth** - Socket.IO connection includes CSRF token:
   ```javascript
   auth: (cb) => {
       getCsrfToken()
           .then((token) => cb({ csrf_token: token }))
   }
   ```

4. **State Sync** - The `/state_sync` namespace validates CSRF before sending agent state

### Container Information
- **Container**: agent-zero (CT 111 on pve2)
- **Image**: agentzero-custom:latest (based on agent0ai/agent-zero:v0.9.8.1)
- **Port**: 50080 → 80
- **URL**: https://agentzero.acmea.tech

## Prevention

### After Container Updates/Restarts
Always clear browser cache or use incognito mode when testing after container changes.

### Monitoring
Watch for this warning in logs:
```
Warning: WebSocket CSRF validation failed for /state_sync
```

## Related Issues

This is the same class of issue as the Feb 12 WebSocket troubleshooting - both are client-side cache issues that appear as backend problems.

## Related Documentation

- [Agent Zero WebSocket Troubleshooting](/docs/agentzero/websocket-troubleshooting-2026-02-12.md)
- [Agent Zero README](/docs/agentzero/README.md)

---

*Last Updated: 2026-02-23 - CSRF token cache issue documented*
