# Uptime Kuma Monitoring Setup Guide

**Target:** Uptime Kuma instance at http://192.168.1.9:3010
**Purpose:** Configure comprehensive infrastructure monitoring with alerts
**Created:** 2025-10-17

---

## Overview

Uptime Kuma is already running on OMV (192.168.1.9:3010). This guide will help you configure it to monitor critical infrastructure components with automated alerts.

### Current Status

- ✅ Uptime Kuma is accessible at http://192.168.1.9:3010
- ✅ Running in Docker container on OMV host
- ⏳ Needs monitoring configuration
- ⏳ Needs alert notifications setup

---

## Access Uptime Kuma

1. **Open web interface:**
   ```
   http://192.168.1.9:3010
   ```

2. **Login with your credentials**
   - If first time: Create admin account
   - Use strong password (store in password manager)

---

## Critical Monitors to Configure

### 1. Pi-hole DNS (HIGHEST PRIORITY)

**Monitor Type:** DNS
**Monitor Name:** Pi-hole DNS Server
**Hostname:** 192.168.1.5
**DNS Resolver:** 192.168.1.5
**Test Hostname:** google.com
**Port:** 53
**Heartbeat Interval:** 60 seconds
**Retries:** 3
**Notification:** ✅ Enable all alerts

**Why Critical:** Single point of failure for network DNS

---

### 2. OPNsense Firewall

**Monitor Type:** Ping or HTTP
**Monitor Name:** OPNsense Firewall
**Hostname:** 192.168.1.3
**Port:** 443 (if using HTTPS check)
**Heartbeat Interval:** 60 seconds
**Notification:** ✅ Enable all alerts

**Why Critical:** Network gateway and firewall

---

### 3. Proxmox Virtualization Host

**Monitor Type:** HTTP(s)
**Monitor Name:** Proxmox pve2
**URL:** https://192.168.1.10:8006
**Heartbeat Interval:** 120 seconds
**Accept Unauthorized SSL:** ✅ (self-signed cert)
**Notification:** ✅ Enable all alerts

**Why Critical:** Hosts all VMs and LXC containers

---

### 4. Docker Host - Supabase (pct111)

**Monitor Type:** Ping or HTTP
**Monitor Name:** Docker Host pct111
**Hostname:** 192.168.1.20
**Heartbeat Interval:** 120 seconds
**Notification:** ✅ Enable all alerts

**Why Critical:** Hosts Supabase stack and n8n

---

### 5. Docker Host - OMV

**Monitor Type:** Ping
**Monitor Name:** OMV Storage & Docker Host
**Hostname:** 192.168.1.9
**Heartbeat Interval:** 120 seconds
**Notification:** ✅ Enable all alerts

**Why Critical:** Storage server + Immich stack

---

### 6. Supabase Studio

**Monitor Type:** HTTP(s)
**Monitor Name:** Supabase Studio
**URL:** http://192.168.1.20:3000
**Heartbeat Interval:** 300 seconds (5 min)
**Notification:** ✅ Enable on important alerts

---

### 7. Supabase Kong Gateway

**Monitor Type:** HTTP(s)
**Monitor Name:** Supabase Kong Gateway
**URL:** http://192.168.1.20:8000
**Heartbeat Interval:** 300 seconds
**Notification:** ✅ Enable on important alerts

---

### 8. n8n Automation

**Monitor Type:** HTTP(s)
**Monitor Name:** n8n Workflow Automation
**URL:** http://192.168.1.20:5678
**Heartbeat Interval:** 300 seconds
**Notification:** ✅ Enable on important alerts

---

### 9. Immich Photos

**Monitor Type:** HTTP(s)
**Monitor Name:** Immich Photo Management
**URL:** http://192.168.1.9:2283
**Heartbeat Interval:** 300 seconds
**Notification:** ✅ Enable on important alerts

---

### 10. Nginx Proxy Manager

**Monitor Type:** HTTP(s)
**Monitor Name:** Nginx Proxy Manager
**URL:** https://192.168.1.9:81
**Accept Unauthorized SSL:** ✅
**Heartbeat Interval:** 300 seconds
**Notification:** ✅ Enable on important alerts

---

## Notification Setup

Uptime Kuma supports multiple notification channels. Configure at least one:

### Option 1: Discord (Recommended)

1. **Create Discord Webhook:**
   - Open Discord server
   - Server Settings → Integrations → Webhooks → New Webhook
   - Name: "Uptime Kuma Alerts"
   - Copy webhook URL

2. **Configure in Uptime Kuma:**
   - Settings → Notifications → Add
   - Type: Discord
   - Webhook URL: `https://discord.com/api/webhooks/...`
   - Test notification

### Option 2: Email (SMTP)

1. **Configure in Uptime Kuma:**
   - Settings → Notifications → Add
   - Type: Email (SMTP)
   - From Email: `alerts@yourdomain.com`
   - To Email: `your-email@example.com`
   - SMTP Host: `smtp.gmail.com` (or your provider)
   - Port: 587 (TLS) or 465 (SSL)
   - Username: Your email
   - Password: App-specific password

