# Moltbot (formerly Clawdbot) - Personal AI Assistant

## Overview

**Service**: Moltbot Personal AI Assistant
**Formerly Known As**: Clawdbot (renamed ~January 22, 2026 due to trademark issues)
**Container Type**: Proxmox LXC Container (PCT)
**Deploy Date**: 2024-04-22 (based on home directory timestamp)
**Status**: Running

### Key Information

| Property | Value |
|----------|-------|
| **VMID** | 101 |
| **Container Name** | clawdbot (to be renamed) |
| **New Name** | Moltbot |
| **Status** | running |
| **OS** | Ubuntu 24.04 LTS (Noble Numbat) |
| **Architecture** | amd64 |
| **IP Address** | 192.168.1.151/24 |
| **Gateway** | 192.168.1.3 (OPNsense) |
| **MAC Address** | BC:24:11:51:B6:BD |
| **Memory** | 4096 MB RAM |
| **Swap** | 2048 MB |
| **CPU Cores** | 2 |
| **Disk** | 32G (local-lvm) |
| **Proxmox Host** | pve2 (192.168.1.10) |

## Project Details

### What is Moltbot?

**Moltbot** is a *personal AI assistant* you run on your own devices. It answers you on the channels you already use:

- **Messaging Platforms**: WhatsApp, Telegram, Slack, Discord, Google Chat, Signal, iMessage, Microsoft Teams, WebChat
- **Extension Channels**: BlueBubbles, Matrix, Zalo, Zalo Personal
- **Voice Support**: Can speak and listen on macOS/iOS/Android
- **Live Canvas**: Can render a live Canvas you control

**Tagline**: "EXFOLIATE! EXFOLIATE!" (Lobster/molting reference)

### GitHub Repository

| Property | Value |
|----------|-------|
| **Old Repository** | https://github.com/clawdbot/clawdbot |
| **New Repository** | https://github.com/moltbot/moltbot |
| **Organization** | https://github.com/moltbot |
| **License** | MIT |

### Version Information

| Property | Value |
|----------|-------|
| **Installed Version** | 2026.1.25 (main branch) |
| **Latest Stable Release** | v2026.1.24 (released ~January 20, 2026) |
| **Last Commit** | 6859e1e6a - "fix(webchat): support image-only sends" (2026-01-26) |
| **Node Requirement** | >=22.12.0 |
| **Package Manager** | pnpm@10.23.0 |

## Installation Details

### Source Code Location

| Property | Value |
|----------|-------|
| **Source Directory** | `/opt/clawdbot/` |
| **Installation Method** | Git clone from repository |
| **Last Updated** | 2026-01-26 05:32:29 UTC |

### Whisper.cpp Integration

| Property | Value |
|----------|-------|
| **Whisper Directory** | `/opt/whisper.cpp/` |
| **Whisper Binary** | `/usr/local/bin/whisper` |
| **Model** | ggml-base.bin |
| **Transcription Script** | `/opt/transcribe-audio.sh` |

### Dependencies

Core dependencies include:
- `@mariozechner/pi-agent-core` 0.49.3
- `@whiskeysockets/baileys` 7.0.0-rc.9 (WhatsApp gateway)
- `@slack/bolt` 4.6.0
- `grammy` 1.39.3 (Telegram)
- `discord-api-types` 0.38.37
- `express` 5.2.1
- `playwright-core` 1.58.0
- `sqlite-vec` 0.1.7-alpha.2 (vector database)
- `@napi-rs/canvas` 0.1.88
- `node-llama-cpp` 3.15.0 (local LLM support)

## Running Services

| Service | Status | Details |
|---------|--------|---------|
| **Tailscale** | Running | PID 240, listening on port 41641 |
| **SSH Server** | Running | `/usr/sbin/sshd -D` |
| **Postfix** | Running | Mail server (master + qmgr + pickup) |
| **Systemd services** | Running | journald, networkd, logind, resolved, rsyslogd |

## Device Mounts

The container has special device mounts for VPN/tunnel functionality:
- `/dev/net` (bind mounted)
- `/dev/net/tun` (TUN device for networking - required for Tailscale)

