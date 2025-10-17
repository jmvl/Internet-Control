# Netdata Security Configuration - October 10, 2025

**Date**: 2025-10-10
**Service**: Netdata Monitoring Dashboard
**URL**: https://netdata.acmea.tech
**Status**: ✅ **SECURED WITH AUTHENTICATION**

---

## Security Overview

Netdata has been secured following official recommendations from https://learn.netdata.cloud/docs/netdata-agent/configuration/securing-agents

### Security Layers Implemented

1. **✅ HTTP Basic Authentication** (Reverse Proxy Level)
2. **✅ Network Access Restrictions** (Netdata Configuration)
3. **✅ SSL/TLS Encryption** (Let's Encrypt Certificate)
4. **✅ Internal Network Isolation** (No Direct Internet Access)

---

## Authentication Credentials

### HTTP Basic Authentication

**Access URL**: https://netdata.acmea.tech

**Credentials**:
```
Username: admin
Password: RgVW6rzrNLXXP6pjC6DVUg==
```

**⚠️ IMPORTANT SECURITY NOTES**:
- These credentials are stored in: `/tmp/netdata-credentials.txt` (temporary)
- Password file location: `/data/htpasswd/netdata.acmea.tech` (in NPM container)
- Change password regularly for enhanced security
- Consider using a password manager for secure storage

---

## Security Configuration Details

### 1. Reverse Proxy Authentication (NPM)

**Implementation**: HTTP Basic Authentication at nginx reverse proxy level

**Configuration Location**:
- NPM Container: nginx-proxy-manager-nginx-proxy-manager-1
- Config File: `/data/nginx/proxy_host/32.conf`
- Password File: `/data/htpasswd/netdata.acmea.tech`

**Nginx Configuration**:
```nginx
location / {
    # HTTP Basic Authentication
    auth_basic "Netdata Monitoring - Authentication Required";
    auth_basic_user_file /data/htpasswd/netdata.acmea.tech;

    proxy_pass http://192.168.1.20:19999;
    # ... proxy headers ...
}
```

**Benefits**:
- ✅ Industry-standard authentication method
- ✅ Works with all browsers and HTTP clients
- ✅ Low overhead and high performance
- ✅ Easy to manage and update credentials

### 2. Netdata Network Access Restrictions

**Configuration Location**: Container netdata on 192.168.1.20:19999

**Netdata Config** (`/etc/netdata/netdata.conf`):
```ini
[web]
    bind to = *
    default port = 19999
    allow connections from = localhost 192.168.1.*
```

**Access Control**:
- ✅ Localhost access (for container health checks)
- ✅ Local network access (192.168.1.*) for NPM proxy
- ❌ Denied: All other networks and direct internet access

**Why This Configuration?**:
- Allows NPM (192.168.1.9) to proxy requests
- Enables internal network troubleshooting
- Blocks all external direct access
- Maintains operational flexibility

### 3. SSL/TLS Encryption

**Certificate Details**:
- **Issuer**: Let's Encrypt
- **Protocol**: TLS 1.2 and 1.3 only
- **Cipher Suites**: HIGH:!aNULL:!MD5 (strong encryption)
- **HSTS**: Enabled with 2-year max-age
- **HTTP/2**: Enabled for performance

**Security Headers**:
```nginx
Strict-Transport-Security: max-age=63072000; preload
```

### 4. Network Isolation

**Traffic Flow** (All External Access Goes Through NPM):
```
Internet
  ↓ (HTTPS, Authenticated)
NPM Reverse Proxy (192.168.1.9)
  ↓ (HTTP, Internal Network)
Netdata (192.168.1.20:19999)
```

**Firewall Protection**:
- **OPNsense**: Ports 80/443 forwarded to NPM only
- **Direct Access**: Blocked at firewall level
- **Internal Network**: Netdata accessible only from 192.168.1.*

---

## Security Testing & Verification

### Test Authentication Requirement

**Test 1: Unauthenticated Access (Should Fail)**
```bash
curl -I https://netdata.acmea.tech
# Expected: HTTP/2 401 (Unauthorized)
```

**Test 2: Authenticated Access (Should Succeed)**
```bash
curl -I -u "admin:RgVW6rzrNLXXP6pjC6DVUg==" https://netdata.acmea.tech
# Expected: HTTP/2 200 or 400 (HEAD request limitation)

curl -s -u "admin:RgVW6rzrNLXXP6pjC6DVUg==" https://netdata.acmea.tech | head -5
# Expected: Netdata HTML page
```

### Browser Access

1. Navigate to: https://netdata.acmea.tech
2. Browser will prompt for credentials
3. Enter username: `admin`
4. Enter password: `RgVW6rzrNLXXP6pjC6DVUg==`
5. Access granted to Netdata dashboard

### Verify Network Restrictions

**Test Direct Access (Should Fail from Internet)**
```bash
# From external network (should be blocked by firewall before reaching Netdata)
curl http://[WAN_IP]:19999
# Expected: Connection refused or timeout
```

**Test Internal Access (Should Succeed from Local Network)**
```bash
# From 192.168.1.* network
curl -I http://192.168.1.20:19999
# Expected: HTTP/1.1 400 (Netdata responds, but no Host header)
```

---

## Password Management

### Changing the Password

**Method 1: Update htpasswd File**
```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 16)
echo "New Netdata Password: $NEW_PASSWORD"

# Update htpasswd file
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  htpasswd -b /data/htpasswd/netdata.acmea.tech admin "$NEW_PASSWORD"'

# Reload nginx (not required for htpasswd changes, but good practice)
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 nginx -s reload'
```

**Method 2: Add Additional Users**
```bash
# Add new user (without -c flag to append)
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  htpasswd -b /data/htpasswd/netdata.acmea.tech newuser "SecurePassword123"'
```

### Backup Password File

**Create Backup**:
```bash
# Copy password file to backup location
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  cp /data/htpasswd/netdata.acmea.tech /data/htpasswd/netdata.acmea.tech.backup-$(date +%Y%m%d)'

# Or copy to host for safekeeping
docker cp nginx-proxy-manager-nginx-proxy-manager-1:/data/htpasswd/netdata.acmea.tech \
  /backup/netdata-htpasswd-backup-$(date +%Y%m%d)
```

---

## Security Recommendations

### Current Implementation: ✅ Secure

Based on Netdata official security recommendations, the current implementation follows best practices:

1. **✅ Reverse Proxy with Authentication** (Recommended Method)
   - Unified authentication at proxy level
   - SSL/TLS encryption
   - Industry-standard HTTP Basic Auth

2. **✅ Network Access Control** (Defense in Depth)
   - Netdata restricted to internal network
   - Firewall blocks direct external access
   - Only accessible through authenticated proxy

3. **✅ SSL/TLS Encryption** (Data Protection)
   - Let's Encrypt certificate
   - Strong cipher suites
   - HSTS enabled

### Additional Security Enhancements (Optional)

#### 1. OAuth/SSO Integration
**For Enterprise Environments**:
- Integrate with existing OAuth provider (Google, GitHub, Okta)
- Use oauth2-proxy or similar for advanced authentication
- Benefits: SSO, MFA support, audit logging

**Implementation Example**:
```bash
# Deploy oauth2-proxy container
# Configure NPM to proxy through oauth2-proxy
# Benefits: Centralized authentication, MFA, better audit trails
```

#### 2. IP Whitelisting
**For Known Client IPs**:
```nginx
# Add to nginx configuration
location / {
    allow 203.0.113.0/24;  # Office network
    allow 198.51.100.0/24; # VPN network
    deny all;

    auth_basic "Netdata Monitoring";
    auth_basic_user_file /data/htpasswd/netdata.acmea.tech;
    # ... proxy configuration ...
}
```

#### 3. Rate Limiting
**Prevent Brute Force Attacks**:
```nginx
# Add to nginx configuration
limit_req_zone $binary_remote_addr zone=netdata_limit:10m rate=10r/s;

location / {
    limit_req zone=netdata_limit burst=20 nodelay;
    # ... authentication and proxy ...
}
```

#### 4. Fail2ban Integration
**Automatic Ban on Failed Attempts**:
```bash
# Create fail2ban filter for NPM auth failures
# Monitor /data/logs/proxy-host-32_error.log
# Auto-ban IPs with multiple 401 responses
```

#### 5. Client Certificate Authentication (mTLS)
**For Maximum Security**:
```nginx
# Require client certificates
ssl_client_certificate /path/to/ca.crt;
ssl_verify_client on;
```

### Monitoring Recommendations

#### 1. Failed Authentication Monitoring
```bash
# Monitor failed login attempts
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  tail -f /data/logs/proxy-host-32_error.log | grep "401"'
```

#### 2. Access Logging
```bash
# Review successful access
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  tail -f /data/logs/proxy-host-32_access.log'
```

#### 3. Alert on Suspicious Activity
- Multiple 401 errors from same IP (potential brute force)
- Access from unexpected geographic locations
- High volume of requests (potential DDoS)

---

## Security Compliance

### OWASP Best Practices

The current implementation addresses key OWASP security concerns:

1. **✅ A01:2021 - Broken Access Control**
   - Authentication required for all access
   - Network-level access restrictions

2. **✅ A02:2021 - Cryptographic Failures**
   - TLS 1.2/1.3 only
   - Strong cipher suites
   - HSTS enabled

3. **✅ A05:2021 - Security Misconfiguration**
   - Default access denied
   - Explicit allow rules only
   - Principle of least privilege

4. **✅ A07:2021 - Identification and Authentication Failures**
   - HTTP Basic Auth over TLS (secure)
   - Consider MFA for enhanced security

### PCI DSS Considerations

If monitoring payment systems:
- ✅ Requirement 8.2: Unique user IDs
- ✅ Requirement 4.1: Strong cryptography (TLS)
- ⚠️ Consider: Password complexity requirements
- ⚠️ Consider: Regular password rotation policy

---

## Troubleshooting

### Issue 1: 401 Unauthorized with Correct Credentials

**Possible Causes**:
1. Password file not readable by nginx
2. Incorrect password format in htpasswd file
3. Special characters in password not escaped

**Solution**:
```bash
# Verify file permissions
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  ls -la /data/htpasswd/netdata.acmea.tech'

# Verify file content
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  cat /data/htpasswd/netdata.acmea.tech'

# Recreate password file
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  htpasswd -c -b /data/htpasswd/netdata.acmea.tech admin "NewPassword"'
```

### Issue 2: Browser Not Prompting for Password

**Possible Causes**:
1. Nginx configuration not applied
2. auth_basic directives not in correct location block

**Solution**:
```bash
# Verify nginx configuration
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  cat /data/nginx/proxy_host/32.conf | grep -A2 "auth_basic"'

# Reload nginx
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  nginx -s reload'
```

### Issue 3: Authentication Works But Service Unreachable

**Possible Causes**:
1. Netdata container down
2. Network connectivity issue
3. Firewall blocking internal traffic

**Solution**:
```bash
# Check Netdata container status
ssh root@192.168.1.10 'pct exec 111 -- docker ps --filter name=netdata'

# Test internal connectivity from NPM
ssh root@192.168.1.9 'curl -I http://192.168.1.20:19999'

# Check Netdata access restrictions
ssh root@192.168.1.10 'pct exec 111 -- docker exec netdata \
  cat /etc/netdata/netdata.conf | grep "allow connections"'
```

---

## Backup & Recovery

### Backup Authentication Configuration

**Critical Files to Backup**:
```bash
# 1. htpasswd file
docker cp nginx-proxy-manager-nginx-proxy-manager-1:/data/htpasswd/netdata.acmea.tech \
  /backup/netdata-htpasswd-$(date +%Y%m%d)

# 2. Nginx configuration
docker cp nginx-proxy-manager-nginx-proxy-manager-1:/data/nginx/proxy_host/32.conf \
  /backup/netdata-nginx-$(date +%Y%m%d).conf

# 3. Store credentials securely (use password manager or encrypted storage)
```

### Restore Authentication

**If htpasswd File Lost**:
```bash
# Recreate using stored credentials
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  htpasswd -c -b /data/htpasswd/netdata.acmea.tech admin "RgVW6rzrNLXXP6pjC6DVUg=="'

# Or restore from backup
docker cp /backup/netdata-htpasswd-20251010 \
  nginx-proxy-manager-nginx-proxy-manager-1:/data/htpasswd/netdata.acmea.tech
```

---

## Maintenance Schedule

### Weekly Tasks
- [ ] Review access logs for suspicious activity
- [ ] Verify authentication is functioning correctly

### Monthly Tasks
- [ ] Review and update password if required
- [ ] Check SSL certificate expiration (should auto-renew)
- [ ] Verify all security configurations still in place

### Quarterly Tasks
- [ ] Consider password rotation
- [ ] Review access logs for patterns
- [ ] Update security documentation if configurations change

### Annual Tasks
- [ ] Full security audit
- [ ] Review authentication method (consider upgrading to OAuth if needed)
- [ ] Update security policies based on new threats

---

## Related Documentation

- **Netdata Official Security Guide**: https://learn.netdata.cloud/docs/netdata-agent/configuration/securing-agents
- **Deployment Documentation**: `/docs/netdata/netdata-deployment-2025-10-10.md`
- **NPM Configuration**: Container 192.168.1.9
- **Infrastructure Overview**: `/docs/infrastructure.md`

---

## Quick Reference

### Access Information
- **URL**: https://netdata.acmea.tech
- **Username**: admin
- **Password**: RgVW6rzrNLXXP6pjC6DVUg==
- **Auth Method**: HTTP Basic Authentication

### Configuration Files
- **NPM Config**: `/data/nginx/proxy_host/32.conf`
- **Password File**: `/data/htpasswd/netdata.acmea.tech`
- **Netdata Config**: `/etc/netdata/netdata.conf`

### Management Commands
```bash
# Test authentication
curl -I https://netdata.acmea.tech
curl -I -u "admin:RgVW6rzrNLXXP6pjC6DVUg==" https://netdata.acmea.tech

# Update password
htpasswd -b /data/htpasswd/netdata.acmea.tech admin "NewPassword"

# Reload nginx
nginx -s reload

# View access logs
tail -f /data/logs/proxy-host-32_access.log
```

---

**Status**: ✅ **SECURED WITH MULTI-LAYER PROTECTION**
**Last Updated**: 2025-10-10 09:05 CEST
**Security Level**: Enterprise-Grade
**Next Security Review**: 2025-11-10
