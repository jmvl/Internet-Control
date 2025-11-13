# Pi-hole Sentry.io Blocking Analysis

**Date:** 2025-10-18 11:36 UTC
**Issue:** Pi-hole blocking Sentry CDN domains
**Status:** ✅ Identified - Whitelist fix available
**Impact:** Medium - Affects error tracking and monitoring services

---

## Executive Summary

Pi-hole is **blocking multiple Sentry CDN domains** which are essential for error tracking and application monitoring. The main `sentry.io` domain resolves correctly, but critical CDN subdomains return `0.0.0.0` (blocked).

### Blocking Status

| Domain | Status | IP Returned | Impact |
|--------|--------|-------------|--------|
| **sentry.io** | ✅ NOT BLOCKED | 35.186.247.156 | Main domain works |
| **s1.sentry-cdn.com** | ❌ BLOCKED | 0.0.0.0 | CDN assets fail |
| **browser.sentry-cdn.com** | ❌ BLOCKED | 0.0.0.0 | Browser SDK fails |
| **js.sentry-cdn.com** | ❌ BLOCKED | 0.0.0.0 | JavaScript SDK fails |
| **reload.getsentry.net** | ✅ NOT BLOCKED | 34.160.100.224 | Source maps work |

**Critical Issue:** 3 out of 5 Sentry domains are blocked!

---

## Evidence from Pi-hole Logs

### Log Excerpt (2025-10-18 11:35:06 UTC)
```
Oct 18 11:35:06 dnsmasq[49]: query[A] s1.sentry-cdn.com from 192.168.1.131
Oct 18 11:35:06 dnsmasq[49]: gravity blocked s1.sentry-cdn.com is 0.0.0.0
Oct 18 11:35:06 dnsmasq[49]: query[A] s1.sentry-cdn.com from 192.168.1.131
Oct 18 11:35:06 dnsmasq[49]: gravity blocked s1.sentry-cdn.com is 0.0.0.0
Oct 18 11:35:06 dnsmasq[49]: query[HTTPS] s1.sentry-cdn.com from 192.168.1.131
Oct 18 11:35:06 dnsmasq[49]: gravity blocked s1.sentry-cdn.com is NODATA
```

**Analysis:**
- Multiple query attempts from client 192.168.1.131
- All queries blocked by gravity (blocklist)
- Returns 0.0.0.0 for A records
- Returns NODATA for HTTPS records

---

## DNS Resolution Tests

### Main Domain (Working)
```bash
$ dig @192.168.1.5 sentry.io +short
35.186.247.156
```
✅ **Result:** Resolves correctly to Google Cloud IP

### CDN Domains (Blocked)
```bash
$ dig @192.168.1.5 s1.sentry-cdn.com +short
0.0.0.0

$ dig @192.168.1.5 browser.sentry-cdn.com +short
0.0.0.0

$ dig @192.168.1.5 js.sentry-cdn.com +short
0.0.0.0
```
❌ **Result:** All return 0.0.0.0 (Pi-hole block page)

### Reload Domain (Working)
```bash
$ dig @192.168.1.5 reload.getsentry.net +short
34.160.100.224
```
✅ **Result:** Resolves correctly

---

## Impact Analysis

### What is Sentry?
Sentry is an **error tracking and performance monitoring platform** used by developers to:
- Track application errors and exceptions
- Monitor application performance
- Capture stack traces and context
- Alert on critical issues
- Provide real-time error reporting

### Blocked Functionality

#### 1. Browser SDK (browser.sentry-cdn.com)
**Impact:** Web applications cannot load Sentry browser SDK
- ❌ No client-side error tracking
- ❌ No JavaScript exception reporting
- ❌ No browser performance monitoring
- ❌ Frontend errors go unreported

#### 2. JavaScript SDK (js.sentry-cdn.com)
**Impact:** JavaScript applications cannot initialize Sentry
- ❌ Node.js applications cannot report errors
- ❌ React/Vue/Angular apps lose error tracking
- ❌ Mobile web apps lose crash reporting

#### 3. CDN Assets (s1.sentry-cdn.com)
**Impact:** Static assets and resources fail to load
- ❌ SDK files don't download
- ❌ Configuration files unavailable
- ❌ Additional dependencies missing

### Affected Applications

Any application using Sentry for error tracking will experience:
- **Silent failures** - Errors occur but aren't reported
- **Incomplete monitoring** - Performance data not collected
- **Developer blindness** - Issues go unnoticed until user reports
- **Delayed response** - Problems discovered late

### Common Use Cases
- **Web Applications:** SaaS platforms, e-commerce sites, dashboards
- **Mobile Apps:** React Native, Flutter, native iOS/Android
- **Backend Services:** Node.js, Python, Ruby, Go, Java APIs
- **Development Teams:** Any team using Sentry for observability

---

## Root Cause Analysis

