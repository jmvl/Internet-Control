# Hestia ClamAV Swap Issue Fix & Ubuntu 22.04 Upgrade

**Date:** 2026-01-02
**Server:** mail.vega-messenger.com (192.168.1.30)
**LXC Container:** 130 on pve2

## Issue Summary

Hestia mail server experiencing high load (8.58) with swap fully utilized (511MB/512MB) despite having 3GB+ free RAM after 34 days uptime.

Additionally, Ubuntu was upgraded from 20.04 to 22.04 LTS to get ClamAV 1.4.3 (replacing EOL 0.103.12), which required fixing Exim 4.95 tainted filename errors.

## Symptoms

- Load average: 8.58, 6.32, 6.85
- Swap: 511MB/512MB used (99%)
- RAM: 3.1GB free
- CPU: 96% idle
- Email delivery working but system sluggish

## Root Cause Analysis

### Primary Cause: ClamAV Memory Behavior

1. **ClamAV uses ~1.4GB RAM** to load virus signature databases
2. **freshclam was updating 24x/day** (every hour)
3. During database reload, ClamAV temporarily needs **double memory** (~2.8GB)
4. Kernel swaps out inactive pages to make room
5. Once swapped, pages stay in swap (Linux doesn't proactively swap back)
6. Over 34 days, swap accumulated and never cleared

### Secondary Issue: ClamAV Blocked by CDN

- ClamAV version 0.103.12 is EOL (End of Life)
- ClamAV CDN actively blocks outdated clients with HTTP 403
- Rate limiting triggered due to 24x/day update attempts
- Ubuntu 20.04 repos don't have newer ClamAV versions

## Resolution Steps

### 1. Rebooted LXC Container
```bash
# Cleared swap and reset memory state
ssh root@192.168.1.30 'reboot'
```

### 2. Reduced freshclam Frequency
```bash
# Changed from 24 to 4 checks per day
sed -i 's/^Checks 24/Checks 4/' /etc/clamav/freshclam.conf
```

### 3. Installed cvdupdate (Bypasses CDN Rate Limiting)
```bash
apt install -y python3-pip
pip3 install cvdupdate

# Update databases using cvdupdate
cvd config set --dbdir /var/lib/clamav
cvd update
```

### 4. Disabled freshclam, Enabled cvdupdate Cron
```bash
# Stop and disable freshclam
systemctl stop clamav-freshclam
systemctl disable clamav-freshclam

# Create cvdupdate cron (every 6 hours)
echo "0 */6 * * * root /usr/local/bin/cvd update >/dev/null 2>&1" > /etc/cron.d/cvdupdate
```

### 5. Cleaned Duplicate Database Files
```bash
# Remove old .cld files (duplicates of .cvd)
rm -f /var/lib/clamav/*.cld

# Fix ownership
chown clamav:clamav /var/lib/clamav/*.cvd

# Restart ClamAV daemon
systemctl restart clamav-daemon
```

## Verification

```bash
# Check ClamAV version and database
clamscan --version
# Output: ClamAV 0.103.12/27868/Fri Jan  2 07:26:29 2026

# Test virus detection (EICAR test)
curl -s https://www.eicar.org/download/eicar.com.txt -o /tmp/eicar.com
clamscan /tmp/eicar.com
# Output: /tmp/eicar.com: Eicar-Test-Signature FOUND

# Verify memory usage reduced
ps aux | grep clamd
# ~993 MB (down from 1.36 GB)
```

## Post-Fix Status

| Metric | Before | After |
|--------|--------|-------|
| Load Average | 8.58 | 3.48 |
| Swap Used | 511MB | 0MB |
| ClamAV Memory | 1.36GB | 993MB |
| DB Version | 27778 | 27868 |
| Update Method | freshclam (blocked) | cvdupdate |
| Update Frequency | 24x/day | 4x/day |

## Prevention

1. **cvdupdate cron** runs every 6 hours instead of hourly freshclam
2. **Reduced memory churn** from fewer database reloads
3. **No CDN rate limiting** - cvdupdate uses different download method
4. **Consider monthly reboot** to prevent long-term swap accumulation:
   ```bash
   echo "0 4 1 * * root /sbin/reboot" >> /etc/cron.d/monthly-reboot
   ```

## Future Considerations

- Ubuntu 20.04 is stuck at ClamAV 0.103.12 (EOL)
- Upgrade to Ubuntu 22.04+ for native ClamAV 1.0.x support
- Alternatively, increase swap to 2GB on LXC container:
  ```bash
  # On pve2
  pct set 130 -swap 2048
  ```

---

## Part 2: Ubuntu 22.04 Upgrade

### Pre-Upgrade Backups

```bash
# 1. Hestia user backups (7 users, ~12GB)
for user in admin vega accelior dinero jmvl artbit vidsnap; do
  /usr/local/hestia/bin/v-backup-user $user
done

# 2. Proxmox vzdump backup (60.48GB compressed)
ssh root@192.168.1.10 'vzdump 130 --compress zstd --storage ssd-4tb --mode snapshot'
# Output: /mnt/ssd_4tb/dump/vzdump-lxc-130-2026_01_02-17_51_55.tar.zst
```

### Upgrade Process

```bash
# Update Hestia repo to Ubuntu 22.04 (jammy)
sed -i 's/focal/jammy/g' /etc/apt/sources.list.d/hestia.list

# Run upgrade
DEBIAN_FRONTEND=noninteractive do-release-upgrade -f DistUpgradeViewNonInteractive
```

### Post-Upgrade: Exim 4.95 Tainted Filename Fix

Ubuntu 22.04 ships Exim 4.95 which has stricter "taint checking" that broke Hestia's mail delivery.

**Error:**
```
Tainted '/home/jmvl/mail/acmea.tech/jmvl' (file or directory name for local_delivery transport) not permitted
```

**Root Cause:** Exim 4.94+ treats user-supplied values (`$domain`, `$local_part`) as "tainted" and won't use them in file paths directly.

**Fix Applied to `/etc/exim4/exim4.conf.template`:**

1. **Domain paths** - Use `dsearch` to untaint domain:
   ```
   # Changed:
   /etc/exim4/domains/$domain/
   # To:
   /etc/exim4/domains/${lookup{$domain}dsearch{/etc/exim4/domains/}}/
   ```

2. **Mail directory** - Use lookup results instead of raw variables:
   ```
   # Changed:
   /mail/$domain/$local_part
   # To:
   /mail/${lookup{$domain}dsearch{/etc/exim4/domains/}}/${extract{1}{:}{${lookup{$local_part}lsearch{.../passwd}}}}
   ```

**Apply fix:**
```bash
# Backup original
cp /etc/exim4/exim4.conf.template /etc/exim4/exim4.conf.template.bak

# Apply dsearch for all domain paths
sed -i 's|/etc/exim4/domains/$domain/|/etc/exim4/domains/${lookup{$domain}dsearch{/etc/exim4/domains/}}/|g' /etc/exim4/exim4.conf.template

# Apply extracted values for mail paths (lines 446, 463, 465)
# Use dsearch for domain and extract field 1 from passwd for local_part
sed -i 's|/mail/$domain/$local_part"|/mail/${lookup{$domain}dsearch{/etc/exim4/domains/}}/${extract{1}{:}{${lookup{$local_part}lsearch{/etc/exim4/domains/${lookup{$domain}dsearch{/etc/exim4/domains/}}/passwd}}}}"|g' /etc/exim4/exim4.conf.template

# Regenerate and restart
update-exim4.conf && systemctl restart exim4
```

### Final Status

| Component | Before Upgrade | After Upgrade |
|-----------|---------------|---------------|
| Ubuntu | 20.04.6 LTS | 22.04.5 LTS |
| ClamAV | 0.103.12 (EOL) | 1.4.3 |
| Exim | 4.93 | 4.95 (with taint fix) |
| Kernel | 5.15.x-pve | 6.8.12-15-pve |
| Load Average | 8.58 | 1.16 |
| Swap Used | 511MB | 0MB |
| Email | Working | Working |

---

## Part 3: Exim Taint Fix Bug - Misdirected Emails (2026-01-03)

### Issue Discovery

User reported not receiving emails on jmvl@accelior.com and jmvl@acmea.tech despite Exim logs showing successful delivery ("Completed").

### Root Cause

The initial taint fix from Part 2 had a critical bug. The `extract{1}` was extracting the **password hash** instead of the **username**.

**Why this happened:**
- `lsearch` returns the **value** after the key, not including the key itself
- The passwd file format: `jmvl:{BLF-CRYPT}$2y$05$...:accelior:mail::/home/accelior:0:...`
- `lsearch{jmvl}` returns: `{BLF-CRYPT}$2y$05$...:accelior:mail::/home/accelior:0:...`
- `extract{1}{:}` on that returns: `{BLF-CRYPT}$2y$05$...` (the password hash!)

**Result:** Emails were delivered to directories named with password hashes:
```
/home/accelior/mail/accelior.com/{BLF-CRYPT}$2y$05$LZ6cs0AfvOUYcy2rYa6v4.zKmYTPsV1LpjbjisChaxaYFYGZRzppi/
```
Instead of:
```
/home/accelior/mail/accelior.com/jmvl/
```

### Corrected Fix

Use `dsearch` on the mail directory to look up and untaint `$local_part`:

**Before (broken):**
```
directory = ".../mail/${lookup{$domain}dsearch{...}}/${extract{1}{:}{${lookup{$local_part}lsearch{.../passwd}}}}"
```

**After (working):**
```
directory = ".../mail/${lookup{$domain}dsearch{...}}/${lookup{$local_part}dsearch{${extract{5}{:}{${lookup{$local_part}lsearch{.../passwd}}}}/mail/${lookup{$domain}dsearch{...}}/}}"
```

**Apply fix:**
```bash
# Backup
cp /etc/exim4/exim4.conf.template /etc/exim4/exim4.conf.template.bak.20260103

# Replace extract{1} with dsearch for local_part
# The dsearch validates the local_part exists in the mail directory and returns it untainted
sed -i 's|\${extract{1}{:}{\${lookup{\$local_part}lsearch{/etc/exim4/domains/\${lookup{\$domain}dsearch{/etc/exim4/domains/}}/passwd}}}}|\${lookup{\$local_part}dsearch{\${extract{5}{:}{\${lookup{\$local_part}lsearch{/etc/exim4/domains/\${lookup{\$domain}dsearch{/etc/exim4/domains/}}/passwd}}}}/mail/\${lookup{\$domain}dsearch{/etc/exim4/domains/}}/}}|g' /etc/exim4/exim4.conf.template

# Regenerate and restart
update-exim4.conf && systemctl restart exim4
```

### Email Recovery

Misdirected emails were recovered by moving them to correct mailboxes:

```bash
# For accelior.com (15 emails)
mv "/home/accelior/mail/accelior.com/{BLF-CRYPT}\$2y\$05\$..."/new/* \
   /home/accelior/mail/accelior.com/jmvl/new/
chown accelior:mail /home/accelior/mail/accelior.com/jmvl/new/*
rm -rf "/home/accelior/mail/accelior.com/{BLF-CRYPT}\$2y\$05\$..."
doveadm force-resync -u jmvl@accelior.com "*"

# For acmea.tech (15 emails)
mv "/home/jmvl/mail/acmea.tech/{BLF-CRYPT}\$2y\$05\$..."/*/new/* \
   /home/jmvl/mail/acmea.tech/jmvl/new/
chown jmvl:mail /home/jmvl/mail/acmea.tech/jmvl/new/*
rm -rf "/home/jmvl/mail/acmea.tech/{BLF-CRYPT}\$2y\$05\$..."
doveadm force-resync -u jmvl@acmea.tech "*"
```

### Recovered Emails

| Mailbox | Emails Recovered | Examples |
|---------|------------------|----------|
| jmvl@accelior.com | 15 | Figma login (3x), KAYAK alerts, Binance, Revolut, Bitget, Wio statement |
| jmvl@acmea.tech | 15 | Test emails from debugging, Health Check, Ubuntu upgrade notifications |

### Verification

```bash
# Test email delivery
echo "Test" | mail -s "Test $(date)" jmvl@accelior.com

# Verify file lands in correct directory
ls -lt /home/accelior/mail/accelior.com/jmvl/new/
# or after IMAP fetch:
ls -ltc /home/accelior/mail/accelior.com/jmvl/cur/ | head -5
```

### Key Lessons

1. **`lsearch` returns value only** - The key is NOT included in the return value
2. **`dsearch` validates and untaints** - Use dsearch on the mail directory to safely untaint `$local_part`
3. **Test with file verification** - Don't just check Exim logs; verify files actually appear in correct directories
4. **Exim taint debugging**: Use `exim -be '${lookup{...}}'` to test expansions interactively

---

## Related Files

- `/etc/clamav/freshclam.conf` - freshclam configuration (disabled)
- `/etc/cron.d/cvdupdate` - cvdupdate cron job
- `/etc/cron.d/clamav-weekly-restart` - Weekly ClamAV restart cron
- `/etc/cron.d/monthly-reboot` - Monthly container reboot cron
- `/etc/systemd/system/clamav-daemon.service.d/limits.conf` - ClamAV memory limit (1.5GB)
- `/var/lib/clamav/` - ClamAV database directory
- `/var/log/clamav/freshclam.log` - freshclam logs (historical)
- `/etc/exim4/exim4.conf.template` - Exim config template (modified for taint fix)
- `/etc/exim4/exim4.conf.template.bak.20260102` - Original exim template backup
- `/etc/exim4/exim4.conf.template.bak.20260103` - Post-upgrade backup (before Part 3 fix)
- `/mnt/ssd_4tb/dump/vzdump-lxc-130-2026_01_02-17_51_55.tar.zst` - Pre-upgrade backup
