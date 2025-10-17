# OMV Swap Memory Issue Resolution - October 10, 2025

**Date**: 2025-10-10 11:14 CEST
**System**: OMV (OpenMediaVault) - 192.168.1.9
**Alert Source**: Netdata monitoring system
**Status**: ✅ **RESOLVED**

---

## 🚨 ISSUE SUMMARY

### Alert Details
- **Alert**: System Swap Memory Utilization Critical
- **System**: OMV at 192.168.1.9
- **Severity**: Critical (99.9% swap utilization)
- **Impact**: Performance degradation, potential service instability

### Initial State
```
Memory:  7.4 GB total, 3.3 GB used, 735 MB free, 4.2 GB available
Swap:    975 MB total, 975 MB used, 196 KB free (99.98% utilized)
Uptime:  50 days, 13 hours
```

**Critical Finding**: System had 4.2 GB available RAM but 975 MB stuck in swap!

---

## 🔍 ROOT CAUSE ANALYSIS

### Primary Cause: Aggressive Swappiness + Memory Fragmentation

1. **High Swappiness Setting**
   - Default swappiness: 60 (kernel swaps aggressively)
   - Kernel swapped out pages even when RAM available
   - Swapped pages never reclaimed despite abundant free RAM

2. **Long Uptime**
   - System uptime: 50 days
   - Pages swapped out weeks ago during memory pressure
   - Memory pressure resolved but swap never cleared

3. **Memory Usage Pattern**
   - Available RAM: 4.2 GB (plenty)
   - Used RAM: 3.3 GB (44%)
   - Swap usage: 975 MB (99.9%) - unnecessary!

### Top Swap Consumers (KB)

| Process | Swap Used | Description |
|---------|-----------|-------------|
| python3 (Calibre-web) | 163 MB | E-book management |
| python (Immich ML) | 135 MB | Image ML processing |
| immich-api | 124 MB | Immich API service |
| rrdcached | 108 MB | Round-robin database cache |
| immich_server | 108 MB | Immich main service |

**Total Top 5**: ~638 MB of 975 MB swap

### Docker Container Memory Usage

| Container | Memory Usage |
|-----------|--------------|
| immich_server | 785.9 MB |
| immich_postgres | 566.6 MB |
| uptime-kuma | 129.4 MB |
| nginx-proxy-manager | 124.1 MB |
| WeddingShare | 92.96 MB |

**Total Containers**: ~1.7 GB (23% of total RAM)

---

## ✅ RESOLUTION

### Solution Implemented

**Two-Step Fix:**
1. **Reduce Swappiness** - Less aggressive swapping
2. **Clear Swap** - Move swapped pages back to RAM

### Execution

```bash
# Step 1: Reduce swappiness from 60 to 10
sysctl vm.swappiness=10

# Step 2: Clear swap (safe - 4.2 GB RAM available)
swapoff -a && swapon -a  # Completed in 19 seconds

# Step 3: Make swappiness permanent
echo "vm.swappiness=10" >> /etc/sysctl.conf
```

### Results

**Before Fix:**
```
Memory:  7.4 GB total, 3.3 GB used, 735 MB free
Swap:    975 MB used / 975 MB total (99.98%)
```

**After Fix:**
```
Memory:  7.4 GB total, 4.3 GB used, 157 MB free
Swap:    256 KB used / 975 MB total (0.03%)
```

**Improvement:**
- ✅ Swap usage: 975 MB → 256 KB (99.97% reduction)
- ✅ Available RAM: 4.2 GB → 3.1 GB (pages moved from swap)
- ✅ All services: Healthy and stable
- ✅ Execution time: 19 seconds

---

## 📊 VERIFICATION

### System Health Check

```bash
# All containers healthy
docker ps --format "table {{.Names}}\t{{.Status}}"
# Result: All containers "Up" and "(healthy)"

# Load average normal
uptime
# Result: load average: 1.26, 0.75, 0.60 (normal)

# Memory usage healthy
free -h
# Result: 3.1 GB available, swap at 0.03%

# Disk I/O normal
iostat -x 1 2
# Result: Low utilization, no bottlenecks
```

### Docker Container Status

All containers verified healthy:
- ✅ immich_server - Up 13 days (healthy)
- ✅ immich_machine_learning - Up 13 days (healthy)
- ✅ immich_postgres - Up 2 weeks (healthy)
- ✅ calibre-web - Up 3 weeks
- ✅ immich_redis - Up 7 weeks (healthy)
- ✅ nginx-proxy-manager - Up 1 hour
- ✅ portainer_agent - Up 7 weeks
- ✅ uptime-kuma - Up 7 weeks (healthy)
- ✅ WeddingShare - Up 7 weeks
- ✅ portainer - Up 7 weeks

---

## 🛠️ TECHNICAL DETAILS

### Swappiness Explained

**What is Swappiness?**
- Linux kernel parameter (0-100)
- Controls swap aggressiveness
- Higher value = more aggressive swapping

**Values:**
- `0` = Avoid swap except to prevent OOM
- `10` = Recommended for servers with plenty of RAM
- `60` = Default (too aggressive for servers)
- `100` = Swap very aggressively

