# OPNsense Internet Addiction Control - Deployment Instructions

## Overview
This script automatically configures time-based internet restrictions for specific devices (Rica's iPhone and MacBook Air) to help manage internet addiction.

## What It Does
- **Identifies target devices** by MAC address
- **Creates device alias** for easy management
- **Sets up traffic throttling** to 64 Kbit/s (dial-up speed)
- **Configures midnight restrictions** (00:00 - 06:00)
- **Provides manual setup instructions** for components requiring web interface

## Target Devices
- **Rica iPhone 1**: `f6:d0:95:cd:52:13`
- **Rica iPhone 2**: `12:24:46:0c:b3:1d`
- **Rica MacBook Air**: `66:46:fb:9c:0a:0a`

## Deployment Steps

### Step 1: Transfer Script to OPNsense
```bash
# From your local machine, copy the script to OPNsense
scp opnsense_addiction_control.sh root@192.168.1.3:/tmp/

# Or alternatively, SSH into OPNsense and create the file directly
ssh root@192.168.1.3
```

### Step 2: Run the Script on OPNsense Console
```bash
# SSH into OPNsense
ssh root@192.168.1.3

# Make script executable
chmod +x /tmp/opnsense_addiction_control.sh

# Run the setup
/tmp/opnsense_addiction_control.sh
```

### Step 3: Complete Manual Configuration
The script will provide detailed instructions for:

1. **Creating the Schedule** (Firewall → Schedules)
   - Name: `midnight_restriction`
   - Time: 00:00 - 06:00
   - Days: All days

2. **Creating Firewall Rules** (Firewall → Rules → LAN192)
   - Block internet access for `restricted_devices` alias
   - During `midnight_restriction` schedule

## Script Commands

```bash
# Run full setup
./opnsense_addiction_control.sh

# Check device status
./opnsense_addiction_control.sh status

# Remove all configurations
./opnsense_addiction_control.sh cleanup

# Show help
./opnsense_addiction_control.sh help
```

## Configuration Options

### Restriction Levels

**Option 1: Complete Block (Recommended)**
- Completely blocks internet access during restriction hours
- Allows local network access only
- Most effective for addiction control

**Option 2: Traffic Throttling**
- Limits speed to 64 Kbit/s (dial-up speed)
- Allows basic connectivity but makes browsing frustrating
- Less harsh but still effective

### Timing Adjustments
Modify these variables in the script:
```bash
RESTRICTION_START="00:00"  # Start time
RESTRICTION_END="06:00"    # End time
```

### Bandwidth Throttling
Adjust throttle speed:
```bash
THROTTLE_BANDWIDTH="64"    # Kbit/s
THROTTLE_METRIC="Kbit"     # or "Mbit"
```

## Monitoring and Management

### Check if Devices are Active
```bash
# From OPNsense console
arp -a | grep -E "(f6:d0:95:cd:52:13|12:24:46:0c:b3:1d|66:46:fb:9c:0a:0a)"
```

### View Firewall Logs
```bash
# Monitor blocked connections
tail -f /var/log/filter.log | grep "restricted_devices"
```

### Web Interface Monitoring
- **Status → System Logs → Firewall**: View blocked connections
- **Status → Interfaces**: Check device connectivity
- **Firewall → Aliases**: Manage restricted devices list

## Troubleshooting

### Common Issues

**1. Script Fails to Create Alias**
- Check API credentials in script
- Verify OPNsense API is enabled
- Ensure proper permissions for MCP user

**2. Rules Not Working**
- Verify schedule is created correctly
- Check firewall rule order (rules are processed top to bottom)
- Ensure alias contains correct MAC addresses

**3. Devices Still Have Internet Access**
- Check if devices are using different MAC addresses (randomized MAC)
- Verify devices are on the correct network interface (LAN192)
- Check if VPN or cellular data is being used

### MAC Address Randomization
Modern devices randomize MAC addresses. To handle this:

1. **Disable MAC randomization** on target devices:
   - **iOS**: Settings → Wi-Fi → Network → Private Wi-Fi Address (Off)
   - **macOS**: System Preferences → Network → Wi-Fi → Advanced → Wi-Fi tab

2. **Use DHCP reservations** to track devices by IP instead
3. **Monitor ARP table** to identify new MAC addresses

## Advanced Configuration

### Add More Devices
Edit the script variables:
```bash
# Add more MAC addresses
ADDITIONAL_DEVICE="aa:bb:cc:dd:ee:ff"
```

### Different Time Schedules
Create multiple schedules for different restriction levels:
- Light restrictions: 23:00 - 07:00
- Heavy restrictions: 00:00 - 06:00
- Study time: 14:00 - 17:00

### Whitelist Essential Services
Allow access to specific services during restrictions:
- Emergency services
- Educational websites
- Family communication apps

## Security Considerations

- **Bypass Prevention**: Users may try to:
  - Change MAC addresses
  - Use VPN or cellular data
  - Connect to different networks
  - Use different devices

- **Enforcement**: Consider additional measures:
  - Router-level controls
  - Device-level parental controls
  - Physical device management

## Backup and Restore

### Backup Current Configuration
```bash
# Before running script, backup current config
curl -k -u "API_KEY:API_SECRET" https://192.168.1.3/api/core/backup/backup > backup.xml
```

### Restore if Needed
Use OPNsense web interface: System → Configuration → Backups → Restore

## Support and Maintenance

### Regular Tasks
- Monitor effectiveness weekly
- Adjust timing as needed
- Update device MAC addresses if changed
- Review firewall logs for bypass attempts

### Script Updates
Keep the script updated as OPNsense API evolves or requirements change.