# Hestia SMTP Relay Credential Update

**Date**: 2026-02-04
**Server**: Hestia Mail Server (192.168.1.30)
**Task**: Update EDPnet SMTP relay password
**Status**: Ready for execution

---

## Executive Summary

This document describes the update of EDPnet SMTP relay credentials on the Hestia mail server. The password for the `micheljean2.m2` account has been changed and needs to be updated in the Exim4 SMTP relay configuration.

**New Credentials:**
- **Host**: relay.edpnet.be
- **Port**: 587
- **Username**: micheljean2.m2 (unchanged)
- **Password**: `*Gq%BdxS4JuN` (NEW)

---

## Affected Configuration Files

### Primary Configuration
- **File**: `/etc/exim4/smtp_relay.conf`
- **Purpose**: Global SMTP relay configuration used by all domains

### Domain-Specific Configurations (may exist)
- `/etc/exim4/domains/accelior.com/smtp_relay.conf`
- `/etc/exim4/domains/acmea.tech/smtp_relay.conf`
- `/etc/exim4/domains/vega-messenger.com/smtp_relay.conf`

**Note**: According to the 2026-01-22 incident resolution, the Exim configuration was simplified to use only the global config (`/etc/exim4/smtp_relay.conf`) rather than domain-specific configs. However, this script will check for and update any domain-specific configs that exist.

---

## Execution Procedure

### Option 1: Automated Script Execution (Recommended)

1. **Copy the script to Hestia:**
   ```bash
   scp /Users/jm/Codebase/internet-control/docs/hestia/smtp-relay-credential-update-2026-02-04.sh root@192.168.1.30:/root/
   ```

2. **Execute the script:**
   ```bash
   ssh root@192.168.1.30 'bash /root/smtp-relay-credential-update-2026-02-04.sh'
   ```

### Option 2: Manual Execution

1. **Connect to Hestia:**
   ```bash
   ssh root@192.168.1.30
   ```

2. **Backup current config:**
   ```bash
   cp /etc/exim4/smtp_relay.conf /etc/exim4/smtp_relay.conf.backup.$(date +%Y%m%d-%H%M%S)
   ```

3. **Update the password:**
   ```bash
   cat > /etc/exim4/smtp_relay.conf << 'EOF'
   host: relay.edpnet.be
   port: 587
   user: micheljean2.m2
   pass: *Gq%BdxS4JuN
   EOF
   ```

4. **Set correct permissions:**
   ```bash
   chmod 640 /etc/exim4/smtp_relay.conf
   chown root:Debian-exim /etc/exim4/smtp_relay.conf
   ```

5. **Check for domain-specific configs and update if needed:**
   ```bash
   for domain in accelior.com acmea.tech vega-messenger.com; do
       config="/etc/exim4/domains/$domain/smtp_relay.conf"
       if [ -f "$config" ]; then
           echo "Updating $config"
           cp "$config" "$config.backup.$(date +%Y%m%d-%H%M%S)"
           cat > "$config" << 'EOF'
   host: relay.edpnet.be
   port: 587
   user: micheljean2.m2
   pass: *Gq%BdxS4JuN
   EOF
           chmod 640 "$config"
           chown root:Debian-exim "$config"
       fi
   done
   ```

6. **Restart Exim:**
   ```bash
   systemctl restart exim4
   ```

7. **Verify service status:**
   ```bash
   systemctl status exim4
   ```

8. **Check logs:**
   ```bash
   # Recent relay activity
   grep "send_via_smtp_relay" /var/log/exim4/mainlog | tail -5

   # Recent authentication attempts
   grep "smtp_relay_login" /var/log/exim4/mainlog | tail -5
   ```

---

## Verification Steps

### 1. Check Configuration Syntax
```bash
exim4 -bV
```

### 2. Verify File Contents (password hidden)
```bash
sed 's/^pass:.*/pass: [HIDDEN]/' /etc/exim4/smtp_relay.conf
```

### 3. Test Email Sending
```bash
echo "Test email from Hestia" | mail -s "SMTP Relay Test" test@example.com
```

### 4. Monitor Logs
```bash
tail -f /var/log/exim4/mainlog | grep -E "send_via_smtp_relay|smtp_relay_login"
```

---

## Configuration File Format

The `/etc/exim4/smtp_relay.conf` file uses the following format:

```conf
host: relay.edpnet.be
port: 587
user: micheljean2.m2
pass: *Gq%BdxS4JuN
```

