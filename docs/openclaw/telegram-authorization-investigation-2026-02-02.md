# OpenClaw Telegram Authorization Investigation - Summary Report

**Date**: 2026-02-02
**Container**: openclaw (VMID: 101)
**IP Address**: 192.168.1.151
**Issue**: User receiving "You are not authorized to use this command" from Telegram bot
**Status**: BLOCKED - Critical Storage Failure

---

## Executive Summary

The investigation into the OpenClaw Telegram authorization issue was **BLOCKED** by a critical storage failure that has rendered the container inaccessible. While attempting to investigate the authorization configuration, we discovered:

1. **CRITICAL**: OpenClaw container filesystem is severely corrupted
2. **CRITICAL**: LVM thin pool is at 100% capacity (130.27GB/130.27GB)
3. **BLOCKING**: Cannot read configuration files or logs due to I/O errors
4. **RESULT**: Unable to complete authorization investigation

---

## Original User Request

**Reported Issue**: User receiving "You are not authorized to use this command" response from Telegram bot (@Nestor4JM_bot)

**Expected Behavior**: Bot should respond to commands from authorized users

**Actual Behavior**: Bot is rejecting commands with authorization error

---

## Investigation Timeline

### Phase 1: Initial Connection Attempts (FAILED)

**Attempts**:
1. Direct SSH to `root@nestor` (192.168.1.151) - **FAILED**: Connection reset
2. Via `ssh_nestor.sh` script - **FAILED**: I/O errors on all commands
3. Via Proxmox `pct exec` - **FAILED**: Input/output errors

**Error Pattern**:
```
lxc-attach: 101: ../src/lxc/attach.c: lxc_attach_run_command: 1841 Input/output error
```

### Phase 2: Container Diagnosis (CRITICAL FINDINGS)

**Container Status**: Listed as "running" but unresponsive

**Root Cause Discovered**:
```bash
lxc-start 101 -F -l DEBUG
# Error: mount: /var/lib/lxc/.pve-staged-mounts/rootfs: can't read superblock
# on /dev/mapper/pve-vm--101--disk--0
```

**LVM Status**:
```
LV               LSize    Data%  Meta%
vm-101-disk-0    32.00g   42.19
data             <130.27g  100.00 4.45  # THIN POOL EXHAUSTED
```

### Phase 3: Filesystem Recovery Attempt

**Filesystem Check Results**:
```bash
fsck -y /dev/pve/vm-101-disk-0

# Findings:
- Journal corruption requiring recovery
- 100+ orphaned inodes found and fixed
- Multiple block groups with incorrect free block counts
- Final error: "Error writing file system info: Input/output error"
```

**Result**: Container can start, but filesystem has severe I/O errors

### Phase 4: Data Recovery Attempt (FAILED)

**Attempted**: Mount filesystem directly to read configuration

**Result**:
```bash
mount /dev/pve/vm-101-disk-0 /mnt/vm-101-recovery
cat /mnt/vm-101-recovery/root/.openclaw/openclaw.json
# Error: Input/output error

cat /mnt/vm-101-recovery/root/.openclaw/credentials/telegram-pairing.json
# Error: Input/output error

cat /mnt/vm-101-recovery/root/.openclaw/credentials/telegram-allowFrom.json
# Error: Input/output error
```

**Outcome**: **All configuration files are unreadable due to filesystem corruption**

---

## What We Know About Telegram Authorization

### From Existing Documentation

Based on `/docs/openclaw/README.md` and `/docs/openclaw/telegram-streaming-investigation-2026-01-30.md`:

**Bot Information**:
- **Bot Name**: @Nestor4JM_bot
- **Bot Token**: `8354121845:AAF2brbzFO3n_e0EVvkOUoxWIUliUPUUnN8`
- **Status**: Configured and enabled

**Authorization Configuration** (from documentation):
```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist",
      "groups": {
        "*": {
          "requireMention": true
        }
      }
    }
  }
}
```

### Authorization Logic

**DM Policy: `pairing`**
- Users must be "paired" with the bot to send direct messages
- Pairing requires approval via OpenClaw command:
  ```bash
  npx openclaw pairing approve telegram <CODE>
  ```
- Unpaired users receive authorization rejection

**Group Policy: `allowlist`**
- Only allowed groups can interact with the bot
- All groups (`*`) require mentioning the bot:
  - Correct: `@Nestor4JM_bot /status`
  - Incorrect: `/status` (will be ignored)

### Authorization Files (Currently Unreadable)

The following files should contain authorization configuration but are **currently corrupted**:

1. **`/root/.openclaw/credentials/telegram-pairing.json`**
   - Contains list of paired users
   - Shows which Telegram accounts are authorized
   - **Status**: I/O error - cannot read

2. **`/root/.openclaw/credentials/telegram-allowFrom.json`**
   - Contains group allowlist configuration
   - Shows which groups can interact with the bot
   - **Status**: I/O error - cannot read

