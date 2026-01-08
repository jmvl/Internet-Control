# Hestia Mail Server LXC Reboot and RAM Analysis

**Date**: 2026-01-03
**Author**: Infrastructure Team
**LXC Container**: ID 130 on Proxmox host 192.168.1.10 (pve2)
**Container IP**: 192.168.1.30

---

## Executive Summary

Successfully rebooted Hestia mail server LXC container to clear swap usage. Fixed Dovecot startup failure caused by missing SSL certificates. Current RAM allocation (6.5GB) is adequate for current workload with ClamAV enabled.

---

## Container Configuration

```bash
Cores: 8
Memory: 6624 MB (6.5 GB)
Swap: 512 MB
```

---

## Maintenance Actions Performed

### 1. Container Reboot
```bash
ssh root@192.168.1.10 'pct reboot 130'
```

**Result**: Container rebooted successfully, swap cleared from previous usage to 0 MB.

### 2. Dovecot SSL Certificate Issue Resolution

**Problem Detected**:
```
dovecot.service: Failed with result 'exit-code'
Error: ssl_cert: Can't open file /home/vidsnap/conf/mail/vidsnap.me/ssl/vidsnap.me.pem: No such file or directory
```

**Root Cause**: SSL certificates missing in `/home/vidsnap/conf/mail/vidsnap.me/ssl/` directory after previous maintenance.

**Resolution**:
```bash
# Copied webmail SSL certificates to mail domain
cp /home/vidsnap/conf/web/webmail.vidsnap.me/ssl/webmail.vidsnap.me.crt /home/vidsnap/conf/mail/vidsnap.me/ssl/vidsnap.me.crt
cp /home/vidsnap/conf/web/webmail.vidsnap.me/ssl/webmail.vidsnap.me.pem /home/vidsnap/conf/mail/vidsnap.me/ssl/vidsnap.me.pem
cp /home/vidsnap/conf/web/webmail.vidsnap.me/ssl/webmail.vidsnap.me.key /home/vidsnap/conf/mail/vidsnap.me/ssl/vidsnap.me.key

# Fixed permissions
chown Debian-exim:mail /home/vidsnap/conf/mail/vidsnap.me/ssl/vidsnap.me.*

# Restarted Dovecot
systemctl restart dovecot
```

**Result**: Dovecot started successfully and all mail services operational.

---

## Post-Reboot Service Status

### All Critical Services Running

| Service | Status | Memory Usage |
|---------|--------|--------------|
| **exim4** | ✅ Active | 31.3 MB |
| **dovecot** | ✅ Active | 12.5 MB |
| **nginx** | ✅ Active | 23.8 MB |
| **mariadb** | ✅ Active | 226.4 MB |
| **clamav-daemon** | ✅ Active | 1.2 GB |

### System Resources Post-Reboot

```
Load Average: 1.55, 4.25, 3.32 (1 min after boot)

Memory Usage:
  Total:     6.5 GB
  Used:      1.4 GB
  Free:      3.4 GB
  Available: 5.1 GB

Swap Usage:
  Total:     512 MB
  Used:      0 MB ✅ (cleared successfully)
```

---

## Memory Breakdown by Service

### Top Memory Consumers

| Service | Memory Used | Process Count | Notes |
|---------|-------------|---------------|-------|
| **ClamAV** | 962.9 MB | 1 | Antivirus daemon with virus definitions |
| **SpamAssassin** | 191.1 MB | 2 | Spam filtering (parent + child) |
| **Perl (spamd)** | 102.0 MB | 1 | SpamAssassin parent process |
| **MariaDB** | 113.2 MB | 1 | Database server |
| **Docker** | 74.0 MB | 1 | Container runtime |
| **Nginx** | 69.7 MB | 12 | Web server (master + workers) |
| **Python Services** | 63.5 MB | 3 | Various system services |
| **PHP-FPM** | 48.1 MB | 2 | PHP processor (master + worker) |
| **Containerd** | 46.6 MB | 1 | Container runtime |
| **Apache2** | 35.8 MB | 4 | Web server processes |
| **BIND** | 31.3 MB | 1 | DNS server |
| **Exim4** | 19.8 MB | 1 | Mail transfer agent |

**Total Active Memory**: ~1.7 GB
**Available Memory**: 5.1 GB
**Memory Utilization**: ~25% of allocated RAM

---

## RAM Requirements Analysis

### Current Memory Allocation: 6.5 GB (6624 MB)

#### Service Requirements Breakdown

**Critical Mail Services** (~1.4 GB baseline):
- **ClamAV**: 600-1000 MB (virus database in RAM)
- **SpamAssassin**: 200-300 MB (2 processes + Perl runtime)
- **MariaDB**: 100-200 MB (mail database)
- **Exim4 + Dovecot**: 50-100 MB combined
- **PHP-FPM**: 50-150 MB (Hestia web interface)
- **Nginx**: 50-100 MB (web server)

