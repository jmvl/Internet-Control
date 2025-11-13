# BTRFS SSD Best Practices - Official Documentation Summary

**Source**: BTRFS Official Documentation (btrfs.readthedocs.io)
**Compiled**: 2025-10-23
**Related**: pve2-fan-activity-btrfs-io-2025-10-23.md

## Current pve2 Configuration Status ✅

Your current pve2 mount options are **already following best practices**:
```
/dev/sda on /mnt/ssd_4tb type btrfs (rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2)
```

## SSD-Specific Mount Options

### 1. SSD Detection and Optimization

**Auto-detection**: BTRFS automatically detects SSDs via `/sys/block/DEV/queue/rotational`

```bash
ssd, nossd
- Default: Auto-detected
- Status: ✅ Already enabled on pve2
- Benefit: Enables SSD-specific optimizations
```

**Modern SSD Behavior (since kernel 4.14)**:
- Block layout optimizations were **dropped** in kernel 4.14
- These optimizations were for first-gen SSDs
- Modern SSD FTLs (Flash Translation Layers) handle block allocation better
- Old optimizations actually **caused increased fragmentation** on modern SSDs

### 2. SSD Spread Allocation (Optional)

```bash
ssd_spread
- Not currently used on pve2
- Benefit: May help on low-end SSDs
- Action: Allocates bigger, aligned chunks of unused space
- Implication: Automatically enables 'ssd' option
- Trade-off: Can increase fragmentation on modern high-end SSDs
```

**Recommendation**: **Not needed** for your Samsung or Intel enterprise SSDs.

---

## TRIM/Discard Configuration

### Asynchronous Discard (Recommended) ✅

```bash
discard=async
- Default: Since kernel 6.2 (if devices support it)
- Support: Since kernel 5.6
- Status: ✅ Already enabled on pve2
- Benefit: Gathers freed extents in larger chunks before TRIM
- Performance: Much better than synchronous mode
```

### Synchronous vs Async Comparison

```bash
discard=sync (or just 'discard')
- ❌ NOT RECOMMENDED
- Can severely degrade performance
- Only acceptable if backing device has async queued TRIM
- Requires SATA chipsets newer than revision 3.1
```

**Your configuration is optimal** with `discard=async`.

---

## Access Time Tracking

### noatime (Recommended) ✅

```bash
noatime
- Status: ✅ Already enabled on pve2
- Benefit: Reduces metadata writes by not updating access times
- Impact: Significant performance improvement
- Trade-off: Some applications rely on access times (rare)
```

### nodiratime (Additional Optimization)

```bash
nodiratime
- Status: ❌ Not currently enabled
- Benefit: Prevents directory access time updates
- Recommendation: Add this to /etc/fstab
- Combined with noatime: Maximum access time optimization
```

**Action**: Consider adding `nodiratime` to mount options.

---

## Compression Configuration

### ZSTD Compression ✅

```bash
compress=zstd:3
- Status: ✅ Already enabled on pve2
- Level: 3 (good balance of compression ratio vs CPU)
- Default: zstd:3 is recommended default
- Range: 1-15 (higher = better compression, more CPU)
```

**Compression Level Guidelines**:
- **Level 1**: Fastest, lowest compression (good for CPU-constrained systems)
- **Level 3**: Balanced (recommended default) ✅ Your current setting
- **Level 9**: High compression, more CPU usage
- **Level 15**: Maximum compression, significant CPU overhead

**Your current setting is optimal** for general use.

---

## Copy-on-Write (COW) Behavior

### Default: datacow (enabled)

```bash
datacow / nodatacow
- Current: datacow (default, COW enabled)
- Status: ✅ Correct for most use cases
```

### When to Consider nodatacow

```bash
nodatacow
- Use case: Database files, VM images, frequent overwrites
- Benefits:
  - Updates in-place (no COW overhead)
  - Improves performance for frequent random writes
- Drawbacks:
  - Disables checksumming (nodatasum implied)
  - Disables compression
  - No snapshot benefits for affected files
  - Risk of partial writes on interruption
```

