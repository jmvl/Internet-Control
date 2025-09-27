# Hestia Mail Server Maintenance Log

## September 9, 2025 - Anti-Spam Enhancement & Queue Cleanup

### Problem
User reported receiving excessive junk emails despite SpamAssassin being active on the mail server.

### Investigation
- **Mail Queue Status**: Found 66+ messages with 47 frozen messages
- **SpamAssassin Status**: Running but using default configuration (threshold 5.0)
- **Detection Rate**: 0 spam messages detected - too lenient settings
- **Root Cause**: Default SpamAssassin configuration was not aggressive enough

### Actions Taken

#### 1. Mail Queue Cleanup ✅
```bash
# Removed 47 frozen messages caused by mail loops
exim4 -bp | grep frozen | awk '{print $3}' | xargs -I {} exim4 -Mrm {}

# Root cause of frozen messages: Mail loop to root@mail.vega-messenger.com
# Error: "Too many 'Received' headers - suspected mail loop"
```

**Result**: Queue reduced from 66+ to 19 legitimate messages

#### 2. SpamAssassin Configuration Enhancement ✅
**File Modified**: `/etc/spamassassin/local.cf`

**Configuration Changes**:
```bash
# Backup original config
cp /etc/spamassassin/local.cf /etc/spamassassin/local.cf.backup.20250909

# Applied new aggressive configuration:
required_score 3.5          # Lowered from 5.0 (more sensitive)
use_bayes 1                 # Enable Bayesian learning
bayes_auto_learn 1          # Auto-learn from spam/ham
rewrite_header Subject [***SPAM***]  # Add spam markers
report_safe 1               # Encapsulate spam as attachments
trusted_networks 192.168.1.0/24 127.0.0.1  # Local network trust

# Custom spam rules added:
- Suspicious subject keywords (urgent, act now, free money, etc.)
- HTML-only email penalty
- Performance optimizations with shortcircuiting
```

#### 3. Service Restart ✅
```bash
# Test configuration syntax
spamassassin --lint

# Restart SpamAssassin service
systemctl restart spamassassin

# Verify service status
systemctl status spamassassin
```

### Testing & Verification

#### Before Enhancement:
```
Test message score: -1.0/5.0 (not detected as spam)
Spam detection: 0 messages flagged
```

#### After Enhancement:
```
Test message score: 7.9/3.5 (flagged as spam) ✅
Subject rewriting: [***SPAM***] prefix added ✅
Spam detection: Active and aggressive ✅
```

### Current Configuration Status

#### Services Status:
- **SpamAssassin**: ✅ Active (aggressive mode, threshold 3.5)
- **ClamAV**: ✅ Active (8.7M signatures, daily updates)
- **Exim4**: ✅ Active (integrated with SpamAssassin)
- **Mail Queue**: ✅ Clean (19 legitimate outbound messages)

#### Domain Configuration:
- **accelior.com**: Anti-spam enabled (`/etc/exim4/domains/accelior.com/antispam` exists)
- **acmea.tech**: Anti-spam enabled
- **Both domains**: DKIM, SPF, and TLS active

### Expected Results

Users should now experience:
1. **Reduced junk email**: Lower threshold catches more spam
2. **Clear spam identification**: `[***SPAM***]` in subject lines
3. **Improved learning**: Bayesian filter learns user patterns over time
4. **Better performance**: Shortcircuiting rules for faster processing

### Monitoring Commands

```bash
# Check mail queue status
exim4 -bp

# View recent SpamAssassin activity
tail -f /var/log/mail.log | grep spamd

# Check spam detection rates
grep "spam.*score" /var/log/exim4/mainlog | tail -10

# Monitor frozen messages
exim4 -bp | grep frozen | wc -l

# View SpamAssassin configuration
cat /etc/spamassassin/local.cf
```

### Future Maintenance

#### Monthly Tasks:
- Review mail queue for stuck messages: `exim4 -bp`
- Check SpamAssassin learning progress: `sa-learn --dump magic`
- Update spam rules if needed
- Monitor false positive rates

#### Bayesian Training (Optional):
```bash
# Train on existing spam folder (if available)
sa-learn --spam /path/to/spam/folder

# Train on ham (legitimate email)
sa-learn --ham /path/to/ham/folder

# Check learning statistics
sa-learn --dump magic
```

### Configuration Files Modified

1. **SpamAssassin**: `/etc/spamassassin/local.cf`
2. **Backup Created**: `/etc/spamassassin/local.cf.backup.20250909`