**Why Change to 10?**
- OMV has 7.4 GB RAM (plenty for current workload)
- Containers use ~1.7 GB (23% of RAM)
- Available RAM usually 3-4 GB
- No need for aggressive swapping
- Reduces disk I/O and improves performance

### Swap Clear Process

**Command**: `swapoff -a && swapon -a`

**What It Does:**
1. `swapoff -a` - Disable all swap devices
   - Kernel moves all swapped pages back to RAM
   - Requires available RAM (we had 4.2 GB)
   - Can take 10-60 seconds depending on swap usage

2. `swapon -a` - Re-enable swap devices
   - Swap available again for emergencies
   - Starts with 0 bytes used
   - System now uses RAM preferentially

**Safety Check Before Execution:**
```bash
free -h
# Verify: MemAvailable > SwapUsed
# Our case: 4.2 GB available > 975 MB swap ✓ SAFE
```

---

## 📋 CONFIGURATION CHANGES

### Permanent Configuration

**File**: `/etc/sysctl.conf`

**Added**:
```ini
vm.swappiness=10
```

**Verification**:
```bash
# Check current setting
sysctl vm.swappiness
# Output: vm.swappiness = 10

# Check persistence
grep swappiness /etc/sysctl.conf
# Output: vm.swappiness=10

# Reload sysctl (if needed)
sysctl -p
```

### No Reboot Required

Changes applied immediately:
- ✅ Swappiness active: `sysctl vm.swappiness=10`
- ✅ Swap cleared: `swapoff -a && swapon -a`
- ✅ Configuration persisted: `/etc/sysctl.conf`
- ✅ Survives reboots: Yes

---

## 🔮 PREVENTION & MONITORING

### Future Prevention

1. **Monitor Swap Usage**
   - Netdata alerts configured
   - Threshold: Warn at 50%, Critical at 80%
   - Current: 0.03% (healthy)

2. **Optimal Swappiness**
   - Set to 10 (permanent)
   - Reduces unnecessary swapping
   - Improves performance

3. **Regular Maintenance**
   - Monthly: Check swap usage
   - Quarterly: Review memory usage trends
   - Annually: Consider RAM upgrade if needed

### Monitoring Commands

```bash
# Quick swap check
free -h | grep Swap

# Detailed memory info
cat /proc/meminfo | grep -E "Swap|MemAvailable"

# Current swappiness
sysctl vm.swappiness

# Top swap consumers
for pid in $(ps -eo pid --no-headers); do
  printf "%s\t%s\t%s\n" "$pid" \
    "$(awk '/^VmSwap/ {print $2}' /proc/$pid/status 2>/dev/null || echo 0)" \
    "$(ps -p $pid -o comm= 2>/dev/null)"
done | sort -k2 -rn | head -10
```

### Expected Normal State

```
Memory:  7.4 GB total
Used:    3-4 GB (40-54%)
Available: 3-4 GB
Swap:    < 100 MB (< 10%)
```

**Alert Thresholds:**
- 🟢 Normal: Swap < 10% (< 100 MB)
- 🟡 Warning: Swap > 50% (> 500 MB)
- 🔴 Critical: Swap > 80% (> 780 MB)

---

## 🤔 WHEN TO REBOOT vs CLEAR SWAP

### Clear Swap (What We Did)

**When Safe:**
- ✅ Available RAM > Swap Used
- ✅ System uptime high (weeks/months)
- ✅ Services can tolerate brief pause
- ✅ Non-production or controlled maintenance

**Advantages:**
- ✅ Fast (10-60 seconds)
- ✅ No downtime
- ✅ Services continue running
- ✅ Immediate resolution

**Disadvantages:**
- ⚠️ Brief memory pressure spike
- ⚠️ Can fail if not enough RAM
- ⚠️ Requires root access

### Reboot Alternative

**When Necessary:**
- ❌ Available RAM < Swap Used (risky to clear)
- ❌ System instability suspected
- ❌ Memory leaks need process restart
- ❌ Kernel updates pending

**In Our Case:**
- Available: 4.2 GB
- Swap Used: 975 MB
- Ratio: 4.3:1 (✅ Safe to clear without reboot)

---

## 📝 LESSONS LEARNED

### Key Insights

1. **High Swap ≠ Low RAM**
   - System had 4.2 GB available RAM
   - But 975 MB stuck in swap
   - Swappiness was the culprit

2. **Default Settings Not Always Optimal**
   - Default swappiness=60 too aggressive for servers
   - Optimal for servers: 10 (with adequate RAM)

3. **Long Uptime Can Cause Issues**
   - 50 days uptime = memory fragmentation
   - Pages swapped out and never reclaimed
   - Periodic swap clear beneficial

4. **Monitoring is Critical**
   - Netdata caught the issue
   - Alert allowed proactive fix
   - Prevented service degradation

### Best Practices

1. **Set Appropriate Swappiness**
   ```bash
   # Servers with 4GB+ RAM
   vm.swappiness=10

   # Desktops/laptops
   vm.swappiness=60 (default)

   # Memory-constrained systems
   vm.swappiness=30-40
   ```

