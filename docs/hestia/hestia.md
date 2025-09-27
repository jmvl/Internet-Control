
This document outlines the comprehensive strategy for implementing traffic throttling and bandwidth management across a three-tier network infrastructure utilizing OpenWrt, OPNsense, and Pi-hole components. The architecture provides multiple layers of control with redundancy, granular management, and best-practice implementation.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRAFFIC CONTROL LAYERS                      │
├─────────────────────────────────────────────────────────────────┤
│ Layer 1: OpenWrt (192.168.1.2) - Wireless QoS & SQM          │
│ Layer 2: OPNsense (192.168.1.3) - Firewall & Traffic Shaper  │
│ Layer 3: Pi-hole (192.168.1.5) - DNS Filtering & Rate Limit  │
└─────────────────────────────────────────────────────────────────┘
```

## Servers and VMz

## NPM (Nginx Proxy Manager)
Nginx Proxy manager running as a docker on 192.168.1.9 (OMV) accessible via ssh root@omv
CONTAINER ID   IMAGE                                                COMMAND                  CREATED        STATUS                  PORTS                                                                                                                                                                                            NAMES
4ca94dda70a7   jc21/nginx-proxy-manager:latest                      "/init"                  3 weeks ago    Up 2 days               0.0.0.0:80-81->80-81/tcp, [::]:80-81->80-81/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp                                                                                                         nginx-proxy-manager-nginx-proxy-manager-1

## Proxmox

Proxomox 8.1 on 192.168.1.10 accessible via ssh root@pve2

PCT container 130 mail.vega-messenger.com - Hestia accessible via ssh root@192.168.1.30

## Radicale
In this container there is a Radicale server running 

URL: https://mail.accelior.com/radicale/.web/

root@mail:~# docker ps
CONTAINER ID   IMAGE                       COMMAND                  CREATED         STATUS                PORTS                      NAMES
33207121d67a   tomsquest/docker-radicale   "docker-entrypoint.s…"   12 months ago   Up 3 days (healthy)   127.0.0.1:5232->5232/tcp   radicale

## Email Configuration

### Domain Setup
**accelior.com**
- Hestia user: `accelior`
- Mail accounts: jmvl, confluence, weblate, sohil
- Mail URL: mail.accelior.com
- Dynamic DNS: home.accelior.com → 77.109.88.209

**acmea.tech**
- Hestia user: `jmvl`
- Mail accounts: jmvl
- Mail URL: mail.acmea.tech
- Dynamic DNS: base.acmea.tech → 77.109.88.209
- Nginx Proxy Manager: mail.acmea.tech → 192.168.1.30 port 8083

### SPF Records Configuration
Due to dynamic IP, use hostname-based SPF records:

**accelior.com SPF:**
```
v=spf1 a mx a:home.accelior.com include:_spf.google.com include:spf.protection.outlook.com ~all
```

**acmea.tech SPF:**
```
v=spf1 a mx a:base.acmea.tech include:_spf.google.com include:spf.mtasv.net ~all
```

### Email Services Status
- **SpamAssassin**: Active (threshold: 3.5) - Enhanced September 9, 2025
- **ClamAV**: Active with daily updates (8.7M signatures)
- **DKIM**: Enabled for both domains
- **TLS**: Enabled for both domains
- **Webmail**: Roundcube (accessible via mail.domain.com)

### Webmail Configuration
**Software**: Roundcube v1.6.x
**Location**: `/var/lib/roundcube/`
**Architecture**: External Nginx Proxy Manager → Hestia Nginx → Apache → Roundcube

**Domains Configured**:
- `webmail.acmea.tech` / `mail.acmea.tech`
- `webmail.accelior.com` / `mail.accelior.com`
- `webmail.artbit.gallery` / `mail.artbit.gallery`
- `webmail.vega-messenger.com` / `mail.vega-messenger.com`

**Service Architecture**:
```
External (port 443) → OMV NPM (192.168.1.9) → Hestia Nginx (192.168.1.30:443) → Apache (192.168.1.30:8443) → Roundcube
```

**Apache Virtual Hosts**: Configured on port 8443 with SSL
**Nginx Proxy**: Configured to reverse proxy to Apache backend
**SSL Certificates**: Let's Encrypt via NPM, some need webmail subdomain additions

## Webmail Troubleshooting Knowledge Base

### Common Webmail Issues & Solutions

#### 1. **Firewall Blocking (Primary Issue)**
**Symptoms**: 504 Gateway Timeout, connection timeouts, "upstream timed out"
**Cause**: Hestia container iptables blocking Apache ports 8080/8443
**Solution**:
```bash
# Add permanent firewall rules via Hestia
/usr/local/hestia/bin/v-add-firewall-rule ACCEPT 0.0.0.0/0 8443 TCP 'Apache-Webmail-HTTPS'
/usr/local/hestia/bin/v-add-firewall-rule ACCEPT 0.0.0.0/0 8080 TCP 'Apache-Webmail-HTTP'