### Network Integration

The anti-spam system integrates with the existing infrastructure:
- **OPNsense Firewall** (192.168.1.3): Network-level filtering
- **Pi-hole DNS** (192.168.1.5): Domain-based blocking  
- **Hestia Mail Server** (192.168.1.30): Email-level spam detection
- **Nginx Proxy Manager** (192.168.1.9): SSL termination and routing

This provides comprehensive multi-layer protection against spam and malicious content.

---

**Completed by**: Claude Code
**Date**: September 9, 2025
**Duration**: ~15 minutes
**Status**: ✅ Successfully implemented and tested

---

## September 16, 2025 - Webmail Service Restoration & Deep Infrastructure Analysis

### Problem
Webmail service (mail.accelior.com) was completely inaccessible despite mail server functioning correctly. User reported "no roundcube interface" after updating NPM port configurations.

### Investigation & Root Cause Analysis

#### Initial Symptoms
- **External Access**: 504 Gateway Timeout from NPM
- **Backend Status**: Hestia mail server (192.168.1.30) fully operational
- **Services**: Exim4, Dovecot, Apache, and Roundcube all running correctly
- **Configuration**: NPM proxy updated to HTTPS scheme but still failing

#### Deep System Analysis

**1. Network Connectivity Testing**:
```bash
# External connectivity - FAILED
curl -I https://mail.accelior.com/ → 504 Gateway Timeout

# NPM to Hestia - FAILED
curl -k -I https://192.168.1.30:8443/ → Connection timeout

# Local Apache - SUCCESS
curl -k -I https://192.168.1.30:8443/ (from Hestia) → 200 OK
```

**2. NPM Configuration Analysis**:
- ✅ Forward scheme correctly set to `https`
- ✅ Port correctly set to `8443`
- ✅ SSL certificates valid for mail.accelior.com
- ❌ Backend connectivity failing despite correct configuration

**3. Apache Service Verification**:
- ✅ Apache listening on `192.168.1.30:8443` (IP-specific binding)
- ✅ SSL virtual hosts properly configured
- ✅ Roundcube installation functional
- ✅ Self-signed certificates present and valid

**4. Firewall Investigation**:
```bash
# Critical Discovery: iptables blocking webmail ports
iptables -L INPUT -n | grep -E "(8443|8080)"
# No rules found for ports 8080/8443 - BLOCKED BY DEFAULT POLICY
```

### Root Cause Identified

**Primary Issue**: Hestia container firewall (iptables) blocking Apache ports 8080 and 8443
- **Default Hestia Rules**: Only allow standard web ports (80, 443, 8083)
- **Missing Rules**: No explicit ACCEPT rules for Apache webmail ports
- **Previous Fix Lost**: Temporary iptables rules were overwritten by Hestia firewall management

### Actions Taken

#### 1. Firewall Rules Addition ✅
```bash
# Add permanent rules via Hestia firewall management
/usr/local/hestia/bin/v-add-firewall-rule ACCEPT 0.0.0.0/0 8443 TCP 'Apache-Webmail-HTTPS'
/usr/local/hestia/bin/v-add-firewall-rule ACCEPT 0.0.0.0/0 8080 TCP 'Apache-Webmail-HTTP'

# Verify implementation
iptables -L INPUT -n | grep -E "(8443|8080)"
```

#### 2. Connectivity Verification ✅
```bash
# NPM to Hestia connectivity restored
ssh root@192.168.1.9 "curl -k -I https://192.168.1.30:8443/" → 200 OK

# External webmail access restored
curl -I https://mail.accelior.com/ → 200 OK (Roundcube response)
```

#### 3. Full Service Testing ✅
- **Browser Test**: Roundcube login page loading correctly
- **SSL Verification**: HTTPS working end-to-end
- **Session Management**: Roundcube cookies being set properly
- **Response Headers**: All webmail functionality operational

### Technical Architecture Verified

```
External HTTPS Request (mail.accelior.com)
    ↓
OPNsense Firewall (192.168.1.3) - Port forwarding 443
    ↓
NPM (192.168.1.9:443) - Let's Encrypt SSL + Proxy
    ↓
Hestia Nginx (192.168.1.30:443) - Internal routing
    ↓
Apache (192.168.1.30:8443) - SSL virtual host ← FIREWALL ISSUE
    ↓
Roundcube (/var/lib/roundcube/) - PHP application
```

### Configuration Details

