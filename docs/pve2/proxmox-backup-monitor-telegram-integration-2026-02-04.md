# Proxmox Backup Monitor - Telegram Integration

**Date**: 2026-02-04
**Host**: pve2 (192.168.1.10)
**Script**: `/root/disaster-recovery/proxmox-backup-monitor.sh`

## Summary

Added Telegram notification capabilities to the Proxmox Backup Monitoring script to enable real-time alerts for backup failures and health issues.

## Changes Made

### 1. Credential Loading (Lines 16-20)

Added after `ALERT_EMAIL="admin@accelior.com"`:

```bash
# Load Telegram credentials
CREDENTIALS_FILE="$(dirname "$0")/.backup-telegram-credentials"
if [[ -f "$CREDENTIALS_FILE" ]]; then
    source "$CREDENTIALS_FILE"
fi
```

**Purpose**: Dynamically loads Telegram bot token and chat ID from a secure credentials file.

**Credentials File**: `/root/disaster-recovery/.backup-telegram-credentials`
- Contains: `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`
- Permissions: Secure file (not world-readable)
- Format:
  ```bash
  TELEGRAM_BOT_TOKEN="bot<token>"
  TELEGRAM_CHAT_ID="<chat_id>"
  ```

### 2. Enhanced send_alert Function (Lines 287-307)

**Replaced placeholder with full Telegram + Email implementation**:

```bash
send_alert() {
    local message="$1"
    local severity="${2:-WARNING}"
    log "ALERT [$severity]: $message"

    # Telegram notification
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] && [[ -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        local emoji="⚠️"
        [[ "$severity" == "CRITICAL" ]] && emoji="🔴"
        [[ "$severity" == "INFO" ]] && emoji="✅"

        local text="${emoji} *Proxmox Backup Alert \[${severity}]*%0A${message}%0A%0AHost: $(hostname)%0ATime: $(date -Iseconds)"

        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${text}" \
            -d "parse_mode=Markdown" >/dev/null 2>&1 && log "Telegram notification sent"
    fi

    # Email notification (fallback)
    if [[ -n "${ALERT_EMAIL:-}" ]]; then
        echo "$message" | mail -s "Proxmox Backup Alert [$severity]" "$ALERT_EMAIL" 2>/dev/null
    fi
}
```

**Features**:
- **Severity-based emojis**:
  - 🔴 CRITICAL - Backup failures, integrity issues
  - ⚠️ WARNING - Size issues, remote sync failures
  - ✅ INFO - Successful operations (optional)
- **Markdown formatting** for rich Telegram messages
- **Silent curl execution** - Only logs on success
- **Dual notification channels**: Telegram (primary) + Email (fallback)
- **Safe defaults**: No alerts if credentials not configured

## Alert Scenarios

The script now sends alerts for the following conditions:

| Check | Severity | Trigger |
|-------|----------|---------|
| Backup Age | CRITICAL | Age > 168 hours (7 days) |
| Backup Size | WARNING | Size < 1GB |
| Integrity | CRITICAL | Corrupted archives, missing files, checksum failures |
| Remote Sync | WARNING | Latest backup not synced to 192.168.1.9 |

## Testing

### Syntax Check
```bash
ssh root@192.168.1.10 'bash -n /root/disaster-recovery/proxmox-backup-monitor.sh'
```
**Result**: ✅ Passed

### Manual Test
```bash
ssh root@192.168.1.10 '/root/disaster-recovery/proxmox-backup-monitor.sh help'
```
**Result**: ✅ Help output displayed correctly

### Credential File Verification
```bash
ssh root@192.168.1.10 'test -f /root/disaster-recovery/.backup-telegram-credentials'
```
**Result**: ✅ Credentials file exists

## Backup

Original script backed up to:
```
/root/disaster-recovery/proxmox-backup-monitor.sh.backup-20260204
```

## Usage Examples

### Run all health checks
```bash
ssh root@192.168.1.10 '/root/disaster-recovery/proxmox-backup-monitor.sh check'
```

### Check only backup age
```bash
ssh root@192.168.1.10 '/root/disaster-recovery/proxmox-backup-monitor.sh age'
```

### Generate full report
```bash
ssh root@192.168.1.10 '/root/disaster-recovery/proxmox-backup-monitor.sh report'
```

## Integration with Cron

The script can be automated via cron for periodic monitoring:

```bash
# Add to crontab for daily checks at 6 AM
0 6 * * * /root/disaster-recovery/proxmox-backup-monitor.sh check
```

## Security Considerations

1. **Credentials file** should not be world-readable:
   ```bash
   chmod 600 /root/disaster-recovery/.backup-telegram-credentials
   ```

2. **Telegram bot token** should be treated as sensitive data

3. **No hardcoded secrets** in the main script

## Troubleshooting

### No Telegram alerts received
- Verify credentials file exists and is readable
- Check `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` values
- Test Telegram API manually:
  ```bash
  curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
    -d "chat_id=<CHAT_ID>" \
    -d "text=Test message"
  ```

### Script execution errors
- Verify syntax: `bash -n /root/disaster-recovery/proxmox-backup-monitor.sh`
- Check script permissions: `chmod +x /root/disaster-recovery/proxmox-backup-monitor.sh`
- Review logs: `/root/disaster-recovery/proxmox-backup-monitor.sh check`

## Related Documentation

- [Proxmox Backup System Overview](/docs/pve2/proxmox-backup-system.md)
- [Backup Verification Procedures](/docs/pve2/backup-verification.md)
- [Infrastructure Database](/infrastructure-db/README.md)

## Files Modified

| File | Action | Date |
|------|--------|------|
| `/root/disaster-recovery/proxmox-backup-monitor.sh` | Modified | 2026-02-04 |
| `/root/disaster-recovery/proxmox-backup-monitor.sh.backup-20260204` | Created | 2026-02-04 |
| `/root/disaster-recovery/.backup-telegram-credentials` | Existing | - |

## Verification Checklist

- [x] Credential loading code added
- [x] send_alert function implemented
- [x] Syntax check passed
- [x] Help command works
- [x] Credentials file exists
- [x] Original script backed up
- [x] Script remains executable

---

**Author**: Infrastructure Team
**Last Updated**: 2026-02-04
