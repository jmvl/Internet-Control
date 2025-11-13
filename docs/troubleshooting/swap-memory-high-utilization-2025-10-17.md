# Swap Memory High Utilization - Intervention Report

**Date**: 2025-10-17
**Alert Severity**: CRITICAL (OMV), WARNING (pve2)
**Status**: ⚠️ INVESTIGATED - ACTION REQUIRED
**Reported By**: Netdata Monitoring System

---

## 🚨 ALERT SUMMARY

### Critical Alerts Detected

| Node | Alert Status | Swap Utilization | Last Updated | Duration Since Alert |
|------|--------------|------------------|--------------|---------------------|
| **openmediavault** | 🔴 **CRITICAL** | **99.99%** | 2025-10-17 | ~30 hours |
| **pve2** | 🟡 **WARNING** | **94.08%** | 2025-10-17 | ~29 hours |

### Alert Details from CSV

```csv
status,summary,context,instance,nodeName,value,lastUpdated,lastStatusChangeValue,lastStatusChange,silencing,actions
critical,System swap memory utilization,mem.swap,mem.swap,openmediavault,99.9867923,1760697475,98.93738368253587,1760664604,"{""state"":""NONE""}",-
warning,System swap memory utilization,mem.swap,mem.swap,pve2,94.0848322,1760697477,92.58918408831791,1760590174,"{""state"":""NONE""}",-
```

**Key Observations**:
- OMV alert transitioned to CRITICAL approximately 9 hours ago (lastStatusChange: 1760664604)
- pve2 alert transitioned to WARNING approximately 29 hours ago (lastStatusChange: 1760590174)
- Both systems have been in alert state for extended periods

---

## 📊 SYSTEM ANALYSIS

### OpenMediaVault (192.168.1.9) - CRITICAL

#### Swap Configuration
```bash
Device:     /dev/sda3
Type:       Partition
Total:      976 MB (999,420 KB)
Used:       975.9 MB (999,276 KB)
Free:       144 KB
Utilization: 99.99%
Priority:   -2
```

#### Memory Statistics
```
Total Memory:      7.6 GB (7,779,136 KB)
Used Memory:       3.3 GB (3,443,116 KB)
Free Memory:       906 MB (917,928 KB)
Buffer Memory:     52 MB (52,728 KB)
Cached Memory:     4.1 GB (4,220,276 KB in swap cache)
Available Memory:  4.1 GB

Active Memory:     2.1 GB (2,182,956 KB)
Inactive Memory:   1.1 GB (1,122,156 KB)
```

#### System Configuration
- **Swappiness**: 10 (conservative - favors RAM over swap)
- **Memory Pressure**: MODERATE (906 MB free, 4.1 GB available)
- **Swap Cache**: 4.1 GB (indicates high swap I/O activity)

#### Top Memory Consumers
| Process | Memory % | Memory (RSS) | Description |
|---------|----------|--------------|-------------|
| **immich** | 6.5% | 510 MB | AI-powered photo management |
| **immich-api** | 2.9% | 226 MB | Immich API server |
| **netdata** | 2.4% | 188 MB | Monitoring dashboard |
| **node (n8n)** | 1.5% | 122 MB | Workflow automation |
| **WeddingShare** | 1.4% | 116 MB | .NET custom application |
| **postgres** | 1.4% | 113 MB | PostgreSQL database |
| **mergerfs** | 1.1% | 90 MB | Filesystem pooling |

**Total Active Docker Containers**: 15+ services
**Total Physical RAM**: 7.4 GB

---

### pve2 Proxmox Host (192.168.1.10) - WARNING

#### Swap Configuration
```bash
Device:     /dev/dm-0 (LVM)
Type:       Partition
Total:      8 GB (8,388,604 KB)
Used:       7.5 GB (7,897,512 KB)
Free:       479 MB (491,092 KB)
Utilization: 94.08%
Priority:   -2
```

#### Memory Statistics
```
Total Memory:      62 GB (65,249,016 KB)
Used Memory:       29 GB (30,524,128 KB)
Free Memory:       1.1 GB (1,329,348 KB)
Buffer Memory:     2.5 GB (2,548,304 KB)
Cached Memory:     33 GB (32,063,024 KB in swap cache)
Available Memory:  32 GB

Active Memory:     25 GB (25,123,280 KB)
Inactive Memory:   32 GB (32,601,668 KB)
```