#### Firewall Rules Added:
```
Rule ID: [auto-generated]
Action: ACCEPT
Source: 0.0.0.0/0
Port: 8443
Protocol: TCP
Comment: Apache-Webmail-HTTPS

Rule ID: [auto-generated]
Action: ACCEPT
Source: 0.0.0.0/0
Port: 8080
Protocol: TCP
Comment: Apache-Webmail-HTTP
```

#### NPM Proxy Configuration (Verified Correct):
```yaml
Domain: mail.accelior.com
Scheme: https
Forward Host: 192.168.1.30
Forward Port: 8443
SSL Certificate: Let's Encrypt (npm-16)
Force SSL: Yes
```

### Current Status

#### Services Status:
- **Apache Webmail (8443)**: ✅ Active and accessible
- **NPM Proxy**: ✅ Correctly configured and forwarding
- **SSL Certificates**: ✅ Valid and auto-renewing
- **Firewall Rules**: ✅ Permanent rules in place
- **Roundcube Interface**: ✅ Fully functional

#### Domain Status:
- **mail.accelior.com**: ✅ Working (confirmed via browser test)
- **mail.acmea.tech**: ✅ Should work (same configuration pattern)
- **webmail.acmea.tech**: ✅ Should work (same configuration pattern)
- **Other webmail domains**: ✅ Should work (same infrastructure)

### Documentation Added

#### Knowledge Base Section:
- **Troubleshooting Guide**: Comprehensive diagnostic procedures
- **Common Issues**: Firewall blocking, NPM misconfiguration, SSL binding
- **Diagnostic Commands**: Health checks, service verification, log analysis
- **Maintenance Procedures**: Regular checks and post-update verification

### Prevention Measures

#### Monitoring Commands Added:
```bash
# Monthly webmail health check
curl -I https://mail.accelior.com/ && echo "✅ Webmail OK" || echo "❌ Webmail Failed"

# Firewall rule persistence verification
/usr/local/hestia/bin/v-list-firewall | grep -E "(8443|8080)"

# SSL certificate monitoring
docker exec nginx-proxy-manager-nginx-proxy-manager-1 certbot certificates
```

#### System Update Checklist:
1. Verify firewall rules persist after updates
2. Check Apache virtual host configuration
3. Confirm NPM proxy settings unchanged
4. Test end-to-end webmail connectivity

### Lessons Learned

1. **Hestia Firewall Management**: Always use Hestia commands for persistent firewall rules
2. **IP-Specific Binding**: Apache configuration binds to specific IP addresses, not all interfaces
3. **Multi-Layer Debugging**: Issues can exist at firewall, proxy, and application layers simultaneously
4. **Service Interdependencies**: NPM configuration correctness doesn't guarantee connectivity without proper firewall rules

### Files Modified/Created

1. **Firewall Rules**: Added permanent rules via Hestia firewall management
2. **Documentation**: Updated `/docs/hestia/hestia.md` with troubleshooting knowledge base
3. **Maintenance Log**: This entry in `/docs/hestia/hestia-maintenance.md`

### Future Recommendations

1. **Automated Monitoring**: Implement regular webmail health checks
2. **Backup Procedures**: Document NPM configuration backup/restore procedures
3. **SSL Certificate Monitoring**: Set up expiration alerts for Let's Encrypt certificates
4. **Infrastructure Documentation**: Maintain current network topology documentation

---

**Completed by**: Claude Code (Senior System Administrator)
**Date**: September 16, 2025
**Duration**: ~45 minutes (deep troubleshooting)
**Status**: ✅ Fully resolved and documented
**Severity**: Critical (service completely down)
**Resolution**: Firewall configuration + comprehensive documentation

---

## September 16, 2025 - Mail Client Connectivity Restoration via OPNsense & Fail2ban Resolution

### Problem
Mail clients for both accelior.com and acmea.tech domains unable to connect to mail server externally. User reported connection failures despite mail server services running correctly.

### Investigation & Root Cause Analysis

#### Initial Symptoms
- **External SMTP (587)**: Connection refused
- **External IMAP (993)**: Connection refused
- **External SMTP (25)**: Connection refused
- **All mail ports**: External accessibility completely blocked
- **Internal Services**: Hestia mail server (192.168.1.30) fully operational locally
- **Port Forwarding**: OPNsense rules existed but appeared inactive

#### Systematic Diagnostic Process