# Verify rules
iptables -L INPUT -n | grep 844
```

#### 2. **NPM Proxy Configuration Mismatch**
**Symptoms**: "upstream prematurely closed connection", 400 Bad Request
**Cause**: HTTP scheme configured with HTTPS port
**Solution**: In NPM admin (http://192.168.1.9:81), set:
- Scheme: `https` (not http)
- Forward Hostname/IP: `192.168.1.30`
- Forward Port: `8443`
- SSL Certificate Verification: Disabled

#### 3. **Apache SSL Binding**
**Issue**: Apache binds to specific IP (192.168.1.30:8443) not all interfaces
**Testing**:
```bash
# Works (specific IP)
curl -k https://192.168.1.30:8443/

# Fails (localhost)
curl -k https://127.0.0.1:8443/
```

#### 4. **Service Architecture Flow**
```
External HTTPS Request
    ↓
NPM (192.168.1.9:443) - Let's Encrypt SSL Termination
    ↓
Hestia Nginx (192.168.1.30:443) - Proxy Pass
    ↓
Apache (192.168.1.30:8443) - SSL Virtual Host
    ↓
Roundcube (/var/lib/roundcube/) - PHP Application
```

### Diagnostic Commands

#### Quick Health Check
```bash
# Test external access
curl -I https://mail.accelior.com/

# Test NPM to Hestia connectivity
ssh root@192.168.1.9 "curl -k -I https://192.168.1.30:8443/"

# Check Apache SSL status
ssh root@192.168.1.30 "curl -k -I https://192.168.1.30:8443/"

# Verify firewall rules
ssh root@192.168.1.30 "iptables -L INPUT -n | grep -E '(8443|8080)'"
```

#### Service Verification
```bash
# Apache virtual hosts
ssh root@192.168.1.30 "apache2ctl -S | grep 8443"

# NPM proxy configuration
ssh root@192.168.1.9 "docker exec nginx-proxy-manager-nginx-proxy-manager-1 grep -A 10 'forward_scheme\|proxy_pass' /data/nginx/proxy_host/18.conf"

# SSL certificate validity
ssh root@192.168.1.9 "docker exec nginx-proxy-manager-nginx-proxy-manager-1 openssl x509 -in /etc/letsencrypt/live/npm-16/fullchain.pem -text -noout | grep -A 5 'Subject Alternative Name'"
```

#### Log Analysis
```bash
# NPM error logs
ssh root@192.168.1.9 "docker exec nginx-proxy-manager-nginx-proxy-manager-1 tail -20 /data/logs/proxy-host-18_error.log"

# Apache error logs
ssh root@192.168.1.30 "tail -20 /var/log/apache2/error.log"

# Hestia Nginx logs
ssh root@192.168.1.30 "tail -20 /var/log/nginx/domains/webmail.accelior.com.error.log"
```

### SSL Certificate Management

#### Let's Encrypt via NPM
- **Domain Coverage**: Ensure certificates include all required subdomains
- **Auto-Renewal**: NPM handles automatic renewal
- **Backend Verification**: Disable SSL verification for self-signed backend certificates

#### Hestia Backend Certificates
- **Location**: `/usr/local/hestia/ssl/certificate.crt`
- **Self-Signed**: Default Hestia installation uses self-signed certificates
- **Domain Mismatch**: Certificate warnings normal for IP-based access

### Maintenance Procedures

#### Regular Checks
```bash
# Monthly webmail health check
curl -I https://mail.accelior.com/ && echo "✅ Webmail OK" || echo "❌ Webmail Failed"

