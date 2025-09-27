# ntopng Network Monitoring Guide

## Overview
This guide covers how to use ntopng for comprehensive network monitoring, with specific focus on device tracking and usage analysis for parental controls and network management.

## Setup Configuration

### Docker Stack Configuration
```yaml
ntopng:
    container_name: ntopng
    network_mode: host
    privileged: true
    environment:
        - PUID=1000
        - PGID=1000
    command: [ 
        '--interface=vmbr0,vmbr1',
        '--local-networks=192.168.1.0/24',
        '--http-port=3001',
        '--data-dir=/var/lib/ntopng',
        '--community'
    ]
    image: ntop/ntopng:latest
    restart: unless-stopped
```

### Access
- **Web Interface**: http://192.168.1.20:3000
- **Default Login**: admin/admin

## Key Features

### 1. Device Monitoring Methods

#### Global Search (Top-right corner)
- Type IP addresses: `192.168.1.172`
- Type hostnames: `mac.lan`, `MacBookAir` 
- Type partial matches: `192.168.1.`

#### Hosts Page Filtering
**URL**: `http://192.168.1.20:3000/lua/hosts_stats.lua`
- Local/Remote filter buttons
- Sort by traffic, name, last seen
- Click any host for detailed individual analysis

#### MAC Address Filtering
**URL**: `http://192.168.1.20:3000/lua/macs_stats.lua`
- Track devices even if IP changes (DHCP)
- Device manufacturer identification
- Persistent device tracking

#### Flow-based Filtering
**URL**: `http://192.168.1.20:3000/lua/flows_stats.lua`
- Client IP: `client=192.168.1.172`
- Server IP: `server=8.8.8.8`  
- Port: `port=443`
- Protocol: `application=TLS`

### 2. Usage Monitoring & Analytics

#### Top Applications View
- Main Dashboard shows DNS, TLS, HTTP, etc.
- Click any application for detailed breakdown
- Percentage breakdown of traffic by protocol

#### Device-Specific Monitoring
```bash
# Replace with actual MAC address or IP
http://192.168.1.20:3000/lua/host_details.lua?host=192.168.1.172
```

#### Interface-Level Usage Graphs
```bash
http://192.168.1.20:3000/lua/if_stats.lua
```

#### Time-Based Analysis
Available periods:
- **Real-time** (5-minute windows)
- **Hourly** (last 24 hours)
- **Daily** (last 30 days) 
- **Weekly** (last 12 weeks)
- **Monthly** (last 12 months)

## 5 Teen Phone Monitoring Use Cases

### 1. Time-Based Usage Monitoring
**Purpose**: Track when and how long your teen is online
- View historical graphs by hour/day
- Identify peak usage times (late night, school hours)
- Set baseline expectations based on data

### 2. Data Consumption Analysis
**Purpose**: Monitor bandwidth usage and data-heavy activities
- Top Hosts → Find teen's device in traffic rankings
- Application breakdown → See YouTube vs TikTok vs messaging
- Daily/weekly data usage tracking

### 3. Website & App Monitoring
**Purpose**: See which websites and services are being accessed
- Flows → Filter by teen's device IP/MAC
- Top Applications → Social media, gaming, streaming
- DNS queries → Website visit attempts

### 4. Off-Limits Hours Detection
**Purpose**: Catch usage during restricted times (bedtime, study, family time)
- Real-time monitoring → Live traffic alerts
- Historical analysis → "What happened at 3 AM last Tuesday?"
- Flow timeline → Exact start/stop times of activities

### 5. Behavioral Pattern Analysis
**Purpose**: Understand usage trends and changes in behavior
- Weekly/monthly trends → Is usage increasing?
- Application shifts → New apps appearing suddenly
- Academic impact correlation → Heavy usage during study periods

## Step-by-Step Teen Monitoring

### Step 1: Find the Device
1. Go to **Hosts** → **Hosts**
2. Look for device by name (`Sarah-iPhone`) or high traffic usage
3. Click on the device name

### Step 2: Device Details Analysis
Once you click a device, you'll see:
- Real-time traffic graphs
- Historical usage charts (hourly, daily, weekly)
- Top applications used by that device
- Top destinations (websites/servers)
- Activity timeline

### Step 3: Application Breakdown
- **"Applications" tab** → See TikTok, Instagram, YouTube usage
- **"Flows" tab** → See active connections in real-time
- **"Traffic" tab** → Historical graphs

## Quick Access URLs

### Main Monitoring Pages
```bash
# Main Dashboard
http://192.168.1.20:3000

# All Hosts (Find Teen's Device)
http://192.168.1.20:3000/lua/hosts_stats.lua

# Interface Traffic Graphs
http://192.168.1.20:3000/lua/if_stats.lua

# All Active Flows (Real-time)
http://192.168.1.20:3000/lua/flows_stats.lua
```

### Direct Device Monitoring
```bash
# Specific host details
http://192.168.1.20:3000/lua/host_details.lua?host=192.168.1.172

# Host flows only
http://192.168.1.20:3000/lua/flows_stats.lua?client=192.168.1.172

# MAC address specific
http://192.168.1.20:3000/lua/mac_details.lua?host=AA:BB:CC:DD:EE:FF
```

## Understanding Usage Graphs

### Traffic Patterns
- **High peaks during school hours** = Phone use in class
- **Late night spikes** = Not sleeping
- **Constant background traffic** = Apps running continuously

### Application Changes
- **New apps appearing** = Downloaded something new
- **Usage pattern shifts** = Different activities/interests
- **Social messaging spikes** = Group conversations

## Daily Monitoring Routine

### Daily Check (2 minutes)
1. Main dashboard → Check "Top Hosts" for teen's device
2. Click teen's device → View daily usage graph
3. Applications tab → See what apps were used most

### Weekly Review (5 minutes)
1. Host details → Switch to "Weekly" view
2. Compare usage patterns → School days vs weekends  
3. Application trends → New apps appearing?
4. Peak usage times → Late night activity?

## Configuration Recommendations

### MAC Address Tracking
**Issue**: DHCP popup - "This interface is monitoring DHCP hosts..."
**Solution**: Configure → Local Broadcast Domain Hosts Identifier → Select "MAC Address"

**Benefits**:
- Persistent device identity
- Better historical data
- Accurate device counting
- Improved analytics

### Pro Tips
- Bookmark specific device URLs for quick access
- Use MAC filtering for mobile devices (IP may change)
- Set up custom host pools for device grouping
- Be transparent about monitoring - explain to family members
- Focus on health/sleep impact rather than punishment
- Use data to help teens self-regulate
- Review together weekly to build digital awareness

## Troubleshooting

### Common Issues
1. **No traffic showing**: Check interface selection (ensure monitoring correct interface)
2. **Devices appear/disappear**: Switch to MAC address tracking
3. **Missing applications**: Data may be encrypted (shows as TLS instead of specific app)
4. **Performance issues**: Consider reducing retention period or upgrading to paid version

### Network Architecture
This setup monitors traffic from both bridge interfaces (vmbr0 and vmbr1) via direct packet capture, providing comprehensive visibility into network usage across your entire infrastructure.

## Security & Privacy Notes
- All monitoring is local to your network
- No data sent to external services
- Use monitoring responsibly and transparently
- Consider privacy implications and local laws
- Focus on digital wellness rather than surveillance