2. **Test notification**

### Option 3: Telegram

1. **Create Telegram Bot:**
   - Message @BotFather on Telegram
   - Send `/newbot` and follow instructions
   - Copy bot token

2. **Get Chat ID:**
   - Message your bot
   - Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Copy chat ID from response

3. **Configure in Uptime Kuma:**
   - Type: Telegram
   - Bot Token: `<your-bot-token>`
   - Chat ID: `<your-chat-id>`

### Option 4: Slack

1. **Create Slack Incoming Webhook:**
   - Slack App Directory → Incoming Webhooks
   - Add to Workspace
   - Choose channel
   - Copy webhook URL

2. **Configure in Uptime Kuma:**
   - Type: Slack
   - Webhook URL: `https://hooks.slack.com/services/...`

---

## Monitor Groups

Organize monitors into logical groups:

### Critical Infrastructure
- Pi-hole DNS
- OPNsense Firewall
- Proxmox pve2
- Docker Host pct111
- OMV Storage

### Application Services
- Supabase Stack
- n8n Automation
- Immich Photos

### Collaboration Tools
- Confluence
- JIRA
- GitLab
- Seafile

---

## Alert Priorities

Configure different notification levels:

### 🔴 CRITICAL (Immediate Alert - ALL Channels)
- Pi-hole DNS
- OPNsense Firewall
- Proxmox Host
- Docker Hosts (pct111, OMV)

### 🟡 HIGH (Alert - Primary Channel Only)
- Supabase Stack
- n8n Automation
- Email Server
- GitLab

### 🟢 MEDIUM (Daily Summary)
- Immich Photos
- Nginx Proxy Manager
- Media Services

---

## Automated Health Check Scripts

Since Uptime Kuma doesn't have a public REST API for adding monitors, I've created scripts to complement it:

### Script 1: Infrastructure Health Check

Create this script to run alongside Uptime Kuma:

```bash
#!/bin/bash
# File: /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/health-check.sh

DB_PATH="/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db"
LOG_FILE="/Users/jm/Codebase/internet-control/infrastructure-db/monitoring/health-check.log"

echo "=== Infrastructure Health Check - $(date) ===" | tee -a "$LOG_FILE"

# Function to check service and log to database
check_service() {
    local service_name="$1"
    local check_command="$2"

    echo -n "Checking $service_name... " | tee -a "$LOG_FILE"

    if eval "$check_command" > /dev/null 2>&1; then
        echo "✅ HEALTHY" | tee -a "$LOG_FILE"
        sqlite3 "$DB_PATH" "INSERT INTO health_checks (service_id, status, check_timestamp) VALUES ((SELECT id FROM services WHERE service_name = '$service_name' LIMIT 1), 'healthy', CURRENT_TIMESTAMP);"
        return 0
    else
        echo "❌ UNHEALTHY" | tee -a "$LOG_FILE"
        sqlite3 "$DB_PATH" "INSERT INTO health_checks (service_id, status, check_timestamp, error_message) VALUES ((SELECT id FROM services WHERE service_name = '$service_name' LIMIT 1), 'unhealthy', CURRENT_TIMESTAMP, 'Health check failed');"
        return 1
    fi
}

# Check critical services
check_service "Pi-hole DNS" "dig @192.168.1.5 google.com +time=2 +tries=1"
check_service "OPNsense Web UI" "curl -k -s -m 5 https://192.168.1.3 -o /dev/null"
check_service "Proxmox Web UI" "curl -k -s -m 5 https://192.168.1.10:8006 -o /dev/null"
check_service "Supabase Studio" "curl -s -m 5 http://192.168.1.20:3000 -o /dev/null"
check_service "n8n Automation" "curl -s -m 5 http://192.168.1.20:5678 -o /dev/null"
check_service "Immich Photos" "curl -s -m 5 http://192.168.1.9:2283 -o /dev/null"

echo "=== Health Check Complete ===" | tee -a "$LOG_FILE"
echo "" >> "$LOG_FILE"
```

Make it executable:
```bash
chmod +x /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/health-check.sh
```

### Script 2: Pi-hole Specific Monitor (High Priority)

```bash
#!/bin/bash
# File: /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/check-pihole.sh

PIHOLE_IP="192.168.1.5"
ALERT_WEBHOOK="YOUR_DISCORD_WEBHOOK_HERE"  # Configure this

# Check DNS
if ! dig @$PIHOLE_IP google.com +time=2 +tries=1 > /dev/null 2>&1; then
    echo "🔴 CRITICAL: Pi-hole DNS is DOWN!"

    # Send alert via webhook
    curl -X POST "$ALERT_WEBHOOK" \
         -H "Content-Type: application/json" \
         -d "{\"content\": \"🔴 CRITICAL ALERT: Pi-hole DNS ($PIHOLE_IP) is DOWN! Network DNS resolution failing.\"}"

    # Log to database
    sqlite3 /Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db \
        "INSERT INTO health_checks (service_id, status, error_message) VALUES ((SELECT id FROM services WHERE service_name = 'Pi-hole DNS' LIMIT 1), 'unhealthy', 'DNS query timeout');"

    exit 1
else
    echo "✅ Pi-hole DNS is healthy"
    exit 0
fi
```

