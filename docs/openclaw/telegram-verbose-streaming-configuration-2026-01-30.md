# OpenClaw Telegram Verbose Mode and Streaming Configuration

**Date**: 2026-01-30
**Container**: openclaw (VMID: 101)
**IP Address**: 192.168.1.151
**Issue**: Telegram not showing thought process streaming or verbose output

---

## Executive Summary

OpenClaw's Telegram integration was missing configuration for typing indicators and verbose output was not enabled. The fix involved:
1. Setting `typingMode: "thinking"` to show typing indicators when reasoning starts
2. Setting `typingIntervalSeconds: 6` for periodic typing updates
3. Enabling verbose mode via Telegram command `/verbose on`

---

## Symptoms

### User Reports
- No visible thinking/reasoning process in Telegram
- No typing indicators when agent is processing
- Console shows "I cannot read HEARTBEAT.md" error

### Expected Behavior
- Typing indicator should appear when agent starts processing
- Verbose mode should show detailed processing information
- HEARTBEAT.md access is expected behavior (not an error)

---

## Root Cause Analysis

### Phase 1: Configuration Check

**Missing Configuration:**
```json
"agents": {
  "defaults": {
    // ❌ "typingMode" was not set
    // ❌ "typingIntervalSeconds" was not set
  }
}
```

**Existing Configuration:**
```json
"channels": {
  "telegram": {
    "streamMode": "partial",  // ✅ Already enabled
    "textChunkLimit": 1000    // ✅ Already set
  }
}
```

### Key Findings

1. **`typingMode`** controls when typing indicators appear:
   - `never` - No typing indicator
   - `instant` - Starts immediately when message received
   - `thinking` - Starts when reasoning begins (recommended)
   - `message` - Starts when text generation begins

2. **`verbose` is a session command, not a config setting:**
   - Send `/verbose on` in Telegram to enable for current session
   - Send `/verbose off` to disable
   - Cannot be persisted in `openclaw.json`

3. **HEARTBEAT.md "error" is expected:**
   - Agent is instructed to read HEARTBEAT.md during heartbeat polls
   - File exists at `/root/.openclaw/workspace/HEARTBEAT.md`
   - This is normal behavior, not an actual error

---

## Resolution

### Step 1: Enable Typing Mode

```bash
ssh root@192.168.1.151 "npx openclaw config set agents.defaults.typingMode thinking"
```

### Step 2: Set Typing Interval

```bash
ssh root@192.168.1.151 "npx openclaw config set agents.defaults.typingIntervalSeconds 6"
```

### Step 3: Restart Gateway

```bash
ssh root@192.168.1.151 "systemctl --user restart openclaw-gateway.service"
```

### Step 4: Enable Verbose Mode in Telegram

Send this command directly in your chat with @Nestor4JM_bot:

```
/verbose on
```

---

## Verification

### Check Configuration Applied

```bash
ssh root@192.168.1.151 "npx openclaw config get agents.defaults"
```

**Expected Output:**
```json
{
  "model": {
    "primary": "zai/glm-4.7"
  },
  "models": {
    "zai/glm-4.7": {}
  },
  "blockStreamingDefault": "off",
  "typingMode": "thinking",           // ✅ Set
  "typingIntervalSeconds": 6,         // ✅ Set
  "maxConcurrent": 4,
  "subagents": {
    "maxConcurrent": 8
  }
}
```

### Check Gateway Health

```bash
ssh root@192.168.1.151 "npx openclaw gateway health"
```

**Expected Output:**
```
Gateway Health
OK (39ms)
Telegram: ok (@Nestor4JM_bot) (39ms)
```

### Test in Telegram

1. Send a message to @Nestor4JM_bot
2. Send `/verbose on`
3. Send a question/request
4. You should see:
   - **Typing indicator** 🔄 appears when reasoning starts
   - **Verbose output** shows detailed processing steps

---

## Configuration Reference

### Typing Mode Options

| Mode | Description | When Typing Starts |
|------|-------------|-------------------|
| `never` | No typing indicator | Never |
| `instant` | Starts immediately | When message received |
| `thinking` | Starts on reasoning delta | When reasoning starts ✅ |
| `message` | Starts on text delta | When text appears |

**Recommended:** `thinking` - Shows activity when agent actually starts thinking.

### Typing Interval

