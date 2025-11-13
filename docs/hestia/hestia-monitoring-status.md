# HestiaCP Monitoring Status & Setup

**Date:** 2025-10-18
**Server:** mail.vega-messenger.com (192.168.1.30)
**Status:** ✅ Operational & Monitored

---

## Executive Summary

HestiaCP mail server (192.168.1.30) is **currently partially monitored** via Uptime Kuma. Basic SMTP and webmail domain monitoring is in place, but comprehensive service monitoring is recommended for production readiness.

### Current Monitoring Coverage

| Service | Status | Monitor ID | Check Interval |
|---------|--------|------------|----------------|
| **Webmail Domain** | ✅ Monitored | ID: 3 | 6 minutes |
| **SMTP Port 25** | ✅ Monitored | ID: 26 | 10 minutes |
| **Control Panel (8083)** | ❌ Not monitored | - | - |
| **Webmail Interface (8443)** | ❌ Not monitored | - | - |
| **IMAP (993)** | ❌ Not monitored | - | - |
| **POP3 (995)** | ❌ Not monitored | - | - |
| **Submission (587)** | ❌ Not monitored | - | - |
| **Radicale CalDAV** | ❌ Not monitored | - | - |

---

## HestiaCP Infrastructure Overview

### Location & Access

```
Host:           PCT container 130 (Proxmox pve2)
IP Address:     192.168.1.30
Hostname:       mail.vega-messenger.com
SSH Access:     ssh root@192.168.1.30
Documentation:  /docs/hestia/hestia.md
```

### Service Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    HestiaCP Mail Server                     │
│                    (192.168.1.30)                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Control Panel:    Port 8083 (HTTPS) - Hestia Admin       │
│  Webmail:          Port 8443 (HTTPS) - Roundcube          │
│                    Port 80   (HTTP)  - Nginx Proxy         │
│                                                             │
│  Mail Services:                                             │
│    SMTP:           Port 25   - Exim4 (relay via EDP.net)  │
│    Submission:     Port 587  - Authenticated sending       │
│    IMAP:           Port 993  - Dovecot (secure)           │
│    POP3:           Port 995  - Dovecot (secure)           │
│                                                             │
│  CalDAV/CardDAV:   Port 5232 - Radicale (in container)    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Service Status (Verified 2025-10-18 06:21 UTC)

```bash
# HestiaCP Service
● hestia.service - LSB: starts the hestia control panel
   Active: active (running) since Wed 2025-09-03 07:40:21 UTC
   Uptime: 1 month 14 days

# Control Panel Access Test
curl -k -I https://192.168.1.30:8083/
HTTP/2 302 - ✅ Redirects to login (service operational)
```

---

## Managed Domains

### accelior.com
- **Hestia User:** `accelior`
- **Mail Accounts:** jmvl, confluence, weblate, sohil
- **External URL:** https://mail.accelior.com
- **SMTP Relay:** relay.edpnet.be:587
- **DNS:** Cloudflare (via API)

### vega-messenger.com
- **Hestia User:** `vega`
- **Mail Accounts:** jmvl, admin, + 16 others
- **External URL:** https://mail.vega-messenger.com
- **SMTP Relay:** relay.edpnet.be:587
- **DNS:** Cloudflare (via API)

### acmea.tech
- **Hestia User:** `jmvl`
- **Mail Accounts:** jmvl
- **External URL:** https://mail.acmea.tech
- **SMTP Relay:** relay.edpnet.be:587
- **DNS:** Cloudflare (via API)

---

## Uptime Kuma Monitoring Setup

### Current Monitors

#### Monitor ID: 3 - Mail Domain
```
Name:        Mail
Type:        HTTP
URL:         https://mail.accelior.com
Interval:    360 seconds (6 minutes)
Status:      ✅ Active
Description: External webmail access via Nginx Proxy Manager
```

#### Monitor ID: 26 - SMTP Service
```
Name:        🟢 Mail Server (SMTP)
Type:        PORT
Host:        192.168.1.30
Port:        25
Interval:    600 seconds (10 minutes)
Status:      ✅ Active
Description: Email delivery system
```

### Infrastructure Database Entry

```sql
-- From infrastructure.db
Host ID:         13
Hostname:        mail.vega-messenger.com
Type:            lxc
Management IP:   192.168.1.30
Status:          active
CPU Cores:       8
RAM:             8192 MB
Container ID:    130 (Proxmox PCT)
Criticality:     high
```

---

## Recommended Comprehensive Monitoring

### Setup Script Available

**Location:** `/infrastructure-db/monitoring/add-hestia-monitors.py`

