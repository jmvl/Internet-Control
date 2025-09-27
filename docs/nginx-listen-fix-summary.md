# Nginx Listen Configuration Fix - COMPLETED

## ✅ Problem Solved: Hestia Server Configuration

You were absolutely correct! The issue was that Hestia nginx was listening on `192.168.1.30:80` instead of `0.0.0.0:80`.

### ✅ What Was Fixed:

1. **Main nginx IP configuration**: `/etc/nginx/conf.d/192.168.1.30.conf`
   - Changed: `listen 192.168.1.30:80` → `listen 0.0.0.0:80`
   - Changed: `listen 192.168.1.30:443` → `listen 0.0.0.0:443`

2. **All domain configurations**: Updated HTTP and HTTPS listen directives
   - Updated 9 nginx.conf files across all domains
   - Updated all nginx.ssl.conf files

3. **Verification**: 
   ```bash
   # Before fix:
   192.168.1.30:80 (connection refused from NPM)
   
   # After fix:
   0.0.0.0:80 (accepts connections from anywhere)
   0.0.0.0:443 (accepts connections from anywhere)
   ```

### ✅ Current Status:

- **HTTP requests**: ✅ Being received and processed
- **NPM connectivity**: ✅ Working (receiving redirects)
- **Hestia backend**: ✅ Apache + Roundcube working
- **SSL certificates**: ✅ Properly configured

## ❌ Remaining Issue: Nginx Proxy Manager HTTPS Configuration

The 502 error is now coming from **NPM HTTPS configuration**, not Hestia.

### Evidence:
1. HTTP requests reach NPM and get redirected to HTTPS (301 redirect)
2. The redirect is coming from NPM (server: openresty)
3. Direct Apache backend works: `https://192.168.1.30:8443/` serves Roundcube
4. The 502 only occurs on HTTPS requests through NPM

## 🔧 Next Steps: Fix NPM Configuration

### Check NPM SSL Settings:

1. **Access NPM**: `http://192.168.1.9:81`

2. **Check mail.acmea.tech SSL configuration**:
   - SSL Certificate: Should be "Let's Encrypt" or "Request New"
   - Force SSL: Should be enabled ✅
   - HSTS Enabled: Optional
   - HTTP/2 Support: Should be enabled ✅

3. **Verify Forward Configuration**:
   - Scheme: `http` (not https)
   - Forward Hostname/IP: `192.168.1.30`
   - Forward Port: `80`
   - ⚠️ **Do NOT use `https` scheme or port `443` for forwarding**

4. **Advanced Tab** (if needed):
   ```nginx
   # Only add if absolutely necessary
   proxy_set_header Host $host;
   proxy_set_header X-Real-IP $remote_addr;
   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   proxy_set_header X-Forwarded-Proto $scheme;
   ```

### Common NPM SSL Issues:

1. **Wrong forwarding scheme**: Using `https://192.168.1.30:443` instead of `http://192.168.1.30:80`
2. **Certificate problems**: NPM trying to verify Hestia's certificate
3. **Missing headers**: Not setting proper proxy headers

## 🧪 Testing Commands:

```bash
# Should show Roundcube login (after NPM fix)
curl -L https://mail.acmea.tech | grep -i roundcube

# Should return 200 OK (not 502)
curl -I https://mail.acmea.tech

# Direct backend test (working)
curl -k https://192.168.1.30:8443/ -H 'Host: mail.acmea.tech'
```

## 📋 Summary:

- ✅ **Hestia server**: Fixed to accept external connections
- ✅ **Backend services**: Apache + Roundcube working correctly  
- ✅ **SSL certificates**: Properly configured
- ❌ **NPM SSL proxy**: Needs configuration review

The fix you suggested was exactly right - nginx needed to listen on all interfaces, not just the specific IP!