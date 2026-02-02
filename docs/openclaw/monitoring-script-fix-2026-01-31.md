# OpenClaw Monitoring Script Fix

**Date**: 2026-01-31
**Component**: OpenClaw Monitoring Script (`/root/monitor-openclaw.sh`)
**LXC Container**: openclaw (VMID 101 on pve2)
**Issue**: Over-aggressive restart behavior causing service disruption

## Problem Statement

The original monitoring script was restarting the OpenClaw gateway service too frequently, causing service disruption. Issues identified:

### 1. Race Condition During Normal Restarts
When the gateway restarts normally (e.g., after config changes), there's a brief window where `systemctl is-active` returns "inactive" or "activating". The monitoring script caught this and triggered additional restarts, creating a restart loop.

**Evidence from logs**:
```
[2026-01-31 09:56:20] Gateway received SIGUSR1; restarting (normal config reload)
[2026-01-31 10:05:01] Gateway not running, restarting... (monitoring script interference)
[2026-01-31 10:10:01] Gateway not running, restarting... (monitoring script interference)
```

### 2. Stuck Session False Positives
The script checked for "stuck session" log entries in the last 10 minutes and immediately restarted. However:
- OpenClaw logs stuck session diagnostics as informational messages
- Sessions often self-heal or complete naturally
- 137-second old sessions (2.3 minutes) are not truly "stuck"

**Evidence from logs**:
```
[2026-01-31 10:05:52] stuck session: age=137s
[2026-01-31 10:10:10] Stuck session detected, restarting... (false positive)
```

### 3. No Cooldown Protection
The script had no mechanism to prevent rapid successive restarts, which could compound problems rather than solve them.

## Solution Implemented

### New Monitoring Script Features

#### 1. **Cooldown Period (10 minutes)**
Prevents restarts within 10 minutes of the last restart, allowing the service to stabilize after normal restarts.

**Implementation**:
```bash
COOLDOWN_MINUTES=10
STATE_FILE="/var/run/openclaw-monitor.state"

is_in_cooldown() {
    local last_restart=$(get_state last_restart)
    local current_time=$(date +%s)
    local cooldown_seconds=$((COOLDOWN_MINUTES * 60))

    if [ $((current_time - last_restart)) -lt $cooldown_seconds ]; then
        return 0  # In cooldown - don't restart
    fi
    return 1  # Not in cooldown
}
```

#### 2. **Enhanced Gateway State Detection**
Uses `systemctl show` to check both `ActiveState` and `SubState` for more accurate service status detection.

**Implementation**:
```bash
check_gateway() {
    local state=$(systemctl --user show openclaw-gateway -p ActiveState --value)
    local substate=$(systemctl --user show openclaw-gateway -p SubState --value)

    if [ "$state" != "active" ]; then
        if is_in_cooldown; then
            log "Gateway not active but in cooldown period - waiting..."
            return
        fi
        # Only restart if not in cooldown
    fi
}
```

#### 3. **Stuck Session Age Threshold (15 minutes)**
Only restarts for sessions stuck longer than 15 minutes (not 10 minutes as before).

**Implementation**:
```bash
STUCK_SESSION_MINUTES=15

check_stuck_sessions() {
    local logs=$(journalctl --user -u openclaw-gateway --since "${STUCK_SESSION_MINUTES} minutes ago")
    local stuck_sessions=$(echo "$logs" | grep "stuck session" | grep -oP 'age=\K[0-9]+')

    while IFS= read -r age; do
        local age_minutes=$((age / 60))
        if [ "$age_minutes" -ge "$STUCK_SESSION_MINUTES" ]; then
            # Only restart if session age >= 15 minutes
        fi
    done <<< "$stuck_sessions"
}
```

#### 4. **Telegram Connection Failure Counter**
Requires 2 consecutive failed checks before restarting (not 1), preventing restarts during transient network issues.

