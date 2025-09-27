# Device-Specific WiFi Throttling

This document describes how to implement device-specific bandwidth throttling on OpenWrt using traffic control (tc) to limit specific devices while maintaining normal speeds for others.

## Overview

Device-specific throttling allows you to selectively limit bandwidth for individual devices by MAC address while other devices continue to operate at full WiFi speeds. This is useful for:

- Parental controls and device management
- Bandwidth prioritization for critical devices
- Network abuse prevention
- Testing and development scenarios

## Prerequisites

- OpenWrt router with root SSH access
- Traffic control (tc) package installed (usually included)
- Device MAC address and WiFi interface identification
- Basic understanding of Linux traffic shaping

## Implementation Guide

### 1. Identify Target Device and Interface

First, identify the device MAC address and which WiFi interface it's connected to:

```bash
# Check ARP table for device IP to MAC mapping
arp -a | grep [device_ip]

# List all WiFi interfaces
iw dev

# Check which interface the device is connected to
iw dev [interface] station dump | grep -A15 [mac_address]
```

Example output:
```bash
# Device found in ARP
iPhone.lan (192.168.1.102) at a8:ab:b5:8c:3a:05 on vtnet0

# Connected to 5GHz interface
Station a8:ab:b5:8c:3a:05 (on phy1-ap0)
    inactive time:  40 ms
    rx bytes:       1281544
    tx bitrate:     288.2 MBit/s 80MHz HE-MCS 3
```

### 2. Set Up Traffic Control Classes

Create HTB (Hierarchical Token Bucket) classes for bandwidth management:

```bash
# Remove any existing qdisc
tc qdisc del dev phy1-ap0 root 2>/dev/null

# Create HTB qdisc for device-specific shaping
tc qdisc add dev phy1-ap0 root handle 1: htb default 30

# Create root class with full bandwidth (adjust to your connection speed)
tc class add dev phy1-ap0 parent 1: classid 1:1 htb rate 500mbit

# Create throttled class for target device (1 Mbps limit, 2 Mbps burst)
tc class add dev phy1-ap0 parent 1:1 classid 1:10 htb rate 1mbit ceil 2mbit

# Create default class for other devices (450 Mbps to leave headroom)
tc class add dev phy1-ap0 parent 1:1 classid 1:30 htb rate 450mbit
```

### 3. Apply MAC Address Filters

Create filters to match the target device's MAC address:

```bash
# Filter for packets TO the device (download limiting)
tc filter add dev phy1-ap0 protocol ip parent 1: prio 1 u32 \
    match ether dst [MAC_ADDRESS] flowid 1:10

# Filter for packets FROM the device (upload limiting)
tc filter add dev phy1-ap0 protocol ip parent 1: prio 1 u32 \
    match ether src [MAC_ADDRESS] flowid 1:10
```

Example with iPhone MAC:
```bash
tc filter add dev phy1-ap0 protocol ip parent 1: prio 1 u32 \
    match ether dst a8:ab:b5:8c:3a:05 flowid 1:10
tc filter add dev phy1-ap0 protocol ip parent 1: prio 1 u32 \
    match ether src a8:ab:b5:8c:3a:05 flowid 1:10
```

## Verification and Monitoring

### Check Configuration Status

```bash
# Verify qdisc is active
tc qdisc show dev phy1-ap0

# Show traffic classes
tc class show dev phy1-ap0

# Show active filters
tc filter show dev phy1-ap0

# Monitor traffic statistics
tc -s class show dev phy1-ap0
```

### Monitor Real-Time Traffic

```bash
# Watch traffic statistics (refresh every 2 seconds)
watch -n 2 'tc -s class show dev phy1-ap0'

# Check specific class statistics
tc -s class show dev phy1-ap0 classid 1:10
```

Expected output showing throttling in effect:
```bash
class htb 1:10 parent 1:1 prio 0 rate 1Mbit ceil 2Mbit burst 1600b cburst 1600b
 Sent 6024507 bytes 5339 pkt (dropped 0, overlimits 3954 requeues 0)
 backlog 6210b 3p requeues 0
 lended: 2099 borrowed: 1991 giants: 0
```

Key indicators:
- **overlimits**: Shows throttling is actively applied
- **Sent bytes/packets**: Traffic flowing through throttled class
- **backlog**: Queued packets (indicates rate limiting)

## Configuration Examples

### Example 1: Basic Device Throttling (1 Mbps)
```bash
#!/bin/bash
# throttle_device.sh - Throttle specific device to 1 Mbps

INTERFACE="phy1-ap0"
MAC_ADDRESS="a8:ab:b5:8c:3a:05"
THROTTLE_RATE="1mbit"
THROTTLE_CEIL="2mbit"

# Setup traffic control
tc qdisc add dev $INTERFACE root handle 1: htb default 30
tc class add dev $INTERFACE parent 1: classid 1:1 htb rate 500mbit
tc class add dev $INTERFACE parent 1:1 classid 1:10 htb rate $THROTTLE_RATE ceil $THROTTLE_CEIL
tc class add dev $INTERFACE parent 1:1 classid 1:30 htb rate 450mbit

# Apply MAC filters
tc filter add dev $INTERFACE protocol ip parent 1: prio 1 u32 match ether dst $MAC_ADDRESS flowid 1:10
tc filter add dev $INTERFACE protocol ip parent 1: prio 1 u32 match ether src $MAC_ADDRESS flowid 1:10

echo "Device $MAC_ADDRESS throttled to $THROTTLE_RATE on $INTERFACE"
```

