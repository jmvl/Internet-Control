# mail.acmea.tech Webmail Inaccessible - DynDNS Cloudflare API Authentication Failure

**Date**: 2025-10-10
**Status**: ✅ RESOLVED
**Severity**: HIGH - Email service inaccessible
**Services Affected**: Hestia webmail (mail.acmea.tech), OPNsense DynDNS, Cloudflare DNS
**Root Cause**: Invalid Cloudflare API key preventing DynDNS updates

---

## Executive Summary

The webmail interface for jmvl@acmea.tech was inaccessible due to DNS records pointing to an old IP address. Investigation revealed that OPNsense's ddclient service was failing to update `base.acmea.tech` DNS records due to an invalid Cloudflare API key, causing the domain to remain stuck at the old IP (77.109.77.7) where a different service (Nextcloud cloud.leleux.me) was hosted. Updating the API key to match the working credentials used by `home.accelior.com` resolved the issue.

**Impact**: Users unable to access webmail at https://mail.acmea.tech
**Duration**: Unknown start time - 2025-10-10 13:27 CET
**Resolution Time**: ~30 minutes

---

## Problem Description

### Initial Symptoms
- User unable to access jmvl@acmea.tech webmail interface
- Accessing https://mail.acmea.tech showed wrong SSL certificate (cloud.leleux.me instead of mail.acmea.tech)
- NPM (Nginx Proxy Manager) was serving correct configuration internally but wrong certificate externally

### User Impact
- Complete inability to access webmail
- Email communication disruption for jmvl@acmea.tech account
- SSL certificate warning in browsers

---

## Environment Details

### Network Architecture
```
Internet (WAN IP: 94.105.107.145)
    ↓
OPNsense Firewall (192.168.1.3)
    ↓ [Port 443 forwarding]
NPM - Nginx Proxy Manager (192.168.1.9:443)
    ↓ [Reverse proxy: mail.acmea.tech → 192.168.1.30:8443]
Hestia Mail Server (192.168.1.30)
    ↓
Webmail Interface (Roundcube)
```

### DNS Configuration
- **Domain**: acmea.tech
- **DNS Provider**: Cloudflare
- **CNAME Record**: mail.acmea.tech → base.acmea.tech
- **A Record**: base.acmea.tech → (should be updated dynamically by DynDNS)
- **DynDNS Service**: OPNsense ddclient

### System Versions
- **OPNsense**: Version with ddclient 3.11.2
- **NPM**: Latest (Docker container on 192.168.1.9)
- **Hestia**: Running on Debian 12 (192.168.1.30)

---

## Root Cause Analysis

### Timeline of Events

1. **Initial State** (Before issue)
   - WAN IP changed from 77.109.77.7 to 94.105.107.145
   - DynDNS should have updated base.acmea.tech automatically

2. **Failure Point**
   - ddclient attempted to update base.acmea.tech DNS record
   - Cloudflare API rejected requests with HTTP 400 error
   - Error: "Invalid format for X-Auth-Key header" (code 6103)

3. **Impact Cascade**
   - base.acmea.tech remained at old IP: 77.109.77.7
   - mail.acmea.tech CNAME resolved to wrong IP via base.acmea.tech
   - Traffic reached wrong server (Nextcloud at old IP)
   - Wrong SSL certificate presented (cloud.leleux.me)

### Root Cause

**Primary Cause**: Invalid Cloudflare API key for acmea.tech zone

OPNsense configuration had **two separate DynDNS entries** with different API keys:

1. **base.acmea.tech** (FAILING)
   - API Key: `nNZSTw1xMqoy39mRSXoWvG5fWq7ztJpHTj3Krrgb`
   - Status: Invalid/expired key causing HTTP 400 errors
   - Zone: acmea.tech

2. **home.accelior.com** (WORKING)
   - API Key: `887f05016d2aede5ccc4d0a9bcd56c96d8564`
   - Status: Successfully updating DNS records
   - Zone: accelior.com

Both entries used the same Cloudflare account (jmvl@accelior.com), but different API keys for different zones.

---

## Investigation Process

### Step 1: Initial Diagnostics

```bash
# Checked NPM configuration internally
ssh root@192.168.1.9 "docker exec -it nginx-proxy-manager cat /data/nginx/proxy_host/28.conf"
# Result: Configuration correct, proxying to 192.168.1.30:8443

# Tested SSL certificate internally vs externally
echo | openssl s_client -connect 192.168.1.9:443 -servername mail.acmea.tech
# Internal: Correct certificate (mail.acmea.tech)

echo | openssl s_client -connect mail.acmea.tech:443 -servername mail.acmea.tech
# External: Wrong certificate (cloud.leleux.me)
```

**Conclusion**: NPM working correctly, issue was DNS-related

### Step 2: DNS Investigation