Make it executable:
```bash
chmod +x /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/check-pihole.sh
```

### Script 3: Docker Container Health Monitor

```bash
#!/bin/bash
# File: /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/check-docker-health.sh

DB_PATH="/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db"

# Check Docker host pct111 (192.168.1.20)
echo "Checking Docker containers on pct111 (192.168.1.20)..."
ssh root@192.168.1.20 'docker ps --format "{{.Names}}\t{{.Status}}" | grep unhealthy' | while read line; do
    echo "⚠️  Unhealthy container: $line"
done

# Check Docker host OMV (192.168.1.9)
echo "Checking Docker containers on OMV (192.168.1.9)..."
ssh root@192.168.1.9 'docker ps --format "{{.Names}}\t{{.Status}}" | grep unhealthy' | while read line; do
    echo "⚠️  Unhealthy container: $line"
done
```

Make it executable:
```bash
chmod +x /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/check-docker-health.sh
```

---

## Cron Schedule

Add these to crontab for automated monitoring:

```bash
# Edit crontab
crontab -e

# Add these lines:

# Check Pi-hole DNS every minute (critical)
*/1 * * * * /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/check-pihole.sh >> /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/pihole-check.log 2>&1

# Full infrastructure health check every 5 minutes
*/5 * * * * /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/health-check.sh

# Docker health check every 10 minutes
*/10 * * * * /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/check-docker-health.sh
```

---

## Uptime Kuma Status Page (Optional)

Create a public status page for your infrastructure:

1. **In Uptime Kuma:**
   - Settings → Status Pages → Add
   - Name: "Infrastructure Status"
   - Slug: `infra-status`
   - Select monitors to display
   - Choose theme (light/dark)

2. **Access status page:**
   ```
   http://192.168.1.9:3010/status/infra-status
   ```

3. **Optionally expose via Nginx Proxy Manager:**
   - Create proxy host: `status.yourdomain.com`
   - Forward to: `192.168.1.9:3010`
   - Enable SSL certificate

---

## Dashboard View

Create a monitoring dashboard combining Uptime Kuma with other tools:

### Suggested Layout

**Row 1: Critical Infrastructure**
- Pi-hole DNS status + response time
- OPNsense uptime
- Proxmox resource usage

**Row 2: Docker Hosts**
- pct111 container health (27 containers)
- OMV container health (14 containers)

**Row 3: Key Services**
- Supabase stack uptime
- n8n workflow status
- Immich photos availability

---

## Maintenance

### Weekly Tasks
- Review uptime statistics
- Check for any flapping services
- Verify alert notifications are working

### Monthly Tasks
- Review and adjust heartbeat intervals
- Check notification channels still valid
- Update monitor list for new services

---

## Troubleshooting

### Uptime Kuma Not Accessible

```bash
# Check if container is running
ssh root@192.168.1.9 'docker ps | grep uptime-kuma'

# Check container logs
ssh root@192.168.1.9 'docker logs uptime-kuma --tail 50'

# Restart if needed
ssh root@192.168.1.9 'docker restart uptime-kuma'
```

### Monitors Showing False Positives

1. Increase retry count (3-5 retries)
2. Increase heartbeat interval (reduce check frequency)
3. Adjust timeout values
4. Check network connectivity from OMV to target

### Notifications Not Working

1. Test notification channel in settings
2. Check webhook URLs are still valid
3. Verify SMTP credentials
4. Check spam folder for email alerts

---

## Next Steps

1. ✅ Access Uptime Kuma: http://192.168.1.9:3010
2. ⏳ Configure the 10 critical monitors listed above
3. ⏳ Set up at least one notification channel (Discord recommended)
4. ⏳ Create monitoring scripts in the `monitoring/` directory
5. ⏳ Add cron jobs for automated health checks
6. ⏳ Test alerts by manually stopping Pi-hole service
7. ⏳ Create status page for infrastructure visibility

---

## Related Documentation

- **Infrastructure Overview:** `/infrastructure-db/INFRASTRUCTURE-OVERVIEW.md`
- **Pi-hole Failure Analysis:** `/docs/troubleshooting/pihole-failure-impact-analysis.md`
- **Network Topology:** `/infrastructure-db/NETWORK-TOPOLOGY.md`
- **Database Schema:** `/infrastructure-db/schema.sql`

---

**Created:** 2025-10-17
**Status:** Ready for implementation
**Priority:** HIGH (especially Pi-hole monitoring)
