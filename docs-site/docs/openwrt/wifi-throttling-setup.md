# WiFi-Specific Throttling Setup Guide

## Overview

The `openwrt_wifi_throttle_setup.sh` script provides WiFi-specific bandwidth throttling instead of throttling the entire WAN connection. This allows you to:

- Throttle specific WiFi networks (BSSID) while keeping others at full speed
- Maintain backup WiFi networks that aren't affected by throttling
- Create targeted restrictions for specific devices or users

## Key Differences from WAN Throttling

### Original WAN Throttling (`openwrt_time_throttle_setup_v2.sh`)
- **Target**: Entire WAN interface (ethernet connection)
- **Effect**: ALL devices get throttled (wired + wireless)
- **Backup**: No backup internet access during throttling
- **Use Case**: Whole-network throttling

### New WiFi Throttling (`openwrt_wifi_throttle_setup.sh`)
- **Target**: Specific WiFi interface/BSSID
- **Effect**: Only devices on selected WiFi network get throttled
- **Backup**: Other WiFi networks remain at full speed
- **Use Case**: Selective device/user throttling

## Prerequisites

- OpenWrt router with multiple WiFi interfaces/networks
- Root access to the router
- SQM (Smart Queue Management) support

## Quick Setup

1. **Copy the script to your OpenWrt router**:
   ```bash
   scp openwrt_wifi_throttle_setup.sh root@router_ip:/tmp/
   ```

2. **Make executable and run**:
   ```bash
   ssh root@router_ip
   chmod +x /tmp/openwrt_wifi_throttle_setup.sh
   /tmp/openwrt_wifi_throttle_setup.sh
   ```

3. **Follow the interactive prompts**:
   - Select WiFi interface to throttle
   - Configure speed settings
   - Confirm setup

## Configuration Options

### Speed Settings
- **Normal Download/Upload**: Full-speed settings (default: 85000/10000 kbps)
- **Throttled Download/Upload**: Restricted speeds (default: 64/64 kbps)
- **Study Mode**: Moderate throttling (1000/500 kbps)

### Time Settings
- **Throttle Start**: When to begin throttling (default: 00:00)
- **Throttle End**: When to restore normal speeds (default: 06:00)

### Customization
All settings can be modified during setup or by editing the script variables:
```bash
NORMAL_DOWNLOAD="85000"     # Normal download speed in kbit/s
NORMAL_UPLOAD="10000"       # Normal upload speed in kbit/s
THROTTLE_DOWNLOAD="64"      # Throttled download speed in kbit/s
THROTTLE_UPLOAD="64"        # Throttled upload speed in kbit/s
THROTTLE_START="00:00"      # Start throttling time
THROTTLE_END="06:00"        # End throttling time
```

## Usage Examples

### Example 1: Family Internet Control
**Scenario**: Family has main WiFi for parents, guest WiFi for children
- **Main WiFi**: `wlan0` (always full speed)
- **Guest WiFi**: `wlan1` (throttled during night hours)

**Setup**:
1. Run script and select `wlan1`
2. Configure night-time throttling (00:00-06:00)
3. Children's devices connect to guest WiFi
4. Parents' devices use main WiFi (unaffected)

### Example 2: Multi-SSID Setup
**Scenario**: Multiple WiFi networks for different purposes
- **Work WiFi**: `wlan0-1` (always full speed)
- **Personal WiFi**: `wlan0-2` (throttled during work hours)
- **Kids WiFi**: `wlan1` (heavily throttled)

**Setup**:
1. Run script for each WiFi network you want to throttle
2. Configure different schedules for each network
3. Each network gets independent throttling control

## Created Files and Commands

### Scripts Created
- `/root/scripts/wifi_throttle.sh` - Enable WiFi throttling
- `/root/scripts/wifi_normal_speed.sh` - Restore normal speeds
- `/root/scripts/wifi_study_throttle.sh` - Moderate throttling
- `/root/scripts/check_wifi_throttle_status.sh` - Status checker
- `/root/scripts/wifi_throttle_control.sh` - Manual control

### Command Aliases
After setup, these commands are available:
```bash
wifi-throttle on      # Enable throttling manually
wifi-throttle off     # Disable throttling manually
wifi-throttle study   # Enable study mode throttling
wifi-throttle status  # Check current status
wifi-throttle-status  # Detailed status report
```

