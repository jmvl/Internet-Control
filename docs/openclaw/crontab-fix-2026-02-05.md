# OpenClaw Monitor Crontab Fix

**Date**: 2026-02-05
**Host**: nestor (192.168.1.151)
**Issue**: Cron-based monitoring failing to restart gateway

## Problem

The OpenClaw monitor script was unable to restart the gateway when run from cron because `systemctl --user` commands require specific environment variables that are not present in the cron environment.

### Symptoms

- Gateway went down and stayed down for 10+ hours
- Monitor script ran every 5 minutes but failed to restart
- Monitor log showed: `Failed to connect to bus: No medium found`
- 100+ failed restart attempts logged

### Root Cause

Cron jobs lack the `DBUS_SESSION_BUS_ADDRESS` and `XDG_RUNTIME_DIR` environment variables required to control user systemd services:

```bash
# In cron environment:
DBUS_SESSION_BUS_ADDRESS=
XDG_RUNTIME_DIR=
# systemctl --user fails with: Failed to connect to bus: No medium found
```

## Solution

### 1. Updated Monitor Script

Added environment variables to `/root/bin/openclaw-monitor.sh`:

```bash
# Required for systemctl --user in cron
export XDG_RUNTIME_DIR="/run/user/0"
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/0/bus"
```

### 2. Fixed Crontab

Updated crontab to include environment variable and proper logging:

```bash
XDG_RUNTIME_DIR=/run/user/0
*/5 * * * * /root/bin/openclaw-monitor.sh >> /tmp/openclaw-monitor.log 2>&1
*/5 * * * * /root/bin/config-monitor.sh >> /tmp/config-monitor.log 2>&1
```

## Verification

### Crash Recovery Test

Simulated gateway crash and verified automatic recovery:

| Metric | Result |
|--------|--------|
| Detection | Success |
| Recovery time | ~5 seconds |
| Gateway status | Running (PID: 6779) |
| Port 18789 | Responding (HTTP 200) |

### Monitor Log (Successful Recovery)

```
[2026-02-05 08:56:50] Checking OpenClaw gateway status...
[2026-02-05 08:56:50] ERROR: Gateway is not running! Attempting restart...
[2026-02-05 08:56:55] SUCCESS: Gateway restarted successfully
```

### Current Status

- Gateway: Active (running)
- Monitor: Checking every 5 minutes via cron
- Logging: Full output to `/tmp/openclaw-monitor.log`

## Files Modified

- `/root/bin/openclaw-monitor.sh` - Added environment variables
- Crontab - Added `XDG_RUNTIME_DIR` and logging
- `/tmp/openclaw-monitor.log` - Monitor execution log

## References

- OpenClaw Gateway Documentation: https://docs.openclaw.ai/gateway/
- Systemd user sessions: https://www.freedesktop.org/software/systemd/man/systemctl.html#%24XDG_RUNTIME_DIR
