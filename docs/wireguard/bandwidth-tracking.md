# WireGuard Bandwidth Tracking System

**Server**: wg.accelior.com
**Setup Date**: 2025-10-08
**Status**: ✅ Active and Logging

## Overview

Automated bandwidth tracking system for WireGuard VPN that logs historical usage data for all clients. Statistics are collected hourly and retained for 90 days.

## Features

- ✅ **Hourly logging** of bandwidth usage per client
- ✅ **Client name resolution** from WireGuard Easy configuration
- ✅ **90-day retention** with automatic log rotation
- ✅ **Easy viewing** with simple command-line tools
- ✅ **CSV format** for easy export and analysis
- ✅ **Automatic tracking** via cron job

## Quick Usage

### View Latest Bandwidth Stats
```bash
ssh root@wg.accelior.com 'wg-stats latest'
```

### View Monthly Summary
```bash
ssh root@wg.accelior.com 'wg-stats summary'
```

### View Today's Usage
```bash
ssh root@wg.accelior.com 'wg-stats today'
```

### View Specific Client History
```bash
ssh root@wg.accelior.com 'wg-stats client "JM MacBook Pro"'
```

---

## System Components

### 1. Logging Script
**Location**: `/usr/local/bin/wg-stats-logger.sh`

**Function**: Collects WireGuard transfer statistics and logs them with client names

**Runs**: Every hour via cron

**Manual Execution**:
```bash
/usr/local/bin/wg-stats-logger.sh
```

### 2. Viewing Script
**Location**: `/usr/local/bin/wg-stats`

**Function**: Display bandwidth statistics in human-readable format

**Commands**:
- `wg-stats latest` - Last 10 readings
- `wg-stats summary` - Monthly totals per client
- `wg-stats today` - Today's usage
- `wg-stats client <name>` - Client-specific history
- `wg-stats raw` - Raw log entries

### 3. Cron Job
**Schedule**: Every hour (0 * * * *)

**View cron configuration**:
```bash
crontab -l | grep wg-stats
```

**Output**: `0 * * * * /usr/local/bin/wg-stats-logger.sh >> /var/log/wireguard/cron.log 2>&1`

---

## Log Files

### Bandwidth Logs
**Location**: `/var/log/wireguard/bandwidth-YYYY-MM.log`

**Format**: CSV (Comma-Separated Values)
```
unix_timestamp,datetime,public_key,client_name,rx_bytes,tx_bytes,rx_mb,tx_mb,total_mb
```

**Example**:
```csv
1759954165,2025-10-08 22:09:25,R49dHwwD...,JM MacBook Pro,23462368,353708940,22.38,337.32,359.70
```

**Fields**:
- `unix_timestamp`: Unix epoch time
- `datetime`: Human-readable timestamp
- `public_key`: Client's WireGuard public key
- `client_name`: Friendly name from WireGuard Easy
- `rx_bytes`: Bytes received (download)
- `tx_bytes`: Bytes transmitted (upload)
- `rx_mb`: MB received
- `tx_mb`: MB transmitted
- `total_mb`: Total MB (rx + tx)

### Client Configuration Backup
**Location**: `/var/log/wireguard/clients.json`

**Purpose**: Snapshot of WireGuard Easy client configuration for name resolution

**Updates**: Every time logging script runs

### Cron Log
**Location**: `/var/log/wireguard/cron.log`

**Purpose**: Track cron execution and any errors

**View**:
```bash
tail -f /var/log/wireguard/cron.log
```

---

## Examples

### Monthly Bandwidth Summary
```bash
ssh root@wg.accelior.com 'wg-stats summary'
```

**Output**:
```
=== Bandwidth Summary (Current Month) ===
Client                    |   Downloaded |     Uploaded |        Total
JM MacBook Pro            |      22.38 MB |     337.32 MB |     359.70 MB
Thierry                   |       0.00 MB |       0.00 MB |       0.00 MB
```

### Today's Detailed Usage
```bash
ssh root@wg.accelior.com 'wg-stats today'
```

**Output**:
```
=== Bandwidth Today (2025-10-08) ===
Time       | Client                    |   Downloaded |     Uploaded |        Total
22:07      | JM MacBook Pro            |      16.67 MB |     330.06 MB |     346.73 MB
22:08      | JM MacBook Pro            |      20.51 MB |     333.07 MB |     353.58 MB
22:09      | JM MacBook Pro            |      22.38 MB |     337.32 MB |     359.70 MB
```

### Client-Specific History
```bash
ssh root@wg.accelior.com 'wg-stats client JM'
```

**Output**:
```
=== Bandwidth History for: JM ===
Time                 |   Downloaded |     Uploaded |        Total
2025-10-08 22:07:51 |      16.67 MB |     330.06 MB |     346.73 MB
2025-10-08 22:08:22 |      18.57 MB |     331.02 MB |     349.59 MB
2025-10-08 22:08:50 |      20.51 MB |     333.07 MB |     353.58 MB
2025-10-08 22:09:25 |      22.38 MB |     337.32 MB |     359.70 MB
```

---

## Data Export & Analysis

### Export to CSV File
```bash
# Download current month's data
scp root@wg.accelior.com:/var/log/wireguard/bandwidth-$(date +%Y-%m).log ~/wg-bandwidth.csv
```

### Analyze with Excel/Google Sheets
1. Download CSV file
2. Open in Excel or Google Sheets
3. Create pivot tables or charts
4. Filter by client name or date range

