# OpenClaw Telegram Streaming Issue - Investigation Report

**Date**: 2026-01-30
**Container**: openclaw (VMID: 101)
**IP Address**: 192.168.1.151
**Issue**: Telegram not receiving streaming text and real-time updates

---

## Executive Summary

The investigation revealed TWO separate issues:

1. **Service Conflict**: Duplicate OpenClaw services were running, causing the gateway to fail
2. **Telegram Streaming Limitation**: Streaming requires Telegram Bot API 9.3+ with "Threaded Mode" enabled via @BotFather

Both issues have been resolved. The service is now running correctly, and the requirements for Telegram streaming have been identified.

---

## Issue 1: Service Conflict (RESOLVED)

### Root Cause
Two OpenClaw services were configured and running simultaneously:

1. **System Service**: `/etc/systemd/system/openclaw.service` (incorrect)
2. **User Service**: `/root/.config/systemd/user/openclaw-gateway.service` (correct)

The system service was attempting to start but failing because the user service was already using port 18789, causing a continuous restart loop.

### Evidence
```
Jan 30 14:25:25 openclaw npx[64232]: Gateway failed to start: gateway already running (pid 64113); lock timeout after 5000ms
Jan 30 14:25:25 openclaw npx[64232]: Port 18789 is already in use.
Jan 30 14:25:25 openclaw npx[64232]: - pid 64113 root: openclaw-gateway (*:18789)
Jan 30 14:25:25 openclaw npx[64232]: Gateway already running locally. Stop it (openclaw gateway stop) or use a different port.
```

### Resolution
```bash
# Disabled and stopped the conflicting system service
systemctl disable openclaw.service
systemctl stop openclaw.service

# Verified the correct user service is running
systemctl --user status openclaw-gateway.service
```

### Current Status
```
● openclaw-gateway.service - OpenClaw Gateway (v2026.1.29)
     Loaded: loaded (/root/.config/systemd/user/openclaw-gateway.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-01-30 14:27:54 UTC
   Main PID: 64757 (openclaw-gatewa)
      Tasks: 17 (limit: 76384)
     Memory: 329.7M (peak: 330.8M)
        CPU: 6.394s
```

### Gateway Health
```
Gateway Health
OK (97ms)
Telegram: ok (@Nestor4JM_bot) (97ms)
```

---

## Issue 2: Telegram Streaming Requirements

### Root Cause
Telegram streaming in OpenClaw requires specific Telegram Bot API features that may not be enabled by default.

### Technical Requirements

According to OpenClaw documentation and Telegram Bot API 9.3+:

1. **Bot API Version**: Telegram Bot API 9.3 or higher
2. **Threaded Mode**: Must be enabled for the bot via @BotFather
3. **Private Chats Only**: Streaming is **ignored for groups/supergroups/channels**
4. **sendMessageDraft API**: OpenClaw uses this method for streaming (not real messages)

### How Streaming Works in OpenClaw

OpenClaw uses the Telegram Bot API's `sendMessageDraft` method to:
- Send partial messages to a user while being generated
- Update the draft bubble with latest streaming text
- Send the final reply as a normal message

### Configuration

Current Telegram configuration:
```json
{
  "enabled": true,
  "configWrites": true,
  "dmPolicy": "pairing",
  "botToken": "8354121845:AAF2brbzFO3n_e0EVvkOUoxWIUliUPUUnN8",
  "groups": {
    "*": {
      "requireMention": true
    }
  },
  "groupPolicy": "allowlist",
  "historyLimit": 50,
  "dmHistoryLimit": 100,
  "textChunkLimit": 1000,
  "draftChunk": {
    "breakPreference": "paragraph"
  },
  "blockStreamingCoalesce": {},
  "streamMode": "partial",
  "mediaMaxMb": 20,
  "actions": {
    "reactions": true,
    "sendMessage": true,
    "deleteMessage": true,
    "sticker": true
  },
  "linkPreview": true
}
```

### streamMode Options

- `"off"`: Streaming disabled
- `"partial"`: Update draft bubble with latest streaming text (current setting)
- `"block"`: Block streaming entirely

---

## Action Required: Enable Threaded Mode

To enable Telegram streaming, you must enable "Threaded Mode" for your bot:

### Steps to Enable Threaded Mode

1. **Open Telegram** and search for `@BotFather`
2. **Start a chat** with @BotFather
3. **Send the command**: `/mybots`
4. **Select your bot**: `@Nestor4JM_bot`
5. **Choose "Bot Settings"**
6. **Select "Threaded Mode"**
7. **Toggle it ON**

### Verification

After enabling Threaded Mode, verify streaming works:

```bash
# Check channel status
ssh root@192.168.1.151 "npx openclaw channels status"

# Check gateway health
ssh root@192.168.1.151 "npx openclaw gateway health"

# View logs for streaming activity
ssh root@192.168.1.151 "journalctl --user -u openclaw-gateway -f"
```

---

## Important Limitations

### Streaming Not Supported In:
- **Groups**: Telegram groups
- **Supergroups**: Telegram supergroups
- **Channels**: Telegram channels

### Streaming Only Works In:
- **Private Chats**: Direct messages with the bot (when Threaded Mode is enabled)

### From OpenClaw Documentation:
> "Never send streaming/partial replies to external messaging surfaces (WhatsApp, Telegram); only final replies should be delivered there. Streaming/tool events may still go to internal UIs/control channel."

---

## Service Management Commands

### Check Service Status
```bash
# User service (correct)
systemctl --user status openclaw-gateway.service

# System service (disabled)
systemctl status openclaw.service
```

### Restart Service
```bash
# Restart the user service
systemctl --user restart openclaw-gateway.service
```

### View Logs
```bash
# Follow service logs
journalctl --user -u openclaw-gateway -f

# View OpenClaw log file
tail -f /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log
```

### Gateway Commands
```bash
# Check gateway health
npx openclaw gateway health

# Check channel status
npx openclaw channels status

# View configuration
npx openclaw config get channels.telegram
```

---

## Summary

### What Was Fixed
1. ✅ Resolved service conflict by disabling duplicate system service
2. ✅ Verified user service is running correctly
3. ✅ Confirmed gateway health is OK
4. ✅ Confirmed Telegram channel is operational

### What Needs To Be Done
1. ⚠️ Enable "Threaded Mode" for @Nestor4JM_bot via @BotFather
2. ⚠️ Test streaming in private chats after enabling Threaded Mode
3. ⚠️ Note that streaming will NOT work in groups/supergroups/channels

### Current System Status
- **Gateway**: Running and healthy (PID 64757)
- **Port**: 18789 (listening)
- **Telegram**: Connected and operational (@Nestor4JM_bot)
- **Memory Usage**: 329.7M
- **CPU**: 6.394s total

---

## References

- [OpenClaw Telegram Documentation](https://docs.openclaw.ai/channels/telegram)
- [Telegram Bot API Changelog](https://core.telegram.org/bots/api-changelog)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [OpenClaw AGENTS.md](https://github.com/openclaw/openclaw/blob/main/AGENTS.md)

---

**Report Generated**: 2026-01-30T14:31:10Z
**Investigated By**: Kilo Code
