# OpenClaw - Personal AI Assistant

**Container**: openclaw (formerly moltbot/clawdbot)
**VMID**: 101
**Proxmox Host**: pve2 (192.168.1.10)
**IP Address**: 192.168.1.151/24
**GitHub**: https://github.com/openclaw/openclaw
**Version**: 2026.2.9 (Reinstalled 2026-02-12)

## Overview

OpenClaw is a personal AI assistant that connects to multiple messaging platforms including WhatsApp, Telegram, Slack, Discord, Signal, iMessage, Microsoft Teams, and WebChat. It features voice support on macOS/iOS/Android and a Live Canvas for interactive output.

### Key Information

| Property | Value |
|----------|-------|
| **Container Name** | openclaw |
| **Hostname** | openclaw |
| **Status** | running |
| **OS** | Ubuntu 24.04 LTS (Noble Numbat) |
| **Architecture** | amd64 |
| **IP Address** | 192.168.1.151/24 |
| **Gateway Port** | 18789 |
| **Memory** | 4096 MB RAM |
| **CPU Cores** | 2 |
| **Disk** | 32G (local-lvm) |

## Quick Start

### SSH Access

```bash
# From macOS
ssh root@nestor

# From pve2
ssh root@192.168.1.10 "pct enter 101"

# Direct IP
ssh root@192.168.1.151
```

### Web Access

- **Dashboard**: https://openclaw.acmea.tech/
- **Gateway Token**: `d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22`

## OpenClaw CLI Commands

### Core Commands

```bash
npx openclaw --help              # Show help
npx openclaw --version           # Show version
npx openclaw --dev               # Use dev profile (isolated state)
npx openclaw --profile <name>    # Use named profile
```

## Gateway Management

### Gateway Control

```bash
npx openclaw gateway run                    # Run gateway (foreground)
npx openclaw gateway start                  # Start gateway service
npx openclaw gateway stop                   # Stop gateway service
npx openclaw gateway restart                # Restart gateway service
npx openclaw gateway status                 # Show gateway status
npx openclaw gateway health                 # Check gateway health
npx openclaw gateway install                # Install gateway service
npx openclaw gateway uninstall             # Uninstall gateway service
```

### Gateway Options

```bash
npx openclaw gateway --port 18789           # Set port
npx openclaw gateway --bind lan             # Bind mode (loopback|lan|tailnet)
npx openclaw gateway --token <token>        # Set auth token
npx openclaw gateway --auth password        # Auth mode (token|password)
npx openclaw gateway --force                # Kill existing listener first
npx openclaw gateway --verbose              # Verbose logging
```

## Channel Management

### Channel Commands

```bash
npx openclaw channels list                 # List all channels
npx openclaw channels status                # Show channel status
npx openclaw channels status --deep         # Deep channel status check
npx openclaw channels capabilities          # Show provider capabilities
npx openclaw channels resolve               # Resolve names to IDs
npx openclaw channels logs                  # Show recent channel logs
```

### Channel Account Management

```bash
npx openclaw channels add                   # Add channel account
npx openclaw channels remove                # Remove channel account
npx openclaw channels login                 # Link channel account
npx openclaw channels logout                # Logout from channel
```

### Telegram Examples

```bash
npx openclaw channels add telegram          # Add Telegram account
npx openclaw channels login telegram        # Link Telegram (interactive)
npx openclaw channels status telegram       # Check Telegram status
```

## Model Management

### Model Commands

```bash
npx openclaw models list                    # List available models
npx openclaw models status                  # Show configured model state
npx openclaw models set <model>             # Set default model
npx openclaw models set-image <model>       # Set image model
npx openclaw models scan                    # Scan OpenRouter free models
npx openclaw models aliases                 # Manage model aliases
npx openclaw models fallbacks               # Manage fallback list
npx openclaw models auth                    # Manage auth profiles
```

## Device & Node Management

### Device Pairing

```bash
npx openclaw devices list                   # List pending/paired devices
npx openclaw devices approve <request-id>   # Approve device pairing
npx openclaw devices reject <request-id>    # Reject device pairing
npx openclaw devices rotate <role>           # Rotate device token
npx openclaw devices revoke <role>           # Revoke device token
```

### Node Management

```bash
npx openclaw nodes list                     # List all nodes
npx openclaw nodes list --connected         # List connected nodes
npx openclaw nodes list --last-connected 24h  # Filter by connection time
npx openclaw nodes pending                  # Show pending nodes
```

## Configuration

### Config Commands

```bash
npx openclaw config                         # Run config wizard
npx openclaw config get <path>              # Get config value
npx openclaw config set <path> <value>      # Set config value
npx openclaw config unset <path>            # Remove config value
```

### Config Examples

```bash
npx openclaw config set gateway.bind lan
npx openclaw config get gateway.port
npx openclaw config get channels.telegram.botToken
```

## Messaging & Agent

### Message Commands

```bash
npx openclaw message send --target +15551234567 --message "Hi"
npx openclaw message send --channel telegram --target @chat --message "Hi"
npx openclaw message send --json            # Output JSON result
```

### Agent Commands

```bash
npx openclaw agent --to +15551234567 --message "Run summary"
npx openclaw agent --local                   # Run embedded mode
npx openclaw agents list                    # Manage agents
```

## System & Diagnostics

### Status & Health

```bash
npx openclaw status                         # Show channel health
npx openclaw health --verbose                # System health check
npx openclaw doctor                          # Run diagnostics
npx openclaw doctor --repair                 # Auto-fix issues
```

### Logs & Events