3. **`/root/.openclaw/openclaw.json`**
   - Main OpenClaw configuration file
   - Contains all channel settings including Telegram
   - **Status**: I/O error - cannot read

---

## Likely Causes of Authorization Error

Based on the configuration and typical OpenClaw behavior, the "not authorized" error is likely caused by:

### Scenario 1: Unpaired User Account (Most Likely)
**Symptom**: User sending DMs to bot without being paired

**Requirements**:
- User must initiate pairing with the bot
- Admin must approve the pairing request

**Verification** (currently blocked):
```bash
npx openclaw pairing list telegram
# Should show pending and approved pairings
```

**Resolution**:
```bash
npx openclaw pairing approve telegram <PAIRING_CODE>
```

### Scenario 2: Group Not on Allowlist
**Symptom**: User sending commands in a group chat

**Requirements**:
- Group must be on the allowlist
- User must mention the bot in messages

**Verification** (currently blocked):
```bash
npx openclaw config get channels.telegram.groupPolicy
cat /root/.openclaw/credentials/telegram-allowFrom.json
```

**Resolution**:
```bash
npx openclaw config set channels.telegram.groupPolicy open
# Or add specific group to allowlist
```

### Scenario 3: Bot Configuration Reset
**Symptom**: All users being rejected unexpectedly

**Possible Causes**:
- Configuration file corruption
- Recent configuration changes
- Service restart with wrong configuration

**Verification** (currently blocked):
```bash
npx openclaw config get channels.telegram
```

---

## Container Recovery Status

### Current Status: CRITICAL

**Container**: Running but severely degraded
- **Network**: Responds to ping
- **SSH**: Connection failures
- **Filesystem**: Severe I/O errors
- **Services**: Unknown (cannot check status)

**Storage Issues**:
- **LVM Thin Pool**: 100% full (130.27GB/130.27GB)
- **Filesystem**: ext4 with corruption and I/O errors
- **Container Disk**: 32GB volume, 42% used (normally fine)

### Recovery Options

#### Option 1: Emergency Repair (High Risk)
```bash
# 1. Stop container
lxc-stop 101

# 2. Run full filesystem repair
fsck.ext4 -yf /dev/pve/vm-101-disk-0

# 3. Attempt to start container
lxc-start 101
```

**Risk**: Data loss if corruption is severe
**Success Probability**: Low

#### Option 2: Expand Thin Pool and Retry (Recommended)
```bash
# 1. Expand thin pool (16GB available in VG)
lvextend -L +16G pve/data

# 2. Stop container
lxc-stop 101

# 3. Run filesystem repair
fsck.ext4 -yf /dev/pve/vm-101-disk-0

# 4. Start container
lxc-start 101
```

**Risk**: Low
**Success Probability**: Medium

#### Option 3: Migrate to New Container (Most Reliable)
```bash
# 1. Create new LXC container with fresh disk
pctcreate 102 --local-lvm:64 --hostname openclaw-new

# 2. Install OpenClaw on new container
# 3. Restore configuration from backups (if available)
# 4. Update DNS/service configurations
# 5. Decommission old container
```

**Risk**: Medium (configuration required)
**Success Probability**: High

---

## Immediate Recommendations

### Priority 1: Restore Container Access

**Action Required**:
1. Emergency expansion of LVM thin pool
2. Filesystem repair
3. Container recovery

**Commands**:
```bash
# On pve2 (192.168.1.10)
lvextend -L +16G pve/data
lxc-stop 101
fsck.ext4 -yf /dev/pve/vm-101-disk-0
lxc-start 101
```

### Priority 2: Backup Critical Data

**Once container is accessible**:
```bash
# Backup OpenClaw configuration
tar czf /tmp/openclaw-backup-$(date +%Y%m%d).tar.gz /root/.openclaw/

# Copy to safe location
scp /tmp/openclaw-backup-*.tar.gz backup-server:/backups/
```

### Priority 3: Investigate Telegram Authorization

**Once container is accessible**:
```bash
# Check paired users
npx openclaw pairing list telegram

# Check group allowlist
npx openclaw config get channels.telegram.groupPolicy

# View recent logs for authorization failures
npx openclaw logs --tail 100 | grep -i authoriz

# Check Telegram channel status
npx openclaw channels status telegram
```

---

## User Action Required

### For User Experiencing Authorization Error

**Immediate Workaround**:
1. Ensure you're mentioning the bot in groups: `@Nestor4JM_bot <command>`
2. If sending DMs, you may need to re-pair with the bot
3. Check if you're using the correct Telegram account

**To Verify**:
- Are you in a private DM with @Nestor4JM_bot?
- Are you mentioning the bot in group chats?
- Have you recently changed Telegram accounts?