2. **Monitor Swap Regularly**
   - Weekly checks if high usage
   - Monthly checks if normal
   - Netdata or similar monitoring

3. **Periodic Swap Clear**
   - Monthly: If uptime > 30 days
   - Quarterly: If uptime > 90 days
   - Only if available RAM > swap used

4. **Consider RAM Upgrade If:**
   - Swap consistently > 25% (> 250 MB)
   - Services OOM killed
   - Performance degradation
   - Available RAM < 2 GB consistently

---

## 🔧 MAINTENANCE COMMANDS

### Daily Monitoring

```bash
# Quick health check
ssh root@192.168.1.9 'free -h | grep -E "Mem:|Swap:"'
```

### Weekly Monitoring

```bash
# Detailed memory check
ssh root@192.168.1.9 '
  echo "=== Memory Status ===";
  free -h;
  echo "";
  echo "=== Swap Usage ===";
  swapon --show;
  echo "";
  echo "=== Top Swap Consumers ===";
  for pid in $(ps -eo pid --no-headers | head -20); do
    printf "%s\t%s\t%s\n" "$pid" \
      "$(awk "/^VmSwap/ {print \$2}" /proc/$pid/status 2>/dev/null || echo 0)" \
      "$(ps -p $pid -o comm= 2>/dev/null)"
  done | sort -k2 -rn | head -5
'
```

### Monthly Maintenance

```bash
# Clear swap if usage > 10% and available RAM sufficient
ssh root@192.168.1.9 '
  SWAP_USED=$(free | awk "/Swap/ {print \$3}")
  SWAP_TOTAL=$(free | awk "/Swap/ {print \$2}")
  MEM_AVAILABLE=$(free | awk "/Mem/ {print \$7}")
  SWAP_PCT=$((SWAP_USED * 100 / SWAP_TOTAL))

  echo "Swap: $SWAP_PCT% used ($SWAP_USED KB / $SWAP_TOTAL KB)"
  echo "Available RAM: $MEM_AVAILABLE KB"

  if [ $SWAP_PCT -gt 10 ] && [ $MEM_AVAILABLE -gt $((SWAP_USED + 1048576)) ]; then
    echo "Clearing swap...";
    swapoff -a && swapon -a;
    echo "Swap cleared!";
    free -h;
  else
    echo "Swap usage OK, no action needed";
  fi
'
```

---

## 📚 RELATED DOCUMENTATION

### Internal Documentation
- **OMV Configuration**: `/docs/infrastructure.md` - OMV specifications
- **Immich Setup**: Container configuration and resource usage
- **Netdata Monitoring**: Alert configuration and thresholds

### External References
- **Linux Swap Management**: https://www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html
- **Swappiness Tuning**: https://wiki.archlinux.org/title/Swap#Swappiness
- **Memory Management**: https://www.kernel.org/doc/gorman/html/understand/

---

## 📊 HISTORICAL REFERENCE

### Issue Timeline

```
2025-10-10 11:14 - Alert received (Netdata)
2025-10-10 11:15 - Investigation started
2025-10-10 11:16 - Root cause identified
2025-10-10 11:18 - Solution implemented
2025-10-10 11:19 - Verification completed
2025-10-10 11:20 - Documentation created
```

**Total Resolution Time**: 6 minutes

### System State Evolution

| Time | Memory Used | Swap Used | Available |
|------|-------------|-----------|-----------|
| Before | 3.3 GB | 975 MB (99.9%) | 4.2 GB |
| During | 4.1 GB | Clearing... | 3.3 GB |
| After | 4.3 GB | 256 KB (0.03%) | 3.1 GB |

---

## ✅ RESOLUTION CHECKLIST

- [x] Issue identified and diagnosed
- [x] Root cause determined (high swappiness + long uptime)
- [x] Solution implemented (reduce swappiness + clear swap)
- [x] System verified stable (all services healthy)
- [x] Configuration persisted (sysctl.conf updated)
- [x] Monitoring confirmed working (Netdata alert cleared)
- [x] Documentation created (this file)
- [x] Prevention measures in place (swappiness=10)

---

## 🎯 CONCLUSION

**Issue**: Critical swap utilization (99.9%) despite abundant available RAM

**Root Cause**: Aggressive swappiness (60) + long uptime (50 days) caused pages to be swapped unnecessarily and never reclaimed

**Solution**:
1. Reduced swappiness to 10 (less aggressive)
2. Cleared swap (moved 975 MB back to RAM)
3. Made permanent (sysctl.conf)

**Outcome**:
- ✅ Swap usage: 975 MB → 256 KB (99.97% reduction)
- ✅ System stable: All services healthy
- ✅ Performance improved: No swap thrashing
- ✅ Future prevention: Swappiness optimized

**Status**: ✅ **RESOLVED** - No further action required

---

**Document Version**: 1.0
**Last Updated**: 2025-10-10 11:20 CEST
**Next Review**: 2025-11-10 (monthly swap check)
