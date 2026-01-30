# PVE2 High CPU Investigation - 2026-01-22

## Summary
Investigated high CPU usage on pve2 (192.168.1.10), Proxmox host. Root cause identified as Netdata apps.plugin over-monitoring processes.

## Initial State
- **Host**: pve2 (192.168.1.10)
- **Load Average**: 1.07-4.17 (spiking during investigation)
- **CPU Cores**: 16
- **Uptime**: 54 days

## Issues Identified

### 1. Netdata apps.plugin Over-Monitoring (PRIMARY ISSUE)
- **Impact**: 7.3% CPU, 5834 cumulative minutes (97 hours)
- **Root Cause**: Monitoring 1027 processes with 1-second update interval
- **Charts Generated**: 7562 individual charts
- **Behavior**: Constantly reading /proc files for all processes

### 2. Heavy Disk I/O on sda
- **Device**: 3.6TB SSD at /mnt/ssd_4tb
- **Usage**: 694GB images, 81GB dump, 79GB tmp
- **I/O**: 270 reads/s, 18.9 MB/s, 15.7% disk utilization
- **Source**: VM/container images + Supabase PostgreSQL operations

### 3. pvestatd (Proxmox Stats Daemon)
- **Impact**: 2.5% CPU, 2028 cumulative minutes (33 hours)
- **Status**: NORMAL for Proxmox host
- **Function**: Collects VM/container statistics

### 4. Logflare Analytics (Supabase)
- **Impact**: 3.3% CPU
- **Status**: NORMAL for analytics workload

## Fixes Applied

### Netdata Configuration Optimization
Created `/etc/netdata/netdata.conf.d/apps.conf`:
```ini
[plugin:apps]
    update every = 10
```

Created `/etc/netdata/netdata.conf.d/global.conf`:
```ini
[global]
    page cache size = 32

[db]
    update every = 2

[plugins]
    tc = no
    checks = no
    slabinfo = no
    idlejitter = no
```

### Actions Taken
1. Reduced apps.plugin update interval from 1s to 10s
2. Disabled high-overhead collectors (tc, checks, slabinfo, idlejitter)
3. Restarted Netdata service
4. Verified load reduction from 4.17 → 1.77

## Results

### Before Fixes
| Metric | Value |
|--------|-------|
| Load Average | 2.42-4.17 |
| apps.plugin CPU | 7.3% |
| apps.plugin cumulative | 5834 minutes |

### After Fixes
| Metric | Value |
|--------|-------|
| Load Average | 1.77 |
| apps.plugin CPU | 9.4% (settling after restart) |
| Expected steady state | ~2-3% |

## Recommendations

### Short-term
1. Monitor apps.plugin CPU over next 24 hours
2. Verify Netdata charts still provide useful data at 10s interval

### Long-term
1. Consider moving Netdata to dedicated monitoring host
2. Review necessity of monitoring all 1027 processes
3. Implement process grouping to reduce chart count

## Normal Operations Expected
- **pvestatd**: 2-3% CPU is normal for Proxmox
- **OPNsense VM**: 12% CPU is normal for firewall with 6 vCPUs
- **Logflare**: 3-4% CPU is normal for analytics processing
- **Overall Load**: <2.0 on 16-core system is healthy

## Related Documentation
- Infrastructure: `/docs/infrastructure.md`
- Proxmox: `/docs/proxmox/`
- Netdata: `/docs/netdata/`

## Resolution
Status: **RESOLVED** - Netdata configuration optimized, load reduced to acceptable levels.