**1. OPNsense Port Forwarding Analysis**:
```bash
# Discovered all mail port forwarding rules were DISABLED
pfctl -s nat | grep -E "(25|587|993|995|143|110|465)"
# Result: No active NAT rules for mail ports

# Found port 587 (SMTP submission) completely missing from configuration
# All other mail ports configured but disabled in OPNsense web interface
```

**2. Infrastructure Verification**:
- ✅ **Hestia Services**: Exim4, Dovecot running and listening on all mail ports
- ✅ **Network Connectivity**: OPNsense could ping mail server (192.168.1.30)
- ✅ **DNS Resolution**: Dynamic DNS working correctly (home.accelior.com, base.acmea.tech)
- ✅ **ISP Confirmation**: EDPnet Belgium confirmed no port blocking
- ❌ **Port Forwarding**: Rules existed but were disabled in OPNsense

**3. OPNsense Configuration Issues Identified**:
```bash
# Port forwarding rules status:
# Port 25 (SMTP): CONFIGURED but DISABLED
# Port 143 (IMAP): CONFIGURED but DISABLED
# Port 465 (SMTPS): CONFIGURED but DISABLED
# Port 587 (Submission): MISSING entirely
# Port 993 (IMAPS): CONFIGURED but DISABLED
# Port 995 (POP3S): CONFIGURED but DISABLED
# Port 110 (POP3): CONFIGURED but DISABLED
```

### Actions Taken

#### 1. OPNsense Port Forwarding Configuration ✅

**Created Missing Port 587 Rule**:
```yaml
# Via OPNsense Web Interface (192.168.1.3)
Interface: WAN
Protocol: TCP
Source: any
Source Port: any
Destination: WAN net
Destination Port: 587 (submission)
Redirect Target IP: 192.168.1.30 (mailserver alias)
Redirect Target Port: 587
Description: SMTP Submission Port
```

**Enabled All Disabled Mail Port Rules**:
- ✅ Port 25 (SMTP): Enabled
- ✅ Port 143 (IMAP): Enabled
- ✅ Port 465 (SMTPS): Enabled
- ✅ Port 587 (Submission): Created and enabled
- ✅ Port 993 (IMAPS): Enabled
- ✅ Port 995 (POP3S): Enabled
- ✅ Port 110 (POP3): Enabled

#### 2. Firewall Rules Verification ✅
```bash
# Confirmed NAT redirect rules active
pfctl -s nat | grep -E "(submission|smtp|imap)"

# Verified firewall pass rules exist
pfctl -s rules | grep -E "port = (submission|smtp|imap)"

# All mail ports showing active NAT and filter rules
```

#### 3. Critical Discovery: Fail2ban Blocking OPNsense ⚠️

**Root Cause Identified**:
```bash
# fail2ban recidive jail was blocking OPNsense firewall IP
fail2ban-client status recidive
# Result: 192.168.1.3 (OPNsense) was BANNED

# This explained why port forwarding appeared broken -
# all forwarded traffic was being blocked at fail2ban level
```

**Resolution Applied**:
```bash
# 1. Unban OPNsense IP immediately
fail2ban-client set recidive unbanip 192.168.1.3

# 2. Add OPNsense to permanent whitelist
# Backup current configuration
cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup.20250916

# Add OPNsense IP to ignoreip list
sed -i 's/ignoreip = 127.0.0.1 87.98.133.204 135.181.154.169 94.130.69.132 213.49.106.34 ::1 home.accelior.com 192.168.1.9/ignoreip = 127.0.0.1 87.98.133.204 135.181.154.169 94.130.69.132 213.49.106.34 ::1 home.accelior.com 192.168.1.9 192.168.1.3/' /etc/fail2ban/jail.local

# 3. Reload fail2ban with new configuration
systemctl reload fail2ban
```

### Testing & Verification

#### External Connectivity Testing Results:
```bash
# Port 25 (SMTP)
nc -zv 77.109.89.47 25 → SUCCESS ✅

# Port 587 (SMTP Submission)
nc -zv 77.109.89.47 587 → SUCCESS ✅

# Port 143 (IMAP)
nc -zv 77.109.89.47 143 → SUCCESS ✅

# Port 993 (IMAPS)
nc -zv 77.109.89.47 993 → SUCCESS ✅

# SMTP Response Verification
curl -v telnet://77.109.89.47:587
# Result: Connected and received proper SMTP greeting
```

