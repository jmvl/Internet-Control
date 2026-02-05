# pve2 LVM Thin Storage Analysis

**Date**: 2026-02-03
**Host**: pve2 (Proxmox VE 7.x)
**Analyst**: Claude Code
**Status**: CRITICAL - Historical out-of-data-space events detected

## Executive Summary

pve2's LVM thin pool (`pve/data`) is currently **HEALTHY** but has a **CRITICAL HISTORY** of repeated out-of-data-space events. The thin pool auto-extend feature is **DISABLED** (threshold set to 100%), which caused previous failures. Immediate configuration changes are recommended to prevent recurrence.

### Key Findings

- **Current Thin Pool Usage**: 10.23% (14.9 GB used of 146.27 GB)
- **Metadata Usage**: 1.61% (healthy)
- **Auto-Extend**: DISABLED (threshold=100%)
- **Critical Events**: Multiple out-of-data-space events in dmesg
- **dmeventd**: Running and monitoring active

---

## LVM Storage Architecture

### Physical Layout

```
Physical Volume: /dev/nvme0n1p3 (222.57 GB)
       ↓
Volume Group: pve (222.57 GB)
       ↓
Logical Volumes:
├── root (65.64 GB) - Proxmox OS (75% used)
├── swap (8.00 GB) - System swap
└── data (146.27 GB) - Thin pool for VM/CT disks
       ↓
Thin Volumes (Virtual):
├── vm-122-disk-0 (32 GB) - npm-vm [STOPPED]
├── vm-133-disk-1 (16 GB) - opnsense [RUNNING] 49.13% used
├── vm-501-disk-0 (95 GB) - gitlab.accelior.com [STOPPED] 4.62% used
└── vm-505-disk-0 (32 GB) - gitlab-bulk [STOPPED] 8.49% used
```

### Storage Allocation

| Volume | Size | Used % | Status | VM/CT Name |
|--------|------|--------|--------|------------|
| **Thin Pool** | 146.27 GB | 10.23% | Healthy | N/A |
| vm-122-disk-0 | 32 GB | 0.00% | Stopped | npm-vm |
| vm-133-disk-1 | 16 GB | 49.13% | Running | OPNsense |
| vm-501-disk-0 | 95 GB | 4.62% | Stopped | GitLab |
| vm-505-disk-0 | 32 GB | 8.49% | Stopped | gitlab-bulk |

---

## Current Health Status

### Thin Pool Metrics

```bash
LV: data
Size: 146.27 GB
Data Percent: 10.23% (15 GB actual usage)
Metadata Percent: 1.61%
Attributes: twi-aotz--
  t: Thin
  w: Writeable
  i: Inherited
  a: Allocation
  o: Open
  t: Thin pool
  z: Zero
  -: No monitoring (BUT dmeventd is running)
Monitor: Active (monitored)
```

### Critical Kernel Events (Historical)

The kernel logs show **REPEATED** out-of-data-space events:

```
[device-mapper: thin: 252:4: switching pool to out-of-data-space (queue IO) mode]
[device-mapper: thin: 252:4: switching pool to write mode]
[device-mapper: thin: 252:4: switching pool to out-of-data-space (error IO) mode]
[device-mapper: thin: 252:4: growing the data device from 2134272 to 2396416 blocks]
```

**Impact**: When thin pool hits 100%, VMs/CTs experience **I/O queue stalls** or **I/O errors**, causing:
- Application crashes
- Database corruption risk
- VM/CT freezes
- Potential data loss

---

## VM and Container Storage Allocation

### LXC Containers (Using Directory Storage)

Most containers use **directory storage** (`ssd-4tb`), NOT thin volumes:

| CT ID | Name | Storage Type | Disk Size | Internal Usage |
|-------|------|--------------|-----------|----------------|
| 100 | ConfluenceDocker20220712 | ssd-4tb | 60 GB | Stopped |
| 101 | openclaw | ssd-4tb | 32 GB | Stopped |
| 102 | jira.accelior.com | ssd-4tb | 70 GB | Stopped |
| 103 | files.accelior.com | ssd-4tb | 310 GB | 85% (244 GB used) |
| 109 | wanderwish | ssd-4tb | 20 GB | 35% (6.5 GB used) |
| 110 | ansible-mgmt | ssd-4tb | 15 GB | 14% (1.9 GB used) |
| 111 | docker-debian | ssd-4tb | 110 GB | 29% (1.1 TB used) |
| 120 | dev-ai | ssd-4tb | 150 GB | 9% (12 GB used) |
| 121 | npm-pve2 | ssd-4tb | 4 GB | 78% (2.9 GB used) |
| 130 | mail.vega-messenger.com | ssd-4tb | 160 GB | 37% (55 GB used) |
| 501 | gitlab.accelior.com | ssd-4tb | 95 GB | Stopped |
| 502 | CT502 | ssd-4tb | 100 GB | Stopped |
| **505** | **gitlab-bulk** | **local-lvm (THIN)** | **32 GB** | **Stopped** |