**For Docker containers**: Keep `datacow` enabled (current setting is correct).

**For database files**: Consider per-file `nodatacow` attribute:
```bash
chattr +C /path/to/database/file
```

---

## Space Cache Configuration

### Space Cache v2 (Recommended) ✅

```bash
space_cache=v2
- Status: ✅ Already enabled on pve2
- Default: Since kernel 4.5
- Benefit: New b-tree implementation (free space tree)
- Performance: Addresses v1 degradation on large filesystems
- Compatibility: Kernels without v2 can only mount read-only
```

**Your configuration is optimal** with `space_cache=v2`.

---

## Transaction Commit Interval

### Commit Interval (Default: 30 seconds)

```bash
commit=<seconds>
- Default: 30
- Current: Using default (recommended)
- Range: Typically 5-300 seconds
- Trade-off:
  - Lower value = Less data loss on crash, more I/O overhead
  - Higher value = Better performance, more unwritten data at risk
```

**For containers/databases**: Default 30 seconds is appropriate.

---

## Additional Optimizations

### 1. Checksumming

```bash
datasum (default: enabled)
- Status: ✅ Enabled (recommended)
- Benefit: Data integrity verification
- Modern CPUs: Hardware acceleration for checksums
- Trade-off: Minimal overhead on modern CPUs
```

**Keep checksumming enabled** for data integrity.

### 2. Barriers

```bash
barrier (default: enabled)
- Status: ✅ Enabled (recommended for safety)
- Benefit: Ensures writes persist to physical media
- Risk with nobarrier: Filesystem corruption on power loss
```

**Only disable barriers** if you have battery-backed write cache.

### 3. Thread Pool

```bash
thread_pool=<number>
- Default: min(NRCPUS + 2, 8)
- Your system: Likely 8 threads (default)
- Tuning: Higher values can cause contention
```

**Keep default** unless profiling shows bottleneck.

---

## Recommended Mount Options for pve2

### Current Configuration ✅
```
/dev/sda on /mnt/ssd_4tb type btrfs (rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2)
```

### Proposed Enhanced Configuration
```
/dev/sda  /mnt/ssd_4tb  btrfs  defaults,noatime,nodiratime,compress=zstd:3,ssd,discard=async,space_cache=v2  0  2
```

**Changes**:
1. ✅ Add `nodiratime` - Prevents directory access time updates
2. ✅ Add to `/etc/fstab` for persistence (if not already there)

---

## Maintenance Best Practices

### 1. Regular Scrubbing
```bash
# Monthly scrub for data integrity verification
btrfs scrub start /mnt/ssd_4tb
btrfs scrub status /mnt/ssd_4tb
```

### 2. Periodic Balance (SSD-specific)
```bash
# Balance metadata to reduce fragmentation
# Run during low-usage periods
btrfs balance start -dusage=50 -musage=50 /mnt/ssd_4tb
```

**Warning**: Balance operations are I/O intensive. Schedule during maintenance windows.

### 3. Monitor SSD Health
```bash
# Check SMART data
smartctl -a /dev/sda

# For NVMe SSDs (if applicable)
nvme smart-log /dev/nvme0n1
```

### 4. Filesystem Usage Monitoring
```bash
# Check overall usage and fragmentation
btrfs filesystem usage /mnt/ssd_4tb

# Check device statistics
btrfs device stats /mnt/ssd_4tb
```

---

## Options to Avoid on SSDs

### ❌ autodefrag
```bash
autodefrag
- Status: Disabled (correct)
- Why avoid:
  - Increases read latency
  - Not suitable for database workloads
  - Can break reflinks (snapshots, --reflink copies)
  - Increases space usage
```

### ❌ discard=sync
```bash
discard=sync (synchronous TRIM)
- Status: Not used (correct)
- Why avoid: Severe performance degradation
- Use instead: discard=async (already configured)
```