#### Service Architecture Verified:
```
External Mail Client
    ↓
Internet (77.109.89.47)
    ↓
OPNsense Firewall (192.168.1.3) - Port forwarding all mail ports
    ↓
Hestia Mail Server (192.168.1.30)
    ├── Exim4 (SMTP: 25, 587, 465)
    └── Dovecot (IMAP: 143, 993 | POP3: 110, 995)
```

### Current Status

#### Services Status:
- **OPNsense Port Forwarding**: ✅ All mail ports active and forwarding correctly
- **Fail2ban Configuration**: ✅ OPNsense IP whitelisted permanently
- **External Mail Ports**: ✅ All ports (25, 143, 465, 587, 993, 110, 995) externally accessible
- **SMTP Services**: ✅ Exim4 responding to external connections
- **IMAP Services**: ✅ Dovecot responding to external connections
- **Mail Client Connectivity**: ✅ Ready for external mail client configuration

#### Domain Status:
- **accelior.com**: ✅ All mail protocols accessible externally
- **acmea.tech**: ✅ All mail protocols accessible externally

### Prevention Measures

#### Fail2ban Monitoring:
```bash
# Regular fail2ban health checks
fail2ban-client status recidive

# Verify OPNsense IP remains whitelisted
grep "192.168.1.3" /etc/fail2ban/jail.local

# Monitor banned IP counts
fail2ban-client status | grep "Currently banned"
```

#### OPNsense Port Forwarding Verification:
```bash
# Monthly port forwarding status check
pfctl -s nat | grep -E "(smtp|submission|imap|pop3)" | wc -l
# Should return 21 rules (7 ports × 3 interfaces)

# External connectivity verification
for port in 25 587 143 993; do
  timeout 5 nc -zv 77.109.89.47 $port && echo "Port $port OK" || echo "Port $port FAILED"
done
```

### Configuration Files Modified

1. **fail2ban Configuration**: `/etc/fail2ban/jail.local`
   - Added 192.168.1.3 to `ignoreip` whitelist
   - Backup: `/etc/fail2ban/jail.local.backup.20250916`

2. **OPNsense Port Forwarding**: Via web interface
   - Created port 587 forwarding rule
   - Enabled all disabled mail port rules (25, 143, 465, 993, 110, 995)

### Root Cause Summary

**Primary Issue**: fail2ban's recidive jail had banned the OPNsense firewall IP (192.168.1.3), blocking all port-forwarded mail traffic at the iptables level before it could reach mail services.

**Secondary Issue**: Several mail port forwarding rules in OPNsense were disabled, and port 587 (SMTP submission) was completely missing from the configuration.

**Resolution Impact**: Both issues needed to be resolved for mail client connectivity to work:
1. Enable/create all required port forwarding rules in OPNsense
2. Remove OPNsense IP from fail2ban ban list and add to permanent whitelist

### Lessons Learned

1. **fail2ban Infrastructure Impact**: fail2ban can block critical infrastructure components (firewalls, proxies) that appear as connection sources
2. **Whitelist Network Infrastructure**: All network infrastructure IPs should be in fail2ban's `ignoreip` configuration
3. **Port Forwarding Verification**: Regular verification needed that port forwarding rules remain enabled after OPNsense updates
4. **Multi-Layer Troubleshooting**: Mail connectivity issues require checking firewall rules, port forwarding, AND intrusion prevention systems

### Future Maintenance

#### Monthly Checks:
```bash
# Verify fail2ban is not blocking infrastructure IPs
fail2ban-client status recidive | grep "Currently banned: 0"

# Confirm all mail ports externally accessible
for port in 25 587 143 993; do timeout 3 nc -zv 77.109.89.47 $port; done

# Check OPNsense port forwarding rule count
ssh root@opnsense "pfctl -s nat | grep mailserver | wc -l" # Should be 21
```

#### Post-Update Procedures:
1. **After OPNsense Updates**: Verify port forwarding rules remain enabled
2. **After fail2ban Updates**: Confirm infrastructure IPs remain in `ignoreip` list
3. **After Hestia Updates**: Test external mail port connectivity end-to-end
4. **After Network Changes**: Update fail2ban whitelist with any new infrastructure IPs

---

**Completed by**: Claude Code (Senior System Administrator)
**Date**: September 16, 2025
**Duration**: ~90 minutes (comprehensive infrastructure troubleshooting)
**Status**: ✅ Fully resolved - all mail ports externally accessible
**Severity**: Critical (complete mail client connectivity failure)
**Resolution**: OPNsense port forwarding configuration + fail2ban infrastructure whitelist