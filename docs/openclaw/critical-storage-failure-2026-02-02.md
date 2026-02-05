# OpenClaw Container Critical Storage Failure

**Date**: 2026-02-02
**Container**: openclaw (VMID: 101)
**IP Address**: 192.168.1.151
**Severity**: CRITICAL - Container Offline
**Status**: INVESTIGATION

---

## Executive Summary

The OpenClaw container (nestor) experienced a critical storage failure that prevents it from starting. The container is currently offline due to:

1. **LVM Thin Pool Exhaustion**: The `pve/data` thin pool is at 100% capacity (130.27GB used)
2. **Filesystem Corruption**: The ext4 filesystem on `/dev/mapper/pve-vm--101--disk--0` has severe corruption
3. **I/O Errors**: The container cannot mount its root filesystem due to I/O errors

---

## Timeline of Events

### Initial Discovery (2026-02-02)

**User Request**: Investigate OpenClaw Telegram authorization configuration issue

**Investigation Attempts**:
1. Attempted SSH connection to nestor (192.168.1.151) - Connection reset by peer
2. Tried `ssh_nestor.sh` script - I/O errors on all commands
3. Checked container status from Proxmox - Container marked as "running"
4. Attempted `pct exec` commands - All failed with "Input/output error"

**Error Pattern**:
```
lxc-attach: 101: ../src/lxc/attach.c: lxc_attach_run_command: 1841 Input/output error
```

### Container Restart Attempts

**First Restart**:
```bash
ssh root@pve2 "pct shutdown 101 && sleep 3 && pct start 101"
```
- Container appeared to restart
- Still had I/O errors on all commands

**Second Restart**:
```bash
ssh root@pve2 "lxc-stop 101 && sleep 5 && lxc-start 101"
```
- Failed to start
- Error: "No such file or directory - Failed to receive the container state"

**Debug Start**:
```bash
lxc-start 101 -F -l DEBUG -o /tmp/lxc-101-start.log
```
- **Key Error**: `mount: /var/lib/lxc/.pve-staged-mounts/rootfs: can't read superblock on /dev/mapper/pve-vm--101--disk--0`
- **Exit Code**: 32 (mount failure)

---

## Root Cause Analysis

### Storage Status

**LVM Volume Status**:
```
LV               VG  Attr       LSize    Pool Origin Data%  Meta%
vm-101-disk-0    pve Vwi-a-tz-- 32.00g   data        42.19
data             pve twi-aotzD- <130.27g              100.00 4.45
```

**Critical Findings**:
- **Thin Pool**: `pve/data` is at **100% capacity** (130.27GB used)
- **Container Volume**: `vm-101-disk-0` is 42.19% full (normally fine)
- **Problem**: Thin pool exhaustion prevents new metadata allocations

### Filesystem Check Results

**Command**: `fsck -y /dev/pve/vm-101-disk-0`

**Findings**:
```
/dev/mapper/pve-vm--101--disk--0: recovering journal
fsck.ext4: Input/output error while recovering journal
/dev/mapper/pve-vm--101--disk--0 contains a file system with errors, check forced.
```

**Corruption Detected**:
- Journal corruption requiring recovery
- 100+ orphaned inodes found and fixed
- Free blocks count wrong in multiple block groups
- Free inodes count wrong
- **Final Error**: "Error writing file system info: Input/output error"

**Status**: FILESYSTEM WAS MODIFIED (but incomplete due to I/O error)

---

## Current Status

### Container Status
```
NAME STATE   AUTOSTART GROUPS IPV4 IPV6 UNPRIVILEGED
101  STOPPED 0         -      -    -    false
```

### Network Status
- Container IP: 192.168.1.151 - **UNREACHABLE**
- SSH connection: **FAILED**
- All services: **DOWN**

### Telegram Bot Status
- **Bot Name**: @Nestor4JM_bot
- **Expected Response**: "You are not authorized to use this command"
- **Actual Response**: **NO RESPONSE** (container offline)

---

## Impact Assessment

### Services Affected
1. **OpenClaw Gateway** - CRITICAL (completely offline)
2. **Telegram Integration** - CRITICAL (no response)
3. **WhatsApp Integration** - CRITICAL (no response)
4. **All Other Channels** - CRITICAL (no response)

### Data at Risk
- **OpenClaw Configuration**: `/root/.openclaw/openclaw.json`
- **Agent State**: `/root/.openclaw/agents/`
- **Session History**: `/root/.openclaw/sessions/`
- **Workspace Data**: `/root/.openclaw/workspace/`

---

## Resolution Steps (In Progress)

### Immediate Actions Required

