# Fix 502 Bad Gateway Error - Nginx Proxy Manager Configuration

## Problem Diagnosed

The 502 error occurs because:
1. **Nginx Proxy Manager** is forwarding to the wrong target
2. **Hestia nginx** only listens on `192.168.1.30:80`, not `0.0.0.0:80`
3. **mail.acmea.tech** in NPM is configured incorrectly

## Current Status Check

✅ **webmail.acmea.tech** - Shows default page (200 OK)
❌ **mail.acmea.tech** - Returns 502 Bad Gateway
✅ **Hestia server** - Roundcube working on Apache (port 8080)
✅ **SSL certificates** - Properly configured

## Required Fix: Update Nginx Proxy Manager

### Step 1: Access Nginx Proxy Manager
```
http://192.168.1.9:81
```

### Step 2: Fix mail.acmea.tech Configuration

**Current (WRONG) Configuration:**
- Domain: `mail.acmea.tech`
- Forward to: `localhost:80` OR `127.0.0.1:80` OR just `80`
- This causes 502 because Hestia nginx doesn't listen on localhost

**Correct Configuration:**
- Domain: `mail.acmea.tech`
- Scheme: `http`
- Forward Hostname/IP: `192.168.1.30`
- Forward Port: `80`
- Cache Assets: ✅ (optional)
- Block Common Exploits: ✅ (optional)

### Step 3: Check webmail.acmea.tech Configuration

If `webmail.acmea.tech` is showing a default page instead of Roundcube:

**Fix webmail.acmea.tech:**
- Domain: `webmail.acmea.tech`
- Scheme: `http`
- Forward Hostname/IP: `192.168.1.30`
- Forward Port: `80`

### Step 4: SSL Configuration (Optional but Recommended)

For both domains, under "SSL" tab:
- SSL Certificate: Let's Encrypt
- Force SSL: ✅
- HTTP/2 Support: ✅

## Alternative: Use Direct Server Access (Temporary)

If you want to test Roundcube immediately while fixing NPM:

**Direct access URL:**
```
http://192.168.1.30/
```
(This bypasses NPM entirely)

## After NPM Fix - Expected Results

✅ **http://mail.acmea.tech** → Redirects to HTTPS → Roundcube login
✅ **https://mail.acmea.tech** → Roundcube login page
✅ **http://webmail.acmea.tech** → Redirects to HTTPS → Roundcube login
✅ **https://webmail.acmea.tech** → Roundcube login page

## Verification Commands

After making NPM changes, test:

```bash
# Should show Roundcube login page
curl -L http://mail.acmea.tech | grep -i roundcube

# Should return 200 OK
curl -I https://mail.acmea.tech

# Should show webmail interface
curl -L http://webmail.acmea.tech | grep -i roundcube
```

## Key Points

1. **The issue is NOT in Hestia** - Roundcube is working fine
2. **The issue is in NPM configuration** - Wrong forwarding target
3. **Both domains should point to** `192.168.1.30:80`
4. **SSL will work automatically** once HTTP access works

## Why This Happens

Hestia nginx binds to the specific IP (`192.168.1.30:80`) for security reasons, rather than all interfaces (`0.0.0.0:80`). NPM must specify the exact IP address when forwarding, not just "localhost" or port number alone.