### Cron Jobs
Automatic scheduling is configured via crontab:
```bash
# Enable throttling at midnight
0 0 * * * /root/scripts/wifi_throttle.sh

# Restore normal speeds at 6 AM
0 6 * * * /root/scripts/wifi_normal_speed.sh
```

## Monitoring and Troubleshooting

### Check Status
```bash
wifi-throttle-status
```

### View Logs
```bash
logread | grep WiFi-Throttle
```

### Manual Control
```bash
# Force throttling on
wifi-throttle on

# Force throttling off
wifi-throttle off

# Check current speeds
uci show sqm | grep wifi
```

### Verify SQM Configuration
```bash
# Check SQM status
/etc/init.d/sqm status

# View SQM configuration
uci show sqm
```

## Advanced Configuration

### Multiple WiFi Networks
To throttle multiple WiFi networks with different schedules:

1. Run the setup script multiple times
2. Select different WiFi interfaces each time
3. Configure different time schedules
4. Each network gets its own SQM configuration

### Custom Schedules
Edit the crontab directly for custom schedules:
```bash
crontab -e
```

Example custom schedules:
```bash
# Weekday restrictions (more strict)
0 22 * * 1-5 /root/scripts/wifi_throttle.sh       # 10 PM
0 7 * * 1-5 /root/scripts/wifi_normal_speed.sh    # 7 AM

# Weekend restrictions (more lenient)
0 1 * * 6,0 /root/scripts/wifi_throttle.sh        # 1 AM
0 9 * * 6,0 /root/scripts/wifi_normal_speed.sh    # 9 AM
```

## Security Considerations

### Access Control
- Only root can modify throttling settings
- Configuration files are protected
- Cron jobs run with root privileges

### Bypass Prevention
- WiFi throttling is applied at the interface level
- Switching between WiFi networks may allow bypass
- Consider additional firewall rules if needed

### Monitoring
- All throttling events are logged
- Status can be checked remotely
- Automated alerts can be configured

## Troubleshooting

### Common Issues

**1. WiFi interface not found**
- Check interface exists: `iw dev`
- Verify interface is up: `ip link show`
- Check wireless configuration: `uci show wireless`

**2. SQM not working**
- Verify SQM is installed: `opkg list-installed | grep sqm`
- Check SQM service: `/etc/init.d/sqm status`
- Review SQM logs: `logread | grep sqm`

**3. Throttling not activating**
- Check cron service: `/etc/init.d/cron status`
- Verify cron jobs: `crontab -l`
- Check script permissions: `ls -l /root/scripts/`

**4. Multiple WiFi networks affected**
- Verify correct interface selected
- Check SQM configuration: `uci show sqm`
- Ensure different SQM instances for different interfaces

### Reset Configuration
To completely reset the WiFi throttling setup:
```bash
# Remove cron jobs
crontab -r

# Remove scripts
rm -rf /root/scripts/wifi_*

# Remove SQM configuration
uci delete sqm.wifi_wlan0  # Replace with your interface
uci commit sqm
/etc/init.d/sqm restart
```

## Comparison with Original Script

| Feature | WAN Throttling | WiFi Throttling |
|---------|---------------|-----------------|
| Target | Entire WAN interface | Specific WiFi interface |
| Devices Affected | All devices | Only devices on selected WiFi |
| Backup Access | None during throttling | Other WiFi networks available |
| Granularity | Network-wide | Per-WiFi network |
| Use Case | Whole-family restrictions | Selective user restrictions |
| Complexity | Simple | Moderate |
| Flexibility | Limited | High |

## Best Practices

1. **Test thoroughly** before deploying in production
2. **Keep backup WiFi** networks for emergency access
3. **Monitor logs** regularly for issues
4. **Document configuration** for future reference
5. **Update firmware** and packages regularly
6. **Use strong passwords** for all WiFi networks
7. **Regular backups** of configuration files

## Support

For issues or questions:
1. Check the logs first: `logread | grep WiFi`
2. Verify configuration: `wifi-throttle-status`
3. Review this documentation
4. Check OpenWrt forums and documentation