### ❌ ssd_spread
```bash
ssd_spread
- Status: Not used (correct for modern SSDs)
- Why avoid: May increase fragmentation on modern SSDs
- Legacy option: For older, low-end SSDs
```

---

## Summary: pve2 Configuration Assessment

### ✅ Optimal Settings Already Applied
1. `ssd` - SSD optimizations enabled
2. `discard=async` - Asynchronous TRIM (optimal)
3. `noatime` - Access time updates disabled
4. `compress=zstd:3` - Balanced compression
5. `space_cache=v2` - Modern space cache

### 🔧 Recommended Addition
1. Add `nodiratime` to further reduce metadata updates

### ✅ Correctly Avoided
1. No `autodefrag` (correct for container workload)
2. No `ssd_spread` (correct for modern SSDs)
3. No `discard=sync` (correct - would degrade performance)

---

## Implementation Steps

### Update /etc/fstab (if not already persistent)

1. **Backup current fstab**:
```bash
ssh root@pve2 'cp /etc/fstab /etc/fstab.backup-$(date +%Y%m%d)'
```

2. **Check if /dev/sda is in fstab**:
```bash
ssh root@pve2 'grep /mnt/ssd_4tb /etc/fstab'
```

3. **If not present, add entry**:
```bash
ssh root@pve2 'echo "/dev/sda  /mnt/ssd_4tb  btrfs  defaults,noatime,nodiratime,compress=zstd:3,ssd,discard=async,space_cache=v2  0  2" >> /etc/fstab'
```

4. **If present, update options**:
```bash
# Manual edit required or use sed
ssh root@pve2 'nano /etc/fstab'
```

5. **Remount to test**:
```bash
ssh root@pve2 'mount -o remount,noatime,nodiratime,compress=zstd:3,ssd,discard=async,space_cache=v2 /mnt/ssd_4tb'
```

6. **Verify mount options**:
```bash
ssh root@pve2 'mount | grep sda'
```

---

## Related Documentation

- **Official BTRFS Docs**: https://btrfs.readthedocs.io/en/latest/
- **Mount Options Reference**: https://btrfs.readthedocs.io/en/latest/btrfs-man5.html
- **Local Issue Report**: docs/troubleshooting/pve2-fan-activity-btrfs-io-2025-10-23.md
- **Infrastructure Overview**: docs/infrastructure.md

---

## Community Best Practices (Additional Recommendations)

### Filesystem Creation Optimizations

#### Metadata Duplication on Single SSD
```bash
mkfs.btrfs -m single /dev/sda
```

**Consideration for pve2**:
- ❌ **Already created with default `-m dup`**
- Cannot change metadata profile on existing filesystem without full recreation
- Trade-off Analysis:
  - `-m single`: Saves space (50% metadata overhead reduction), trust SSD firmware
  - `-m dup`: Current setting, provides redundancy against corruption
  - **Recommendation**: Keep current `-m dup` for production safety

### Filesystem Usage Thresholds

#### Keep Usage Below 95%

```bash
# Current pve2 usage: 23% (845GB / 3.7TB) ✅
# Threshold: Maintain < 95% to avoid:
  - Performance degradation
  - Complex balance operations
  - Increased fragmentation
```

**Status**: ✅ pve2 has plenty of headroom (77% free space).

### Automated Maintenance

#### btrfsmaintenance Tool

```bash
# Install maintenance automation (Debian/Ubuntu)
apt-get install btrfsmaintenance

# Configure periodic tasks in /etc/sysconfig/btrfsmaintenance or systemd timers
# - Monthly scrub
# - Weekly balance
# - Defragmentation schedules
```

**Recommendation**: Implement automated maintenance schedule for pve2.

### TRIM Verification

#### Verify TRIM is Active