```bash
# Checked DNS resolution
dig +short mail.acmea.tech
# Result: base.acmea.tech → 77.109.77.7 (OLD IP)

# Checked current WAN IP
ssh root@192.168.1.3 "ifconfig pppoe0 | grep inet"
# Result: 94.105.107.145 (CURRENT IP)

# Tested direct access to current IP
echo | openssl s_client -connect 94.105.107.145:443 -servername mail.acmea.tech
# Result: Correct certificate! (mail.acmea.tech)
```

**Conclusion**: DNS pointing to wrong IP, DynDNS not updating

### Step 3: DynDNS Investigation

```bash
# Checked ddclient logs
ssh root@192.168.1.3 "tail -100 /var/log/ddclient/ddclient_$(date +%Y%m%d).log | grep base.acmea.tech"

# Found repeated failures:
# HTTP/2 400
# {"success":false,"errors":[{"code":6003,"message":"Invalid request headers",
#   "error_chain":[{"code":6103,"message":"Invalid format for X-Auth-Key header"}]}]}
# FAILED: updating base.acmea.tech: Could not connect to api.cloudflare.com/client/v4.
```

**Conclusion**: Cloudflare API authentication failing

### Step 4: Configuration Analysis

```bash
# Checked ddclient configuration
ssh root@192.168.1.3 "cat /usr/local/etc/ddclient.conf"

# Found two entries with different API keys:
# Entry 1: home.accelior.com - password=887f05016d2aede5ccc4d0a9bcd56c96d8564 (WORKING)
# Entry 2: base.acmea.tech - password=nNZSTw1xMqoy39mRSXoWvG5fWq7ztJpHTj3Krrgb (FAILING)

# Checked ddclient cache
ssh root@192.168.1.3 "cat /var/tmp/ddclient.cache"
# base.acmea.tech: ip=77.109.77.7, status-ipv4=noconnect
# home.accelior.com: ip=94.105.107.145, status-ipv4=good
```

**Root Cause Confirmed**: Invalid API key for base.acmea.tech

---

## Solution Implemented

### Configuration Changes

#### 1. Backup Current Configuration

```bash
# Backup OPNsense config.xml
ssh root@192.168.1.3 "cp /conf/config.xml /conf/config.xml.backup-20251010-132000"

# Backup ddclient.conf
ssh root@192.168.1.3 "cp /usr/local/etc/ddclient.conf /usr/local/etc/ddclient.conf.backup"
```

#### 2. Update OPNsense config.xml

```bash
# Update API key in config.xml
ssh root@192.168.1.3 "sed -i.bak 's|<password>nNZSTw1xMqoy39mRSXoWvG5fWq7ztJpHTj3Krrgb</password>|<password>887f05016d2aede5ccc4d0a9bcd56c96d8564</password>|g' /conf/config.xml"
```

**Changed**: Account UUID `729c2366-2ea7-4368-ab66-786d68b6ea23` (base.acmea.tech)
- **Old password**: `nNZSTw1xMqoy39mRSXoWvG5fWq7ztJpHTj3Krrgb`
- **New password**: `887f05016d2aede5ccc4d0a9bcd56c96d8564`

#### 3. Update ddclient.conf

```bash
# Update API key in ddclient.conf
ssh root@192.168.1.3 "sed -i.backup 's/password=nNZSTw1xMqoy39mRSXoWvG5fWq7ztJpHTj3Krrgb/password=887f05016d2aede5ccc4d0a9bcd56c96d8564/g' /usr/local/etc/ddclient.conf"
```

#### 4. Force DNS Update

```bash
# Restart ddclient service
ssh root@192.168.1.3 "service ddclient restart"

# Force immediate update (run once in foreground)
ssh root@192.168.1.3 "ddclient -daemon=0 -verbose -noquiet -force"

# Verify update in logs
ssh root@192.168.1.3 "tail -30 /var/log/ddclient/ddclient_$(date +%Y%m%d).log | grep base.acmea.tech"
```

**Result**:
```
SUCCESS: updating base.acmea.tech: IPv4 address set to 94.105.107.145
modified_on: 2025-10-10T11:27:26.470698Z
```

#### 5. Restart ddclient as Daemon

```bash
# Start ddclient as background service
ssh root@192.168.1.3 "service ddclient start"
```

---

## Verification Steps

### 1. Verify ddclient Cache Update

```bash
ssh root@192.168.1.3 "cat /var/tmp/ddclient.cache | grep base.acmea.tech"
```

**Result**:
```
ip=94.105.107.145
status-ipv4=good
mtime=1760095635
```
✅ Cache updated correctly

### 2. Verify DNS Propagation

```bash
# Check DNS via Cloudflare DNS
dig +short base.acmea.tech @1.1.1.1
```

**Result**: `94.105.107.145` ✅