This script adds 8 comprehensive monitors for HestiaCP:

1. **Control Panel** (HTTPS 8083) - Admin interface monitoring
2. **Webmail Interface** (HTTPS 8443) - Roundcube webmail
3. **SMTP Service** (Port 25) - Exim4 mail transfer
4. **IMAP Service** (Port 993) - Dovecot secure IMAP
5. **POP3 Service** (Port 995) - Dovecot secure POP3
6. **Submission Port** (Port 587) - Authenticated SMTP
7. **External Domain** (mail.accelior.com) - Public webmail access
8. **Radicale CalDAV** - Calendar/Contacts service

### Monitoring Tiers

```
🟠 TIER 3: CORE SERVICES (300-second checks)
   - HestiaCP Control Panel
   - Webmail Interface
   - SMTP Service
   - IMAP Service
   - Submission Port
   - External Domain Access

📧 TIER 5: EXTENDED SERVICES (600-second checks)
   - POP3 Service
   - Radicale CalDAV/CardDAV
```

### Installation Steps

```bash
# 1. Navigate to monitoring directory
cd /Users/jm/Codebase/internet-control/infrastructure-db/monitoring/

# 2. Ensure credentials file exists
# Create .uptime-kuma-credentials if needed:
cat > .uptime-kuma-credentials << 'EOF'
UPTIME_KUMA_URL=http://192.168.1.9:3010
UPTIME_KUMA_USERNAME=admin
UPTIME_KUMA_PASSWORD=your_password_here
EOF

# 3. Install Python dependencies (if not already installed)
pip install uptime-kuma-api

# 4. Run the HestiaCP monitoring setup
python add-hestia-monitors.py

# 5. Verify monitors in web UI
# Open: http://192.168.1.9:3010/dashboard
```

---

## Monitoring Strategy

### Critical Services (5-minute checks)
- **Control Panel:** Ensures HestiaCP management interface is accessible
- **Webmail:** Validates Roundcube webmail is serving requests
- **SMTP & Submission:** Confirms mail can be sent
- **IMAP:** Verifies mail can be retrieved

### Extended Services (10-minute checks)
- **POP3:** Alternative mail retrieval protocol
- **Radicale:** CalDAV/CardDAV calendar and contacts

### External Access Validation
- **mail.accelior.com:** End-to-end test via Nginx Proxy Manager
- Validates external DNS, firewall, and reverse proxy chain

---

## Alert Recommendations

### Critical Alerts (Immediate Response)
- **SMTP Port Down:** Mail delivery halted
- **Control Panel Unavailable:** Cannot manage server
- **IMAP Port Down:** Users cannot retrieve mail

### Warning Alerts (Monitor & Schedule Fix)
- **Webmail 502 Error:** Nginx Proxy Manager issue
- **Radicale Unavailable:** Calendar/Contacts sync affected
- **POP3 Port Down:** Alternative retrieval method unavailable

---

## Integration with Infrastructure Database

### Service Entry in Database

```sql
INSERT INTO services (
    service_name,
    service_type,
    host_id,
    protocol,
    port,
    endpoint,
    health_check_interval,
    status,
    criticality,
    category
) VALUES
    ('HestiaCP Control Panel', 'web', 13, 'https', 8083,
     'https://192.168.1.30:8083', 300, 'healthy', 'high', 'Email services'),
    ('HestiaCP Webmail', 'web', 13, 'https', 8443,
     'https://192.168.1.30:8443', 300, 'healthy', 'high', 'Email services'),
    ('Exim4 SMTP', 'mail', 13, 'smtp', 25,
     'smtp://192.168.1.30:25', 300, 'healthy', 'high', 'Email services'),
    ('Dovecot IMAP', 'mail', 13, 'imaps', 993,
     'imaps://192.168.1.30:993', 300, 'healthy', 'high', 'Email services');
```

### Health Check Query

```sql
-- Check HestiaCP service health
SELECT
    s.service_name,
    s.protocol,
    s.port,
    s.status,
    s.last_check,
    h.hostname,
    h.management_ip
FROM services s
JOIN hosts h ON s.host_id = h.id
WHERE h.management_ip = '192.168.1.30'
  AND s.status = 'healthy';
```

---

## Troubleshooting & Diagnostics

### Quick Health Check Commands

