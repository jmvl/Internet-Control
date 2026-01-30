# Hestia Exim Catch-All Not Working - Fixed 2026-01-15

**Date**: 2026-01-15
**Severity**: Critical - Mail Delivery Failure
**Affected Service**: HestiaCP Mail Server (mail.vega-messenger.com / 192.168.1.30)
**Root Cause**: Corrupted Exim configuration template from previous intervention

## Problem Description

**Symptom**: Catch-all email for `acmea.tech` domain was not being delivered to `jmvl@acmea.tech`.

**User Report**: "check why albert@acmea.tech wasn't delivered"

**Observed Behavior**:
- Email to `albert@acmea.tech` was **REJECTED** by Exim
- Log entry: `2026-01-15 07:21:14 rejected RCPT <albert@acmea.tech>`
- Exim routing test: `exim4 -bt albert@acmea.tech` returned "undeliverable: Unrouteable address"

## Root Cause Analysis

### Primary Issue: Corrupted Exim Template

The `/etc/exim4/exim4.conf.template` file was replaced with a **simplified 1.3KB template** (only macro definitions) instead of the full **~19KB Hestia configuration**. This happened during the 2026-01-08 maintenance intervention to address "tainted filename" errors in Exim 4.95+.

**What Was Broken**:
- The simplified template only contained macro definitions (SMTP_RELAY_FILE, OUTGOING_IP, DKIM_FILE)
- Missing: All Hestia-specific domain routers and transports
- Missing: `domainlist local_domains = dsearch;/etc/exim4/domains/ : lsearch;/etc/exim4/domains/domains.list`
- Result: Exim could not discover Hestia mail domains, making all local mail undeliverable

### Secondary Issue: REJECT Mode Enabled

The `acmea.tech` domain had `REJECT='yes'` in Hestia configuration, which caused Exim to reject unknown recipients before the catch-all alias could take effect.

## Investigation Timeline

1. **Verified catch-all configuration in Hestia**:
   - `/usr/local/hestia/data/users/jmvl/mail.conf`: `CATCHALL='jmvl@acmea.tech'` ✓
   - `/etc/exim4/domains/acmea.tech/aliases`: `*@acmea.tech:jmvl@acmea.tech` ✓

2. **Disabled REJECT mode**:
   ```bash
   /usr/local/hestia/bin/v-delete-mail-domain-reject jmvl acmea.tech
   ```

3. **Tested Exim routing** - Still failed:
   ```bash
   exim4 -bt albert@acmea.tech
   # Output: undeliverable: Unrouteable address
   ```

4. **Identified template corruption**:
   ```bash
   wc -l /etc/exim4/exim4.conf.template
   # Output: Only ~50 lines (should be ~513 lines)

   head -50 /etc/exim4/exim4.conf.template
   # Output: "Exim4 Configuration Template - Simplified Macros"
   ```

5. **Found valid backup**:
   ```bash
   ls -la /etc/exim4/exim4.conf.template.backup-*
   # Found: exim4.conf.template.backup-2026-01-15T02-00-04Z (513 lines, 20KB)
   ```

## Resolution

### Step 1: Backup Broken Configuration
```bash
cp /etc/exim4/exim4.conf.template \
   /etc/exim4/exim4.conf.template.broken-20260115-120632
```

### Step 2: Restore Working Template
```bash
cp /etc/exim4/exim4.conf.template.backup-2026-01-15T02-00-04Z \
   /etc/exim4/exim4.conf.template
```

### Step 3: Regenerate Exim Configuration
```bash
update-exim4.conf
```

### Step 4: Reload Exim Service
```bash
systemctl reload exim4
```

### Step 5: Verify Catch-All Routing
```bash
exim4 -bt albert@acmea.tech
# Output: jmvl@acmea.tech (SUCCESS)

exim4 -bt test@acmea.tech
# Output: jmvl@acmea.tech (SUCCESS)
```

### Step 6: Create Reference Backup
```bash
cp /etc/exim4/exim4.conf.template \
   /etc/exim4/exim4.conf.template.REFERENCE-WORKING-2026-01-15.md5sum-44839e06
```