**Supporting Infrastructure** (~500 MB):
- **Docker + Containerd**: 100-150 MB
- **Apache2**: 30-50 MB
- **BIND DNS**: 30-50 MB
- **System Services**: 100-200 MB
- **Fail2ban, journald, etc**: 50-100 MB

**Buffer for Email Processing** (~1 GB recommended):
- Email spikes during bulk operations
- Multiple concurrent IMAP/POP3 sessions
- Spam filtering on large emails
- File system cache for performance

### Memory Headroom Analysis

- **Allocated**: 6.5 GB
- **Current Usage**: 1.4 GB (22%)
- **Available**: 5.1 GB (78%)
- **Peak Estimate**: ~3.5 GB (with email spikes)
- **Safety Margin**: 3 GB (46% of total)

---

## Recommendations

### ✅ Current RAM Allocation is Adequate

**6.5 GB RAM is sufficient** for this mail server configuration with the following justification:

1. **Low Baseline Usage**: Current 1.4 GB usage leaves substantial headroom
2. **ClamAV Fully Loaded**: 963 MB usage includes complete virus database in RAM
3. **Peak Capacity**: Even with 2-3x spike during bulk email operations (~3.5-4 GB), still within limits
4. **Performance Buffer**: 2+ GB remaining for file system cache improves I/O performance

### ⚠️ Monitor These Scenarios

Consider RAM upgrade to **8 GB** if you observe:

1. **Swap Usage Patterns**: Regular swap usage above 200 MB during normal operations
2. **Email Volume Growth**: Processing >10,000 emails/day with frequent queuing
3. **Additional Services**: Adding more containers or services to this LXC
4. **Performance Issues**: Slow webmail or IMAP response times during peak hours
5. **MariaDB Growth**: Mail database exceeds 5 GB (may need more buffer cache)

### 🔧 Swap Configuration

Current 512 MB swap is **appropriately sized** as emergency overflow:
- Acts as safety valve for temporary spikes
- Not intended for regular use (currently 0 MB used ✅)
- If swap usage becomes regular, add RAM rather than increasing swap

### 📊 Monitoring Recommendations

Set up alerts for:
- **Memory usage > 80%** (5.2 GB of 6.5 GB)
- **Swap usage > 100 MB** (indicates memory pressure)
- **Load average > 8** sustained (exceeds core count)
- **Dovecot or Exim4 service failures**

---

## Follow-up Actions

1. ✅ **Immediate**: All services operational, swap cleared
2. ⚠️ **24-48 hours**: Monitor memory usage patterns during business hours
3. 📅 **Weekly**: Check swap usage trends in monitoring
4. 📋 **Monthly**: Review mail server logs for performance issues
5. 🔐 **As needed**: Ensure SSL certificates are properly managed through Hestia

---

## Related Documentation

- **Hestia Email Configuration**: `/docs/hestia/vidsnap-me-email-configuration-2025-12-10.md`
- **Infrastructure Database**: `/infrastructure-db/infrastructure.db`
- **Quick Start Guide**: `/QUICK-START.md`

---

## Command Reference

### Service Management
```bash
# Check all mail services
systemctl status exim4 dovecot nginx mariadb clamav-daemon

# Restart specific service
systemctl restart dovecot

# Check service memory usage
systemctl status SERVICE --no-pager | grep Memory
```

### Resource Monitoring
```bash
# Memory and swap
free -h

# Load average
uptime

# Top memory consumers
ps aux --sort=-%mem | head -20

# Aggregate by process name
ps aux --sort=-%mem | awk '{sum[$11]+=$6; count[$11]++} END {for (proc in sum) printf "%8.1f MB (%2d proc) - %s\n", sum[proc]/1024, count[proc], proc}' | sort -rn | head -15
```

### LXC Container Management
```bash
# Proxmox host: Check container config
ssh root@192.168.1.10 'pct config 130'

# Reboot container
ssh root@192.168.1.10 'pct reboot 130'

# Modify RAM allocation (if needed)
ssh root@192.168.1.10 'pct set 130 -memory 8192'
```

### SSL Certificate Management
```bash
# List Hestia SSL commands
ls -la /usr/local/hestia/bin/v-*-ssl

# Check SSL certificate location
ls -la /home/USER/conf/mail/DOMAIN/ssl/
ls -la /home/USER/conf/web/DOMAIN/ssl/

# Copy SSL certificates (if missing)
cp /home/USER/conf/web/DOMAIN/ssl/*.{crt,pem,key} /home/USER/conf/mail/DOMAIN/ssl/
chown Debian-exim:mail /home/USER/conf/mail/DOMAIN/ssl/*
```

---

**Maintenance Window**: 2026-01-03 07:08-07:11 UTC (3 minutes)
**Downtime**: ~2 minutes (reboot + service restart)
**Impact**: Minimal - occurred during low-traffic period
**Status**: ✅ All systems operational