1. **Emergency Recovery**:
   ```bash
   # Check if we can mount the filesystem manually
   ssh root@pve2 "mkdir -p /mnt/vm-101-recovery"
   ssh root@pve2 "mount /dev/pve/vm-101-disk-0 /mnt/vm-101-recovery"
   ```

2. **Backup Critical Data**:
   ```bash
   # Backup OpenClaw configuration
   ssh root@pve2 "tar czf /tmp/openclaw-config-backup-$(date +%Y%m%d).tar.gz /mnt/vm-101-recovery/root/.openclaw/"
   ```

3. **Expand Thin Pool** (if possible):
   ```bash
   # Check available space in VG
   ssh root@pve2 "vgs pve"
   # Output shows 16GB free

   # Expand thin pool (requires 16GB available)
   ssh root@pve2 "lvextend -L +16G pve/data"
   ```

4. **Alternative: Migrate to New Container** (if recovery fails):
   - Create new LXC container with larger disk allocation
   - Restore OpenClaw from backup
   - Update DNS/service configurations

---

## Telegram Authorization Investigation (BLOCKED)

### Original Request
User reported: "You are not authorized to use this command" response from Telegram bot

### Investigation Status
**BLOCKED** - Cannot access container to investigate

### What We Know from Documentation

**From `/docs/openclaw/README.md`**:
- **Telegram Bot**: @Nestor4JM_bot
- **Bot Token**: `8354121845:AAF2brbzFO3n_e0EVvkOUoxWIUliUPUUnN8`
- **DM Policy**: `pairing`
- **Group Policy**: `allowlist`

**Authorization Configuration** (from `/docs/openclaw/telegram-streaming-investigation-2026-01-30.md`):
```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "pairing",
      "botToken": "8354121845:AAF2brbzFO3n_e0EVvkOUoxWIUliUPUUnN8",
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
1. **DM Policy: `pairing`**
   - Users must be "paired" with the bot
   - Requires approval via `npx openclaw pairing approve telegram <CODE>`
   - Unauthorized DMs get rejection message

2. **Group Policy: `allowlist`**
   - Only allowed groups can interact
   - All groups (`*`) require mention: `@Nestor4JM_bot <command>`

### Hypothesis (Cannot Verify Without Access)
The "not authorized" error likely means:
- User sent a command from an unpaired Telegram account
- User sent a command in a group not on the allowlist
- User forgot to mention the bot in a group chat

**Cannot confirm** without accessing container logs and configuration.

---

## Next Steps

### Priority 1: Restore Container Access
1. Attempt manual filesystem mount
2. Backup critical configuration data
3. Expand thin pool or migrate to new container
4. Restore OpenClaw service

### Priority 2: Investigate Telegram Authorization
Once container is accessible:
1. Check OpenClaw logs for authorization failures
2. Review paired users list: `npx openclaw pairing list telegram`
3. Check Telegram channel configuration
4. Verify user's Telegram account is paired

### Priority 3: Prevent Recurrence
1. Monitor thin pool usage (alert at 90%)
2. Implement regular filesystem checks
3. Add container health monitoring to Uptime Kuma
4. Create disaster recovery backup procedure

---

## Technical Details

### Container Configuration
```
arch: amd64
cores: 6
memory: 8096
net0: name=eth0,bridge=vmbr0,gw=192.168.1.3,hwaddr=BC:24:11:51:B6:BD,ip=192.168.1.151/24,type=veth
onboot: 1
rootfs: local-lvm:vm-101-disk-0,size=32G
swap: 2048
```

### Storage Configuration
- **Storage**: local-lvm (LVM thin pool)
- **Volume**: vm-101-disk-0 (32GB)
- **Filesystem**: ext4
- **Thin Pool**: pve/data (130.27GB, 100% full)
- **VG Free Space**: 16GB

### Proxmox Host
- **Hostname**: pve2
- **IP Address**: 192.168.1.10
- **Version**: Proxmox VE (LXC container management)

---

## References

- [OpenClaw README](/docs/openclaw/README.md)
- [SSH Authentication Setup](/docs/openclaw/ssh-authentication-setup-2026-01-31.md)
- [Telegram Streaming Investigation](/docs/openclaw/telegram-streaming-investigation-2026-01-30.md)
- [Telegram Verbose Configuration](/docs/openclaw/telegram-verbose-streaming-configuration-2026-01-30.md)

---

**Report Created**: 2026-02-02T13:36:18Z
**Created By**: Claude Code
**Status**: CRITICAL - Container Offline - Recovery in Progress
**Next Update**: After container recovery attempt