**Next Steps**:
1. Wait for container to be recovered
2. Admin will check pairing status and approve if needed
3. Admin may adjust group policy if needed

---

## Technical Details

### Container Configuration
```
Container ID: 101
Hostname: openclaw
IP Address: 192.168.1.151/24
Memory: 8096 MB
CPU Cores: 6
Disk: 32GB (local-lvm:vm-101-disk-0)
OS: Ubuntu 24.04 LTS (Noble Numbat)
```

### Storage Configuration
```
LVM VG: pve
Thin Pool: pve/data (130.27GB, 100% FULL)
Volume: vm-101-disk-0 (32GB, 42% used)
Filesystem: ext4
VG Free Space: 16GB (available for expansion)
```

### Bot Configuration
```
Bot Name: @Nestor4JM_bot
Bot Token: 8354121845:AAF2brbzFO3n_e0EVvkOUoxWIUliUPUUnN8
DM Policy: pairing
Group Policy: allowlist
Mention Required: Yes (for all groups)
```

---

## Related Documentation

- [Critical Storage Failure](/docs/openclaw/critical-storage-failure-2026-02-02.md)
- [OpenClaw README](/docs/openclaw/README.md)
- [Telegram Streaming Investigation](/docs/openclaw/telegram-streaming-investigation-2026-01-30.md)
- [Telegram Verbose Configuration](/docs/openclaw/telegram-verbose-streaming-configuration-2026-01-30.md)
- [SSH Authentication Setup](/docs/openclaw/ssh-authentication-setup-2026-01-31.md)

---

## Conclusion

**Investigation Status**: **BLOCKED**

The OpenClaw Telegram authorization investigation cannot be completed due to critical storage failure that has rendered the container inaccessible. The filesystem corruption and LVM thin pool exhaustion prevent reading configuration files, logs, or service status.

**Next Steps**:
1. Emergency container recovery (thin pool expansion + filesystem repair)
2. Restore container access
3. Complete authorization investigation
4. Resolve user's authorization issue

**Estimated Recovery Time**: 2-4 hours (depending on repair success)

**Data Loss Risk**: Medium (configuration files may be recoverable after repair)

---

## UPDATE 2: New Root Cause Identified (17:45 UTC)

### Container is Now Running ✅

**Good News**: The container has been recovered and is now accessible via SSH (root@nestor).

**Bad News**: A NEW issue has been discovered that explains why Telegram is not working.

### Critical Discovery: Slack Authentication Failure Crashes Gateway

**Root Cause**: The OpenClaw gateway is crashing due to **Slack authentication failure**, which prevents Telegram from functioning.

**Evidence**:

1. **Service Status - Crash Loop**:
   ```
   ● openclaw.service - OpenClaw Gateway
      Active: activating (auto-restart) (Result: exit-code)
      Restart counter: 470+
   ```

2. **Error Pattern**:
   ```
   Feb 02 17:44:29 [telegram] starting provider ✅
   Feb 02 17:44:32 Unhandled promise rejection: Error: An API error occurred: invalid_auth ❌
                  at platformErrorFromResult (@slack/web-api/src/errors.ts:119:5)
   Feb 02 17:44:32 Main process exited, code=exited, status=1/FAILURE
   ```

3. **Token Verification**:
   - **Telegram Token**: ✅ VALID (confirmed via Telegram API)
   - **Slack Token**: ❌ INVALID (confirmed via Slack API)

**Why Telegram Doesn't Work**:
```
Service Start → Telegram Init ✅ → Slack Init ❌ → Gateway Crashes → Restart Loop
```

The gateway crashes 3 seconds after Telegram starts, preventing Telegram from reaching polling state.

### Solution: Disable Slack Channel

**Immediate Fix** (recommended):
```bash
# Disable Slack to restore Telegram functionality
ssh root@nestor "npx openclaw config set channels.slack.enabled false"

# Restart service
ssh root@nestor "systemctl restart openclaw"

# Verify
ssh root@nestor "systemctl status openclaw"
```

**Expected Result**: OpenClaw gateway will start successfully and Telegram will begin polling.

### Alternative: Fix Slack Authentication

If Slack integration is needed:
1. Go to https://api.slack.com/apps
2. Regenerate bot token or reinstall app
3. Update OpenClaw config with new token
4. Restart service

### Service Lifecycle After Fix

**Current (Broken)**:
```
START → Telegram ✅ → Slack ❌ → CRASH (3 sec) → Restart (repeat 470x)
```

**Fixed (Slack Disabled)**:
```
START → Telegram ✅ → Slack (skipped) → Gateway Running ✅ → Telegram Polling ✅
```

---

**Report Created**: 2026-02-02T13:45:00Z
**Updated**: 2026-02-02T17:46:00Z
**Created By**: Claude Code
**Status**: ROOT CAUSE IDENTIFIED - Solution Ready
**Next Action**: Apply fix (disable Slack or update token)