### VMs Using Thin Volumes

| VM ID | Name | Thin Volume | Size | Usage | Status |
|-------|------|-------------|------|-------|--------|
| 122 | npm-vm | vm-122-disk-0 | 32 GB | 0% | Stopped |
| 133 | opnsense | vm-133-disk-1 | 16 GB | 49.13% | Running |

**Key Insight**: Only **4 thin volumes** exist, and only **OPNsense is currently running**.

---

## Critical Configuration Issues

### Issue 1: Auto-Extend Disabled

**Current Configuration** (`/etc/lvm/lvm.conf`):
```conf
thin_pool_autoextend_threshold = 100  # DISABLED
thin_pool_autoextend_percent = 20
```

**Problem**: With threshold at 100%, the thin pool will **NOT auto-extend** until it's completely full, causing I/O failures.

**Impact**: VMs/CTs will experience out-of-data-space errors before any extension occurs.

### Issue 2: Volume Group Exhaustion

The volume group `pve` has only **4 MB free**:
```bash
VG  #PV #LV #SN Attr   VSize    VFree
pve   1   8   0 wz--n- <222.57g 4.00m
```

**Problem**: Even if auto-extend is enabled, there's **no free space** in the VG to extend into.

**Impact**: The thin pool CANNOT grow beyond 146.27 GB without adding physical storage.

---

## Root Cause Analysis

### Why Previous Out-of-Space Events Occurred

1. **Auto-extend disabled**: Thin pool hit 100% usage before extension
2. **Manual extension required**: Someone had to manually extend the pool
3. **No VG free space**: Pool can only grow if VG has space (currently only 4 MB)

### Sequence of Events

```
1. Thin pool usage reaches 100%
2. VM/CT I/O queued or errors out
3. Kernel: "switching pool to out-of-data-space mode"
4. Admin notices and extends pool manually
5. Pool returns to write mode
6. Cycle repeats
```

---

## Recommendations

### IMMEDIATE (Critical Priority)

1. **Enable Thin Pool Auto-Extend**:
   ```bash
   # Edit LVM configuration
   vi /etc/lvm/lvm.conf

   # Change:
   thin_pool_autoextend_threshold = 100
   # To:
   thin_pool_autoextend_threshold = 70

   # Restart dmeventd
   systemctl restart dmeventd.service  # OR kill -HUP $(pidof dmeventd)
   ```

   **Rationale**: Pool will auto-extend at 70% usage, preventing out-of-space events.

2. **Add Storage to Volume Group** (CRITICAL):
   ```bash
   # Option A: Add new physical disk
   pvcreate /dev/sdX
   vgextend pve /dev/sdX

   # Option B: Expand existing NVMe partition (if space exists)
   # Use gparted or fdisk to expand partition
   # Then:
   pvresize /dev/nvme0n1p3
   ```

   **Rationale**: Auto-extend cannot work without VG free space.

### HIGH Priority

3. **Monitor Thin Pool Usage**:
   ```bash
   # Add to monitoring system (Uptime Kuma)
   # Check command:
   lvs -o lv_name,data_percent pve/data

   # Alert threshold: 60%
   ```

4. **Review Thin Volume Sizes**:
   - **vm-501-disk-0** (GitLab): 95 GB allocated, only 4.62% used (~4.4 GB)
   - Consider reducing to 20 GB if GitLab data allows
   - **vm-505-disk-0** (gitlab-bulk): 32 GB allocated, 8.49% used (~2.7 GB)
   - Consider reducing to 10-16 GB

5. **Migrate Low-Usage Thin Volumes to Directory Storage**:
   ```bash
   # Example: Move vm-501-disk-0 to ssd-4tb
   qm disk import 501 /mnt/ssd_4tb/vm-501-disk-0.raw local-lvm
   ```

   **Rationale**: Directory storage doesn't risk thin pool exhaustion.

