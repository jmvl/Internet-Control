# OpenWrt Time-Based Bandwidth Throttling Guide

## Overview
This guide explains how to configure time-based bandwidth throttling on OpenWrt using SQM (Smart Queue Management) and cron jobs. This allows you to automatically adjust internet speeds during specific hours (e.g., limiting bandwidth during midnight hours for addiction control).

## Prerequisites
- OpenWrt router with LuCI web interface
- SSH access to your OpenWrt router
- Basic understanding of command line

## Part 1: Setting Up SQM (Smart Queue Management)

### Step 1: Install Required Packages
SSH into your OpenWrt router and install SQM:
```bash
ssh root@192.168.1.2
opkg update
opkg install luci-app-sqm sqm-scripts
```

### Step 2: Access SQM Configuration in LuCI
1. Open your browser and navigate to: `http://192.168.1.2`
2. Login with your credentials
3. Navigate to: **Network → SQM QoS**

### Step 3: Configure Basic SQM Settings
Based on your screenshots, configure the following:

#### Basic Settings Tab:
1. **Enable this SQM instance**: ✓ Check this box
2. **Interface name**: Select your WAN interface (e.g., `phy0-ap0` or your internet-facing interface)
3. **Download speed (ingress)**: 85000 (85 Mbps - set to 90% of your actual speed)
4. **Upload speed (egress)**: 10000 (10 Mbps - set to 90% of your actual speed)
5. **Enable debug logging**: Leave unchecked unless troubleshooting
6. **Log verbosity**: info (default)

#### Queue Discipline Tab:
1. **Queueing discipline**: Select `cake` (recommended)
2. **Queue setup script**: Select `piece_of_cake.qos`

#### Link Layer Adaptation Tab:
1. **Link layer**: Select `none (default)` or appropriate for your connection type

### Step 4: Save and Apply
Click **Save & Apply** to activate SQM with your current settings.

## Part 2: Creating Time-Based Throttling Scripts

### Step 1: Create Throttling Scripts
SSH into your router and create two scripts:

#### Script 1: Enable Throttling (midnight_throttle.sh)
```bash
cat > /root/midnight_throttle.sh << 'EOF'
#!/bin/sh
# Midnight throttling script - Limits bandwidth to dial-up speeds

# Stop SQM first
/etc/init.d/sqm stop

# Update SQM configuration for throttling
uci set sqm.eth1.download='64'    # 64 kbps download
uci set sqm.eth1.upload='64'      # 64 kbps upload
uci commit sqm

# Restart SQM with new settings
/etc/init.d/sqm start

# Log the action
logger -t "SQM-Throttle" "Midnight throttling activated - 64kbps limit"
EOF

chmod +x /root/midnight_throttle.sh
```

#### Script 2: Restore Normal Speed (normal_speed.sh)
```bash
cat > /root/normal_speed.sh << 'EOF'
#!/bin/sh
# Normal speed restoration script

# Stop SQM first
/etc/init.d/sqm stop

# Update SQM configuration for normal speeds
uci set sqm.eth1.download='85000'  # 85 Mbps download
uci set sqm.eth1.upload='10000'    # 10 Mbps upload
uci commit sqm

# Restart SQM with new settings
/etc/init.d/sqm start

# Log the action
logger -t "SQM-Throttle" "Normal speeds restored"
EOF

chmod +x /root/normal_speed.sh
```

### Step 2: Test the Scripts
Test both scripts to ensure they work:
```bash
# Test throttling
/root/midnight_throttle.sh

# Check SQM status
/etc/init.d/sqm status

# Test normal speed restoration
/root/normal_speed.sh
```

## Part 3: Setting Up Cron Jobs for Automatic Scheduling

### Step 1: Access Cron Configuration
```bash
# Edit crontab
crontab -e
```

### Step 2: Add Time-Based Rules
Add the following lines to schedule automatic throttling:
```cron
# Enable throttling at midnight (00:00)
0 0 * * * /root/midnight_throttle.sh

# Restore normal speeds at 6 AM (06:00)
0 6 * * * /root/normal_speed.sh
```

