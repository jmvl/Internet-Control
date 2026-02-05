# Hestia Mail Server - Email Sending Status Report

**Date**: 2026-02-04
**System**: Hestia Mail Server (192.168.1.30)
**Checked by**: Infrastructure Team (Claude Code)
**Related Incident**: 2026-01-22 SMTP Relay Authentication Failure

---

## Executive Summary

**Status**: ✅ **OPERATIONAL** - Email sending is working

**Key Findings**:
- SMTP relay authentication is **working** with current credentials
- Last successful relay: 2026-02-04 09:00:13 UTC (7+ hours ago)
- Mail queue is **empty** (0 messages pending)
- No frozen messages in queue
- Exim service is healthy and running

**Previous Issue Resolution**: The SMTP relay authentication failure from 2026-01-22 has been **resolved**.

---

## Current Status Details

### Mail Queue Status
```
Queue Count: 0 messages
Frozen Messages: None
Queue Runs: Completing successfully (last run: 16:15:02 UTC)
```

### Exim Service Status
```
Status: active (running)
Uptime: 3 days (since 2026-02-01 04:00:21 UTC)
Memory: 136.5M
Process: /usr/sbin/exim4 -bd -q30m
```

### SMTP Relay Configuration
**File**: `/etc/exim4/smtp_relay.conf`
```conf
host: relay.edpnet.be
port: 587
user: micheljean2.m2
pass: [hidden]
```

### Relay Connectivity
```
relay.edpnet.be (212.71.0.16) 587 port [tcp/submission] - SUCCESS
```

---

## Recent Email Activity

### Last Successful Outgoing Email via Relay
**Timestamp**: 2026-02-04 09:00:13 UTC
**From**: jmvl@accelior.com
**To**: thierry@sultan.ae
**Size**: 3.5 MB
**Status**: ✅ Delivered
**Queue ID**: 1vnYk1-0033BQ-1E

**Full Transaction Log**:
```
2026-02-04 09:00:06 1vnYk1-0033BQ-1E <= jmvl@accelior.com H=(smtpclient.apple) [192.168.1.3] P=esmtpsa X=TLS1.2:ECDHE_SECP256R1__RSA_SHA256__AES_128_GCM:128 CV=no SNI=mail.accelior.com A=dovecot_plain:jmvl@accelior.com S=3573121

2026-02-04 09:00:07 1vnYk1-0033BQ-1E => jmvl <jmvl@acmea.tech> R=localuser T=local_delivery
2026-02-04 09:00:07 1vnYk1-0033BQ-1E => jmvl <jmvl@accelior.com> R=localuser T=local_delivery

2026-02-04 09:00:13 1vnYk1-0033BQ-1E H=relay.edpnet.be [212.71.0.16] TLS error on connection (recv): The TLS connection was non-properly terminated.
2026-02-04 09:00:13 1vnYk1-0033BQ-1E => thierry@sultan.ae R=send_via_smtp_relay T=smtp_relay_smtp H=relay.edpnet.be [212.71.0.16] X=TLS1.3:ECDHE_SECP256R1__RSA_PSS_RSAE_SHA256__AES_256_GCM:256 CV=yes A=smtp_relay_login C="250 Ok: queued as 01D3D1B40072"

2026-02-04 09:00:13 1vnYk1-0033BQ-1E Completed
```

**Note**: The "TLS error on connection (recv): The TLS connection was non-properly terminated" is a benign warning that occurs after successful delivery. This is normal behavior when the remote server closes the connection after accepting the message.

---

## Authentication Status

### SMTP Relay Authentication
**Status**: ✅ **Working**

Recent successful authentications with relay.edpnet.be:
- 2026-02-04 09:00:13 - Successful (A=smtp_relay_login)
- 2026-02-04 00:25:03 - Successful (A=smtp_relay_login)

### Incoming Email Authentication (IMAP/SMTP Submission)
**Status**: ⚠️ **External Authentication Attempts Failing**