#### System Configuration
- **Swappiness**: 60 (default - balanced swap usage)
- **Memory Pressure**: LOW (32 GB available out of 62 GB total)
- **Swap Cache**: 32 GB (indicates significant swap activity despite available RAM)

#### Top Memory Consumers
| Process | Memory % | Memory (RSS) | Description |
|---------|----------|--------------|-------------|
| **Confluence** | 6.8% | 4.4 GB | Wiki/collaboration platform |
| **JIRA** | 5.9% | 3.9 GB | Issue tracking system |
| **OPNsense VM** | 5.2% | 3.4 GB | Firewall virtual machine |
| **Logflare** | 3.0% | 1.9 GB | Log aggregation (Supabase) |
| **Next.js** | 2.3% | 1.5 GB | Web framework server |
| **MySQL** | 2.0% | 1.3 GB | Database server |
| **GitLab Workers** | 3x ~1.5% | ~1 GB each | CI/CD platform workers |
| **GitLab Sidekiq** | 1.4% | 931 MB | Background job processor |

**Total VMs/Containers**: 11 active LXC containers + 1 VM (OPNsense)
**Total Physical RAM**: 62 GB

---

## 🔍 ROOT CAUSE ANALYSIS

### OpenMediaVault - CRITICAL Swap Usage

#### Primary Causes:
1. **Insufficient Physical RAM**
   - **Total RAM**: 7.4 GB
   - **Memory Allocation**: Running 15+ Docker containers with memory-intensive applications
   - **Cumulative Memory Demand**: Exceeds available physical RAM
   - **Result**: System forced to swap aggressively despite low swappiness

2. **Memory-Intensive Services**
   - **Immich Stack**: 750 MB+ (photo AI/ML processing)
   - **PostgreSQL**: 113 MB (database operations)
   - **Netdata**: 188 MB (monitoring with retention)
   - **n8n**: 122 MB (workflow automation)
   - **Multiple nginx workers**: ~100 MB combined
   - **Container overhead**: Additional memory per container

3. **Swap Size Inadequacy**
   - **Swap Partition**: 976 MB (only 12% of physical RAM)
   - **Recommended Ratio**: 1x-2x physical RAM for systems with <8GB RAM
   - **Current Shortfall**: Should be 7-14 GB instead of 976 MB

4. **High Swap Cache Pressure**
   - **Swap Cache**: 4.1 GB (larger than swap partition!)
   - **Indicates**: Frequent swap in/out operations
   - **Performance Impact**: Severe disk I/O bottleneck

#### Secondary Contributing Factors:
- **Docker Memory Limits**: Not configured (containers can consume unlimited RAM)
- **OOM Killer**: Not actively triggered (swapping preferred over killing processes)
- **File Cache Competition**: 4.1 GB cache competes with application memory
- **Background Services**: OMV system services, Samba, monitoring tools

---

### pve2 Proxmox Host - WARNING Swap Usage

#### Primary Causes:
1. **High Swappiness Configuration**
   - **Current Swappiness**: 60 (default Linux value)
   - **Impact**: Kernel aggressively swaps even with 32 GB RAM available
   - **Behavior**: Swaps out inactive memory pages to maintain file cache
   - **Recommendation**: Reduce to 10-20 for server workloads

2. **Large Inactive Memory Pool**
   - **Inactive Memory**: 32 GB (50% of total RAM)
   - **Kernel Behavior**: Swaps inactive pages to preserve file cache
   - **VM/Container Pattern**: Background processes swapped when idle
   - **Result**: High swap usage despite low memory pressure

3. **Memory-Intensive Applications**
   - **Confluence**: 4.4 GB (Java heap + caching)
   - **JIRA**: 3.9 GB (Java heap + indexing)
   - **OPNsense VM**: 3.4 GB (firewall state tables, traffic inspection)
   - **GitLab Stack**: ~5 GB combined (workers + sidekiq + database)
   - **Supabase Stack**: ~3 GB (Logflare + databases)

4. **Guest Memory Balloning Not Optimized**
   - **OPNsense VM**: 3.6 GB allocated (static allocation)
   - **LXC Containers**: No dynamic memory balancing
   - **Result**: Over-committed memory not reclaimed efficiently

#### Secondary Contributing Factors:
- **Container Memory Limits**: Not enforced for many LXC containers
- **VM Memory Reservations**: Static allocations don't account for actual usage
- **ZFS ARC Cache**: Competes with application memory (if using ZFS)
- **File System Cache**: Kernel prefers maintaining large cache over freeing memory

