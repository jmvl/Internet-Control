# Hestia SMTP Relay Authentication Failure - 2026-01-22

**Date**: 2026-01-22
**System**: Hestia Mail Server (192.168.1.30)
**Severity**: **CRITICAL** - Outgoing emails stuck for 3+ days
**Status**: ⚠️ **REQUIRES CREDENTIALS FROM EDP.NET**
**Author**: Infrastructure Team (Claude Code)

---

## Executive Summary

**Critical Issue**: Outgoing emails from jmvl@accelior.com and jmvl@acmea.tech are stuck in queue due to SMTP relay authentication failure at relay.edpnet.be:587.

**Impact**:
- **11 emails stuck** in queue (some for 3+ days)
- All outgoing email from jmvl@accelior.com and jmvl@acmea.tech affected
- Authentication failing with "535 Error: authentication failed"

**Root Cause**: The SMTP relay credentials are either incorrect, expired, or the EDP.net account requires verification.

---

## Investigation Timeline

### Initial Discovery
- User reported emails not being sent from jmvl@accelior.com and jmvl@acmea.tech
- Found 11 messages stuck in Exim queue, some for 3+ days

### Errors Found in Logs

**Primary Error**:
```
smtp_relay_login authenticator failed H=relay.edpnet.be [212.71.0.16] 535 Error: authentication failed
== recipient@example.com R=send_via_smtp_relay T=smtp_relay_smtp defer (-42): authentication required but authentication attempt(s) failed
```

**Secondary Issue - Tainted Filename** (FIXED):
```
Tainted filename for search: '/etc/exim4/domains/acmea.tech/smtp_relay.conf'
```
This was a separate Exim 4.95+ security issue that was resolved during troubleshooting.

---

## Credentials Attempted

All of the following credentials were rejected by relay.edpnet.be:

| Attempt | Username | Password | Result |
|---------|----------|----------|--------|
| 1 | michelje.1970.d1@EDPNET | WrnAxV | ❌ 535 Error |
| 2 | michel.jean1 | u9BWFN3NwzX!9WT! | ❌ 535 Error |
| 3 | michel.jean1@edpnet.be | u9BWFN3NwzX!9WT! | ❌ 535 Error |
| 4 | micheljean2.m2 | *Gq%BdxS4JuN | ❌ 535 Error |
| 5 | micheljean2.m2 | Jklqsd!970 | ❌ 535 Error |

---

## Stuck Emails

| From | To | Age | Size | Status |
|------|-----|-----|------|--------|
| jmvl@accelior.com | lupapuppy1765@gmail.com | 3 days | 9.2M | ❌ Deferred |
| jmvl@accelior.com | jl.deville@delacroix.law | 3 days | 15K | ❌ Deferred |
| jmvl@acmea.tech | hayezgilles@gmail.com | 57 hours | 19M | ❌ Deferred |
| jmvl@acmea.tech | jason@zooctouch.cn | 57 hours | 6.5K | ❌ Deferred |
| jmvl@acmea.tech | service-fr@xgimi.com | 30 hours | 56K | ❌ Deferred |
| jmvl@acmea.tech | hayezgilles@gmail.com | 10 hours | 654K | ❌ Deferred |
| jmvl@acmea.tech | hayezgilles@gmail.com | 9 hours | 651K | ❌ Deferred |
| jmvl@acmea.tech | thierry@sultan.ae | 7 hours | 42K | ❌ Deferred |
| jmvl@acmea.tech | thierry@sultan.ae | 7 hours | 41K | ❌ Deferred |
| (bounce) | apoyo@accelior.com | 29 hours | 3.0K | ❌ Frozen |
| (bounce) | arts@accelior.com | 26 hours | 3.8K | ❌ Frozen |

---

## Configuration Changes Made

### 1. Fixed Exim "Tainted Filename" Bug

**File**: `/etc/exim4/exim4.conf.template`

**Lines 81-87 (Before)**:
```conf
OUTGOING_IP = /etc/exim4/domains/$sender_address_domain/ip
SMTP_RELAY_FILE = ${if exists{/etc/exim4/domains/${sender_address_domain}/smtp_relay.conf}{/etc/exim4/domains/$sender_address_domain/smtp_relay.conf}{/etc/exim4/smtp_relay.conf}}
```