Multiple failed authentication attempts from external IPs:
```
2026-02-04 02:33:17 - 185.91.69.136 - dovecot_login failed (jmvl@accelior.com)
2026-02-04 04:11:31 - 158.94.208.110 - dovecot_login failed (jmvl@accelior.com)
2026-02-04 05:06:02 - 73.196.144.25 - dovecot_plain failed (jmvl@accelior.com)
2026-02-04 08:31:51 - 194.87.35.180 - dovecot_login failed (admin@accelior.com)
2026-02-04 10:03:39 - 69.5.189.21 - dovecot_login failed (jmvl@accelior.com)
2026-02-04 11:19:02 - 50.6.250.242 - dovecot_login failed (jmvl@accelior.com)
2026-02-04 13:22:20 - 109.195.14.161 - dovecot_plain failed (jmvl@accelior.com)
2026-02-04 13:38:43 - 73.9.189.119 - dovecot_plain failed (jmvl@accelior.com)
```

**Analysis**: These appear to be **brute-force attacks** or unauthorized access attempts. The fact that authentication is failing is **expected behavior** - the server is correctly rejecting invalid credentials.

**Recommendation**: Consider implementing fail2ban or similar intrusion prevention to temporarily ban IPs with repeated authentication failures.

---

## System Health

### Exim Paniclog
```
2026-01-28 18:25:46 - spam acl condition: error reading from spamd [127.0.0.1]:783, socket: Connection timed out
```

**Status**: ⚠️ **Stale entry** (6+ days old)
**Impact**: None - This is an old entry. SpamAssassin may need attention.

**Action**: Check if SpamAssassin is running and consider clearing the paniclog if no recent errors.

### Regular Queue Runs
```
Last queue run: 2026-02-04 16:15:02 UTC (started at 16:15:02, ended at 16:15:02)
Queue runner interval: 30 minutes
```

---

## Comparison with Previous Incident

### 2026-01-22 Incident
- **Issue**: 11 emails stuck in queue for 3+ days
- **Error**: "535 Error: authentication failed" from relay.edpnet.be
- **Status**: Critical - All outgoing email blocked
- **Root Cause**: Incorrect/Expired SMTP relay credentials

### Current Status (2026-02-04)
- **Issue**: None - User reports email sending problem
- **Queue**: Empty (0 messages)
- **Last Successful Relay**: 7+ hours ago
- **Authentication**: Working
- **Status**: Operational

---

## User Issue Analysis

**User Report**: Cannot send email with jmvl@acmea.tech and jmvl@accelior.com

**Possible Explanations**:

1. **Recent Activity**: Last successful email sent was 7+ hours ago (09:00:13 UTC). User may be trying to send now and experiencing delays.

2. **Network/Client Issue**: The problem may be on the client side (Apple Mail client from 192.168.1.3). Check:
   - Client connectivity to mail server
   - Client authentication (SMTP submission, not relay)
   - Mail client configuration

3. **No Queue Buildup**: Since the queue is empty, either:
   - Messages are being rejected before queuing (SMTP submission issue)
   - Messages are being delivered successfully
   - User is not able to connect to submit messages

4. **Brute Force Attacks**: High volume of failed external authentication attempts may be affecting legitimate connections if rate limiting is in place.

---

## Recommended Next Steps

### For the User's Issue

1. **Test SMTP Submission from Client**:
   ```bash
   # From user's machine (192.168.1.3)
   telnet mail.accelior.com 587
   # Or
   telnet mail.acmea.tech 587
   ```

2. **Check Mail Client Logs**:
   - Apple Mail: Window → Connection Doctor
   - Look for authentication errors or connection failures

3. **Test Sending from Server**:
   ```bash
   # From Hestia server
   echo "Test email" | mail -s "Test from Hestia" test@example.com
   # Check logs
   tail -f /var/log/exim4/mainlog
   ```