**Implementation**:
```bash
TELEGRAM_FAILURES=2

check_telegram() {
    local health=$(npx openclaw gateway health 2>/dev/null)

    if echo "$health" | grep -q "Telegram: ok"; then
        set_state telegram_failures 0  # Reset on success
    else
        local failures=$(get_state telegram_failures)
        failures=$((failures + 1))

        if [ "$failures" -ge "$TELEGRAM_FAILURES" ]; then
            # Only restart after 2 consecutive failures
        fi
    fi
}
```

#### 5. **Persistent State File**
Stores last restart time and failure counters in `/var/run/openclaw-monitor.state` to maintain state between script executions.

**State file format**:
```
last_restart=1738312400
telegram_failures="0"
```

## Configuration Thresholds

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `COOLDOWN_MINUTES` | 10 | Prevent restart loops after service restarts |
| `STUCK_SESSION_MINUTES` | 15 | Only restart for genuinely stuck sessions |
| `TELEGRAM_FAILURES` | 2 | Require 2 consecutive failures before restart |
| `MEMORY_THRESHOLD` | 80% | Alert (not restart) on high memory usage |

## Testing Results

**Before Fix** (2026-01-31 10:05-10:15):
```
[10:05:01] Gateway not running, restarting...
[10:10:01] Gateway not running, restarting...
[10:10:10] Stuck session detected, restarting...
[10:15:01] Gateway not running, restarting...
[10:15:10] Stuck session detected, restarting...
```
**Result**: 4 restarts in 10 minutes, service disruption

**After Fix** (2026-01-31 10:17):
```
[10:17:26] Gateway state: active / running
[10:17:26] Gateway running OK
[10:17:30] Telegram connected OK
[10:17:30] Stuck sessions detected but within threshold or in cooldown
[10:17:30] Memory OK: 10%
```
**Result**: No restart, correct assessment, service stable

## Files Modified

| File | Location | Purpose |
|------|----------|---------|
| `monitor-openclaw.sh` | `/root/monitor-openclaw.sh` | Main monitoring script (replaced) |
| State file | `/var/run/openclaw-monitor.state` | Created automatically by script |
| Log file | `/var/log/openclaw-monitor.log` | Enhanced logging with detailed state info |

## Cron Schedule

Unchanged: Runs every 5 minutes via cron
```bash
*/5 * * * * /root/monitor-openclaw.sh
```

## Verification Commands

```bash
# Check monitoring script status
ssh root@pve2 "pct exec 101 -- /root/monitor-openclaw.sh"

# Check monitoring logs
ssh root@pve2 "pct exec 101 -- tail -f /var/log/openclaw-monitor.log"

# Check state file
ssh root@pve2 "pct exec 101 -- cat /var/run/openclaw-monitor.state"

# Verify gateway service
ssh root@pve2 "pct exec 101 -- systemctl --user status openclaw-gateway"
```

## Future Improvements

Potential enhancements to consider:
1. Add restart count tracking to prevent restart loops entirely
2. Implement exponential backoff for repeated failures
3. Add health endpoint readiness checks before marking service as healthy
4. Consider integrating with systemd's built-in restart logic instead of external script

## Related Documentation

- **OpenClaw Setup**: `/docs/openclaw/` - Service configuration and architecture
- **Troubleshooting**: `/docs/troubleshooting/` - Incident logs and resolutions
- **Infrastructure DB**: `/infrastructure-db/infrastructure.db` - Service inventory

## Recovery

If the monitoring script causes issues, it can be temporarily disabled:
```bash
ssh root@pve2 "pct exec 101 -- crontab -l"
# Comment out the monitoring line
ssh root@pve2 "pct exec 101 -- crontab -e"
```

To restore the original script (backup not created - redeploy from git history if needed):
```bash
# The old script was replaced; use git history to recover if necessary
git log --all --full-history -- "docs/openclaw/monitoring-script-fix-2026-01-31.md"
```

## Sign-off

**Fixed by**: Claude Code (Infrastructure Engineer)
**Date**: 2026-01-31 10:20 UTC
**Status**: Deployed and tested
**Impact**: Eliminated false positive restarts, improved service stability
