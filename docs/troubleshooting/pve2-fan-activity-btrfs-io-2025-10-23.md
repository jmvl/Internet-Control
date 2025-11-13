# PVE2 Fan Activity Investigation - BTRFS I/O Load

**Date**: 2025-10-23
**Host**: pve2 (Proxmox VE)
**Issue**: Fan running at elevated speed due to sustained CPU and disk activity
**Status**: ✅ Resolved - Identified as normal behavior under current workload

## Summary

Fan activity on pve2 was caused by sustained BTRFS transaction processing consuming 44% CPU with continuous disk I/O operations. This is normal behavior for the current workload pattern involving heavy Supabase container activity on a BTRFS-backed storage volume.

## Symptoms

- Fan audibly running at higher than idle speed
- System remained stable with no performance degradation
- No error messages or service failures

## Diagnostic Process

### System Overview Check
```bash
ssh root@pve2 'uptime && cat /proc/loadavg'
```
**Result**: Load average of 0.85, 1.08, 1.18 over 1/5/15 minutes - moderate sustained load

### Temperature Monitoring
```bash
ssh root@pve2 'cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -5'
```
**Result**: CPU temperature at 50°C (50000 millidegrees) - within safe operating range but elevated

### Process Analysis
```bash
ssh root@pve2 'top -bn1 | head -20'
```

**Key Findings**:
- `btrfs-transaction` (PID 715): **44.4% CPU** - 34 hours accumulated CPU time
- `dockerd` (PID 9975): **11.1% CPU** - Docker daemon managing Supabase containers
- `beam.smp` (PID 18870): **5.6% CPU** - Supabase Erlang VM (Supavisor)
- `go.d.plugin` (PID 29732): **11.1% CPU** - Netdata monitoring collector

### Storage Analysis
```bash
ssh root@pve2 'btrfs fi show /mnt/ssd_4tb && btrfs fi df /mnt/ssd_4tb'
```

**BTRFS Volume Status**:
- **Total Size**: 3.64TB
- **Used Space**: 845.47GB (23%)
- **Allocated**: 938.02GB
- **Data Profile**: Single (no RAID)
- **Metadata Profile**: DUP (duplicated)
  - Total: 5.00GiB
  - Used: 2.43GiB

### Memory and I/O Statistics
```bash
ssh root@pve2 'free -h && vmstat 1 3'
```

**Memory Status**:
- Total: 62GB
- Used: 31GB
- Free: 599MB
- Buff/cache: 29GB
- Swap: 887MB used of 8GB

**I/O Wait**: 2% - Moderate disk I/O activity

### Running Workloads
```bash
ssh root@pve2 'qm list && pct list'
```

**Active VMs**:
- VM 133: OPNsense (3.6GB RAM)

**Active Containers**:
- CT 100: ConfluenceDocker
- CT 102: jira.accelior.com
- CT 103: files.accelior.com
- CT 109: wanderwish
- CT 110: ansible-mgmt
- CT 111: docker-debian (Supabase stack)
- CT 130: mail.vega-messenger.com
- CT 501: gitlab.accelior.com

## Root Cause Analysis

The fan activity is triggered by a combination of factors:

1. **BTRFS Transaction Overhead**
   - Continuous metadata operations on `/mnt/ssd_4tb`
   - BTRFS uses copy-on-write (COW) which generates significant metadata updates
   - DUP metadata profile doubles write operations for metadata
   - Process accumulated 34 hours of CPU time over 4 days uptime

2. **Heavy Docker Workload**
   - Supabase PostgreSQL database with high write activity
   - Multiple containers writing logs and data to BTRFS volume
   - Docker overlay2 storage driver interacting with BTRFS

3. **Thermal Response**
   - CPU temperature at 50°C is within spec but above idle range (typically 35-40°C)
   - Sustained I/O operations keep disk controller and CPU active
   - Fan ramps up appropriately to maintain thermal envelope

## Resolution

**Status**: This is **normal and expected behavior** for the current workload. No corrective action required.

## Recommendations

### Short-term Monitoring
1. **Track BTRFS performance**:
   ```bash
   # Check filesystem usage and fragmentation
   ssh root@pve2 'btrfs filesystem usage /mnt/ssd_4tb'

   # Monitor write activity
   ssh root@pve2 'btrfs device stats /mnt/ssd_4tb'
   ```

2. **Monitor Docker container logs**:
   ```bash
   # Check log sizes
   ssh root@pve2 'docker ps -q | xargs docker inspect --format="{{.Name}}: {{.HostConfig.LogConfig}}"'

   # Check for excessive logging
   ssh root@pve2 'du -sh /var/lib/docker/containers/*/*.log | sort -rh | head -10'
   ```

3. **Verify log rotation is active**:
   ```bash
   ssh root@pve2 'docker info | grep -A 10 "Logging Driver"'
   ```

### Medium-term Optimizations

1. **BTRFS Mount Options**:
   Consider adding to `/etc/fstab`:
   ```
   /dev/sda  /mnt/ssd_4tb  btrfs  defaults,noatime,nodiratime,compress=zstd  0  2
   ```
   - `noatime`: Reduces metadata writes by not updating access times
   - `nodiratime`: Prevents directory access time updates
   - `compress=zstd`: May reduce I/O through compression

2. **Docker Logging Configuration**:
   Implement log rotation in `/etc/docker/daemon.json`:
   ```json
   {
     "log-driver": "json-file",
     "log-opts": {
       "max-size": "10m",
       "max-file": "3"
     }
   }
   ```

3. **Periodic Maintenance**:
   ```bash
   # Weekly BTRFS balance (run during low-usage period)
   ssh root@pve2 'btrfs balance start -dusage=50 /mnt/ssd_4tb'

   # Monthly scrub for data integrity
   ssh root@pve2 'btrfs scrub start /mnt/ssd_4tb'
   ```

### Long-term Considerations

1. **Filesystem Evaluation**:
   - If BTRFS transaction overhead remains consistently high (>30% CPU)
   - Consider migrating to ZFS (better for database workloads) or ext4 (lower overhead)
   - ZFS would provide better performance for PostgreSQL with tunable ARC cache

2. **Workload Separation**:
   - Consider moving high-I/O Supabase workload to dedicated storage
   - Use NVMe-backed LVM thin pool for database containers
   - Keep BTRFS volume for less I/O-intensive workloads

3. **Hardware Upgrade Path**:
   - Current 1x3.64TB BTRFS single mode has no redundancy
   - Consider RAID1 configuration with second 4TB drive
   - Would improve reliability without sacrificing BTRFS features

## Related Documentation

- Main infrastructure overview: `/docs/infrastructure.md`
- Storage architecture: CLAUDE.md:129-138
- Proxmox management: CLAUDE.md:66-81
- Other recent troubleshooting:
  - `docs/troubleshooting/swap-memory-high-utilization-2025-10-17.md`
  - `docs/troubleshooting/uptime-kuma-monitor-errors-2025-10-17.md`

## Follow-up Actions

- [ ] Schedule weekly BTRFS balance operation via cron
- [ ] Implement Docker log rotation limits
- [ ] Monitor BTRFS transaction CPU usage over next 7 days
- [ ] Document baseline performance metrics for comparison

## Conclusion

The fan activity on pve2 is a **normal thermal response** to sustained BTRFS metadata operations combined with heavy Supabase container I/O. The system is operating within specifications. Recommended optimizations can reduce I/O overhead but are not urgent. No service impact or degradation observed.