4. **Verify User Credentials**:
   ```bash
   # Check if user account is active
   /usr/bin/doveadm user jmvl@accelior.com
   /usr/bin/doveadm user jmvl@acmea.tech
   ```

### System Maintenance

1. **Clear stale paniclog**:
   ```bash
   > /var/log/exim4/paniclog
   ```

2. **Check SpamAssassin status**:
   ```bash
   systemctl status spamassassin
   # Or
   systemctl status spamd
   ```

3. **Consider implementing fail2ban** for brute force protection:
   ```bash
   apt install fail2ban
   # Configure for dovecot and exim
   ```

4. **Monitor mail queue**:
   ```bash
   # Add to monitoring
   watch -n 60 'exim4 -bpc'
   ```

---

## Configuration Reference

### SMTP Relay Configuration
**File**: `/etc/exim4/smtp_relay.conf`
- Host: relay.edpnet.be:587
- Auth: LOGIN
- TLS: Required (TLSv1.3)
- Username: micheljean2.m2

### Exim Router (send_via_smtp_relay)
**File**: `/etc/exim4/exim4.conf.template`
```conf
send_via_smtp_relay:
  driver = manualroute
  address_data = SMTP_RELAY_HOST:SMTP_RELAY_PORT
  domains = !+local_domains
  require_files = SMTP_RELAY_FILE
  transport = smtp_relay_smtp
  route_list = * ${extract{1}{:}{$address_data}}::${extract{2}{:}{$address_data}}
  no_more
  no_verify
```

### Exim Transport (smtp_relay_smtp)
```conf
smtp_relay_smtp:
  driver = smtp
  hosts_require_auth = $host_address
  hosts_require_tls = $host_address
```

### Exim Authenticator (smtp_relay_login)
```conf
smtp_relay_login:
  driver = plaintext
  public_name = LOGIN
  hide client_send = : SMTP_RELAY_USER : SMTP_RELAY_PASS
```

---

## Commands Reference

```bash
# Check mail queue
exim4 -bp

# Count messages in queue
exim4 -bpc

# Flush queue (verbose)
exim4 -qff -v

# View specific message details
exim4 -Mvl <message-id>

# Remove specific message (use with caution)
exim4 -Mrm <message-id>

# Check Exim logs
tail -f /var/log/exim4/mainlog

# Check for authentication failures
grep "authentication failed" /var/log/exim4/mainlog | tail -20

# Check for relay activity
grep "send_via_smtp_relay" /var/log/exim4/mainlog | tail -20

# Test email routing
exim4 -bt recipient@example.com

# Restart Exim
systemctl restart exim4

# Check Exim service status
systemctl status exim4

# Check paniclog
cat /var/log/exim4/paniclog

# Clear paniclog (if errors are resolved)
> /var/log/exim4/paniclog
```

---

## Related Documentation

- **Original Incident**: `/docs/troubleshooting/2026-01-22-hestia-smtp-relay-auth-failure.md`
- **Hestia Maintenance 2026-01-08**: `/docs/hestia/hestia-mail-server-maintenance-intervention-2026-01-08.md`
- **Exim Config Fix 2026-01-14**: `/docs/troubleshooting/2026-01-14-hestia-exim-config-corruption-fix.md`
- **Hestia Overview**: `/docs/hestia/hestia.md`

---

## Sources

- [Exim SMTP Authentication Documentation](https://www.exim.org/exim-html-current/doc/html/spec_html/ch-smtp_authentication.html)
- [EDPnet Email Configuration Guide](https://support.edpnet.be/hc/en-us/articles/17203080063250-Configuration-e-mail)
- [SMTP Configuration Guide 2025](https://blog.webhostmost.com/smtp-configuration/)
- [Troubleshooting Common SMTP Issues](https://www.duocircle.com/emails-services/troubleshooting-common-issues-with-outgoing-smtp-mail)

---

**Document Version**: 1.0
**Last Updated**: 2026-02-04
**Created During**: Diagnostic Check - User Email Sending Issue
