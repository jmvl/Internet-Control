# OpenWrt SQM Throttling Issue Resolution - September 8, 2025

## Issue Summary

Multiple WiFi interfaces were experiencing persistent throttling despite attempts to restore normal speeds. The main networks (Znutar and Znutar_2) were limited to 10 Mbps upload while their backup counterparts had full unrestricted speeds.

## Problem Description

### Affected Interfaces
- **phy0-ap0 (Znutar)**: Throttled to 10 Mbps upload via SQM
- **phy1-ap0 (Znutar_2)**: Throttled to 10 Mbps upload via SQM
- **phy0-ap1 (Znutar_BACKUP)**: Full speed (no SQM)
- **phy1-ap1 (Znutar_2_BACKUP)**: Full speed (no SQM)

### Symptoms
- Main WiFi networks had significantly slower upload speeds
- Backup networks performed at full internet speed
- UCI configuration showed "normal" speeds (85000/10000 kbps) but traffic control was still active
- SQM service restart didn't clear the throttling

## Root Cause Analysis

### Duplicate SQM Configurations
The system had **multiple SQM configurations** targeting the same interfaces:

```bash
# For phy0-ap0
sqm.wifi_phy0ap0.interface='phy0-ap0'      # Disabled but present
sqm.throttle_phy0_ap0.interface='phy0-ap0'  # Enabled and active

# For phy1-ap0  
sqm.wifi_phy1ap0.interface='phy1-ap0'      # Initially enabled
sqm.throttle_phy1_ap0.interface='phy1-ap0' # Also enabled
```

### Traffic Control Evidence
The traffic control showed active throttling despite UCI showing "normal" speeds:

```bash
# Throttled interface (before fix)
phy1-ap0: qdisc cake 8165: root bandwidth 10Mbit

# Unrestricted interface
phy1-ap1: qdisc noqueue 0: root refcnt 2
```

### Script Restoration Attempts
The enhanced restoration script was working correctly - it was setting UCI values to 85000/10000 kbps (which are the configured "normal" speeds). However, these speeds were still restrictive compared to the full internet connection speed.

## Resolution Steps

### 1. Identify Active SQM Configurations
```bash
# Check all SQM configs affecting phy1-ap0
uci show sqm | grep phy1-ap0

# Check which configs are enabled
uci get sqm.wifi_phy1ap0.enabled
uci get sqm.throttle_phy1_ap0.enabled
```

### 2. Disable SQM on Main Networks
```bash
# Disable SQM for phy1-ap0 (Znutar_2)
uci set sqm.throttle_phy1_ap0.enabled=0
uci delete sqm.wifi_phy1ap0  # Remove duplicate config
uci commit sqm

# Disable SQM for phy0-ap0 (Znutar)  
uci set sqm.throttle_phy0_ap0.enabled=0
uci delete sqm.wifi_phy0ap0  # Remove duplicate config
uci commit sqm
```

### 3. Restart SQM Service
```bash
/etc/init.d/sqm restart
```

### 4. Verification
```bash
# Check traffic control is cleared
tc qdisc show dev phy0-ap0  # Should show 'noqueue'
tc qdisc show dev phy1-ap0  # Should show 'noqueue'

# Verify all interfaces have same status
echo "phy0-ap0:"; tc qdisc show dev phy0-ap0 | head -1
echo "phy0-ap1:"; tc qdisc show dev phy0-ap1 | head -1  
echo "phy1-ap0:"; tc qdisc show dev phy1-ap0 | head -1
echo "phy1-ap1:"; tc qdisc show dev phy1-ap1 | head -1
```

## Final Results

All 4 WiFi interfaces now have identical unrestricted bandwidth:

```
phy0-ap0 (Znutar):        qdisc noqueue 0: root refcnt 2
phy0-ap1 (Znutar_BACKUP): qdisc noqueue 0: root refcnt 2
phy1-ap0 (Znutar_2):      qdisc noqueue 0: root refcnt 2  
phy1-ap1 (Znutar_2_BACKUP): qdisc noqueue 0: root refcnt 2
```

## Prevention Measures

### 1. Updated Restoration Script
The `multi_wifi_control_enhanced_fixed.sh` script was improved to:
- Find ALL SQM configurations (not just `throttle_*` prefixed ones)
- Provide detailed error checking and logging
- Add proper delays between service stop/start operations
- Include force restore option for complete SQM removal

### 2. SQM Configuration Best Practices
- Avoid duplicate SQM configurations for the same interface
- Use consistent naming conventions (`throttle_*` prefix)
- Always verify traffic control after SQM service restarts
- Consider disabling SQM entirely for full-speed networks

### 3. Diagnostic Tools
Created `debug_sqm_status.sh` script for comprehensive SQM analysis:
- Shows all UCI SQM configurations
- Displays traffic control settings per interface  
- Lists available network interfaces
- Provides SQM service logs and process information

## Commands Reference

### Check Current SQM Status
```bash
/root/scripts/debug_sqm_status.sh
```

### Force Restore All Interfaces  
```bash
/root/scripts/multi_wifi_control_enhanced_fixed.sh force
```

### Manual SQM Management
```bash
# List all SQM configs
uci show sqm

# Disable specific interface
uci set sqm.throttle_phy0_ap0.enabled=0
uci commit sqm
/etc/init.d/sqm restart

# Check traffic control
tc qdisc show dev phy0-ap0
```

## Lessons Learned

1. **UCI vs Actual Traffic Control**: UCI configuration showing "normal" speeds doesn't guarantee traffic control is cleared. Always verify with `tc qdisc show`.

2. **Service Restart Importance**: Changes to SQM UCI configuration require a complete service restart to take effect on traffic control.

3. **Duplicate Configuration Issues**: Multiple SQM configurations targeting the same interface can cause conflicts and unexpected behavior.

4. **Backup Network Strategy**: Having backup networks without SQM provided a good comparison point to identify the throttling issue.

5. **Script Limitations**: The original restoration script worked correctly but restored to "configured normal" speeds rather than truly unlimited speeds.

## File Locations

- **Enhanced Script**: `/root/scripts/multi_wifi_control_enhanced_fixed.sh`
- **Debug Script**: `/root/scripts/debug_sqm_status.sh`  
- **SQM Configuration**: `/etc/config/sqm`
- **SQM Service**: `/etc/init.d/sqm`

---

**Resolution Date**: September 8, 2025  
**OpenWrt Version**: 21.02+  
**Affected Router**: 192.168.1.2 (Primary OpenWrt Router)