```bash
# Check if TRIM is supported
ssh root@pve2 'lsblk --discard /dev/sda'

# Expected output should show non-zero values for DISC-GRAN and DISC-MAX
# Example:
# NAME DISC-GRAN DISC-MAX
# sda       512B      2G

# Verify async discard is working
ssh root@pve2 'dmesg | grep -i discard'
```

**Status**: ✅ Already configured with `discard=async`.

### Subvolumes Best Practices

#### Use Subvolumes Instead of Partitions

```bash
# Benefits of subvolumes:
  - Independent snapshots
  - Quota management per subvolume
  - No fixed size allocation
  - Easy to create/destroy

# Example structure for pve2 (if re-architecting):
/mnt/ssd_4tb/@docker-data
/mnt/ssd_4tb/@docker-logs
/mnt/ssd_4tb/@backups
/mnt/ssd_4tb/@snapshots
```

**Current Status**: Using single subvolume (root). Consider subvolume structure for future.

### Swap File Considerations

#### Avoid Direct Swap Files on BTRFS

```bash
# BTRFS limitations with swap files:
  - No snapshot support for swap subvolume
  - Must disable COW on swap file
  - Requires kernel 5.0+ for swap file support

# If swap is needed, use dedicated partition OR:
btrfs subvolume create /mnt/ssd_4tb/@swap
chattr +C /mnt/ssd_4tb/@swap  # Disable COW
dd if=/dev/zero of=/mnt/ssd_4tb/@swap/swapfile bs=1M count=4096
chmod 600 /mnt/ssd_4tb/@swap/swapfile
mkswap /mnt/ssd_4tb/@swap/swapfile
```

**pve2 Status**: Uses LVM swap partition (correct approach) ✅

### SSD Health Monitoring

#### Monitor with smartmontools

```bash
# Install smartmontools (if not present)
ssh root@pve2 'apt-get install smartmontools'

# Check SSD health
ssh root@pve2 'smartctl -a /dev/sda | grep -E "(Reallocated|Wear|Life|Temperature|Errors)"'

# Enable periodic monitoring
ssh root@pve2 'systemctl enable smartd'
```

**Recommendation**: Set up weekly SMART monitoring cron job.

### Workload-Specific Optimizations

#### Heavy Write Workloads (Databases/VMs)

For specific high-write directories:
```bash
# Disable COW per-directory (e.g., for database files)
chattr +C /mnt/ssd_4tb/postgres-data

# Must be applied before files are created
# Existing files must be rewritten
```

**pve2 Consideration**:
- Docker containers: Keep COW enabled ✅
- PostgreSQL inside containers: Already using dedicated volumes
- Consider `+C` attribute for VM disk images if performance is critical

### Write Amplification Mitigation

#### Compression Reduces Write Amplification ✅

```bash
compress=zstd:3
```

**Benefits**:
- Reduces physical writes to SSD
- Extends SSD lifespan
- Saves disk space
- **Status**: ✅ Already configured on pve2

---

## Complete Recommended Configuration for pve2

### Immediate Actions (Low Risk)

1. **Add nodiratime to mount options**:
```bash
ssh root@pve2 'mount -o remount,nodiratime /mnt/ssd_4tb'
```

2. **Update /etc/fstab for persistence**:
```bash
# Ensure entry exists with all optimal options
/dev/sda  /mnt/ssd_4tb  btrfs  defaults,noatime,nodiratime,compress=zstd:3,ssd,discard=async,space_cache=v2  0  2
```

### Weekly Maintenance Tasks

```bash
# Create maintenance script: /root/btrfs-weekly-maintenance.sh
#!/bin/bash
# BTRFS Weekly Maintenance for pve2

# Check filesystem usage
echo "=== Filesystem Usage ==="
btrfs filesystem usage /mnt/ssd_4tb

# Check device stats
echo "=== Device Statistics ==="
btrfs device stats /mnt/ssd_4tb

# Verify TRIM status
echo "=== TRIM Status ==="
lsblk --discard /dev/sda

# SMART health check
echo "=== SSD Health ==="
smartctl -H /dev/sda
smartctl -a /dev/sda | grep -E "(Reallocated|Wear|Life|Temperature|Errors)"
```