### Query with Command Line
```bash
# Total bandwidth for specific client
ssh root@wg.accelior.com 'grep "JM MacBook Pro" /var/log/wireguard/bandwidth-$(date +%Y-%m).log | tail -1 | awk -F, "{print \$9}"'

# Count active clients today
ssh root@wg.accelior.com 'grep "$(date +%Y-%m-%d)" /var/log/wireguard/bandwidth-$(date +%Y-%m).log | awk -F, "{print \$4}" | sort -u | wc -l'
```

---

## Maintenance

### View Cron Execution Status
```bash
ssh root@wg.accelior.com 'tail -20 /var/log/wireguard/cron.log'
```

### Manual Log Rotation
```bash
# Compress old logs
ssh root@wg.accelior.com 'gzip /var/log/wireguard/bandwidth-*.log'

# Remove logs older than 90 days
ssh root@wg.accelior.com 'find /var/log/wireguard -name "bandwidth-*.log" -mtime +90 -delete'
```

### Disk Space Usage
```bash
ssh root@wg.accelior.com 'du -sh /var/log/wireguard/'
```

**Expected**: ~1-5 MB per month depending on client activity

### Backup Bandwidth Data
```bash
# Backup all bandwidth logs
ssh root@wg.accelior.com 'tar -czf /root/wg-bandwidth-backup-$(date +%Y%m%d).tar.gz /var/log/wireguard/bandwidth-*.log'

# Download backup
scp root@wg.accelior.com:/root/wg-bandwidth-backup-*.tar.gz ~/backups/
```

---

## Troubleshooting

### No Data Being Logged

**Check cron is running**:
```bash
ssh root@wg.accelior.com 'systemctl status cron'
```

**Check cron job exists**:
```bash
ssh root@wg.accelior.com 'crontab -l | grep wg-stats'
```

**Run manually**:
```bash
ssh root@wg.accelior.com '/usr/local/bin/wg-stats-logger.sh'
```

**Check cron logs**:
```bash
ssh root@wg.accelior.com 'tail -50 /var/log/wireguard/cron.log'
```

### Client Names Show as "Unknown"

**Verify clients.json exists**:
```bash
ssh root@wg.accelior.com 'cat /var/log/wireguard/clients.json | head -20'
```

**Check WireGuard Easy is running**:
```bash
ssh root@wg.accelior.com 'docker ps | grep wg-easy'
```

**Manually update client names**:
```bash
ssh root@wg.accelior.com 'docker exec wg-easy cat /etc/wireguard/wg0.json > /var/log/wireguard/clients.json'
```

### Stats Command Not Found

**Verify script exists**:
```bash
ssh root@wg.accelior.com 'ls -lh /usr/local/bin/wg-stats*'
```

**Reinstall scripts**:
```bash
# See installation section in migration guide
```

### Logs Growing Too Large

**Check current size**:
```bash
ssh root@wg.accelior.com 'du -h /var/log/wireguard/bandwidth-*.log'
```

**Compress old logs**:
```bash
ssh root@wg.accelior.com 'gzip /var/log/wireguard/bandwidth-2025-*.log'
```

**Adjust retention period**:
Edit `/usr/local/bin/wg-stats-logger.sh` and change:
```bash
find "$LOG_DIR" -name "bandwidth-*.log" -mtime +90 -delete
```
Change `+90` to desired number of days.

---

## Advanced Usage

### Create Custom Reports

**Top 5 Users by Bandwidth**:
```bash
ssh root@wg.accelior.com 'awk -F, "!/^===/ {total[\$4]+=\$9} END {for(c in total) print total[c],c}" /var/log/wireguard/bandwidth-$(date +%Y-%m).log | sort -rn | head -5'
```

**Hourly Bandwidth Graph (ASCII)**:
```bash
ssh root@wg.accelior.com 'grep "$(date +%Y-%m-%d)" /var/log/wireguard/bandwidth-$(date +%Y-%m).log | awk -F, "{hour=substr(\$2,12,2); total[hour]+=\$9} END {for(h in total) printf \"%s:00 | %s MB\n\", h, total[h]}" | sort'
```

### Integration with Monitoring Tools

**Export to Prometheus** (requires additional setup):
- Write exporter script to parse logs
- Expose metrics on HTTP endpoint
- Configure Prometheus to scrape

**Send Alerts** (requires additional setup):
- Monitor log files for high usage
- Send notifications via email/Slack when threshold exceeded

---

## Future Enhancements

### Potential Improvements
1. **Web-based dashboard** for bandwidth visualization
2. **Real-time monitoring** with live graphs
3. **Usage alerts** when clients exceed thresholds
4. **Per-client quotas** with automatic throttling
5. **Integration with billing systems** for usage-based charging
6. **Historical charts** with Chart.js or Grafana
7. **Mobile app** for remote monitoring

### Grafana Dashboard (Optional)
For professional monitoring, consider setting up:
- Prometheus WireGuard exporter
- Grafana dashboard
- Historical graphs and alerts
- See `/docs/monitoring/grafana-setup.md` (if created)

---

## Reference

### File Locations

| File | Purpose |
|------|---------|
| `/usr/local/bin/wg-stats-logger.sh` | Bandwidth logging script |
| `/usr/local/bin/wg-stats` | Stats viewing command |
| `/var/log/wireguard/bandwidth-YYYY-MM.log` | Monthly bandwidth logs |
| `/var/log/wireguard/clients.json` | Client configuration backup |
| `/var/log/wireguard/cron.log` | Cron execution log |

### Cron Schedule
```
0 * * * * /usr/local/bin/wg-stats-logger.sh >> /var/log/wireguard/cron.log 2>&1
```

### Log Format
```
unix_timestamp,datetime,public_key,client_name,rx_bytes,tx_bytes,rx_mb,tx_mb,total_mb
```

---

**Document Version**: 1.0
**Last Updated**: 2025-10-08
**Maintained By**: Infrastructure Team