```bash
# Check mail.acmea.tech resolution
dig +short mail.acmea.tech @1.1.1.1
```

**Result**:
```
base.acmea.tech.
94.105.107.145
```
✅ CNAME and A record resolving correctly

### 3. Verify SSL Certificate

```bash
echo | openssl s_client -connect mail.acmea.tech:443 -servername mail.acmea.tech 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

**Result**:
```
subject=CN = mail.acmea.tech
issuer=C = US, O = Let's Encrypt, CN = E7
notBefore=Oct 10 10:07:13 2025 GMT
notAfter=Jan  8 10:07:12 2026 GMT
```
✅ Correct certificate being served

### 4. Verify Webmail Accessibility

```bash
curl -I -k https://mail.acmea.tech
```

**Result**:
```
HTTP/2 200
server: openresty
content-type: text/html; charset=UTF-8
set-cookie: roundcube_sessid=mic9ql0m6vbfh3ck1uilsv4ri9; path=/; secure; HttpOnly
x-served-by: mail.acmea.tech
```
✅ Webmail interface accessible

### 5. Monitor DynDNS Operation

```bash
# Check ongoing ddclient status
ssh root@192.168.1.3 "ps aux | grep ddclient"
ssh root@192.168.1.3 "tail -f /var/log/ddclient/ddclient_$(date +%Y%m%d).log"
```
✅ ddclient running and updating successfully

---

## Post-Resolution Status

### System State After Fix

| Component | Status | Details |
|-----------|--------|---------|
| **OPNsense WAN IP** | ✅ Current | 94.105.107.145 |
| **base.acmea.tech DNS** | ✅ Updated | 94.105.107.145 |
| **mail.acmea.tech DNS** | ✅ Resolving | CNAME → base.acmea.tech → 94.105.107.145 |
| **SSL Certificate** | ✅ Correct | CN=mail.acmea.tech, valid until 2026-01-08 |
| **Webmail Interface** | ✅ Accessible | https://mail.acmea.tech returning HTTP 200 |
| **DynDNS Service** | ✅ Operational | Both domains updating successfully |

### DynDNS Configuration (Final State)

```conf
# /usr/local/etc/ddclient.conf
usev4=ifv4, ifv4=pppoe0, \
protocol=cloudflare, \
zone=accelior.com, \
login=jmvl@accelior.com, \
password=887f05016d2aede5ccc4d0a9bcd56c96d8564 \
home.accelior.com

usev4=ifv4, ifv4=pppoe0, \
protocol=cloudflare, \
zone=acmea.tech, \
login=jmvl@accelior.com, \
password=887f05016d2aede5ccc4d0a9bcd56c96d8564 \
base.acmea.tech
```

**Note**: Both entries now use the same (working) API key.

---

## Lessons Learned

### What Went Well
1. **Systematic Investigation**: Methodical approach from symptoms → DNS → DynDNS → API keys
2. **Proper Backups**: Configuration files backed up before making changes
3. **Quick Resolution**: Issue identified and resolved within 30 minutes
4. **Comprehensive Verification**: Multiple verification steps confirmed complete resolution

### What Could Be Improved

1. **API Key Management**
   - Need centralized documentation of Cloudflare API keys and their purposes
   - Consider using API Tokens instead of Global API Keys for better security
   - Implement monitoring for API key expiration/validity

2. **Monitoring Gaps**
   - No alerting when DynDNS updates fail repeatedly
   - No automated checks for DNS record accuracy vs actual WAN IP
   - Consider implementing ddclient failure alerting

3. **Documentation Gaps**
   - Cloudflare API configuration was not documented
   - DynDNS troubleshooting procedures were unclear
   - Need comprehensive OPNsense DynDNS documentation

### Action Items

- [ ] **Document Cloudflare API Key Management** (/docs/OPNsense/cloudflare-api-keys.md)
- [ ] **Create DynDNS Monitoring** (Uptime Kuma or custom script)
- [ ] **Review All API Keys** (Check validity and document purposes)
- [ ] **Consider API Token Migration** (More secure than Global API Keys)
- [ ] **Update Hestia Documentation** (Link to this troubleshooting doc)

---

## Related Documentation

### Primary Documentation
- `/docs/hestia/hestia.md` - Hestia mail server configuration
- `/docs/npm/` - Nginx Proxy Manager documentation
- `/docs/OPNsense/` - OPNsense firewall configuration

### Related Incidents
- NPM Database Corruption (2025-10-10) - Separate incident during same troubleshooting session
- Port Forwarding Configuration - Standard network architecture

### External References
- [ddclient Documentation](https://ddclient.net/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [OPNsense DynDNS Plugin](https://docs.opnsense.org/manual/dynamic_dns.html)

---

## Appendix A: Configuration File Locations

### OPNsense (192.168.1.3)
```
/conf/config.xml                                    # Main OPNsense configuration
/conf/config.xml.backup-20251010-132000            # Backup created during intervention
/usr/local/etc/ddclient.conf                       # ddclient runtime configuration
/usr/local/etc/ddclient.conf.backup                # ddclient backup
/var/log/ddclient/ddclient_YYYYMMDD.log           # Daily ddclient logs
/var/tmp/ddclient.cache                            # ddclient IP cache and status
```

### NPM (192.168.1.9)
```
/srv/raid/config/nginx/data/database.sqlite        # NPM configuration database
/data/nginx/proxy_host/28.conf                     # mail.acmea.tech proxy config (inside container)
/etc/letsencrypt/live/npm-51/                      # SSL certificates for mail.acmea.tech
```

### Hestia (192.168.1.30)
```
/etc/hestia/                                       # Hestia configuration directory
Port 8443                                          # Webmail interface (Roundcube)
Port 8083                                          # Hestia control panel
```

---

## Appendix B: Diagnostic Commands Reference

### DNS Diagnostics
```bash
# Check DNS resolution
dig +short mail.acmea.tech @1.1.1.1
dig +short base.acmea.tech @1.1.1.1