**Reference Configuration**:
- File: `exim4.conf.template.REFERENCE-WORKING-2026-01-15.md5sum-44839e06`
- MD5: `44839e06e93d36e49e98658f1bc900b5`
- Size: 20KB
- Lines: 513
- Key Feature: `domainlist local_domains = dsearch;/etc/exim4/domains/ : lsearch;/etc/exim4/domains/domains.list`

## Ansible Safeguards

**Status**: The Ansible task that deploys the broken template is **ALREADY DISABLED**

**File**: `ansible/roles/hestia/tasks/exim_config.yml`

**Lines 36-49** (commented out):
```yaml
# DISABLED: This task replaces the full Hestia Exim configuration with a minimal template
# that only contains macro definitions, breaking ALL local mail delivery.
# Hestia manages its own Exim configuration - do not override it with Ansible.
# See: /docs/troubleshooting/2026-01-14-hestia-exim-config-corruption-fix.md
# - name: Deploy Exim4 template with simplified macros (prevents tainted filename errors)
#   template:
#     src: exim4.conf.template.j2
#     dest: /etc/exim4/exim4.conf.template
#     owner: root
#     group: root
#     mode: '0644'
#     backup: yes
#   notify: Update Exim4 configuration
#   tags: config,exim,template
```

**Verification Checks** (Lines 56-68):
- Template size check: `failed_when: exim_template.stat.size < 10000`
- Generated config check: `failed_when: exim_config_lines.stdout | int < 500`

## Infrastructure Database Updates

**Service ID**: 54 (Exim4 SMTP)
**Updated**: Description field with full intervention details and reference configuration information

## Lessons Learned

1. **Never replace Hestia's Exim configuration** with a simplified template. The domain discovery mechanism (`dsearch;/etc/exim4/domains/`) is critical for mail delivery.

2. **Security fixes must preserve functionality**. The "tainted filename" fix (2026-01-08) correctly identified a security issue but broke all mail routing by removing the domain routers.

3. **REJECT mode conflicts with catch-all**. When `REJECT='yes'` is enabled, Exim rejects unknown recipients before the catch-all alias is processed.

4. **Verification is critical**. The Ansible verification checks (size < 10000 bytes, lines < 500) should have caught this issue earlier.

## Configuration Reference

### Working Exim Template Headers
```exim
######################################################################
#                                                                    #
#          Exim configuration file for Hestia Control Panel          #
#                                                                    #
######################################################################

SPAMASSASSIN = yes
SPAM_SCORE = 50
SPAM_REJECT_SCORE = 100
CLAMD = yes

domainlist local_domains = dsearch;/etc/exim4/domains/ : lsearch;/etc/exim4/domains/domains.list
domainlist relay_to_domains = dsearch;/etc/exim4/domains/
hostlist relay_from_hosts = 127.0.0.1 : 192.168.1.0/24
```

### Hestia Domain Configuration (acmea.tech)
```
DOMAIN='acmea.tech'
ANTIVIRUS='yes'
ANTISPAM='yes'
REJECT='no'        # Must be disabled for catch-all
DKIM='yes'
WEBMAIL='roundcube'
SSL='yes'
CATCHALL='jmvl@acmea.tech'
ACCOUNTS='1'
```

## Related Documentation

- `/docs/hestia/hestia-mail-server-maintenance-intervention-2026-01-08.md` - Original intervention that introduced the broken template
- `/docs/troubleshooting/2026-01-14-hestia-exim-config-corruption-fix.md` - Previous fix attempt
- `ansible/roles/hestia/tasks/exim_config.yml` - Ansible configuration management

## Verification Commands

```bash
# Test catch-all routing for any address
exim4 -bt albert@acmea.tech
exim4 -bt random@acmea.tech

# Verify Exim configuration
exim4 -bV

# Check domain list
cat /etc/exim4/domains/domains.list

# Verify Hestia mail domain configuration
/usr/local/hestia/bin/v-list-mail-domain jmvl acmea.tech
```

## Status

✅ **RESOLVED** - Catch-all email for `acmea.tech` is now working correctly. All mail to `*@acmea.tech` is delivered to `jmvl@acmea.tech`.

**Last Verified**: 2026-01-15 11:09 UTC
**Verified By**: jmvl
**Reference Config**: `exim4.conf.template.REFERENCE-WORKING-2026-01-15.md5sum-44839e06`