---

## 💡 RECOMMENDED ACTIONS

### Immediate Actions (Within 24 Hours)

#### For OpenMediaVault (CRITICAL Priority)

1. **⚠️ CRITICAL: Increase Swap Space**
   ```bash
   # Option A: Add swap file (RECOMMENDED - no repartitioning needed)
   ssh root@192.168.1.9 'fallocate -l 8G /swapfile'
   ssh root@192.168.1.9 'chmod 600 /swapfile'
   ssh root@192.168.1.9 'mkswap /swapfile'
   ssh root@192.168.1.9 'swapon /swapfile'
   ssh root@192.168.1.9 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'

   # Verify new swap
   ssh root@192.168.1.9 'swapon --show'
   ssh root@192.168.1.9 'free -h'
   ```

2. **Configure Docker Memory Limits**
   ```bash
   # Limit memory-intensive containers
   # Edit docker-compose.yml files to add:
   # mem_limit: 512m (for most services)
   # mem_limit: 1g (for Immich, PostgreSQL)
   ```

3. **Reduce Swap Cache Pressure**
   ```bash
   # Reduce file cache aggressiveness
   ssh root@192.168.1.9 'echo "vm.vfs_cache_pressure=150" >> /etc/sysctl.conf'
   ssh root@192.168.1.9 'sysctl -p'
   ```

4. **Monitor Critical Services**
   ```bash
   # Check for OOM events
   ssh root@192.168.1.9 'dmesg | grep -i "out of memory"'

   # Monitor swap usage trends
   ssh root@192.168.1.9 'watch -n 5 free -h'
   ```

#### For pve2 Proxmox Host (WARNING Priority)

1. **Reduce Swappiness**
   ```bash
   # Configure for server workload (immediate)
   ssh root@pve2 'sysctl vm.swappiness=10'

   # Make persistent
   ssh root@pve2 'echo "vm.swappiness=10" >> /etc/sysctl.d/99-swap-tuning.conf'
   ssh root@pve2 'sysctl -p /etc/sysctl.d/99-swap-tuning.conf'
   ```

2. **Tune Memory Management**
   ```bash
   # Reduce cache pressure
   ssh root@pve2 'echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-swap-tuning.conf'

   # Optimize dirty page writeback
   ssh root@pve2 'echo "vm.dirty_ratio=10" >> /etc/sysctl.d/99-swap-tuning.conf'
   ssh root@pve2 'echo "vm.dirty_background_ratio=5" >> /etc/sysctl.d/99-swap-tuning.conf'

   ssh root@pve2 'sysctl -p /etc/sysctl.d/99-swap-tuning.conf'
   ```

3. **Clear Swap and Reset**
   ```bash
   # Only if available memory > 15GB
   ssh root@pve2 'swapoff -a && swapon -a'
   ```

---

### Short-Term Actions (Within 1 Week)

#### For OpenMediaVault

1. **Evaluate RAM Upgrade**
   - **Current**: 7.4 GB DDR3/DDR4
   - **Recommended**: 16 GB minimum
   - **Cost**: $50-150 depending on memory type
   - **Impact**: Eliminate swap pressure entirely

2. **Container Consolidation Analysis**
   - Review which services are essential
   - Consider moving non-critical services to pve2 LXC containers
   - Evaluate service usage patterns

3. **Implement Monitoring Alerts**
   ```bash
   # Configure Netdata to send notifications for:
   # - Swap usage > 80% (WARNING)
   # - Swap usage > 95% (CRITICAL)
   # - Memory available < 500 MB (WARNING)
   ```

#### For pve2

1. **Container Memory Limits**
   ```bash
   # Configure LXC container memory limits
   # Edit /etc/pve/lxc/{VMID}.conf:
   # memory: 4096  # Confluence
   # memory: 4096  # JIRA
   # memory: 2048  # GitLab
   # memory: 1024  # Other services
   ```

2. **VM Memory Optimization**
   ```bash
   # Review OPNsense VM memory allocation
   # Consider reducing from 3.6GB to 2GB
   qm set 133 -memory 2048
   ```

3. **Enable Memory Ballooning**
   ```bash
   # Ensure balloon driver is active in VMs
   qm set 133 -balloon 1024  # Minimum memory: 1GB
   ```

---

### Long-Term Actions (Within 1 Month)

