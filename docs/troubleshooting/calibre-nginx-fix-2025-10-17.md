# Calibre E-books Nginx Proxy Manager Fix

**Date:** 2025-10-17
**Time:** 14:03 UTC
**Issue:** 502 Bad Gateway on `https://books.acmea.tech`
**Resolution:** Updated backend host from 192.168.1.20 to 192.168.1.9

---

## Problem Summary

Calibre E-books monitor (ID: 29) was showing `502 Bad Gateway` errors when accessing `https://books.acmea.tech`.

### Root Cause

Nginx Proxy Manager had **two proxy hosts** configured for Calibre:

1. **books.accelior.com** → `192.168.1.9:8083` ✅ (Correct)
2. **books.acmea.tech** → `192.168.1.20:8083` ❌ (Wrong host)

The Uptime Kuma monitor was using `books.acmea.tech`, which was pointing to the wrong backend server.

### Actual Service Location

```
Container: calibre-web
Host: 192.168.1.9 (OMV storage server)
Port: 8083
Image: lscr.io/linuxserver/calibre-web:latest
Status: Up 5 weeks
```

---

## Investigation Steps

### 1. Discovered Port Configuration

**Found:** Calibre-web is running on port 8083, not 8082
```bash
$ docker ps | grep calibre
calibre-web   0.0.0.0:8083->8083/tcp   Up 5 weeks
```

### 2. Checked Nginx Proxy Manager Database

```bash
$ sqlite3 /data/database.sqlite "SELECT id, domain_names, forward_host, forward_port FROM proxy_host WHERE domain_names LIKE '%books%';"

9 |["books.accelior.com"]|192.168.1.9|8083  ← CORRECT
30|["books.acmea.tech"]|192.168.1.20|8083   ← WRONG HOST
```

### 3. Verified Direct Access

```bash
$ curl -I http://192.168.1.9:8083
HTTP/1.1 302 FOUND  ← Service is working
Location: /login?next=%2F
```

### 4. Checked Nginx Config

```nginx
# /data/nginx/proxy_host/30.conf
set $server "192.168.1.20";  ← Wrong!
set $port   8083;
```

---

## Fix Applied

### Step 1: Update Database

```bash
# Copy database locally
docker exec nginx-proxy-manager cat /data/database.sqlite > /tmp/npm-database.sqlite

# Update proxy host configuration
sqlite3 /tmp/npm-database.sqlite "UPDATE proxy_host SET forward_host = '192.168.1.9' WHERE id = 30;"

# Copy back to container
cat /tmp/npm-database.sqlite | docker exec -i nginx-proxy-manager sh -c "cat > /data/database.sqlite"
```

### Step 2: Update Nginx Config File

The database update didn't automatically regenerate the Nginx config, so manual edit was required:

```bash
# Update the $server variable in config file
docker exec nginx-proxy-manager sed -i 's/set $server         "192.168.1.20"/set $server         "192.168.1.9"/' /data/nginx/proxy_host/30.conf

# Reload Nginx
docker exec nginx-proxy-manager nginx -s reload
```

### Step 3: Verify Fix

```bash
$ curl -I https://books.acmea.tech
HTTP/2 302
location: /login?next=%2F
```

✅ **Working!** HTTP 302 redirect to login page is the expected response.

---

## Why Two Domain Names?

**books.accelior.com** and **books.acmea.tech** both point to the same Calibre service but use different domains:

- **accelior.com** - Primary domain for internal services
- **acmea.tech** - Secondary/alternative domain

Both should point to the same backend: `192.168.1.9:8083`

---

## Prevention for Future

### For Setup Scripts

When creating Nginx Proxy Manager configurations, ensure:
1. Verify actual container host with `docker ps`
2. Double-check backend host matches container location
3. Test direct access before creating proxy
4. Use consistent domain naming patterns

### For Monitoring

Monitor both domain names if both exist:
- ✅ Monitor `books.acmea.tech` (primary monitoring target)
- Consider also monitoring `books.accelior.com` for redundancy

---

## Related Changes

### Nginx Proxy Manager Database

**Table:** `proxy_host`
**Record ID:** 30
**Changes:**
- `forward_host`: `192.168.1.20` → `192.168.1.9`

### Nginx Config File

**File:** `/data/nginx/proxy_host/30.conf`
**Line:** `set $server "..."`
**Changes:**
- `192.168.1.20` → `192.168.1.9`

---

## Uptime Kuma Monitor Status

**Monitor ID:** 29
**Name:** 📚 Calibre E-books
**URL:** `https://books.acmea.tech`
**Expected Behavior:** HTTP 302 redirect to /login
**Status After Fix:** ✅ Healthy

---

## Calibre Service Details

### Container Information
```
Name: calibre-web
Image: lscr.io/linuxserver/calibre-web:latest
Host: 192.168.1.9 (OMV storage server)
Port Mapping: 0.0.0.0:8083->8083/tcp
Uptime: 5 weeks
```

### Access URLs
- **External (via NPM):** `https://books.acmea.tech`
- **Alternative (via NPM):** `https://books.accelior.com`
- **Direct (internal):** `http://192.168.1.9:8083`

### Authentication
- Calibre-web requires login
- Redirects to `/login` when unauthenticated
- HTTP 302 redirect is normal/healthy behavior

---

## Testing Commands

### Test External Access
```bash
curl -I https://books.acmea.tech
# Expected: HTTP/2 302 with Location: /login
```

### Test Direct Access
```bash
curl -I http://192.168.1.9:8083
# Expected: HTTP/1.1 302 FOUND with Location: /login
```

### Check Container Status
```bash
docker ps | grep calibre
# Expected: calibre-web running with port 8083 exposed
```

### View Nginx Logs
```bash
docker exec nginx-proxy-manager tail -f /data/logs/proxy-host-30_access.log
```

---

## Related Documentation

- **Main Fix Report:** `/docs/troubleshooting/uptime-kuma-fixes-applied-2025-10-17.md`
- **Monitor Errors:** `/docs/troubleshooting/uptime-kuma-monitor-errors-2025-10-17.md`
- **Domain Mapping:** `/infrastructure-db/monitoring/DOMAIN-NAME-MAPPING.md`
- **Infrastructure Overview:** `/infrastructure-db/INFRASTRUCTURE-OVERVIEW.md`

---

**Status:** ✅ Resolved
**Fix Time:** ~10 minutes
**Impact:** Monitor now reports healthy status
**Severity:** Medium (service was accessible via alternate domain)