# Firewall rule persistence verification
ssh root@192.168.1.30 "/usr/local/hestia/bin/v-list-firewall | grep -E '(8443|8080)'"

# SSL certificate expiration
ssh root@192.168.1.9 "docker exec nginx-proxy-manager-nginx-proxy-manager-1 certbot certificates"
```

#### After System Updates
1. Verify firewall rules persist
2. Check Apache virtual host configuration
3. Confirm NPM proxy settings
4. Test end-to-end connectivity

**Fixed Issues (Sept 16, 2025)**:
- ✅ Firewall blocking ports 8080/8443 - Added permanent Hestia firewall rules
- ✅ NPM HTTP/HTTPS scheme mismatch - Corrected to HTTPS for port 8443
- ✅ SSL certificate chain validation - Configured proper backend SSL handling
- ✅ Apache SSL virtual host connectivity - Verified IP-specific binding works correctly

### Troubleshooting
Common email delivery issues resolved:

1. **Gmail Rejection Issue**: Fixed ACL ordering in Exim configuration
2. **Sender Verification**: Configured proper hostname handling for dynamic IP
3. **Missing PTR Record**: Outgoing emails to Gmail may fail without proper reverse DNS

### Mail Logs
- Main log: `/var/log/exim4/mainlog`
- Reject log: `/var/log/exim4/rejectlog`
- Check recent Gmail activity: `grep -i gmail /var/log/exim4/mainlog`

### Hestia Commands
```bash
# List mail domains
/usr/local/hestia/bin/v-list-mail-domains [user]

# List mail accounts
/usr/local/hestia/bin/v-list-mail-accounts [user] [domain]

# List all users
/usr/local/hestia/bin/v-list-users
```

### Maintenance History

#### September 7, 2025 - Email Delivery Issues Fixed
**Problem**: accelior.com emails not being received due to mail server configuration issues.

**Root Cause Analysis**:
- Exim4 `relay_from_hosts` configuration was too restrictive (only allowed 127.0.0.1)
- OPNsense firewall at 192.168.1.3 was being denied relay access
- 48 frozen messages in mail queue were blocking delivery
- "Relaying denied" errors in reject logs

**Actions Taken**:
1. **Updated Exim Configuration** (`/etc/exim4/exim4.conf.template`):
   - Changed `hostlist relay_from_hosts = 127.0.0.1` 
   - To `hostlist relay_from_hosts = 127.0.0.1 : 192.168.1.0/24`
   - This allows the local network (including OPNsense at 192.168.1.3) to relay mail

2. **Cleaned Mail Queue**:
   - Removed 48 frozen messages using `exim4 -Mrm $(exim4 -bp | grep frozen | awk '{print $3}')`
   - These were mostly failed delivery attempts to invalid addresses

3. **Verified Services**:
   - Confirmed Exim4 and Dovecot services running properly
   - Verified all mail ports listening (25, 587, 143, 993, 995, 110)
   - DNS records confirmed correct (MX, A, SPF)

4. **Testing**:
   - Internal email delivery: ✅ Working
   - External SMTP connectivity: ✅ Accessible on port 25
   - Mail queue: ✅ Processing normally

**Current Status**: Email server fully operational for accelior.com domain.

**Files Modified**:
- `/etc/exim4/exim4.conf.template` (backed up to `.backup.20250907`)

**Commands Used**:
```bash
# Backup configuration
cp /etc/exim4/exim4.conf.template /etc/exim4/exim4.conf.template.backup.20250907

# Update relay hosts configuration  
sed -i 's/hostlist relay_from_hosts = 127.0.0.1/hostlist relay_from_hosts = 127.0.0.1 : 192.168.1.0\/24/' /etc/exim4/exim4.conf.template

# Restart Exim4
systemctl restart exim4

# Clean frozen messages
exim4 -Mrm $(exim4 -bp | grep frozen | awk '{print $3}')
```