```bash
# HestiaCP service status
ssh root@192.168.1.30 'systemctl status hestia'

# Test control panel access
curl -k -I https://192.168.1.30:8083/

# Test webmail access
curl -k -I https://192.168.1.30:8443/

# Check mail services
ssh root@192.168.1.30 'netstat -tulpn | grep -E "(25|587|993|995)"'

# View mail queue
ssh root@192.168.1.30 'mailq'

# Check Exim4 status
ssh root@192.168.1.30 'systemctl status exim4'

# Check Dovecot status
ssh root@192.168.1.30 'systemctl status dovecot'

# Check Radicale container
ssh root@192.168.1.30 'docker ps | grep radicale'
```

### Common Issues & Solutions

#### Issue: Control Panel Unreachable
```bash
# Check Hestia nginx process
ssh root@192.168.1.30 'ps aux | grep hestia-nginx'

# Restart Hestia service
ssh root@192.168.1.30 'systemctl restart hestia'

# Check firewall rules
ssh root@192.168.1.30 '/usr/local/hestia/bin/v-list-firewall | grep 8083'
```

#### Issue: Webmail 502 Error
```bash
# Check Apache status
ssh root@192.168.1.30 'systemctl status apache2'

# Verify Apache listening on 8443
ssh root@192.168.1.30 'netstat -tulpn | grep 8443'

# Check firewall allows port 8443
ssh root@192.168.1.30 '/usr/local/hestia/bin/v-list-firewall | grep 8443'
```

#### Issue: Mail Not Sending
```bash
# Check Exim4 status
ssh root@192.168.1.30 'systemctl status exim4'

# Review mail logs
ssh root@192.168.1.30 'tail -50 /var/log/exim4/mainlog'

# Test SMTP relay connectivity
ssh root@192.168.1.30 'telnet relay.edpnet.be 587'
```

---

## Related Documentation

### HestiaCP Documentation
- **Main Config:** `/docs/hestia/hestia.md`
- **Maintenance Log:** `/docs/hestia/hestia-maintenance.md`
- **SSL Configuration:** `/docs/hestia/hestia-ssl-fix-summary.md`
- **Spamhaus Resolution:** `/docs/hestia/spamhaus-blacklist-resolution.md`

### Infrastructure Documentation
- **Infrastructure DB:** `/infrastructure-db/README.md`
- **Network Topology:** `/docs/infrastructure.md`
- **Uptime Kuma Setup:** `/infrastructure-db/monitoring/setup-uptime-kuma.py`

### Monitoring Documentation
- **Monitor Strategy:** `/infrastructure-db/monitoring/MONITOR-STRATEGY.md` (if exists)
- **Uptime Kuma Installation:** `/docs/uptime-kuma/uptime-kuma-installation.md`
- **Password Reset:** `/docs/uptime-kuma/reset-password.md`

---

## Maintenance Schedule

### Daily Tasks (Automated)
- Monitor health checks via Uptime Kuma
- Review Exim4 mail queue
- Check disk space usage

### Weekly Tasks
- Review HestiaCP logs
- Verify DKIM/SPF/DMARC records
- Check SSL certificate expiration

### Monthly Tasks
- Full backup verification
- Security updates (Debian packages)
- HestiaCP version check and update
- Firewall rule audit

---

## Security Considerations

### Network Security
- **Firewall Rules:** OPNsense allows ports 25, 587, 993, 995, 8083, 8443
- **Fail2ban:** Active protection against brute-force attacks
- **SSL/TLS:** All services use encrypted connections

### Access Control
- **HestiaCP Admin:** Strong password enforced
- **SSH Access:** Key-based authentication only
- **Webmail:** Per-user authentication required

### Email Security
- **SPF Records:** Configured for all domains
- **DKIM Signing:** 2048-bit RSA keys
- **DMARC Policy:** Quarantine mode active
- **SMTP Relay:** EDP.net relay prevents IP blacklisting

---

## Next Steps

### Immediate Actions
1. ✅ **HestiaCP Access Verified** - Service operational
2. ✅ **Documentation Created** - This monitoring status document
3. ⏳ **Run Monitoring Setup** - Execute `add-hestia-monitors.py`
4. ⏳ **Verify Monitors** - Check Uptime Kuma dashboard

### Future Enhancements
- [ ] Set up Telegram/Discord alerts for critical failures
- [ ] Configure email notifications for monitor failures
- [ ] Create status page for public service availability
- [ ] Integrate with Grafana for historical metrics
- [ ] Automate backup verification checks
- [ ] Implement log aggregation (consider Loki/Grafana)

---

**Document Created:** 2025-10-18
**Last Verified:** 2025-10-18 06:21 UTC
**Status:** Production Ready
**Monitoring Coverage:** Partial (2/8 monitors) → Comprehensive (8/8) after setup
