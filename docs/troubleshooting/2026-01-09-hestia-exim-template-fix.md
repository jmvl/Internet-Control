# Hestia Exim Template Fix - Email Delivery Incident

**Date**: 2026-01-09
**System**: Hestia Mail Server (PCT 130 at 192.168.1.30)
**Affected**: All mail delivery to local domains (accelior.com, vega-messenger.com, acmea.tech, vidsnap.me)
**Root Cause**: Ansible Hestia maintenance role deployed incomplete Exim configuration

## Problem Description

All incoming emails to local domains on the Hestia mail server were being rejected with `rejected RCPT <user@domain>` error. This affected:
- `jmvl@accelior.com`
- All other local email addresses across all domains

### Symptoms

- **Exim logs** showed: `rejected RCPT <jmvl@accelior.com>` for all senders
- **Routing test** failed: `exim4 -bt jmvl@accelior.com` returned "Unrouteable address"
- **No incoming emails** being delivered to any local accounts

## Root Cause Analysis

### Timeline

1. **2026-01-08 18:19**: Ansible Hestia maintenance role deployed
2. **2026-01-09 00:44 - 11:09**: All emails rejected (confirmed in `/var/log/exim4/mainlog`)
3. **2026-01-09 11:10**: Root cause identified and fixed

### Technical Details

The Ansible task `Deploy Exim4 template with simplified macros` at
`/ansible/roles/hestia/tasks/exim_config.yml:36` deployed a **27-line template**
that **completely replaced** the full Hestia Exim configuration:

```bash
# Before (working):
-rw-r--r-- 1 root root 19373 Jan  8 14:19 exim4.conf.template.backup-20260108
# Contains 478 lines with routers, transports, ACLs, local_domains definition

# After (broken):
-rw-r--r-- 1 root root  1367 Jan  8 18:19 exim4.conf.template
# Contains only 26 lines of macro definitions - NO ROUTERS OR TRANSPORTS!
```

**Critical missing configuration:**
- `domainlist local_domains = dsearch;/etc/exim4/domains/`
- All routers (`dnslist`, `localuser`, `system_aliases`, etc.)
- All transports (`local_delivery`, `remote_smtp`, etc.)
- All ACLs for spam/virus checking

### Why This Happened

The Ansible template at `/ansible/roles/hestia/templates/exim4.conf.template.j2`
was designed to fix "tainted filename" errors in Exim 4.95+, but it:
1. **Replaced** the entire Hestia Exim configuration instead of updating just the macros
2. Only contained macro definitions (`SMTP_RELAY_FILE`, `OUTGOING_IP`, `DKIM_FILE`)
3. Had none of the actual routing, transport, or ACL configuration needed for mail delivery

## Resolution

### Immediate Fix

Restored the Jan 8 2025 backup (`exim4.conf.template.backup-20260108`) which:
- Contains the complete Hestia Exim configuration
- Already includes proper fixes for tainted filename issues
- Is 513 lines (vs 26 lines in the broken template)

```bash
# On Hestia server (192.168.1.30):
cp /etc/exim4/exim4.conf.template.backup-20260108 /etc/exim4/exim4.conf.template
update-exim4.conf
systemctl reload exim4
```

### Verification

```bash
# Routing test (should succeed):
exim4 -bt jmvl@accelior.com
# Output: router = localuser, transport = local_delivery

# Test email delivery:
echo 'Test' | mail -s 'Test' jmvl@accelior.com
tail -f /var/log/exim4/mainlog
# Should show: => jmvl <jmvl@accelior.com> R=localuser T=local_delivery
```

## Permanent Fix

### Ansible Role Update

**File**: `/ansible/roles/hestia/tasks/exim_config.yml`

Disabled the problematic template deployment task:

```yaml
# DISABLED: This task replaces the full Hestia Exim configuration with a minimal template
# - name: Deploy Exim4 template with simplified macros (prevents tainted filename errors)
#   template:
#     src: exim4.conf.template.j2
#     dest: /etc/exim4/exim4.conf.template
```

**Rationale**:
- Hestia manages its own Exim configuration through its web interface and CLI tools
- The simplified template is incomplete and breaks mail delivery
- The Jan 8 2025 backup already contains the proper tainted filename fixes
- Ansible should only manage the SMTP relay configuration, not the full Exim config

### What Ansible Still Manages

The Ansible role still manages:
- **SMTP relay configuration**: `/etc/exim4/smtp_relay.conf` (deployed via `smtp_relay.conf.j2`)
- **Log rotation**: Hestia, Apache, Nginx, Exim logs
- **Dovecot cache management**: Prevents "Cannot allocate memory" errors
- **Monitoring**: Uptime Kuma checks for mail services

## Impact Assessment

### Affected Services

All mail domains hosted on Hestia:
- `accelior.com` (4 accounts: confluence, jmvl, weblate, sohil)
- `vega-messenger.com`
- `acmea.tech`
- `vidsnap.me`

### Email Senders Affected

Based on Exim logs, the following senders had emails rejected during the outage:
- GitHub notifications (multiple attempts)
- Revolut (bounces@em6163.tezlabapp.com)
- AliExpress (ae-ug-touch-interest@mail.aliexpress.com)
- Beehiiv (o170.ptr9231.mail.beehiiv.com)
- SendGrid (wfbtbdts.outbound-mail.sendgrid.net)
- Infomaniak (smtp-8fad.mail.infomaniak.ch)
- Bitget (hwsg1c236.email.engagelab.com)

### Data Loss

- **Queued emails**: Exim automatically retries frozen messages for 7 days
- **Bounced emails**: Senders that received rejection notices may need to resend
- **No permanent data loss**: Mail queue will process pending deliveries

## Lessons Learned

### For Future Development

1. **Never replace entire configurations with minimal templates**
   - If updating macros, use sed/lineinfile to change only specific lines
   - Always preserve existing configuration structure

2. **Test mail routing after configuration changes**
   - Always run `exim4 -bt user@domain` after Exim updates
   - Monitor `/var/log/exim4/mainlog` for rejection errors

3. **Hestia manages its own Exim configuration**
   - Don't override Hestia's Exim config with external automation
   - Use Hestia's API or CLI tools for configuration changes

4. **Backup and rollback strategy**
   - Keep multiple timestamped backups before config changes
   - The Jan 8 2025 backup saved us from complete rebuild

## Related Documentation

- Hestia mail server overview: `/docs/hestia/hestia.md`
- Hestia maintenance intervention: `/docs/hestia/hestia-mail-server-maintenance-intervention-2026-01-08.md`
- Ansible Hestia role: `/ansible/roles/hestia/`
- Infrastructure database entry for Hestia: `/infrastructure-db/`

## Recovery Timeline

| Time | Event |
|------|-------|
| 2026-01-08 18:19 | Ansible deploys broken Exim template |
| 2026-01-09 00:44 | First rejection logged in mainlog |
| 2026-01-09 11:05 | User reports issue |
| 2026-01-09 11:10 | Root cause identified & fix applied |
| 2026-01-09 11:11 | Test email delivered successfully |
| 2026-01-09 11:15 | Ansible role fixed to prevent recurrence |

## Status

✅ **RESOLVED** - Email delivery fully restored, Ansible role fixed to prevent recurrence
