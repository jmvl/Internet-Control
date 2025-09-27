# Netdata Telegram Notifications Setup

## Prerequisites
- Netdata running (Docker or native)
- Telegram account
- Bot token and chat ID

## Configuration Steps

### 1. Access Netdata Configuration
For Docker installation:
```bash
# Access the running container
docker exec -it netdata bash

# Edit the health notification config
nano /etc/netdata/health_alarm_notify.conf
```

### 2. Configure Telegram Settings
Add/modify these lines in `/etc/netdata/health_alarm_notify.conf`:

```bash
# Enable Telegram notifications
SEND_TELEGRAM="YES"

# Bot token from @BotFather
TELEGRAM_BOT_TOKEN="123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ"

# Your chat ID
DEFAULT_RECIPIENT_TELEGRAM="your_chat_id"

# Optional: Custom message format
TELEGRAM_MESSAGE_FORMAT="plain"
```

### 3. Test Configuration
```bash
# Test Telegram notifications
/usr/libexec/netdata/plugins.d/alarm-notify.sh test

# Or test specific recipient
/usr/libexec/netdata/plugins.d/alarm-notify.sh test "telegram:your_chat_id"
```

### 4. Restart Netdata
For Docker:
```bash
docker restart netdata
```

## Alert Customization

### Per-Alert Configuration
In `/etc/netdata/health.d/` files, you can specify Telegram recipients:
```
alarm: cpu_usage
on: system.cpu
to: telegram:chat_id
```

### Message Templates
Customize message format in `health_alarm_notify.conf`:
```bash
# Available variables: ${alarm}, ${status}, ${hostname}, ${chart}, etc.
TELEGRAM_MESSAGE_FORMAT="markdown"
```

## Troubleshooting

### Check Logs
```bash
# Docker logs
docker logs netdata

# Look for Telegram notification attempts
grep -i telegram /var/log/netdata/error.log
```

### Common Issues
1. **Invalid bot token**: Verify token from @BotFather
2. **Wrong chat ID**: Use `/getUpdates` API to find correct ID
3. **Bot not started**: Send `/start` to your bot first
4. **Network issues**: Check container network access

### Testing Bot Token
```bash
# Test bot API directly
curl "https://api.telegram.org/bot<BOT_TOKEN>/getMe"
```

## Security Notes
- Store bot token securely
- Consider using environment variables for sensitive data
- Limit bot permissions in Telegram