```bash
npx openclaw logs --follow                  # Follow gateway logs
npx openclaw system                         # System events & heartbeat
npx openclaw sessions                       # List conversation sessions
```

## Advanced Features

### Setup & Wizard

```bash
npx openclaw setup                          # Initialize config
npx openclaw onboard                        # Interactive setup wizard
npx openclaw configure                      # Interactive configuration
```

### TUI & Dashboard

```bash
npx openclaw tui                            # Terminal UI
npx openclaw dashboard                      # Open Control UI
```

### Plugins & Skills

```bash
npx openclaw plugins list                   # List plugins
npx openclaw plugins enable <plugin>        # Enable plugin
npx openclaw skills list                    # List skills
```

### Memory & Search

```bash
npx openclaw memory search                  # Search memory
```

### Pairing

```bash
npx openclaw pairing list telegram          # List pending Telegram pairings
npx openclaw pairing approve telegram <CODE>  # Approve pairing
```

## Current Configuration

### Model (Z.ai / Zhipu AI)

```json
{
  "primary": "zai/glm-4.7"
}
```

**Environment Variables**:
- `ZAI_API_KEY`: Configured in systemd service and config

### Gateway

```json
{
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
    "192.168.1.121",
    "192.168.1.0/24"
  ]
}
```

### Telegram

```json
{
  "enabled": true,
  "dmPolicy": "pairing",
  "botToken": "835412***",
  "groupPolicy": "allowlist",
  "streamMode": "partial",
  "textChunkLimit": 4000,
  "mediaMaxMb": 20,
  "linkPreview": true,
  "historyLimit": 50,
  "dmHistoryLimit": 100,
  "configWrites": true,
  "groups": {
    "*": {
      "requireMention": true
    }
  }
}
```

## Quick Reference Card

| Category | Command | Description |
|----------|---------|-------------|
| **Status** | `openclaw status` | System health |
| **Gateway** | `openclaw gateway start` | Start gateway |
| **Channels** | `openclaw channels status` | Channel status |
| **Models** | `openclaw models set glm-4.7` | Set model |
| **Devices** | `openclaw devices list` | List devices |
| **Config** | `openclaw config get <path>` | Get config |
| **Logs** | `openclaw logs --follow` | Follow logs |
| **Message** | `openclaw message send --target <id>` | Send message |
| **Wizard** | `openclaw onboard` | Setup wizard |
| **Doctor** | `openclaw doctor --repair` | Fix issues |

## Services

### Systemd Service

```bash
# Service status
systemctl status openclaw.service

# Restart service
systemctl restart openclaw.service

# View logs
journalctl -u openclaw -f
```

### Directory Structure

```
/opt/openclaw              # Installation directory
/root/.openclaw/           # State directory
  ├── openclaw.json        # Config file
  ├── credentials/         # Auth credentials
  ├── agents/              # Agent workspaces
  ├── devices/             # Device pairing
  └── sessions/            # Conversation sessions
```

## Backup Location

Old Moltbot installation backed up at:
```
/root/moltbot-backup/
├── .clawdbot/              # Config & credentials
└── clawdbot.service        # Old systemd service
```

## Related Documentation

- [Infrastructure Overview](/docs/infrastructure.md)
- [Proxmox pve2 Documentation](/docs/proxmox/)
- [Infrastructure Database](/infrastructure-db/README.md)
- [OpenClaw CLI Docs](https://docs.openclaw.ai/cli)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)

---

*Last Updated: 2026-02-12 - Complete reinstallation with OpenClaw v2026.2.9*

## Troubleshooting

### Bot Not Responding

**CRITICAL: Two-Tier Configuration Requirement**

OpenClaw messaging channels require **BOTH** configurations to be enabled:

1. **Channel Configuration**: `channels.telegram.enabled = true`
2. **Plugin Configuration**: `plugins.entries.telegram.enabled = true`

If the bot is receiving messages (confirmed via Telegram API) but not responding, check:

```bash
# Check channel is enabled
npx openclaw config get channels.telegram.enabled

# Check plugin is enabled (CRITICAL!)
npx openclaw config get plugins.entries.telegram.enabled

# If plugin is disabled, enable it
npx openclaw config set plugins.entries.telegram.enabled true

# Restart gateway
systemctl --user restart openclaw-gateway

# Verify channel appears in list
npx openclaw channels list
```

**Common Issue**: After reinstallations or updates, the channel may be enabled but the plugin disabled. See [telegram-bot-not-responding-fix-2026-02-12.md](/docs/openclaw/telegram-bot-not-responding-fix-2026-02-12.md) for detailed troubleshooting.

### Quick Diagnostic Commands

```bash
# Service status
systemctl --user status openclaw-gateway

# Channel list (should show Telegram)
npx openclaw channels list

# Check logs
journalctl -u openclaw-gateway.service -f

# Verify bot token
curl -s https://api.telegram.org/bot<TOKEN>/getMe

# Check for pending messages
curl -s https://api.telegram.org/bot<TOKEN>/getUpdates
```

## Reinstallation History

- **2026-02-12**: Complete reinstallation due to invalid `runtime` key in configuration. See [reinstall-2026-02-12.md](/docs/openclaw/reinstall-2026-02-12.md) for details.
- **2026-02-12**: Fixed Telegram bot not responding - plugin was disabled. See [telegram-bot-not-responding-fix-2026-02-12.md](/docs/openclaw/telegram-bot-not-responding-fix-2026-02-12.md).
- **2026-01-30**: Initial migration from Moltbot to OpenClaw
