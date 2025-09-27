#!/bin/bash
# Quick setup script for Netdata Telegram notifications in Docker

# Check if running
if ! docker ps | grep -q netdata; then
    echo "Netdata container not running. Start it first:"
    echo "cd /docs/netdata && docker-compose up -d"
    exit 1
fi

echo "=== Netdata Telegram Setup ==="
echo
echo "1. First, create a bot:"
echo "   - Message @BotFather on Telegram"
echo "   - Send: /newbot"
echo "   - Follow prompts and save the token"
echo
echo "2. Get your chat ID:"
echo "   - Start chat with your bot"
echo "   - Send any message"
echo "   - Visit: https://api.telegram.org/bot<TOKEN>/getUpdates"
echo
read -p "Enter bot token: " BOT_TOKEN
read -p "Enter chat ID: " CHAT_ID

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "Error: Bot token and chat ID required"
    exit 1
fi

echo
echo "Configuring Netdata..."

# Configure Telegram in the container
docker exec netdata bash -c "
sed -i 's/^SEND_TELEGRAM=.*/SEND_TELEGRAM=\"YES\"/' /etc/netdata/health_alarm_notify.conf
sed -i 's/^TELEGRAM_BOT_TOKEN=.*/TELEGRAM_BOT_TOKEN=\"$BOT_TOKEN\"/' /etc/netdata/health_alarm_notify.conf
sed -i 's/^DEFAULT_RECIPIENT_TELEGRAM=.*/DEFAULT_RECIPIENT_TELEGRAM=\"$CHAT_ID\"/' /etc/netdata/health_alarm_notify.conf
"

echo "Testing configuration..."
docker exec netdata /usr/libexec/netdata/plugins.d/alarm-notify.sh test "telegram:$CHAT_ID"

echo
echo "Configuration complete!"
echo "Check your Telegram for test message."
echo "Restart if needed: docker restart netdata"