## Name Change: Clawdbot → Moltbot

### Timeline

| Date | Event |
|------|-------|
| ~January 22, 2026 | Project renamed from "Clawdbot" to "Moltbot" |
| January 24, 2026 | Release v2026.1.24 under new name |
| January 26, 2026 | Current installation updated to 2026.1.25 |

### Reason for Rename

The project was renamed due to **trademark considerations**. The lobster-themed "Clawdbot" name conflicted with existing trademarks, leading to a rebrand to "Moltbot" (referencing the molting process lobsters undergo).

### References

- [TechCrunch Article: "Everything you need to know about viral personal AI assistant Clawdbot now Moltbot"](https://techcrunch.com/2026/01/27/everything-you-need-to-know-about-viral-personal-ai-assistant-clawdbot-now-moltbot/)
- [Mashable: "Clawdbot is now Moltbot for reasons that should be obvious"](https://mashable.com/article/clawdbot-changes-name-to-moltbot)
- [Beam.ai: "From Clawdbot to Moltbot: What Happened When Personal AI Assistant Blew Up"](https://beam.ai/agentic-insights/from-clawdbot-to-moltbot-what-happened-when-personal-ai-assistant-blew-up)

## Proxmox Configuration

### Container Configuration

```
arch: amd64
cores: 2
hostname: clawdbot
memory: 4096
net0: name=eth0,bridge=vmbr0,gw=192.168.1.3,hwaddr=BC:24:11:51:B6:BD,ip=192.168.1.151/24,type=veth
onboot: 1
ostype: ubuntu
rootfs: local-lvm:vm-101-disk-0,size=32G
startup: 1
swap: 2048
unprivileged: 1
```

### Startup Configuration

- **Start at Boot**: Yes (onboot: 1)
- **Startup Order**: 1 (starts early in boot sequence)

## Maintenance

### Update to Latest Version

```bash
# SSH to pve2
ssh root@192.168.1.10

# Enter container
pct enter 101

# Pull latest changes
cd /opt/clawdbot
git pull origin main

# Install dependencies
pnpm install

# Build
pnpm build

# Check service status and restart if needed
# (Service management depends on how Moltbot is configured)
```

### View Logs

```bash
# SSH to pve2
ssh root@192.168.1.10

# View container logs
pct exec 101 -- journalctl -u moltbot -f

# Or enter container and check logs
pct enter 101
journalctl -f
```

### Restart Container

```bash
ssh root@192.168.1.10
pct restart 101
```

## Disk Usage

| Filesystem | Size | Used | Available | Use% |
|------------|------|------|-----------|------|
| /dev/mapper/pve-vm--101--disk--0 | 32G | 9.8G | 20G | 33% |

## Network Configuration

### Network Details

| Property | Value |
|----------|-------|
| **Bridge** | vmbr0 (LAN bridge) |
| **IP Address** | 192.168.1.151/24 |
| **Gateway** | 192.168.1.3 (OPNsense firewall) |
| **DNS** | Uses OPNsense for DNS resolution |
| **Tailscale** | Enabled (for secure remote access) |

### Firewall Considerations

- The container is on the internal LAN (192.168.1.0/24)
- Tailscale provides secure remote access
- Outbound internet access via OPNsense NAT

## Upcoming Tasks

1. **Rename Container**: Consider renaming the LXC container from `clawdbot` to `moltbot` to match the new project name
2. **Update Git Remote**: The container still points to the old `clawdbot/clawdbot` repository - should update to `moltbot/moltbot`
3. **Update References**: Update any configuration files or documentation that reference "Clawdbot"

## Related Documentation

- [Infrastructure Overview](/docs/infrastructure.md)
- [Proxmox pve2 Documentation](/docs/proxmox/)
- [Infrastructure Database](/infrastructure-db/README.md)

## Database References

- **LXC Container**: VMID 101
- **Proxmox Host**: pve2 (192.168.1.10)
- **Infrastructure DB**: `/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db`

---

*Last Updated: 2026-01-28 - Initial documentation created following Clawdbot → Moltbot name change investigation*