### Step 3: Alternative - More Complex Schedule
For different speeds at different times:
```cron
# Weekday schedule
0 0 * * 1-5 /root/midnight_throttle.sh    # Midnight on weekdays
0 6 * * 1-5 /root/normal_speed.sh         # 6 AM on weekdays

# Weekend schedule - later restrictions
0 1 * * 6,0 /root/midnight_throttle.sh    # 1 AM on weekends
0 8 * * 6,0 /root/normal_speed.sh         # 8 AM on weekends

# Study time throttling (3 PM - 5 PM on weekdays)
0 15 * * 1-5 /root/study_throttle.sh      # Moderate throttling
0 17 * * 1-5 /root/normal_speed.sh        # Restore after study
```

### Step 4: Verify Cron Jobs
```bash
# List current cron jobs
crontab -l

# Check cron service is running
/etc/init.d/cron status

# Restart cron if needed
/etc/init.d/cron restart
```

## Part 4: Advanced Configuration - Per-Device Throttling

### Step 1: Install nft-qos for Device-Specific Control
```bash
opkg install luci-app-nft-qos
```

### Step 2: Configure Device-Specific Rules
1. Navigate to: **Services → QoS over Nftables**
2. In **Limit Rate** tab, add specific devices:
   - Rica iPhone 1: `f6:d0:95:cd:52:13` - Download: 64 KB/s, Upload: 64 KB/s
   - Rica iPhone 2: `12:24:46:0c:b3:1d` - Download: 64 KB/s, Upload: 64 KB/s
   - Rica MacBook: `66:46:fb:9c:0a:0a` - Download: 64 KB/s, Upload: 64 KB/s

### Step 3: Create Device-Specific Time Scripts
```bash
cat > /root/device_throttle.sh << 'EOF'
#!/bin/sh
# Enable device-specific throttling

# Add nftables rules for specific devices
nft add rule inet nft-qos-monitor upload ip saddr 192.168.1.160 limit rate 64 kbytes/second
nft add rule inet nft-qos-monitor download ip daddr 192.168.1.160 limit rate 64 kbytes/second

logger -t "Device-Throttle" "Device-specific throttling enabled"
EOF

chmod +x /root/device_throttle.sh
```

## Part 5: Monitoring and Troubleshooting

### Check SQM Status
```bash
# View current SQM settings
uci show sqm

# Check SQM service status
/etc/init.d/sqm status

# View SQM logs
logread | grep -i sqm
```

### Monitor Bandwidth Usage
```bash
# Real-time bandwidth monitoring
iftop -i br-lan

# Check connection states
conntrack -L
```

### Troubleshooting Common Issues

#### Issue 1: Scripts Not Running
- Check script permissions: `ls -la /root/*.sh`
- Test scripts manually: `/root/midnight_throttle.sh`
- Check cron logs: `logread | grep cron`

#### Issue 2: SQM Not Limiting Properly
- Verify interface name: `uci get sqm.eth1.interface`
- Check if SQM is running: `ps | grep sqm`
- Review SQM configuration: `cat /etc/config/sqm`

#### Issue 3: Time Zone Issues
```bash
# Check current time
date

# Set correct timezone
uci set system.@system[0].timezone='PST8PDT'
uci commit system
/etc/init.d/system restart
```

## Part 6: Best Practices

### 1. Gradual Implementation
- Start with SQM only
- Test manual throttling first
- Add automation after confirming functionality

### 2. Bandwidth Settings
- Set limits to 85-90% of actual ISP speeds
- Use lower values if experiencing bufferbloat
- Adjust based on real-world testing

### 3. Logging and Monitoring
- Enable logging during initial setup
- Monitor logs for issues
- Disable debug logging in production

### 4. Backup Configuration
```bash
# Backup current settings
sysupgrade -b /tmp/backup-$(date +%Y%m%d).tar.gz

# Save to external location
scp /tmp/backup-*.tar.gz user@backup-server:/path/to/backups/
```

## Conclusion
This setup provides flexible time-based bandwidth control on OpenWrt. The combination of SQM for overall traffic shaping and cron jobs for scheduling creates an effective internet addiction control system that automatically adjusts bandwidth based on time of day.