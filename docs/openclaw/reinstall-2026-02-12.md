# OpenClaw Complete Reinstallation

**Date**: 2026-02-12
**Container**: openclaw (VMID: 101)
**Host**: pve2 (192.168.1.10)
**IP**: 192.168.1.151
**Version**: 2026.2.9

## Problem Statement

OpenClaw installation was broken with configuration errors. The gateway had an invalid `runtime` key that was not recognized by the new version, causing the service to fail to start.

Error encountered:
```
Invalid config at /root/.openclaw/openclaw.json:
- gateway: Unrecognized key: "runtime"
```

## Solution: Complete Reinstallation

### Phase 1: Backup Existing Configuration

**Backup location**: `/root/openclaw-backup-20260212/`

Commands executed:
```bash
# SSH into container via pve2
ssh root@192.168.1.10 "pct exec 101 -- bash"

# Create backup directory
mkdir -p /root/openclaw-backup-20260212

# Backup configuration
cp -r /root/.openclaw /root/openclaw-backup-20260212/
cp /etc/systemd/system/openclaw.service /root/openclaw-backup-20260212/
```

**Credentials preserved**:
- Telegram bot token: `835412***` (redacted)
- Z.ai API key: `05f490***` (redacted)

### Phase 2: Remove OpenClaw Installation

Commands executed:
```bash
# Stop and disable services
systemctl stop openclaw.service
systemctl disable openclaw.service
rm -f /etc/systemd/system/openclaw.service
rm -f ~/.config/systemd/user/openclaw-gateway.service
systemctl daemon-reload

# Uninstall npm package
npm uninstall -g openclaw

# Remove configuration directories
rm -rf /root/.openclaw
rm -rf /opt/openclaw

# Remove remaining binaries
rm -f /usr/local/bin/openclaw
rm -rf /usr/lib/openclaw
```

### Phase 3: Fresh Installation

```bash
# Install latest OpenClaw via npm
npm install -g openclaw

# Verify installation
openclaw --version
# Output: 2026.2.9
```

### Phase 4: Configuration

#### Set Telegram Bot Token
```bash
export ZAI_API_KEY=05f49065dad947f589e85d110f951124.2lLflesMv4Zd9V25
openclaw config set channels.telegram.botToken 8354121845:AAF2brbzFO3n_e0EVvkOUoxWIUliUPUUnN8
```

#### Set Z.ai API Key
```bash
openclaw config set env.ZAI_API_KEY 05f49065dad947f589e85d110f951124.2lLflesMv4Zd9V25
```

#### Set Primary Model
```bash
openclaw config set agents.defaults.model.primary zai/glm-4.7
```

#### Enable Telegram Channel
```bash
openclaw config set channels.telegram.enabled true
openclaw config set plugins.entries.telegram.enabled true
```

#### Configure Gateway
```bash
# Set gateway mode (required for gateway to start)
openclaw config set gateway.mode local

# Set gateway port
openclaw config set gateway.port 18789

# Set gateway bind mode
openclaw config set gateway.bind lan

# Set authentication mode
openclaw config set gateway.auth.mode token

# Set authentication token
openclaw config set gateway.auth.token d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22
```

### Phase 5: Systemd Service Setup

Created system-wide systemd service at `/etc/systemd/system/openclaw.service`:

```ini
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment="NODE_ENV=production"
Environment="ZAI_API_KEY=05f49065dad947f589e85d110f951124.2lLflesMv4Zd9V25"
Environment="ZAI_BASE_URL=https://open.bigmodel.cn/api/paas/v4"
ExecStart=/usr/bin/openclaw gateway run
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start service:
```bash
systemctl daemon-reload
systemctl enable openclaw.service
systemctl start openclaw.service
```

### Phase 6: Verification

#### Service Status
```bash
systemctl status openclaw.service
```
Output:
```
● openclaw.service - OpenClaw Gateway
   Loaded: loaded (/etc/systemd/system/openclaw.service; enabled)
   Active: active (running) since Thu 2026-02-12 09:04:54 UTC
