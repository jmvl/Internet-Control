# Uptime Kuma Monitor Errors - Fix Guide

**Date:** 2025-10-17
**Analysis Time:** 13:47 UTC
**Total Monitors:** 30 active
**Monitors with Errors:** 7

---

## 🚨 Critical Errors (Immediate Attention Required)

### 1. Pi-hole DNS Monitor (ID: 10) - MISCONFIGURED

**Current Status:** ❌ DOWN (repeated failures)
**Error:** `queryA ENOTFOUND 192.168.1.5`

**Problem:**
The DNS monitor is misconfigured. It's trying to perform a DNS query for hostname `192.168.1.5` instead of querying a test domain USING the Pi-hole DNS server.

**Current Configuration:**
```
Type: DNS
Hostname: 192.168.1.5  ← WRONG - This is being queried as a domain
DNS Server: (not set correctly)
```

**Correct Configuration Should Be:**
```
Type: DNS
Hostname: google.com  ← Query this domain
DNS Resolve Server: 192.168.1.5  ← Use Pi-hole as DNS server
DNS Resolve Type: A
Port: 53
```

**Fix via Web UI:**
1. Go to Uptime Kuma dashboard
2. Edit monitor ID 10 "🔴 Pi-hole DNS"
3. Change "Resolver Server" to `192.168.1.5`
4. Change "Resource Record Type" to `A`
5. Change "Hostname" to `google.com` or another test domain
6. Save

**Setup Script Fix Required:** YES
- File: `/infrastructure-db/monitoring/setup-uptime-kuma.py`
- Line: ~60-70
- Current code needs verification of DNS monitor parameters

---

## ⚠️ High Priority Errors

### 2. GitLab Monitor (ID: 24) - WRONG IP ADDRESS

**Current Status:** ❌ Intermittent failures
**Error:** `connect EHOSTUNREACH 192.168.1.35:80`

**Problem:**
Monitor is configured with OLD GitLab IP address instead of domain name. This is exactly the migration issue you mentioned.

**Current Configuration:**
```
URL: http://192.168.1.35:80  ← OLD GitLab instance
```

**Should Be:**
```
URL: https://gitlab.accelior.com  ← Use domain name
```

**Fix via Web UI:**
1. Edit monitor ID 24 "🟢 GitLab"
2. Change URL to `https://gitlab.accelior.com`
3. Save

**Already Fixed in Setup Script:** ✅ YES (updated to use domain name)

---

### 3. Nginx Proxy Manager (ID: 19) - WRONG PROTOCOL

**Current Status:** ❌ DOWN
**Error:** `SSL routines:ssl3_get_record:wrong version number`

**Problem:**
Monitor is configured for HTTPS but port 81 serves HTTP only (admin interface).

**Current Configuration:**
```
URL: https://192.168.1.9:81  ← HTTPS on HTTP port
```

**Should Be:**
```
URL: http://192.168.1.9:81  ← HTTP (admin uses self-signed cert on different setup)
```

**Fix via Web UI:**
1. Edit monitor ID 19 "🟠 Nginx Proxy Manager"
2. Change URL to `http://192.168.1.9:81` OR `https://192.168.1.9:81` with "Ignore TLS/SSL error"
3. Save

**Setup Script Status:** Needs verification

---

### 4. Seafile Monitor (ID: 25) - NOT USING DOMAIN

**Current Status:** ❌ DOWN
**Error:** `connect ECONNREFUSED 192.168.1.25:80`

**Problem:**
Using internal IP instead of domain name.

**Current Configuration:**
```
URL: http://192.168.1.25:80
```

**Should Be:**
```
URL: https://files.accelior.com  ← Use domain name
```

**Fix via Web UI:**
1. Edit monitor ID 25 "🟢 Seafile"
2. Change URL to `https://files.accelior.com`
3. Save

**Already Fixed in Setup Script:** ✅ YES

---

## 🟡 Medium Priority Errors

### 5. Netdata Monitoring (ID: 20) - AUTHENTICATION REQUIRED

**Current Status:** ❌ DOWN
**Error:** `Request failed with status code 401`

**Problem:**
Netdata requires authentication but monitor doesn't have credentials configured.

