# PVE2 Boot Device Correction

**Date**: 2026-02-05
**Host**: pve2 (192.168.1.10)
**Issue**: Incorrect BOOT_DEVICE configuration in comprehensive backup script

## Problem

The `BOOT_DEVICE` variable in `/root/disaster-recovery/proxmox-comprehensive-backup.sh` was incorrectly set to `/dev/sda`, which is actually the 3.6TB data drive mounted at `/mnt/ssd_4tb`, not the system boot disk.

This would cause the boot disk imaging portion of the backup to fail or backup the wrong disk.

## Root Cause Analysis

From `lsblk -f` output:

```
NAME         FSTYPE      MOUNTPOINTS
sda          btrfs                 49a55624-4077-401e-a09a-40ce4d692af8      2.6T    29% /mnt/ssd_4tb
sdb          btrfs       usb-backup 12e87124-aae6-42ee-972a-079126a42cd1       40G    65% /mnt/usb-backup
nvme0n1
├─nvme0n1p1
├─nvme0n1p2  vfat        FAT32               648B-CD1D                              1010.3M     1% /boot/efi
└─nvme0n1p3  LVM2_member LVM2 001            68nk76-dyPo-Gxbt-qs34-ZEgw-SQK6-21c3Y4
  ├─pve-swap                 swap        1                   d17e5a1e-2669-4c79-a320-20a0af408cfc                  [SWAP]
  ├─pve-root                 ext4        1.0                 90cb21ca-824c-4e92-9b43-e4497dcdaac9     15.4G    71% /
```

**Device identification**:
- `/dev/sda` = 3.6TB data drive (BTRFS, mounted at `/mnt/ssd_4tb`)
- `/dev/sdb` = 119GB USB backup drive (BTRFS, mounted at `/mnt/usb-backup`)
- `/dev/nvme0n1` = 223.6GB NVMe SSD (system boot disk with `/boot/efi` and LVM volumes)

The actual boot device is **`/dev/nvme0n1`** (NVMe SSD), not `/dev/sda`.

## Fix Applied

### 1. Backup Original Script

```bash
cp /root/disaster-recovery/proxmox-comprehensive-backup.sh \
   /root/disaster-recovery/proxmox-comprehensive-backup.sh.backup-20260205-100454
```

**Backup file created**: `/root/disaster-recovery/proxmox-comprehensive-backup.sh.backup-20260205-100454`

### 2. Update BOOT_DEVICE Variable

**Old value**:
```bash
BOOT_DEVICE="/dev/sda"
```

**New value**:
```bash
BOOT_DEVICE="/dev/nvme0n1"
```

**Command executed**:
```bash
sed -i 's|^BOOT_DEVICE="/dev/sda"|BOOT_DEVICE="/dev/nvme0n1"|' \
   /root/disaster-recovery/proxmox-comprehensive-boot.sh
```

### 3. Verification

```bash
# Verify the change
grep -n 'BOOT_DEVICE=' /root/disaster-recovery/proxmox-comprehensive-backup.sh
# Output: 21:BOOT_DEVICE="/dev/nvme0n1"

# Verify the device is correct
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT /dev/nvme0n1
```

**Device confirmed**: `/dev/nvme0n1` contains:
- `/boot/efi` partition (nvme0n1p2)
- LVM volumes for root filesystem, swap, and VM storage (nvme0n1p3)

## Impact

The fix ensures that:
1. **Boot disk imaging** will now correctly backup the NVMe SSD (`/dev/nvme0n1`)
2. **Bare metal restore** will have the correct boot disk image
3. **Backup integrity** is maintained for disaster recovery

## Files Modified

- `/root/disaster-recovery/proxmox-comprehensive-backup.sh` - Updated BOOT_DEVICE variable
- `/root/disaster-recovery/proxmox-comprehensive-backup.sh.backup-20260205-100454` - Backup of original script

## Next Steps

1. Test the comprehensive backup script to ensure it works correctly with the new BOOT_DEVICE
2. Verify the backup image is created properly
3. Update infrastructure database with this configuration change

## References

- Infrastructure database: `/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db`
- Host: pve2 (192.168.1.10)
- Related documentation: `/docs/pve2/`