# Check DNS propagation globally
dig +short mail.acmea.tech @8.8.8.8        # Google DNS
dig +short mail.acmea.tech @1.1.1.1        # Cloudflare DNS

# Full DNS trace
dig +trace mail.acmea.tech
```

### SSL Certificate Diagnostics
```bash
# Check certificate being served
echo | openssl s_client -connect mail.acmea.tech:443 -servername mail.acmea.tech 2>/dev/null | openssl x509 -noout -text

# Quick certificate check
echo | openssl s_client -connect mail.acmea.tech:443 -servername mail.acmea.tech 2>/dev/null | openssl x509 -noout -subject -issuer -dates

# Check certificate without SNI
echo | openssl s_client -connect 94.105.107.145:443 2>/dev/null | openssl x509 -noout -subject
```

### DynDNS Diagnostics
```bash
# Check ddclient status
ssh root@192.168.1.3 "service ddclient status"

# View ddclient configuration
ssh root@192.168.1.3 "cat /usr/local/etc/ddclient.conf"

# Check ddclient cache
ssh root@192.168.1.3 "cat /var/tmp/ddclient.cache"

# Monitor ddclient logs in real-time
ssh root@192.168.1.3 "tail -f /var/log/ddclient/ddclient_$(date +%Y%m%d).log"

# Force manual update
ssh root@192.168.1.3 "ddclient -daemon=0 -verbose -noquiet -force"

# Check recent errors
ssh root@192.168.1.3 "grep -i 'failed\|error' /var/log/ddclient/ddclient_$(date +%Y%m%d).log | tail -20"
```

### Network Diagnostics
```bash
# Check OPNsense WAN IP
ssh root@192.168.1.3 "ifconfig pppoe0 | grep inet"

# Test port 443 accessibility
nc -zv mail.acmea.tech 443
curl -I -k https://mail.acmea.tech

# Check routing
traceroute mail.acmea.tech
```

---

## Appendix C: Cloudflare API Key Types

### Global API Key vs API Token

**Global API Key** (Legacy - What was used):
- Full account access
- Single key for entire Cloudflare account
- Less secure - if compromised, entire account at risk
- Format: 37-character string (e.g., `887f05016d2aede5ccc4d0a9bcd56c96d8564`)
- Used in ddclient with `X-Auth-Email` and `X-Auth-Key` headers

**API Token** (Recommended - Future migration):
- Scoped permissions (e.g., only DNS edit for specific zone)
- Multiple tokens with different permissions
- More secure - limited blast radius if compromised
- Format: 40-character string starting with token type
- Used in ddclient with `Authorization: Bearer` header

### Security Recommendation

**Action Item**: Migrate from Global API Key to scoped API Tokens

Create new API Token with:
- **Permission**: Zone:DNS:Edit
- **Zone Resources**: Include → Specific zone → acmea.tech
- **TTL**: No expiration (or set monitoring for expiration)

Update ddclient configuration:
```conf
# Old (Global API Key)
login=jmvl@accelior.com
password=<global-api-key>

# New (API Token - requires ddclient 3.9.0+)
use=web
protocol=cloudflare
zone=acmea.tech
ttl=1
login=token
password=<api-token>
```

---

## Contact Information

**Resolved By**: Claude Code AI Assistant
**Supervised By**: JM (jmvl@accelior.com)
**Date**: 2025-10-10
**Duration**: ~30 minutes investigation + resolution

For questions or related issues:
- Check `/docs/hestia/hestia.md` for mail server configuration
- Check `/docs/OPNsense/` for firewall and DynDNS configuration
- Review this document for DynDNS troubleshooting procedures
