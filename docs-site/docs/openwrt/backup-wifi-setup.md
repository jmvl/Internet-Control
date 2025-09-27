# Backup WiFi Networks Setup Guide

## Overview

The `openwrt_backup_wifi_setup.sh` script creates hidden backup WiFi networks that provide full-speed internet access even during throttling periods. These networks are essential for maintaining emergency connectivity when your main networks are throttled.

## Key Features

- **Hidden SSIDs**: Networks don't broadcast their BSSID (not visible in WiFi scans)
- **Full Speed**: NOT affected by throttling scripts
- **Same Security**: Inherits security settings from original networks
- **Emergency Access**: Provides backup connectivity during restrictions

## How It Works

### Network Structure After Setup:
```
Original Networks:           Backup Networks (Hidden):
- ZNUTAR (throttled)    →    - ZNUTAR_BACKUP (full speed, hidden)
- ZNUTAR_2 (throttled)  →    - ZNUTAR_2_BACKUP (full speed, hidden)
```

### Throttling Behavior:
- **Midnight-6AM**: Main networks throttled to 64 kbps
- **Backup networks**: Always full speed (85 Mbps)
- **Your devices**: Connect to backup networks for full access

## Quick Setup

1. **Copy script to router**:
   ```bash
   scp openwrt_backup_wifi_setup.sh root@192.168.1.2:/tmp/
   ```

2. **Run setup**:
   ```bash
   ssh root@192.168.1.2
   chmod +x /tmp/openwrt_backup_wifi_setup.sh
   /tmp/openwrt_backup_wifi_setup.sh
   ```

3. **Follow prompts**:
   - Select networks to clone (e.g., both ZNUTAR and ZNUTAR_2)
   - Configure SSID suffix (default: "_BACKUP")
   - Set password (optional - can use original passwords)

## Configuration Options

### SSID Naming
- **Default suffix**: `_BACKUP`
- **Example**: `ZNUTAR` becomes `ZNUTAR_BACKUP`
- **Customizable**: You can choose your own suffix

### Security Settings
- **Encryption**: Same as original networks
- **Password Options**:
  - Use original passwords (default)
  - Set custom password for all backup networks

### Hidden SSID Configuration
- **Broadcasting**: Disabled (`hidden='1'`)
- **Visibility**: Networks won't appear in WiFi scans
- **Manual Connection**: Must be added manually to devices

## Connection Instructions

### For Each Device:

1. **Go to WiFi Settings**
2. **Select "Add Network" or "Other Network"**
3. **Enter Details**:
   - **SSID**: `ZNUTAR_BACKUP` (or your chosen name)
   - **Security**: Same as original (e.g., WPA2-PSK)
   - **Password**: Your configured password
4. **Connect**

### Example Connection:
```
Network Name: ZNUTAR_BACKUP
Security: WPA2-PSK
Password: [your_password]
Hidden Network: Yes
```

## Management Commands

After setup, these commands are available:

```bash
backup-wifi status    # Check backup network status
backup-wifi guide     # View connection instructions
backup-wifi enable    # Enable all backup networks
backup-wifi disable   # Disable all backup networks
```

## Generated Files

### Connection Guide
- **Location**: `/root/backup_wifi_guide.txt`
- **Contents**: Detailed connection instructions for each backup network
- **View**: `cat /root/backup_wifi_guide.txt`

### Management Script
- **Location**: `/root/scripts/backup_wifi_control.sh`
- **Purpose**: Enable/disable backup networks
- **Alias**: `backup-wifi`

## Integration with Throttling System

### Throttling Compatibility
- **Main networks**: Affected by `multi-wifi-throttle` commands
- **Backup networks**: NEVER affected by throttling
- **Independent operation**: Backup networks work regardless of throttling status

### Usage Strategy
1. **Normal times**: Use main networks (ZNUTAR, ZNUTAR_2)
2. **Throttling active**: Switch to backup networks (ZNUTAR_BACKUP, ZNUTAR_2_BACKUP)
3. **Emergency access**: Always available via backup networks

## Example Scenarios