### MEDIUM Priority

6. **Implement Thin Pool Alerts**:
   - Configure Proxmox to send email alerts at 60% thin pool usage
   - Add Uptime Kuma monitor for thin pool data percent

7. **Document Recovery Procedure**:
   - Create SOP for thin pool exhaustion recovery
   - Document emergency expansion steps

8. **Consider Long-Term Storage Strategy**:
   - Evaluate ZFS local-zfs storage for better space management
   - Consider migrating VMs from thin to directory storage

---

## Thin Pool Exhaustion Risks

### Risk Level: **HIGH** (when using thin volumes)

| Scenario | Risk | Impact |
|----------|------|--------|
| Auto-extend disabled | **CRITICAL** | I/O failures when pool hits 100% |
| No VG free space | **HIGH** | Cannot extend without adding storage |
| Running VMs on thin | **MEDIUM** | OPNsense (firewall) at risk if pool fills |
| No monitoring/alerts | **HIGH** | No warning before exhaustion |

### Current Risk Assessment

**IMMEDIATE RISK**: **LOW**
- Only OPNsense running on thin storage
- Thin pool at 10.23% usage
- 131 GB free space

**FUTURE RISK**: **HIGH**
- If GitLab (vm-501) starts and fills to 95 GB
- If multiple VMs start simultaneously
- Auto-extend still disabled
- No VG free space for expansion

---

## Action Plan

### Phase 1: Immediate Hardening (Today)

- [ ] Enable thin pool auto-extend at 70% threshold
- [ ] Restart dmeventd to apply configuration
- [ ] Test auto-extend with dummy data
- [ ] Document current thin volume usage

### Phase 2: Storage Expansion (This Week)

- [ ] Assess available physical storage options
- [ ] Add physical volume to `pve` VG
- [ ] Extend thin pool to 200+ GB
- [ ] Verify auto-extend works

### Phase 3: Monitoring Setup (This Week)

- [ ] Add Uptime Kuma monitor for thin pool usage
- [ ] Configure Proxmox email alerts
- [ ] Create runbook for thin pool exhaustion
- [ ] Test alerting system

### Phase 4: Long-Term Optimization (Next Month)

- [ ] Audit all thin volumes for right-sizing
- [ ] Migrate suitable VMs to directory storage
- [ ] Evaluate ZFS implementation
- [ ] Document storage strategy

---

## Commands for Maintenance

### Check Thin Pool Health
```bash
# Quick status
lvs pve/data

# Detailed info
lvs -o lv_name,lv_size,data_percent,metadata_percent,lv_attr pve/data

# Check for kernel errors
dmesg | grep -i "thin.*out-of-data"
```

### Manually Extend Thin Pool (Emergency)
```bash
# Extend thin pool (requires VG free space)
lvextend -L +20G pve/data

# Or extend to specific size
lvextend -L 200G pve/data
```

### Check dmeventd Monitoring
```bash
# Verify dmeventd is running
ps aux | grep dmeventd

# Check monitored LVs
dmsetup status
```

### Add Storage to VG
```bash
# Initialize new physical volume
pvcreate /dev/sdX

# Add to volume group
vgextend pve /dev/sdX

# Verify
vgs pve
```

---

## Appendix: Storage Configuration

### Proxmox Storage Configuration

```conf
dir: usb-backup
    path /mnt/usb-backup
    content backup,vztmpl

dir: local
    path /var/lib/vz
    content vztmpl,iso

dir: ssd-4tb
    path /mnt/ssd_4tb
    content rootdir,iso,images,vztmpl,backup,snippets

lvmthin: local-lvm
    thinpool data
    vgname pve
    content rootdir,images
```

### LVM Configuration (Relevant)

```conf
# /etc/lvm/lvm.conf
activation/thin_pool_autoextend_threshold = 100  # CHANGE TO 70
activation/thin_pool_autoextend_percent = 20
```

---

## Conclusion

pve2's LVM thin storage is **currently healthy** but has **critical configuration issues** that led to past out-of-space events. The auto-extend feature is disabled, and the volume group has no free space for expansion. Immediate action is required to prevent future I/O failures.

**Priority**: Enable auto-extend and add VG free space **before** starting any additional VMs on thin storage.

**Status**: Requires immediate attention to prevent recurrence of past failures.