### Pi-hole Configuration
```
Pi-hole Version: Running in Docker container
Container: pihole (on host 192.168.1.20)
Gravity Database: /etc/pihole/gravity.db (225 MB)
Blocking Status: ✅ Enabled
Total Domains Blocked: ~2.5 million+ domains
```

### Why is sentry-cdn.com Blocked?

**Likely Reasons:**
1. **CDN Blocklist:** Some blocklists flag CDN domains as tracking/telemetry
2. **Broad Blocking Rules:** Aggressive privacy lists block "monitoring" services
3. **False Positive:** Sentry CDN mistaken for advertising/tracking network
4. **Telemetry Blocking:** Privacy-focused lists block error reporting as "telemetry"

### Blocklist Analysis
The blocking is coming from Pi-hole's gravity database, which aggregates multiple blocklists:
- **Potential Source:** Privacy-focused blocklists (e.g., EasyPrivacy, NextDNS blocklists)
- **Category:** Likely categorized as "analytics" or "telemetry"
- **Intent:** Block user tracking and data collection

**Note:** While Sentry does collect error data, it's:
- ✅ Developer-controlled (not third-party tracking)
- ✅ Essential for application monitoring
- ✅ Privacy-compliant (captures errors, not user behavior)
- ✅ Different from advertising trackers

---

## Solution: Whitelist Sentry Domains

### Option 1: Pi-hole Web Interface (Recommended)

**Steps:**
1. Open Pi-hole admin panel: `http://192.168.1.5/admin`
2. Navigate to: **Group Management → Domains (Whitelist)**
3. Add the following domains:
   ```
   s1.sentry-cdn.com
   browser.sentry-cdn.com
   js.sentry-cdn.com
   ```
4. Optional - Add with wildcards for all Sentry CDN:
   ```
   (.*\.)?sentry-cdn\.com$
   ```
5. Click **Add to Whitelist**
6. Whitelist type: Select **Exact whitelist** (or Regex if using wildcards)
7. Group: **Default**
8. Comment: `Sentry error tracking CDN - required for application monitoring`

**Verification:**
```bash
# Wait 30 seconds for DNS cache to clear, then test:
dig @192.168.1.5 s1.sentry-cdn.com +short
# Should return real IP instead of 0.0.0.0
```

---

### Option 2: Command Line (SSH)

**Via Pi-hole Container:**
```bash
# SSH to Docker host
ssh root@192.168.1.20

# Add domains to whitelist
docker exec pihole pihole -w s1.sentry-cdn.com
docker exec pihole pihole -w browser.sentry-cdn.com
docker exec pihole pihole -w js.sentry-cdn.com

# Verify whitelisted domains
docker exec pihole pihole -w -l | grep sentry

# Reload DNS
docker exec pihole pihole restartdns reload
```

**Verification:**
```bash
# Test resolution after whitelist
dig @192.168.1.5 s1.sentry-cdn.com +short

# Check Pi-hole logs
docker exec pihole tail -f /var/log/pihole/pihole.log | grep sentry
```

---

### Option 3: Direct Database Modification (Advanced)

**⚠️ Warning:** This method bypasses the web interface and requires database knowledge.

```bash
# SSH to Docker host
ssh root@192.168.1.20

# Access gravity database
docker exec pihole sh

# Use Pi-hole CLI (preferred over direct SQL)
pihole -w s1.sentry-cdn.com browser.sentry-cdn.com js.sentry-cdn.com

# Exit container
exit
```

---

## Recommended Whitelist Entries

### Minimal Whitelist (Essential Domains Only)
```
s1.sentry-cdn.com
browser.sentry-cdn.com
js.sentry-cdn.com
```
**Use case:** If you only need to unblock current issues

### Comprehensive Whitelist (All Sentry Services)
```
s1.sentry-cdn.com
browser.sentry-cdn.com
js.sentry-cdn.com
o*.ingest.sentry.io
*.sentry.io
reload.getsentry.net
```
**Use case:** If you want to ensure all Sentry functionality works

### Regex Whitelist (Wildcard Pattern)
```regex
(.*\.)?sentry-cdn\.com$
(.*\.)?sentry\.io$
(.*\.)?getsentry\.net$
```
**Use case:** If you want to whitelist all current and future Sentry domains

---

## Testing Procedure

### Before Whitelist
```bash
$ dig @192.168.1.5 s1.sentry-cdn.com +short
0.0.0.0
```

### After Whitelist
```bash
$ dig @192.168.1.5 s1.sentry-cdn.com +short
# Should return real IP addresses, e.g.:
# 151.101.1.134
# 151.101.65.134
# 151.101.129.134
# 151.101.193.134
```

### Application Testing
1. **Clear browser cache** (to remove cached 0.0.0.0 responses)
2. **Reload application** that uses Sentry
3. **Check browser console** for Sentry initialization
4. **Trigger test error** in application
5. **Verify error appears** in Sentry dashboard

---

## Implementation Steps

### Step 1: Access Pi-hole Admin
```bash
# Pi-hole admin URL
http://192.168.1.5/admin

# Or via Nginx Proxy Manager (if configured)
https://pihole.home.accelior.com/admin
```

