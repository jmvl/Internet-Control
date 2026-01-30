# OpenClaw Real-Time Status and Thinking Indicators Guide

**Date**: 2026-01-30
**Purpose**: How to see real-time status and thinking indicators in Telegram

---

## Problem: No Real-Time Feedback

When you send a command to OpenClaw via Telegram, you have to wait without knowing if:
- The agent is stuck
- The agent is reasoning
- The agent is waiting for the LLM API (z.ai)
- The agent is processing your request

---

## Solution 1: Use `/status` Command

### What It Shows

Send `/status` as a standalone message in Telegram to see:
- ✅ Whether agent is reachable
- 📊 How much of session context is used
- 🧠 Current thinking/verbose toggles
- 🔄 When your WhatsApp web creds were last refreshed

### How to Use

Simply type `/status` in your Telegram chat with @Nestor4JM_bot:

```
/status
```

This helps you:
- Spot relink needs
- Verify the agent is working
- Check session context usage
- See current configuration settings

---

## Solution 2: Enable Typing Indicators

### What Are Typing Indicators?

Typing indicators are sent to Telegram while a run is active, showing you that the bot is working on your request.

### Configuration Options

You can control **when** typing starts and **how often** it refreshes:

#### typingMode Options

| Mode | Description | When It Starts |
|--------|-------------|-----------------|
| `never` | No typing indicator, ever | Never |
| `instant` | Start typing as soon as model loop begins | Immediately |
| `thinking` | Start typing on first reasoning delta | When reasoning starts |
| `message` | Start typing on first non-silent text delta | When text appears |

**Order of "how early it fires"**:
`never` → `message` → `thinking` → `instant`

#### typingIntervalSeconds

Controls **how often** the typing indicator refreshes (default: 6 seconds).

### Current Configuration

Your current configuration does **NOT** have `typingMode` set, so it's using the default behavior.

### Recommended Configuration

To see typing indicators as soon as the agent starts reasoning, add this to your configuration:

```json5
{
  "agents": {
    "defaults": {
      "typingMode": "thinking",
      "typingIntervalSeconds": 6
    }
  }
}
```

### How to Apply Configuration

#### Option 1: Via SSH

```bash
# SSH into OpenClaw container
ssh root@192.168.1.151

# Set typing mode
npx openclaw config set agents.defaults.typingMode thinking

# Set typing interval (optional, default is 6)
npx openclaw config set agents.defaults.typingIntervalSeconds 6

# Restart the service to apply changes
systemctl --user restart openclaw-gateway.service
```

#### Option 2: Edit Config File Directly

```bash
# SSH into OpenClaw container
ssh root@192.168.1.151

# Edit the config file
nano /root/.openclaw/openclaw.json
```

Add the `typingMode` and `typingIntervalSeconds` to the `agents.defaults` section:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "zai/glm-4.7"
      },
      "models": {
        "zai/glm-4.7": {}
      },
      "blockStreamingDefault": "off",
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      },
      "typingMode": "thinking",
      "typingIntervalSeconds": 6
    }
  }
}
```

Save and exit (Ctrl+X, then Y, then Enter), then restart:

```bash
systemctl --user restart openclaw-gateway.service
```

---

## Solution 3: Enable Verbose Mode

### What Is Verbose Mode?

Verbose mode shows more detailed information about what the agent is doing, including:
- Tool calls
- Reasoning steps
- Processing status

### How to Enable Verbose Mode

#### Option 1: Per-Session Toggle

Send `/verbose on` in Telegram to enable verbose mode for the current session.

Send `/verbose off` to disable it.

#### Option 2: Global Configuration

```bash
# Set verbose mode globally
npx openclaw config set agents.defaults.verbose true

# Restart service
systemctl --user restart openclaw-gateway.service
```

---

## Solution 4: Monitor Logs in Real-Time

### View Gateway Logs

```bash
# Follow gateway logs in real-time
ssh root@192.168.1.151 "journalctl --user -u openclaw-gateway -f"
```

### View OpenClaw Log File

```bash
# Follow OpenClaw log file
ssh root@192.168.1.151 "tail -f /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log"
```

### Filter for Telegram Activity

```bash
# Show only Telegram-related logs
ssh root@192.168.1.151 "journalctl --user -u openclaw-gateway -f | grep -i telegram"
```

### Filter for Agent Activity

```bash
# Show only agent-related logs
ssh root@192.168.1.151 "journalctl --user -u openclaw-gateway -f | grep -i agent"
```

---

## Solution 5: Use Web Dashboard

### Access the Dashboard

Open your browser and navigate to:
```
https://openclaw.acmea.tech/
```

Or locally:
```
http://192.168.1.151:18789/
```

### What the Dashboard Shows

- 📊 Real-time agent status
- 💬 Active conversations
- 🧠 Current thinking state
- 📝 Session context usage
- 🔧 Configuration settings
- 📈 Usage statistics

### Benefits of the Dashboard

- Visual real-time feedback
- See all active sessions
- Monitor agent activity
- View logs and errors
- Manage configuration

---

## Summary of Recommendations

### Quick Wins (No Configuration Changes)

1. **Use `/status` command** - Check agent status anytime
2. **Use `/verbose on`** - Enable verbose mode for current session
3. **Monitor logs** - Watch real-time activity via SSH

### Recommended Configuration Changes

1. **Enable typing indicators** - Set `typingMode: "thinking"`
2. **Adjust typing interval** - Set `typingIntervalSeconds: 6` (or lower for more frequent updates)

### Best Practice

1. **Use `/status`** when unsure if agent is working
2. **Enable typing indicators** for visual feedback
3. **Monitor logs** when troubleshooting
4. **Use dashboard** for comprehensive monitoring

---

## Troubleshooting

### Typing Indicators Not Showing

**Possible Causes**:
1. `typingMode` is set to `never`
2. Model doesn't emit reasoning deltas (for `thinking` mode)
3. Service needs restart after configuration change

**Solutions**:
1. Check configuration: `npx openclaw config get agents.defaults.typingMode`
2. Restart service: `systemctl --user restart openclaw-gateway.service`
3. Try different mode: Set to `instant` for earliest feedback

### Agent Appears Stuck

**Check**:
1. Send `/status` to verify agent is reachable
2. Check logs for errors: `journalctl --user -u openclaw-gateway -n 50`
3. Verify gateway health: `npx openclaw gateway health`
4. Check LLM API connectivity (z.ai)

### No Real-Time Updates in Telegram

**Remember**:
- Streaming only works in **private chats** with Threaded Mode enabled
- Streaming is **ignored for groups/supergroups/channels**
- Typing indicators work in all chat types
- Use `/status` for status updates

---

## Configuration Reference

### Full Example Configuration

```json5
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "zai/glm-4.7"
      },
      "models": {
        "zai/glm-4.7": {}
      },
      "blockStreamingDefault": "off",
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      },
      "typingMode": "thinking",
      "typingIntervalSeconds": 6,
      "verbose": true
    }
  },
  "channels": {
    "telegram": {
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
  }
}
```

---

## References

- [OpenClaw Session Documentation](https://docs.openclaw.ai/concepts/session)
- [OpenClaw Typing Indicators Documentation](https://github.com/openclaw/openclaw/blob/main/docs/concepts/typing-indicators.md)
- [OpenClaw Telegram Documentation](https://docs.openclaw.ai/channels/telegram)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)

---

**Guide Created**: 2026-01-30T14:38:35Z
**Created By**: Kilo Code
