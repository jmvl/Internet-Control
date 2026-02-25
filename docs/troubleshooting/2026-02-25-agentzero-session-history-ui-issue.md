# Agent Zero Session History UI Issue

**Date**: 2026-02-25
**Issue**: Chat session history not visible in UI after Docker image update
**Status**: RESOLVED (Client-side cache issue - NO DATA LOSS)

## Problem Description

After updating Agent Zero Docker to the latest version (`agentzero-custom:latest` based on v0.9.8.2), the user reported that chat session history was no longer visible in the web UI sidebar.

## Investigation Findings

### Container Status

| Property | Value |
|----------|-------|
| **Image** | `agentzero-custom:latest` |
| **Base Version** | v0.9.8.2 |
| **Created** | 2026-02-24T17:55:55 |
| **Last Restart** | 2026-02-25T08:52:30Z |
| **Status** | Running (healthy) |

### Session Data Verification

**All session data is INTACT** - no data loss occurred. Sessions are stored on the persistent Docker volume:

```
/mnt/docker/volumes/agent-zero-data/usr/chats/
```

Sessions found on disk (10 total):

| Session ID | Created | Name | Status |
|------------|---------|------|--------|
| 5yENTyzy | Feb 12 20:36 | - | Preserved |
| dZRqNrQr | Feb 12 21:20 | - | Preserved |
| mMCV0J5i | Feb 13 09:34 | - | Preserved |
| PK2B5YG1 | Feb 23 19:11 | - | Preserved |
| PXCTecCU | Feb 13 12:07 | - | Preserved |
| ScdAp5Li | Feb 24 15:11 | BTC Signal Agent | Preserved |
| UE9Cp1Qm | Feb 13 11:37 | - | Preserved |
| WhucDmVj | Feb 24 15:12 | BTC Hourly Signal | Preserved |
| YnmpgPF6 | Feb 13 09:41 | - | Preserved |

### Root Cause: CSRF Token Cache Mismatch

The issue is **NOT data loss** - it is a **client-side cache issue** that prevents the UI from receiving session data via WebSocket.

**Evidence from container logs:**
```
Warning: WebSocket authentication failed for /state_sync GaGh3YGSUBWnuOVTAAAB: session not valid
Warning: WebSocket authentication failed for /state_sync Kzrf4gsm08y5W3TkAAAD: session not valid
```

**How the issue occurs:**

1. Agent Zero uses a `runtime_id` that changes on container restart
2. CSRF tokens are tied to this `runtime_id`
3. Browser caches the old CSRF token from the previous session
4. When WebSocket tries to connect, the CSRF validation fails
5. The `/state_sync` WebSocket namespace rejects the connection
6. UI cannot receive the `contexts` list (chat sessions)
7. Sidebar appears empty despite sessions existing on disk

### Session Storage Architecture

```
Agent Zero Session Flow:

[Container Start]
       |
       v
[initialize_migration()] --> Migrates data from tmp/ to usr/
       |
       v
[initialize_chats()] --> persist_chat.load_tmp_chats()
       |
       v
[Read /a0/usr/chats/*/chat.json] --> Deserialize to AgentContext
       |
       v
[AgentContext.all()] --> In-memory context registry
       |
       v
[/poll API] --> build_snapshot() --> contexts array
       |
       v
[WebSocket /state_sync] --> Push to UI
       |
       v
[UI Sidebar] --> Display chat list
```

**The failure point**: WebSocket `/state_sync` connection is rejected due to CSRF token mismatch, so the UI never receives the `contexts` array.

## Resolution

### Client-Side Fix (Required)

**Option 1: Clear Site Data (Recommended)**
1. Open Chrome DevTools (F12)
2. Go to **Application** tab
3. Click **Storage** -> **Clear site data**
4. Refresh the page

**Option 2: Incognito/Private Mode**
- Chrome: `Cmd+Shift+N` (Mac) / `Ctrl+Shift+N` (Windows)
- Navigate to https://agentzero.acmea.tech

**Option 3: Hard Refresh**
- Chrome: `Cmd+Shift+R` (Mac) / `Ctrl+Shift+R` (Windows)
- May require multiple attempts

### Verification

After clearing cache:
1. Login page should appear (if auth enabled)
2. WebSocket connection should establish successfully
3. Chat sessions should appear in sidebar
4. All previous conversations should be accessible

## Technical Details

### Key Files

| File | Purpose |
|------|---------|
| `/a0/python/helpers/persist_chat.py` | Session save/load logic |
| `/a0/python/helpers/state_snapshot.py` | Builds context list for API |
| `/a0/webui/components/sidebar/chats/chats-store.js` | UI chat list management |
| `/a0/run_ui.py` | WebSocket CSRF validation |

### Volume Mounts (docker-compose.yml)

```yaml
volumes:
  - /mnt/docker/volumes/agent-zero-data/chats:/a0/chats
  - /mnt/docker/volumes/agent-zero-data/usr:/a0/usr
```

**Note**: The `usr/` directory contains the actual session data that persists across container updates.

### Related Issues

This is the same class of issue as:
- [CSRF Token Cache Issue (2026-02-23)](/docs/troubleshooting/2026-02-23-agentzero-csrf-token-cache-issue.md)
- [WebSocket Troubleshooting (2026-02-12)](/docs/agentzero/websocket-troubleshooting-2026-02-12.md)

All are client-side cache issues that manifest as backend problems after container restarts.

## Prevention

### After Container Updates/Restarts

Always clear browser cache or use incognito mode when testing after container changes. The `runtime_id` changes on every container restart, invalidating cached CSRF tokens.

### Monitoring

Watch for this warning in logs after container restarts:
```
Warning: WebSocket authentication failed for /state_sync
```

If seen, the UI will need cache clearing to restore full functionality.

## Related Documentation

- [Agent Zero README](/docs/agentzero/README.md)
- [CSRF Token Cache Issue](/docs/troubleshooting/2026-02-23-agentzero-csrf-token-cache-issue.md)
- [WebSocket Troubleshooting](/docs/agentzero/websocket-troubleshooting-2026-02-12.md)

---

*Last Updated: 2026-02-25 - Session history UI issue investigation*
