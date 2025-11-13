# Uptime Kuma Monitoring Setup

Automated setup and configuration for Uptime Kuma infrastructure monitoring.

## Quick Start

### 1. Install Dependencies

```bash
pip3 install uptime-kuma-api
```

### 2. Run Automated Setup

The script will automatically load credentials from `.uptime-kuma-credentials`:

```bash
cd /Users/jm/Codebase/internet-control/infrastructure-db/monitoring
python3 setup-uptime-kuma.py
```

This will create all critical infrastructure monitors:
- 🔴 Pi-hole DNS (60s interval)
- 🔴 OPNsense Firewall (60s interval)
- 🔴 Proxmox pve2 (120s interval)
- 🟡 Docker Host pct111 (120s interval)
- 🟡 OMV Storage (120s interval)
- Supabase Studio (300s interval)
- Supabase Kong Gateway (300s interval)
- n8n Automation (300s interval)
- Immich Photos (300s interval)
- Nginx Proxy Manager (300s interval)

## Configuration

### Credentials File (Recommended)

Credentials are stored in `.uptime-kuma-credentials`:

```bash
UPTIME_KUMA_URL=http://192.168.1.9:3010
UPTIME_KUMA_USERNAME=jmvl
UPTIME_KUMA_PASSWORD=jkljkl!970
UPTIME_KUMA_API_TOKEN=uk2_Y7IWpE-8dUZPUx7woAc2IJrAXXORQaii6k1pvnjX

# Optional: Discord webhook for notifications
# DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE
```

**Security:**
- File permissions: `600` (owner read/write only)
- Excluded from git via `.gitignore`
- Never commit this file to version control

### Command Line Arguments (Alternative)

```bash
# Using API token
python3 setup-uptime-kuma.py \
  --url http://192.168.1.9:3010 \
  --token uk2_Y7IWpE-8dUZPUx7woAc2IJrAXXORQaii6k1pvnjX

# Using username/password
python3 setup-uptime-kuma.py \
  --url http://192.168.1.9:3010 \
  --username jmvl \
  --password 'jkljkl!970'

# With Discord notifications
python3 setup-uptime-kuma.py \
  --discord-webhook https://discord.com/api/webhooks/YOUR_WEBHOOK
```

## Uptime Kuma Access

- **Web Interface:** http://192.168.1.9:3010
- **Username:** jmvl
- **Password:** jkljkl!970
- **API Token:** uk2_Y7IWpE-8dUZPUx7woAc2IJrAXXORQaii6k1pvnjX

## Adding Discord Notifications

### 1. Create Discord Webhook

1. Open your Discord server
2. Server Settings → Integrations → Webhooks
3. Click "New Webhook"
4. Name it "Uptime Kuma Alerts"
5. Choose a channel (e.g., #infrastructure-alerts)
6. Copy webhook URL

### 2. Add to Credentials File

Edit `.uptime-kuma-credentials`:

```bash
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE
```

### 3. Run Setup Script

```bash
python3 setup-uptime-kuma.py
```

The script will automatically configure Discord notifications for all monitors.

## Password Reset

If you forget your password, see the reset guide:

```bash
cat /Users/jm/Codebase/internet-control/docs/uptime-kuma/reset-password.md
```

Quick reset command:
```bash
ssh root@192.168.1.9 '
  docker stop uptime-kuma && \
  cp /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db \
     /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db.backup && \
  sqlite3 /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db "DELETE FROM user;" && \
  docker start uptime-kuma
'
```

## Monitoring Strategy

### Check Intervals

**Critical Infrastructure (60-120s):**
- Pi-hole DNS: 60s (single point of failure)
- OPNsense Firewall: 60s (network gateway)
- Proxmox Host: 120s (VM/container host)
- Docker Hosts: 120s (application platform)

**Application Services (300s):**
- Supabase, n8n, Immich: 5min checks
- Nginx Proxy Manager: 5min checks

### Alert Priorities

**🔴 CRITICAL (immediate response required):**
- Pi-hole DNS down = network-wide DNS failure
- OPNsense down = no internet access
- Proxmox down = all VMs/containers offline

**🟡 HIGH (response within 30 minutes):**
- Docker hosts down = application services unavailable
- Supabase down = development platform offline

**🟢 MEDIUM (response within 24 hours):**
- Individual application services
- Monitoring tools themselves

## Files

- `setup-uptime-kuma.py` - Automated monitor configuration script
- `.uptime-kuma-credentials` - Secure credentials file (gitignored)
- `.gitignore` - Prevents credential files from being committed
- `UPTIME-KUMA-SETUP.md` - Manual setup guide
- `setup-uptime-kuma-monitoring.md` - Detailed configuration guide
- `README.md` - This file

## Troubleshooting

### API Connection Failed

```bash
# Verify Uptime Kuma is running
ssh root@192.168.1.9 'docker ps | grep uptime-kuma'

# Check logs
ssh root@192.168.1.9 'docker logs uptime-kuma --tail 50'

# Test web access
curl -I http://192.168.1.9:3010
```

### Invalid API Token

1. Log in to web interface: http://192.168.1.9:3010
2. Settings → API Keys
3. Generate new token
4. Update `.uptime-kuma-credentials`

### Monitor Already Exists

The script will skip existing monitors. To recreate:
1. Delete monitors via web UI
2. Run script again

### Import Error: uptime_kuma_api

```bash
pip3 install uptime-kuma-api
```

## Related Documentation

- **Password Reset Guide:** `/docs/uptime-kuma/reset-password.md`
- **Pi-hole Failure Analysis:** `/docs/troubleshooting/pihole-failure-impact-analysis.md`
- **Infrastructure Overview:** `/infrastructure-db/INFRASTRUCTURE-OVERVIEW.md`
- **Network Topology:** `/infrastructure-db/NETWORK-TOPOLOGY.md`

---

**Created:** 2025-10-17
**Updated:** 2025-10-17
**Status:** Production Ready