### Scenario 1: Midnight Throttling
**Time**: 00:00 - 06:00
- **Main networks**: Throttled to 64 kbps
- **Your devices**: Connected to `ZNUTAR_BACKUP` (full speed)
- **Other users**: Stuck on throttled networks

### Scenario 2: Manual Throttling
**Command**: `multi-wifi-throttle on`
- **Main networks**: Throttled immediately
- **Your devices**: Unaffected on backup networks
- **Work continues**: Full speed access maintained

### Scenario 3: Study Time
**Command**: `multi-wifi-throttle study`
- **Main networks**: Limited to 1 Mbps
- **Your devices**: Full speed on backup networks
- **Productivity**: No interruption to your work

## Advanced Configuration

### Multiple Device Setup
For each personal device:
1. Add backup networks to saved WiFi
2. Set backup networks as high priority
3. Configure automatic connection

### Network Priorities
```
Priority 1: ZNUTAR_BACKUP (hidden, full speed)
Priority 2: ZNUTAR_2_BACKUP (hidden, full speed)
Priority 3: ZNUTAR (visible, may be throttled)
Priority 4: ZNUTAR_2 (visible, may be throttled)
```

### Custom Scheduling
Since backup networks are separate, you can:
- Use different scheduling for different purposes
- Have work-specific backup networks
- Create guest-specific limitations

## Security Considerations

### Access Control
- **Hidden networks**: Reduced discovery by casual users
- **Strong passwords**: Same security as main networks
- **Limited knowledge**: Only you know backup network names

### Network Isolation
- **Same LAN**: Backup networks use same network segment
- **Firewall rules**: Can be configured independently
- **MAC filtering**: Can be applied separately

### Password Management
- **Unique passwords**: Consider different passwords for backup networks
- **Regular rotation**: Change passwords periodically
- **Secure storage**: Document passwords securely

## Troubleshooting

### Common Issues

**1. Backup networks not visible**
- **Expected behavior**: Networks are hidden by design
- **Solution**: Manually add to devices using network name

**2. Can't connect to backup network**
- **Check SSID**: Ensure exact spelling (case-sensitive)
- **Check password**: Verify password is correct
- **Check security type**: Match original network security

**3. Backup network not working**
- **Check status**: `backup-wifi status`
- **Restart wireless**: `wifi down && wifi up`
- **Check configuration**: `uci show wireless | grep backup`

**4. Backup network being throttled**
- **Not expected**: Backup networks should never be throttled
- **Check scripts**: Verify throttling scripts target correct interfaces
- **Check naming**: Ensure backup interfaces have different names

### Reset Backup Networks
```bash
# Remove all backup configurations
uci show wireless | grep backup | cut -d'=' -f1 | while read section; do
    uci delete "$section"
done
uci commit wireless
wifi down && wifi up
```

### Re-run Setup
```bash
# Run the setup script again to recreate
/tmp/openwrt_backup_wifi_setup.sh
```

## Best Practices

### Device Configuration
1. **Pre-configure**: Add backup networks to all your devices before throttling starts
2. **Test connectivity**: Verify backup networks work before relying on them
3. **Document settings**: Keep connection details secure but accessible

### Network Management
1. **Regular monitoring**: Check backup network status periodically
2. **Password rotation**: Update passwords regularly
3. **Capacity planning**: Monitor usage to ensure sufficient bandwidth

### Emergency Procedures
1. **Quick access**: Know backup network names and passwords by heart
2. **Multiple devices**: Configure backup on phone, laptop, and other devices
3. **Fallback plan**: Have alternative internet access if needed

## Integration Examples

### Personal Schedule
```bash
# Morning: Check if throttling is active
multi-wifi-throttle status

# If throttled: Use backup network
# Connect to: ZNUTAR_BACKUP

# Evening: Normal networks available
# Connect to: ZNUTAR
```

### Work From Home Setup
```bash
# Work hours: Backup network for reliable connection
# Personal time: Main network (may be throttled)
# Emergency: Always have backup access
```

## Summary

The backup WiFi system provides:
- **Reliability**: Always-available full-speed internet
- **Flexibility**: Independent from throttling system
- **Security**: Hidden networks with strong encryption
- **Convenience**: Easy management and monitoring

This ensures you always have emergency internet access while the throttling system manages other users' connectivity appropriately.