**Options:**
1. **Add authentication to monitor:**
   - Edit monitor
   - Add Basic Auth credentials
   - Save

2. **Disable Netdata authentication** (if internal use only):
   - SSH to host running Netdata
   - Edit Netdata config to allow unauthenticated access from local network
   - Restart Netdata

3. **Accept monitoring failure** (track that service is up but requires auth)

**Recommended:** Option 1 - Add authentication to monitor

---

### 6. Calibre E-books (ID: 29) - SERVICE ISSUE

**Current Status:** ❌ DOWN (502 Bad Gateway)
**Error:** `Request failed with status code 502`

**Problem:**
Nginx Proxy Manager is returning 502, indicating backend Calibre service issue.

**Diagnosis Steps:**
```bash
# Check if Calibre container is running
ssh root@192.168.1.9 'docker ps | grep calibre'

# Check Calibre logs
ssh root@192.168.1.9 'docker logs calibre-web --tail 50'

# Check if port 8082 is listening
ssh root@192.168.1.9 'netstat -tulpn | grep 8082'

# Test direct access
curl -I http://192.168.1.9:8082
```

**Possible Causes:**
- Calibre container stopped
- Calibre service crashed
- Port mapping issue
- Nginx Proxy Manager misconfiguration

**Monitor Configuration:**
- Already updated to use domain: `https://books.acmea.tech` ✅

---

### 7. Syncthing Monitor (ID: 30) - SERVICE DOWN

**Current Status:** ❌ DOWN
**Error:** `connect ECONNREFUSED 192.168.1.9:8384`

**Problem:**
Syncthing service is not running on port 8384.

**Diagnosis Steps:**
```bash
# Check if Syncthing container is running
ssh root@192.168.1.9 'docker ps | grep syncthing'

# Check Syncthing logs
ssh root@192.168.1.9 'docker logs syncthing --tail 50'

# Start Syncthing if stopped
ssh root@192.168.1.9 'docker start syncthing'
```

---

## 📊 Summary of Required Actions

### Immediate Fixes (Web UI)

1. **Pi-hole DNS (ID: 10)** - Reconfigure DNS query
   - Change hostname to `google.com`
   - Set resolver server to `192.168.1.5`

2. **GitLab (ID: 24)** - Change to domain name
   - URL: `https://gitlab.accelior.com`

3. **Nginx Proxy Manager (ID: 19)** - Fix protocol
   - URL: `http://192.168.1.9:81` or enable "Ignore TLS error"

4. **Seafile (ID: 25)** - Change to domain name
   - URL: `https://files.accelior.com`

### Service Investigation Required

5. **Netdata (ID: 20)** - Add authentication or disable auth requirement
6. **Calibre (ID: 29)** - Investigate 502 error, check backend service
7. **Syncthing (ID: 30)** - Check if service is running

### Setup Script Updates

- ✅ GitLab - Already fixed to use `https://gitlab.accelior.com`
- ✅ Seafile - Already fixed to use `https://files.accelior.com`
- ✅ Calibre - Already fixed to use `https://books.acmea.tech`
- ⚠️ Pi-hole DNS - Need to verify DNS monitor configuration
- ⚠️ Nginx Proxy Manager - Need to verify HTTP vs HTTPS

---

## 🔧 Quick Fix Commands

### Fix Pi-hole DNS Monitor (Manual SQL Update)

```bash
ssh root@192.168.1.9 'sqlite3 /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db "UPDATE monitor SET hostname = \"google.com\", dns_resolve_server = \"192.168.1.5\", dns_resolve_type = \"A\" WHERE id = 10;"'
```

### Restart Uptime Kuma (if needed)

```bash
ssh root@192.168.1.9 'docker restart uptime-kuma'
```

---

## Related Documentation

- **Monitor Strategy:** `/infrastructure-db/monitoring/MONITOR-STRATEGY.md`
- **Domain Mapping:** `/infrastructure-db/monitoring/DOMAIN-NAME-MAPPING.md`
- **Setup Script:** `/infrastructure-db/monitoring/setup-uptime-kuma.py`

---

**Created:** 2025-10-17
**Priority:** HIGH
**Estimated Fix Time:** 15-30 minutes