1. **Infrastructure Capacity Planning**
   - Document current and projected memory usage
   - Plan for 20% growth buffer
   - Evaluate moving services to dedicated hardware

2. **OMV Hardware Upgrade Path**
   - **Option A**: Upgrade RAM to 16 GB ($50-150)
   - **Option B**: Migrate to more powerful server
   - **Option C**: Offload services to pve2

3. **Implement Resource Governance**
   - Document memory allocation strategy
   - Establish container resource limits policy
   - Regular capacity review meetings

4. **Automated Remediation**
   ```bash
   # Create script to auto-clear swap when safe
   # /usr/local/bin/swap-cleaner.sh
   # Schedule via cron: 0 3 * * * (daily at 3 AM)
   ```

---

## 📈 MONITORING & VERIFICATION

### Verification Commands

#### Check Swap Status
```bash
# OMV
ssh root@192.168.1.9 'free -h && swapon --show'

# pve2
ssh root@pve2 'free -h && swapon --show'
```

#### Check Swappiness
```bash
# OMV
ssh root@192.168.1.9 'cat /proc/sys/vm/swappiness'

# pve2
ssh root@pve2 'cat /proc/sys/vm/swappiness'
```

#### Monitor Memory Trends
```bash
# Real-time monitoring
ssh root@192.168.1.9 'watch -n 2 "free -h && echo && swapon --show"'
ssh root@pve2 'watch -n 2 "free -h && echo && swapon --show"'
```

#### Check OOM Events
```bash
ssh root@192.168.1.9 'dmesg -T | grep -i "out of memory" | tail -20'
ssh root@pve2 'dmesg -T | grep -i "out of memory" | tail -20'
```

### Netdata Monitoring

Access Netdata dashboard to track:
- **URL**: https://netdata.acmea.tech
- **Credentials**: admin / RgVW6rzrNLXXP6pjC6DVUg==

**Key Metrics to Monitor**:
1. **System → Memory → Swap** - Real-time swap utilization
2. **System → Memory → Available** - Available memory trends
3. **System → Memory → Page Faults** - Swap I/O activity
4. **Alerts → Active Alerts** - Current alert status

---

## 🎯 SUCCESS CRITERIA

### OpenMediaVault (OMV)
- ✅ Swap utilization < 80% sustained
- ✅ Available memory > 1 GB sustained
- ✅ No OOM killer events
- ✅ Swap I/O < 10 MB/s average
- ✅ Alert cleared in Netdata (status: CLEAR)

### pve2 Proxmox Host
- ✅ Swap utilization < 50% sustained
- ✅ Swappiness reduced to 10
- ✅ Inactive memory actively reclaimed
- ✅ VMs/containers stay within memory limits
- ✅ Alert cleared in Netdata (status: CLEAR)

---

## 📝 INTERVENTION LOG

### Actions Taken

#### 2025-10-17 - Initial Investigation
- ✅ Retrieved alert data from Netdata CSV export
- ✅ Connected to Netdata container and reviewed health logs
- ✅ Analyzed memory usage on both OMV and pve2
- ✅ Identified swap configuration and usage patterns
- ✅ Documented top memory consumers on both systems
- ✅ Determined root causes for both alerts
- ✅ Created comprehensive intervention plan

#### Pending Actions
- ⏳ Add 8 GB swap file to OMV
- ⏳ Reduce pve2 swappiness to 10
- ⏳ Configure Docker container memory limits
- ⏳ Tune kernel memory management parameters
- ⏳ Verify alert clearance in Netdata

---

## 🔗 RELATED DOCUMENTATION

- **Netdata Documentation**: `/docs/netdata/netdata.md`
- **Infrastructure Overview**: `/docs/infrastructure.md`
- **OMV Troubleshooting**: `/docs/troubleshooting/omv-swap-memory-issue-2025-10-10.md` (previous incident)
- **Network Performance**: `/docs/troubleshooting/docker-vm-network-drops-2025-10-10.md`

---

## 📞 ESCALATION CONTACTS

**System Administrator**: root@192.168.1.9 (OMV), root@pve2 (Proxmox)
**Monitoring Dashboard**: https://netdata.acmea.tech
**Documentation Repository**: /Users/jm/Codebase/internet-control

---

**Report Generated**: 2025-10-17
**Next Review Date**: 2025-10-24 (7 days)
**Status**: ⚠️ **REQUIRES IMMEDIATE ACTION**