```

#### Gateway Port
```bash
ss -tlnp | grep 18789
```
Output:
```
LISTEN 0  511  0.0.0.0:18789  0.0.0.0:*  users:(("openclaw-gatewa",pid=983940,fd=22))
```

#### Gateway Logs
```
2026-02-12T09:04:57.124Z [canvas] host mounted at http://0.0.0.0:18789/__openclaw__/canvas/
2026-02-12T09:04:57.179Z [heartbeat] started
2026-02-12T09:04:57.184Z [gateway] agent model: zai/glm-4.7
2026-02-12T09:04:57.188Z [gateway] listening on ws://0.0.0.0:18789 (PID 983940)
2026-02-12T09:04:57.289Z [telegram] [default] starting provider (@Nestor4JM_bot)
```

## Configuration Summary

### Final Configuration File

Location: `/root/.openclaw/openclaw.json`

```json
{
  "meta": {
    "lastTouchedVersion": "2026.2.9",
    "lastTouchedAt": "2026-02-12T09:03:17.710Z"
  },
  "env": {
    "ZAI_API_KEY": "05f49065dad947f589e85d110f951124.2lLflesMv4Zd9V25"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "zai/glm-4.7"
      },
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist",
      "streamMode": "partial"
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22"
    }
  },
  "plugins": {
    "entries": {
      "telegram": {
        "enabled": true
      }
    }
  }
}
```

### Gateway Configuration

| Property | Value |
|----------|-------|
| **Port** | 18789 |
| **Mode** | local |
| **Bind** | lan |
| **Auth Mode** | token |
| **Auth Token** | d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22 |

### Telegram Configuration

| Property | Value |
|----------|-------|
| **Enabled** | true |
| **Bot Token** | 8354121845:AAF2brbzFO3n_e0EVvkOUoxWIUliUPUUnN8 |
| **Bot Username** | @Nestor4JM_bot |
| **DM Policy** | pairing |
| **Group Policy** | allowlist |

### Model Configuration

| Property | Value |
|----------|-------|
| **Primary Model** | zai/glm-4.7 |
| **Provider** | Z.ai (Zhipu AI) |
| **API Key** | 05f49065dad947f589e85d110f951124.2lLflesMv4Zd9V25 |

## Key Changes from Previous Configuration

### Removed Invalid Keys
The invalid `runtime` key in the gateway configuration was removed. This key was causing the configuration to fail validation.

### New Required Configuration
The `gateway.mode` key is now required and must be set to `local` for the gateway to start.

### Plugin Configuration
The Telegram plugin must be enabled explicitly via `plugins.entries.telegram.enabled`.

## Access Information

### Web Dashboard
- **URL**: http://192.168.1.151:18789/
- **Auth Token**: `d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22`

### Canvas Host
- **URL**: http://192.168.1.151:18789/__openclaw__/canvas/

### WebSocket Gateway
- **URL**: ws://192.168.1.151:18789
- **Auth Token**: `d3b100e6742a6edf24e9e44db49fc8d3c9650508acb95a22`

### Telegram Bot
- **Bot Username**: @Nestor4JM_bot
- **Status**: Running and ready for pairing

## Troubleshooting

### Service Fails to Start
If the service fails to start with "gateway already running" error:
```bash
# Kill all OpenClaw processes
killall -9 openclaw-gateway openclaw

# Restart service
systemctl start openclaw.service
```

### Gateway Configuration Invalid
If configuration errors occur:
```bash
# Run doctor to fix
openclaw doctor --fix

# Check configuration
openclaw config get gateway
```

### Telegram Not Connecting
Check logs for Telegram connection status:
```bash
journalctl -u openclaw.service -f | grep telegram
```

## Maintenance Commands

### Check Service Status
```bash
systemctl status openclaw.service
```

### Restart Service
```bash
systemctl restart openclaw.service
```

### View Logs
```bash
# Systemd logs
journalctl -u openclaw.service -f

# OpenClaw logs
cat /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log
```

### Update Configuration
```bash
# After changing config, restart gateway
systemctl restart openclaw.service
```

## References

- [OpenClaw Documentation](https://docs.openclaw.ai)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [Z.ai (Zhipu AI) Documentation](https://docs.z.ai)
- [Infrastructure Overview](/docs/infrastructure.md)
- [OpenClaw README](/docs/openclaw/README.md)

---

*Last Updated: 2026-02-12 09:05 UTC - Complete reinstallation with OpenClaw v2026.2.9*
