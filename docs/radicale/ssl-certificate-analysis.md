# SSL Certificate Analysis: accelior.com vs acmea.tech

## DNS Resolution Status

### mail.accelior.com ✅ WORKING
```
mail.accelior.com → home.accelior.com → 77.109.89.47
TTL: 169s (dynamic, updates properly)
Status: DNS propagated correctly
```

### mail.acmea.tech ❌ BROKEN
```
mail.acmea.tech → base.acmea.tech → 84.32.84.33 (OLD IP)
Current IP should be: 77.109.89.47
Status: DNS not propagated, pointing to wrong IP
```

## SSL Certificate Status

### mail.accelior.com ✅ WORKING
**IMAP SSL Certificate (port 993):**
- **Status**: Valid and accessible
- **Subject Alternative Names**:
  - `mail.accelior.com` ✅
  - `webmail.accelior.com` ✅
- **Issuer**: Let's Encrypt
- **Android Compatibility**: Full compatibility

**Certificate Details:**
```
Subject: CN=mail.accelior.com
SAN: DNS:mail.accelior.com, DNS:webmail.accelior.com
Validity: Valid certificate chain
```

### mail.acmea.tech ❌ BROKEN
**IMAP SSL Certificate (port 993):**
- **Status**: Cannot connect - SSL handshake fails
- **Primary Issue**: DNS pointing to wrong IP (84.32.84.33 vs 77.109.89.47)
- **Secondary Issue**: Certificate may not include mail.acmea.tech in SAN

## Root Cause Analysis

### Why accelior.com Works
1. **DNS**: Proper dynamic DNS configuration updates home.accelior.com promptly
2. **Certificate**: NPM has generated correct Let's Encrypt certificate including mail.accelior.com
3. **Service Config**: Mail services properly configured with matching certificate

### Why acmea.tech Fails
1. **DNS Propagation**: Global DNS servers still cache old IP (84.32.84.33)
2. **TTL Impact**: High TTL values delay propagation
3. **Certificate Mismatch**: Mail services may not have certificate for mail.acmea.tech subdomain

## Immediate Fixes Required

### 1. DNS Propagation (Critical)
The authoritative Cloudflare DNS is correct:
```bash
# Authoritative DNS (correct):
dig @cleo.ns.cloudflare.com mail.acmea.tech
# Should show: 77.109.89.47

# Public DNS (cached, wrong):
dig @8.8.8.8 mail.acmea.tech
# Currently shows: 84.32.84.33
```

**Solution**: Wait for DNS propagation (1-2 hours with 60s TTL) or use hosts file

### 2. Certificate Configuration
**accelior.com approach** (working model):
- NPM handles Let's Encrypt certificate generation
- Certificate includes both mail.domain.com and webmail.domain.com
- Services properly configured to use NPM certificates

**acmea.tech fix needed**:
- Ensure NPM has proxy configuration for mail.acmea.tech
- Generate Let's Encrypt certificate including mail.acmea.tech
- Configure Hestia mail services to use correct certificate

## Samsung Email App Requirements

### SSL/TLS Requirements
- **Certificate Validation**: Strict hostname matching required
- **SAN Support**: Subject Alternative Name must include mail.domain.com
- **Certificate Chain**: Complete certificate chain validation
- **TLS Version**: TLS 1.2+ support required

### Working Configuration (accelior.com)
```
Server: mail.accelior.com
Port: 993 (IMAPS) / 587 (SMTP with STARTTLS)
Security: SSL/TLS
Certificate: Valid Let's Encrypt with proper SAN
Status: ✅ Android compatible
```

### Broken Configuration (acmea.tech)
```
Server: mail.acmea.tech
Port: 993 (IMAPS) / 587 (SMTP with STARTTLS)
Security: SSL/TLS
Issues:
- DNS points to wrong IP
- Certificate may not include mail.acmea.tech
Status: ❌ Connection fails
```

## Recommended Actions

### Immediate (within 1 hour)
1. **Wait for DNS propagation** - Check every 15 minutes:
   ```bash
   dig @8.8.8.8 mail.acmea.tech +short
   ```
   When it returns `77.109.89.47`, DNS is propagated

2. **Test mail services** once DNS is correct:
   ```bash
   openssl s_client -connect mail.acmea.tech:993
   openssl s_client -connect mail.acmea.tech:587 -starttls smtp
   ```

### Medium Term (1-4 hours)
1. **Add NPM proxy configuration** for mail.acmea.tech if not present
2. **Generate Let's Encrypt certificate** including mail.acmea.tech
3. **Update Hestia configuration** to use correct certificates
4. **Test Android Samsung Email app** connection

### Long Term (maintenance)
1. **Monitor certificate expiration** for both domains
2. **Standardize SSL configuration** between domains
3. **Document working configuration** for future reference
4. **Set up monitoring** for mail service SSL certificate validity

## Testing Commands

### DNS Testing
```bash
# Test current DNS resolution
dig mail.acmea.tech +short
dig mail.accelior.com +short

# Test from different DNS servers
dig @8.8.8.8 mail.acmea.tech +short
dig @1.1.1.1 mail.acmea.tech +short
```

### SSL Testing
```bash
# Test IMAP SSL
openssl s_client -connect mail.accelior.com:993 -servername mail.accelior.com
openssl s_client -connect mail.acmea.tech:993 -servername mail.acmea.tech

# Test SMTP SSL
openssl s_client -connect mail.accelior.com:587 -starttls smtp -servername mail.accelior.com
openssl s_client -connect mail.acmea.tech:587 -starttls smtp -servername mail.acmea.tech

# Check certificate SAN
echo | openssl s_client -connect mail.accelior.com:993 2>/dev/null | openssl x509 -noout -text | grep -A 5 "Subject Alternative Name"
```

### Android Compatibility Testing
```bash
# Test with Android-compatible cipher suites
openssl s_client -connect mail.accelior.com:993 -cipher 'ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM'

# Test TLS 1.2 specifically
openssl s_client -connect mail.accelior.com:993 -tls1_2
```

---

**Status Summary:**
- ✅ **mail.accelior.com**: Fully functional for Android email apps
- ❌ **mail.acmea.tech**: DNS propagation blocking, SSL issues secondary
- 🕐 **ETA**: 1-2 hours for DNS propagation to resolve primary issue

**Last Updated**: September 19, 2025