**Security Notes:**
- File permissions: `640` (rw-r-----)
- Owner: `root:Debian-exim`
- The password is stored in plain text (required by Exim authenticator)
- The `hide` directive in Exim's authenticator prevents the password from being displayed in logs

---

## Exim Configuration Reference

### Router: send_via_smtp_relay
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

### Transport: smtp_relay_smtp
```conf
smtp_relay_smtp:
  driver = smtp
  hosts_require_auth = $host_address
  hosts_require_tls = $host_address
```

### Authenticator: smtp_relay_login
```conf
smtp_relay_login:
  driver = plaintext
  public_name = LOGIN
  hide client_send = : SMTP_RELAY_USER : SMTP_RELAY_PASS
```

### Macro Definitions
```conf
SMTP_RELAY_FILE = /etc/exim4/smtp_relay.conf
SMTP_RELAY_HOST = ${readfile{SMTP_RELAY_FILE}{$\n}{\n}{:1}}
SMTP_RELAY_PORT = ${readfile{SMTP_RELAY_FILE}{$\n}{\n}{:2}}
SMTP_RELAY_USER = ${readfile{SMTP_RELAY_FILE}{$\n}{\n}{:3}}
SMTP_RELAY_PASS = ${readfile{SMTP_RELAY_FILE}{$\n}{\n}{:4}}
```

---

## Troubleshooting

### Authentication Failure (535 Error)

**Symptom**: Logs show "535 Error: authentication failed"

**Causes**:
1. Incorrect password in config file
2. Password changed at EDPnet but not updated in config
3. Account locked or suspended at EDPnet

**Solution**:
1. Verify password in `/etc/exim4/smtp_relay.conf`
2. Test credentials manually:
   ```bash
   openssl s_client -connect relay.edpnet.be:587 -starttls smtp
   ```
3. Contact EDPnet support if account issues suspected

### Mail Queue Backup

**Check queue:**
```bash
exim4 -bp
```

**Count messages:**
```bash
exim4 -bpc
```

**Flush queue:**
```bash
exim4 -qff -v
```

---

## Previous Incidents

### 2026-01-22: SMTP Relay Authentication Failure
- **Issue**: 11 emails stuck in queue for 3+ days
- **Error**: "535 Error: authentication failed" from relay.edpnet.be
- **Root Cause**: Incorrect/Expired SMTP relay credentials
- **Resolution**: Updated credentials in `/etc/exim4/smtp_relay.conf`
- **Documentation**: `/docs/troubleshooting/2026-01-22-hestia-smtp-relay-auth-failure.md`

### 2026-02-04: Email Sending Status Report
- **Status**: Operational
- **Last successful relay**: 2026-02-04 09:00:13 UTC
- **Current credentials**: micheljean2.m2
- **Documentation**: `/docs/hestia/email-sending-status-report-2026-02-04.md`

---

## Maintenance Notes

### Backup Strategy
- Each update creates a timestamped backup: `.backup.YYYYMMDD-HHMMSS`
- Keep at least 3 recent backups for rollback capability
- Backups inherit same permissions as original file

### Service Restart
- Exim restart is required for credential changes to take effect
- Use `systemctl restart exim4` for clean restart
- Monitor queue after restart to ensure no messages are stuck

### Monitoring
- Check `/var/log/exim4/mainlog` for successful authentication
- Look for `A=smtp_relay_login` indicating successful auth
- Watch for `535 Error: authentication failed` indicating credential issues

---

## Related Documentation

- **Original Incident**: `/docs/troubleshooting/2026-01-22-hestia-smtp-relay-auth-failure.md`
- **Status Report**: `/docs/hestia/email-sending-status-report-2026-02-04.md`
- **Hestia Overview**: `/docs/hestia/hestia.md`
- **Hestia Maintenance**: `/docs/hestia/hestia-mail-server-maintenance-intervention-2026-01-08.md`
- **Exim Config Fix**: `/docs/troubleshooting/2026-01-14-hestia-exim-config-corruption-fix.md`

---

## Sources

- [EDPnet Email Configuration Guide](https://support.edpnet.be/hc/en-us/articles/17203080063250-Configuration-e-mail)
- [Exim SMTP Authentication Documentation](https://www.exim.org/exim-html-current/doc/html/spec_html/ch-smtp_authentication.html)

---

**Document Version**: 1.0
**Created**: 2026-02-04
**Script**: `/docs/hestia/smtp-relay-credential-update-2026-02-04.sh`