### Example 2: Multiple Device Throttling
```bash
#!/bin/bash
# throttle_multiple.sh - Throttle multiple devices with different rates

INTERFACE="phy1-ap0"

# Device configurations (MAC:rate:ceil)
DEVICES=(
    "a8:ab:b5:8c:3a:05:1mbit:2mbit"   # iPhone - 1 Mbps
    "b4:2e:99:12:34:56:5mbit:10mbit"  # Laptop - 5 Mbps
    "c6:7f:aa:78:90:12:512kbit:1mbit" # IoT device - 512 Kbps
)

# Setup base qdisc and root class
tc qdisc add dev $INTERFACE root handle 1: htb default 30
tc class add dev $INTERFACE parent 1: classid 1:1 htb rate 500mbit

# Default class for non-throttled devices
tc class add dev $INTERFACE parent 1:1 classid 1:30 htb rate 400mbit

# Create classes and filters for each device
CLASSID=10
for device in "${DEVICES[@]}"; do
    IFS=':' read -r mac rate ceil <<< "$device"

    # Create class
    tc class add dev $INTERFACE parent 1:1 classid 1:$CLASSID htb rate $rate ceil $ceil

    # Add filters
    tc filter add dev $INTERFACE protocol ip parent 1: prio 1 u32 match ether dst $mac flowid 1:$CLASSID
    tc filter add dev $INTERFACE protocol ip parent 1: prio 1 u32 match ether src $mac flowid 1:$CLASSID

    echo "Device $mac throttled to $rate (burst: $ceil)"
    ((CLASSID++))
done
```

### Example 3: Time-Based Throttling
```bash
#!/bin/bash
# time_based_throttle.sh - Apply throttling during specific hours

INTERFACE="phy1-ap0"
MAC_ADDRESS="a8:ab:b5:8c:3a:05"
CURRENT_HOUR=$(date +%H)

# Apply strict throttling during evening hours (18:00-22:00)
if [ $CURRENT_HOUR -ge 18 ] && [ $CURRENT_HOUR -lt 22 ]; then
    RATE="500kbit"
    CEIL="1mbit"
    echo "Evening throttling: $RATE"
else
    RATE="5mbit"
    CEIL="10mbit"
    echo "Normal throttling: $RATE"
fi

# Apply configuration (implementation same as basic example)
# ... tc commands here
```

## Device Disconnection Commands

### Disconnect Device from WiFi
```bash
# Force disconnect from WiFi interface
iw dev phy1-ap0 station del a8:ab:b5:8c:3a:05

# Kill network states (from OPNsense/firewall)
pfctl -k 192.168.1.102
```

### Temporary Firewall Blocking
```bash
# Block device at firewall level (OPNsense)
pfctl -t blockedips -T add 192.168.1.102

# Remove block
pfctl -t blockedips -T delete 192.168.1.102
```

## Removal and Cleanup

### Remove Device-Specific Throttling
```bash
#!/bin/bash
# remove_throttling.sh - Remove all traffic control rules

INTERFACE="phy1-ap0"

# Remove all tc rules
tc qdisc del dev $INTERFACE root 2>/dev/null

echo "All throttling removed from $INTERFACE"
```

### Reset to Normal Operation
```bash
# Method 1: Remove qdisc completely
tc qdisc del dev phy1-ap0 root

# Method 2: Replace with simple qdisc
tc qdisc replace dev phy1-ap0 root noqueue

# Verify removal
tc qdisc show dev phy1-ap0
```

## Troubleshooting

### Common Issues

1. **No throttling effect observed**
   ```bash
   # Check if filters are matching traffic
   tc -s filter show dev phy1-ap0

   # Verify MAC address format
   iw dev phy1-ap0 station dump | grep [partial_mac]
   ```

2. **Device switches interfaces**
   ```bash
   # Monitor all interfaces for device
   for iface in $(iw dev | grep Interface | awk '{print $2}'); do
       echo "=== $iface ==="
       iw dev $iface station dump | grep -A5 a8:ab:b5:8c:3a:05
   done
   ```

3. **Traffic control warnings**
   ```bash
   # HTB quantum warnings - adjust r2q parameter
   tc qdisc add dev phy1-ap0 root handle 1: htb default 30 r2q 1
   ```

### Verification Commands

```bash
# Complete status check
echo "=== Interface Status ==="
tc qdisc show dev phy1-ap0

echo "=== Traffic Classes ==="
tc -s class show dev phy1-ap0

echo "=== Active Filters ==="
tc filter show dev phy1-ap0

echo "=== Device Connection ==="
iw dev phy1-ap0 station dump | grep -A10 a8:ab:b5:8c:3a:05
```

## Integration with Existing Systems

### SQM Compatibility
When using with OpenWrt's SQM (Smart Queue Management):

```bash
# Check current SQM status
uci show sqm

# Disable SQM on interface before applying tc rules
uci set sqm.throttle_phy1_ap0.enabled='0'
uci commit sqm
/etc/init.d/sqm restart
```

### Automation Integration
```bash
# Add to crontab for scheduled throttling
# Throttle device every weekday evening
0 18 * * 1-5 /root/scripts/throttle_device.sh

# Remove throttling late evening
0 23 * * 1-5 /root/scripts/remove_throttling.sh
```

## Security Considerations

- **MAC Address Spoofing**: Devices can change MAC addresses; consider IP-based rules for persistent devices
- **Interface Switching**: Monitor device movement between 2.4GHz and 5GHz interfaces
- **Emergency Access**: Maintain backup WiFi networks unaffected by throttling
- **Logging**: Enable traffic logging for monitoring and debugging

## Performance Notes

- **Minimal Overhead**: HTB adds negligible CPU overhead for small numbers of classes
- **Memory Usage**: Each class uses ~1KB memory; scale accordingly
- **Burst Handling**: Configure appropriate burst sizes for traffic patterns
- **Interface Limits**: Apply throttling per WiFi interface, not globally

This implementation provides granular control over device bandwidth while maintaining network performance for other users.