**Lines 81-83 (After)**:
```conf
OUTGOING_IP =
SMTP_RELAY_FILE = /etc/exim4/smtp_relay.conf
```

**Rationale**: Exim 4.95+ blocks file lookups with user input in paths (tainted filename security feature). Using a single global config file avoids this issue.

### 2. Current SMTP Relay Configuration

**File**: `/etc/exim4/smtp_relay.conf`

```conf
host: relay.edpnet.be
port: 587
user: micheljean2.m2
pass: Jklqsd!970
```

**Note**: These credentials are being rejected by the relay service.

---

## Immediate Solutions

### Option 1: Obtain Correct EDP.net Credentials (Recommended)

1. Log into EDP.net customer portal at https://www.edpnet.be/en/my-EDPnet
2. Navigate to Email Services → SMTP Relay
3. Verify:
   - SMTP relay service is active
   - Correct username and password
   - IP whitelist (if required) - mail server IP: 77.109.112.226
4. Update `/etc/exim4/smtp_relay.conf` with correct credentials
5. Run: `systemctl restart exim4 && exim -qff`

### Option 2: Temporarily Disable SMTP Relay (Workaround)

This will deliver emails directly without relay, which may affect spam scores:

```bash
# Disable relay by commenting out require_files
sed -i 's/require_files = SMTP_RELAY_FILE/# require_files = SMTP_RELAY_FILE/' /etc/exim4/exim4.conf.template

# Regenerate config and restart
update-exim4.conf
systemctl restart exim4

# Flush queue
exim -qff
```

**Consequences**:
- ✅ Emails will be delivered immediately
- ⚠️ May have lower spam score due to missing relay headers
- ⚠️ Some recipient servers may reject emails from dynamic IP

### Option 3: Use Alternative SMTP Relay

Configure a different SMTP relay service:
- **Gmail SMTP** (smtp.gmail.com:587) - Free tier available
- **SendGrid** (smtp.sendgrid.net:587) - Transactional email service
- **Amazon SES** (email-smtp.eu-west-1.amazonaws.com:587) - Pay-per-use

---

## Testing Credentials

To test SMTP relay credentials manually:

```bash
# Method 1: Using swaks (install with: apt install swaks)
swaks --to test@example.com \
       --from jmvl@accelior.com \
       --server relay.edpnet.be \
       --port 587 \
       --auth \
       --auth-user micheljean2.m2 \
       --auth-password 'Jklqsd!970' \
       --tls

# Method 2: Using openssl and base64
echo -ne '\0micheljean2.m2\0Jklqsd!970' | base64
# Then use the output in: AUTH PLAIN <base64_string>
```

---

## Exim Router Configuration

**File**: `/etc/exim4/exim4.conf.template`

**send_via_smtp_relay Router**:
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

**smtp_relay_smtp Transport**:
```conf
smtp_relay_smtp:
  driver = smtp
  hosts_require_auth = $host_address
  hosts_require_tls = $host_address
```

**smtp_relay_login Authenticator**:
```conf
smtp_relay_login:
  driver = plaintext
  public_name = LOGIN
  hide client_send = : SMTP_RELAY_USER : SMTP_RELAY_PASS
```

---

## Related Documentation

- **Hestia Mail Maintenance 2026-01-08**: `/docs/hestia/hestia-mail-server-maintenance-intervention-2026-01-08.md`
- **Exim Config Fix 2026-01-14**: `/docs/troubleshooting/2026-01-14-hestia-exim-config-corruption-fix.md`
- **Hestia Overview**: `/docs/hestia/hestia.md`

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

# Test email routing
exim4 -bt recipient@example.com

# Restart Exim
systemctl restart exim4

# Regenerate Exim configuration
update-exim4.conf
```

---

## Next Steps

1. **Immediate**: Obtain correct EDP.net SMTP relay credentials
2. **Short-term**: Consider implementing credential rotation process
3. **Long-term**: Evaluate alternative SMTP relay services for redundancy

---

**Document Version**: 1.0
**Last Updated**: 2026-01-22
**Created During**: Incident Response