### Monthly Maintenance Tasks

```bash
# Create maintenance script: /root/btrfs-monthly-maintenance.sh
#!/bin/bash
# BTRFS Monthly Maintenance for pve2

# Filesystem scrub (data integrity check)
echo "Starting BTRFS scrub..."
btrfs scrub start /mnt/ssd_4tb
btrfs scrub status -d /mnt/ssd_4tb

# Light balance to reduce fragmentation
# Only during low-usage period (e.g., 3 AM)
if [ $(date +%H) -eq 3 ]; then
    echo "Starting balance operation..."
    btrfs balance start -dusage=50 -musage=50 /mnt/ssd_4tb
fi
```

### Quarterly Tasks

```bash
# Full filesystem analysis
btrfs filesystem show /mnt/ssd_4tb
btrfs filesystem df /mnt/ssd_4tb
btrfs device stats /mnt/ssd_4tb

# Review compression effectiveness
compsize /mnt/ssd_4tb

# Consider more aggressive balance if fragmentation is high
# btrfs balance start -dusage=75 -musage=75 /mnt/ssd_4tb
```

---

## Advanced Considerations for Future Planning

### When to Consider Migration to ZFS or ext4

**Indicators that might justify migration**:
1. BTRFS transaction overhead consistently > 40% CPU
2. Metadata overhead becomes unmanageable (> 10% of volume)
3. Need better performance for random write workloads
4. Frequent balance operations required
5. Database workload dominates (ZFS ARC cache benefits)

**Current Status**: Not justified. pve2 is performing within acceptable parameters.

### Alternative Filesystem Trade-offs

| Filesystem | Pros | Cons |
|------------|------|------|
| **BTRFS** (current) | Snapshots, compression, online growth, flexible | COW overhead, metadata complexity, transaction load |
| **ZFS** | Excellent for databases, ARC cache, mature | Memory hungry, harder to grow, licensing concerns |
| **ext4** | Lowest overhead, stable, fast | No snapshots, no compression, no checksumming |
| **XFS** | Good for large files, stable | No shrinking, no snapshots, limited features |

---

## Conclusion

Your pve2 BTRFS configuration is **already following nearly all best practices** for SSD usage. The recommendations above provide:

### ✅ Immediate Low-Risk Improvements
1. Add `nodiratime` to mount options
2. Implement automated weekly/monthly maintenance scripts
3. Set up SMART monitoring

### ✅ Current Optimal Configuration
1. `ssd` + `discard=async` - Excellent for modern SSDs
2. `compress=zstd:3` - Reduces writes, extends SSD life
3. `noatime` - Minimizes metadata updates
4. `space_cache=v2` - Modern, efficient free space management
5. 23% usage - Well below 95% threshold

### 🔍 Monitor for Future Decisions
1. BTRFS transaction CPU usage trends
2. SSD wear levels and lifespan projections
3. Workload changes (more databases, VMs, etc.)
4. Filesystem fragmentation over time

**Key Takeaway**: The current fan activity from BTRFS transaction processing is **normal behavior** for a COW filesystem managing 33+ Docker containers. Your optimizations are appropriate, and the filesystem is healthy. Further tuning would provide minimal benefit while potentially introducing trade-offs in reliability or features.

---

## References

- **Official BTRFS Documentation**: https://btrfs.readthedocs.io/en/latest/
- **Red Hat SSD Optimization Guide**: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/storage_administration_guide/btrfs-ssd-optimization
- **Community Best Practices**: r/btrfs, Arch Linux Wiki, Manjaro Forums
- **Local Documentation**:
  - Issue Report: `docs/troubleshooting/pve2-fan-activity-btrfs-io-2025-10-23.md`
  - Infrastructure: `docs/infrastructure.md`