- **Setting:** `typingIntervalSeconds: 6`
- **Effect:** Sends typing indicator update every N seconds
- **Recommended:** 4-8 seconds (6 is good balance)

### Verbose Mode Commands

| Command | Effect |
|---------|--------|
| `/verbose on` | Enable verbose for current session |
| `/verbose off` | Disable verbose for current session |
| `/status` | Show session status and settings |

**Note:** Verbose mode must be enabled per session. It does not persist across sessions.

---

## About HEARTBEAT.md

### What It Is

`HEARTBEAT.md` is a workspace file that contains periodic task instructions for the agent. When the agent receives a heartbeat poll, it reads this file to check for background tasks.

**Location:** `/root/.openclaw/workspace/HEARTBEAT.md`

### The "Error" Message

When you see:
> "I cannot read HEARTBEAT.md as I do not have access to your workspace files or external documents."

**Root Cause:** The heartbeat prompt in AGENTS.md was ambiguous. It said "Read HEARTBEAT.md if it exists (workspace context)" without explicitly instructing the agent to **use the `read` tool**.

**Fix Applied (2026-01-30):** Updated AGENTS.md heartbeat prompt to explicitly say:
```
Use the read tool to read HEARTBEAT.md from the workspace directory.
```

**Result:** The agent now knows to use its `read` tool to access workspace files during heartbeats.

### How to Verify the Fix

After the next heartbeat, the agent should successfully read HEARTBEAT.md and either:
- Execute the tasks listed in HEARTBEAT.md
- Reply `HEARTBEAT_OK` if no attention is needed

### HEARTBEAT.md Content

```markdown
# HEARTBEAT.md

## Auto-Update Taskboard

1. Run taskboard sync
2. Review heartbeat-state.json
3. Send Telegram updates if needed
4. Report only if unexpected changes

# Keep this file empty to skip heartbeat API calls.
```

---

## Telegram Streaming Overview

### How Streaming Works

OpenClaw uses Telegram's `sendMessageDraft` API for streaming:

1. **Partial Mode (`streamMode: "partial"`)**: Sends draft messages while generating
2. **Threaded Mode**: Requires Telegram Bot API 9.3+ with topics enabled
3. **Chunking**: Splits messages at `textChunkLimit` (1000 characters)

### Streaming Requirements

- ✅ Bot API 9.3+ (current)
- ✅ Private chat with bot enabled
- ✅ `streamMode: "partial"` configured
- ✅ `/verbose on` in Telegram session
- ✅ `typingMode: "thinking"` configured

### What Verbose Mode Shows

When enabled, verbose mode displays:
- Tool invocations and results
- Reasoning/thinking deltas
- Memory access operations
- Configuration changes
- Processing steps

---

## Troubleshooting

### Typing Indicators Not Showing

**Check:**
1. `typingMode` is set to `thinking` or `instant`
2. Gateway has been restarted since config change
3. Model emits reasoning deltas (for `thinking` mode)

**Fix:**
```bash
ssh root@192.168.1.151 "npx openclaw config set agents.defaults.typingMode instant"
ssh root@192.168.1.151 "systemctl --user restart openclaw-gateway.service"
```

### Verbose Mode Not Working

**Possible Causes:**
1. Not enabled for current session (send `/verbose on`)
2. Agent not using verbose-capable model
3. Session state reset

**Fix:** Send `/verbose on` in Telegram chat.

### HEARTBEAT.md Errors Persist

**If critical:** Check file permissions
```bash
ssh root@192.168.1.151 "ls -la /root/.openclaw/workspace/HEARTBEAT.md"
ssh root@192.168.1.151 "chmod 644 /root/.openclaw/workspace/HEARTBEAT.md"
```

**If non-critical:** Ignore - agent continues functioning normally.

---

## Related Documentation

- [OpenClaw README](/docs/openclaw/README.md)
- [Telegram Streaming Investigation](/docs/openclaw/telegram-streaming-investigation-2026-01-30.md)
- [WebSocket Domain Migration Fix](/docs/troubleshooting/2026-01-30-openclaw-websocket-domain-migration-fix.md)
- [Infrastructure Database](/docs/infrastructure-db/README.md)

---

**Report Created**: 2026-01-30T17:25:00Z
**Created By**: Claude Code
**Status**: RESOLVED