### Step 2: Add Whitelist Entries
```
Group Management → Domains (Whitelist)

Add these domains one by one:
1. s1.sentry-cdn.com
2. browser.sentry-cdn.com
3. js.sentry-cdn.com

Comment: "Sentry CDN - Application error tracking (whitelisted 2025-10-18)"
```

### Step 3: Reload Pi-hole DNS
```bash
ssh root@192.168.1.20 'docker exec pihole pihole restartdns reload'
```

### Step 4: Clear Client DNS Cache
```bash
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

### Step 5: Verify Resolution
```bash
# Test all domains
for domain in s1.sentry-cdn.com browser.sentry-cdn.com js.sentry-cdn.com; do
  echo "Testing $domain:"
  dig @192.168.1.5 "$domain" +short
  echo ""
done
```

---

## Alternative Solutions

### Option A: Bypass Pi-hole for Specific Client
If only one application/device needs Sentry:
```bash
# Configure client to use Google DNS (8.8.8.8) instead of Pi-hole
# This bypasses all Pi-hole filtering for that client
```
**Pros:** Quick fix, doesn't affect other clients
**Cons:** Loses Pi-hole ad blocking for that client

### Option B: Use Sentry Self-Hosted
Deploy your own Sentry instance:
```bash
# Self-hosted Sentry on your infrastructure
# No external CDN dependencies
```
**Pros:** Complete control, no external dependencies
**Cons:** Requires maintenance, resource overhead

### Option C: Disable Sentry in Applications
Remove Sentry integration from applications:
```javascript
// Remove or comment out Sentry initialization
// Sentry.init({ dsn: "..." });
```
**Pros:** No whitelist needed
**Cons:** Lose all error tracking and monitoring

**Recommended:** Option 1 (Whitelist) is best - maintains functionality and security.

---

## Post-Implementation Verification

### DNS Resolution Check
```bash
# All should return real IPs (not 0.0.0.0)
dig @192.168.1.5 s1.sentry-cdn.com +short
dig @192.168.1.5 browser.sentry-cdn.com +short
dig @192.168.1.5 js.sentry-cdn.com +short
```

### Pi-hole Query Log
```bash
# Monitor for successful queries (should not show "gravity blocked")
ssh root@192.168.1.20 'docker exec pihole tail -f /var/log/pihole/pihole.log | grep sentry'
```

### Expected Log Output (After Whitelist)
```
Oct 18 XX:XX:XX dnsmasq[49]: query[A] s1.sentry-cdn.com from 192.168.1.131
Oct 18 XX:XX:XX dnsmasq[49]: forwarded s1.sentry-cdn.com to 8.8.8.8
Oct 18 XX:XX:XX dnsmasq[49]: reply s1.sentry-cdn.com is 151.101.1.134
```
✅ Notice: No "gravity blocked" message

---

## Documentation Updates

### Files to Update
1. **/docs/pihole/pihole-whitelist.md** - Add Sentry domains to whitelist documentation
2. **/docs/pihole/troubleshooting.md** - Add Sentry blocking as known issue
3. **/infrastructure-db/services** - Update Pi-hole service notes

### Recommended Documentation Entry
```markdown
## Whitelisted Domains

### Sentry.io Error Tracking (Added 2025-10-18)
**Domains:**
- s1.sentry-cdn.com
- browser.sentry-cdn.com
- js.sentry-cdn.com

**Reason:** Essential for application error tracking and monitoring
**Category:** Development Tools / Monitoring
**False Positive:** Incorrectly categorized as tracking/telemetry
**Impact if Blocked:** Applications cannot report errors
```

---

## Monitoring Recommendations

### Add to Uptime Kuma
Monitor Sentry CDN availability:
```
Monitor Name: Sentry CDN (s1)
URL: https://s1.sentry-cdn.com
Type: HTTP/HTTPS
Interval: 600 seconds
```

### Pi-hole Dashboard
Create custom query counter:
```
Query Type: Whitelisted
Domain Filter: *sentry*
Chart: Show queries over time
```

---

## Summary

### Current Status
- ❌ **Blocked:** s1.sentry-cdn.com, browser.sentry-cdn.com, js.sentry-cdn.com
- ✅ **Working:** sentry.io, reload.getsentry.net
- ⚠️ **Impact:** Medium - Affects error tracking for applications using Sentry

### Required Action
**Add to Pi-hole whitelist:**
1. s1.sentry-cdn.com
2. browser.sentry-cdn.com
3. js.sentry-cdn.com

### Implementation Method
**Recommended:** Pi-hole Web UI → Group Management → Domains (Whitelist)

### Estimated Time
- Whitelist addition: 2 minutes
- DNS propagation: 30 seconds
- Verification: 1 minute
- **Total: ~5 minutes**

---

**Document Created:** 2025-10-18 11:36 UTC
**Issue Severity:** Medium
**Resolution:** Whitelist required
**Status:** Awaiting implementation
