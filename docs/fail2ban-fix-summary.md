# SOLVED: Fail2ban Was Blocking NPM Access

## ✅ Root Cause Found and Fixed

The 502 Bad Gateway error was caused by **fail2ban blocking the Nginx Proxy Manager server** (192.168.1.9) from accessing Hestia (192.168.1.30).

### 🔍 Diagnosis Process:

1. **NPM Configuration**: ✅ Correct (`http://192.168.1.30:80`)
2. **Hestia nginx**: ✅ Listening on `0.0.0.0:80` 
3. **Network connectivity**: ✅ Ping works
4. **Port access**: ❌ Connection refused on port 80
5. **Fail2ban check**: ❌ Hundreds of REJECT rules blocking ALL traffic

### 🛠️ Solution Applied:

```bash
# Added NPM server to fail2ban ignore list
ignoreip = 127.0.0.1 87.98.133.204 135.181.154.169 94.130.69.132 213.49.106.34 ::1 home.accelior.com 192.168.1.9

# Restarted fail2ban
systemctl restart fail2ban
```

### ✅ Current Status:

- **HTTP access**: ✅ Working (`mail.acmea.tech` → redirects to `webmail.acmea.tech`)
- **NPM connectivity**: ✅ No more connection refused
- **502 errors**: ✅ Resolved
- **Fail2ban**: ✅ NPM server whitelisted

### 🔧 Outstanding Issues:

1. **Domain redirect**: `mail.acmea.tech` redirects to `webmail.acmea.tech`
2. **SSL certificate**: May need configuration for `webmail.acmea.tech`

### 📋 What Was Fixed:

1. ✅ **Nginx listen configuration**: Changed from `192.168.1.30:80` to `0.0.0.0:80`
2. ✅ **Fail2ban whitelist**: Added NPM server IP (192.168.1.9)
3. ✅ **Webmail nginx config**: Added ACME challenge support
4. ✅ **SSL configuration**: Created for mail domain

### 🧪 Test Results:

```bash
# Before fix:
curl -I http://mail.acmea.tech/
HTTP/1.1 502 Bad Gateway

# After fix:
curl -I http://mail.acmea.tech/
HTTP/1.1 301 Moved Permanently
Location: https://webmail.acmea.tech/
```

### 💡 Key Lesson:

When troubleshooting proxy 502 errors:
1. Check proxy configuration ✅
2. Check backend service ✅  
3. Check network connectivity ✅
4. **Check fail2ban/firewall rules** ← This was the missing piece!

The issue was that fail2ban had accumulated hundreds of REJECT rules that were blocking ALL external access to ports 80/443, including the legitimate NPM server.