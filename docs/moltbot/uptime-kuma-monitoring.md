# Moltbot - Uptime Kuma Monitoring Setup

## Overview

This document describes the Uptime Kuma monitoring configuration for the Moltbot service.

## Uptime Kuma Service

| Property | Value |
|----------|-------|
| **Service** | Uptime Kuma |
| **URL** | http://192.168.1.9:3010 |
| **Docker Host** | OMV (192.168.1.9) |
| **Container** | uptime-kuma |
| **Status** | Healthy (running 4+ weeks) |

## Moltbot Monitoring Configuration

### Service Details

| Property | Value |
|----------|-------|
| **Service Name** | moltbot |
| **Container** | moltbot (formerly clawdbot) |
| **VMID** | 101 |
| **Proxmox Host** | pve2 (192.168.1.10) |
| **Internal IP** | 192.168.1.151 |
| **Tailscale IP** | 100.77.69.24 |
| **Gateway Port** | 18789 |

### Monitor Setup Options

**Note**: The Moltbot gateway has been configured to bind to all interfaces (0.0.0.0:18789) for monitoring access via Tailscale.

**Configuration Change**: The gateway bind setting was changed from `"loopback"` to `"lan"` in `/root/.clawdbot/clawdbot.json` and the container was rebooted.

#### Option 1: Tailscale Endpoint (Recommended)

Monitor the Tailscale endpoint directly:

| Setting | Value |
|---------|-------|
| **Monitor Type** | HTTP |
| **Friendly Name** | Moltbot Gateway |
| **URL** | http://100.77.69.24:18789 |
| **Check Interval** | 60 seconds |
| **Method** | GET |
| **Expected Status** | (gateway doesn't return HTTP, use TCP instead) |

**Better Configuration (TCP)**:

| Setting | Value |
|---------|-------|
| **Monitor Type** | TCP Port |
| **Friendly Name** | Moltbot Gateway |
| **Hostname** | 100.77.69.24 |
| **Port** | 18789 |
| **Check Interval** | 60 seconds |

#### Option 2: Proxmox Container Status

Monitor the container status via Proxmox API:

| Setting | Value |
|---------|-------|
| **Monitor Type** | HTTP |
| **Friendly Name** | Moltbot Container |
| **URL** | https://192.168.1.10:8006/api2/json/nodes/pve2/lxc/101/status/current |
| **Method** | GET |
| **Headers** | Authorization: PVEAPIToken=<token> |

#### Option 3: Docker Container (if running in Docker)

Not applicable - Moltbot runs in an LXC container.

## Database Configuration

The monitoring relationship is documented in the infrastructure database:

```sql
-- Service dependency entry
SELECT * FROM service_dependencies
WHERE dependent_service_id = 23 AND dependency_service_id = 80;
```

| Column | Value |
|--------|-------|
| **dependent_service_id** | 23 (Uptime Kuma) |
| **dependency_service_id** | 80 (moltbot) |
| **dependency_type** | soft |
| **description** | Uptime Kuma monitors Moltbot service health via Tailscale endpoint |

## Uptime Kuma Setup Instructions

### 1. Access Uptime Kuma

1. Navigate to http://192.168.1.9:3010
2. Login with your Uptime Kuma credentials

### 2. Add Monitor - TCP Port (Recommended)

1. Click **Add New Monitor**
2. Configure as follows:
   - **Monitor Type**: TCP Port
   - **Friendly Name**: Moltbot Gateway (Tailscale)
   - **Hostname**: 100.77.69.24
   - **Port**: 18789
   - **Check Interval**: 60 seconds
   - **Retry Interval**: 60 seconds
   - **Retries**: 3
   - **Resend Interval**: 0
3. Click **Save**

### 3. Add Monitor - Container Status (Optional)

1. Click **Add New Monitor**
2. Configure as follows:
   - **Monitor Type**: HTTP
   - **Friendly Name**: Moltbot Container Status
   - **URL**: http://192.168.1.10:8006
   - **Method**: GET
   - **Expected Status Code**: 401 (unauthorized but host is up)
3. Click **Save**

### 4. Configure Notifications

Recommended notification channels:

| Channel | Purpose |
|---------|---------|
| Telegram | Send alerts to @Nestor4JM_bot |
| Email | Send email alerts |
| Discord | Post to Discord channel |

## Health Check Details

### Gateway Health

The Moltbot gateway runs on port 18789 and can be checked:

```bash
# From inside the container
pct exec 101 -- curl -s http://127.0.0.1:18789

# Via Tailscale (from any Tailscale node)
curl -s http://100.77.69.24:18789
```

### Container Health

Check container status:

```bash
# Check if container is running
ssh root@192.168.1.10 "pct status 101"

# Check resource usage
ssh root@192.168.1.10 "pct exec 101 -- ps aux | grep clawdbot-gatewa"
```

### Process Health

Key processes to monitor:

| Process | PID | Purpose |
|---------|-----|---------|
| clawdbot-gateway | 419 | Main gateway process |
| clawdbot | 370 | CLI process |
| tailscaled | 242 | VPN connectivity |

## Alert Thresholds

Recommended alert configuration:

| Metric | Warning | Critical |
|--------|---------|----------|
| Gateway Down | 1 minute | 3 minutes |
| High CPU | 80% | 95% |
| High Memory | 80% | 90% |
| Disk Usage | 80% | 90% |

## Troubleshooting

### Monitor Shows Down

1. **Check Tailscale connectivity**:
   ```bash
   ssh root@192.168.1.10 "pct exec 101 -- tailscale status"
   ```

2. **Check gateway process**:
   ```bash
   ssh root@192.168.1.10 "pct exec 101 -- ps aux | grep clawdbot-gatewa"
   ```

3. **Check logs**:
   ```bash
   ssh root@192.168.1.10 "pct exec 101 -- journalctl --user -n 50"
   ```

### Container Not Responding

1. **Check container status**:
   ```bash
   ssh root@192.168.1.10 "pct status 101"
   ```

2. **Restart container**:
   ```bash
   ssh root@192.168.1.10 "pct restart 101"
   ```

## Related Documentation

- [Moltbot README](/docs/moltbot/README.md)
- [Uptime Kuma Documentation](https://github.com/louislam/uptime-kuma)
- [Infrastructure Database](/infrastructure-db/README.md)

---

*Last Updated: 2026-01-28 - Initial monitoring setup documentation*
