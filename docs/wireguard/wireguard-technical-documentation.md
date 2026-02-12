# WireGuard VPN Server - Technical Documentation

**Server**: wg.accelior.com (135.181.154.169)
**Location**: Hetzner Helsinki DC (hel1-dc2)
**Last Updated**: 2025-10-08

> **NOTE**: This document describes the legacy WireGuard setup. For current operations, see:
> - **README.md**: Current setup with multiple management interfaces
> - **wireguard-easy-migration.md**: Migration guide and current access URLs
>
> **Current User Management**: http://wg.accelior.com:8888/app/#/users

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Native WireGuard Installation](#native-wireguard-installation)
- [Docker Management Containers](#docker-management-containers)
- [Network Configuration](#network-configuration)
- [Access & Authentication](#access--authentication)
- [Backup & Recovery](#backup--recovery)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

This WireGuard installation uses a **hybrid architecture**:
- **Native WireGuard**: Installed directly on Ubuntu host for optimal performance
- **Docker Containers**: Web-based management UI and API for easy administration

```
┌─────────────────────────────────────────────────────┐
│ Hetzner Server: wg.accelior.com (Ubuntu 20.04 LTS) │
│                                                     │
│  ┌─────────────────────────────────────────────┐  │
│  │ Native WireGuard (wg0)                      │  │
│  │ - Interface: 10.6.6.1/24                    │  │
│  │ - Port: 51820/udp                           │  │
│  │ - Managed by: systemd (wg-quick@wg0)        │  │
│  │ - Config: /etc/wireguard/wg0.conf           │  │
│  └─────────────────────────────────────────────┘  │
│                                                     │
│  ┌──────────────────────┐  ┌──────────────────┐   │
│  │ wg-gen-web (Docker)  │  │ wg-json-api      │   │
│  │ - Port: 8080/tcp     │  │ (Docker)         │   │
│  │ - Web UI Management  │  │ - JSON API       │   │
│  │ - vx3r/wg-gen-web    │  │ - james/wg-api   │   │
│  └──────────────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────┘
              │
              │ NAT via iptables
              ↓
         Internet (eth0)
```

---

## Native WireGuard Installation

### Service Details
- **Service**: `wg-quick@wg0.service`
- **Status**: Active (enabled at boot)
- **Control Commands**:
  ```bash
  systemctl status wg-quick@wg0
  systemctl restart wg-quick@wg0
  systemctl stop wg-quick@wg0
  systemctl start wg-quick@wg0
  ```

### Configuration
- **File**: `/etc/wireguard/wg0.conf`
- **Permissions**: `600` (root only)
- **Format**: WireGuard standard INI-style config

#### Key Configuration Elements
```ini
[Interface]
Address = 10.6.6.1/24
ListenPort = 51820
PrivateKey = <hidden>

PostUp = iptables -t nat -A POSTROUTING -s '10.6.6.0/24' -o eth0 -j MASQUERADE -m comment --comment "WireGuardNat"
PostDown = iptables-save | grep -v "WireGuardNat" | iptables-restore

[Peer]
PublicKey = <peer-public-key>
PresharedKey = <preshared-key>
AllowedIPs = 10.6.6.X/32
```

### Network Interface
- **Interface Name**: `wg0`
- **IP Address**: `10.6.6.1/24`
- **MTU**: 1420 bytes
- **Type**: Point-to-point tunnel (POINTOPOINT,NOARP)
- **State**: UP, LOWER_UP

### Active Peers
**Current Count**: 13 connected peers

| Peer ID | IP Address | Last Connection |
|---------|------------|-----------------|
| Peer 1  | 10.6.6.7   | Active          |
| Peer 2  | 10.6.6.6   | Active          |
| Peer 3  | 10.6.6.5   | Active          |
| Peer 4  | 10.6.6.2   | Active          |
| Peer 5  | 10.6.6.14  | Active          |
| Peer 6  | 10.6.6.13  | Active          |
| Peer 7  | 10.6.6.12  | Active          |
| Peer 8  | 10.6.6.11  | Active          |
| Peer 9  | 10.6.6.9   | Active          |
| Peer 10 | 10.6.6.4   | Active          |
| Peer 11 | 10.6.6.8   | Active          |
| Peer 12 | 10.6.6.10  | Active          |
| Peer 13 | 10.6.6.3   | Active          |

**Public Key (Server)**: `UKOhgqwTPaPc0Vn13Pw480jroa56Szg59HMYwoLdzlM=`

### NAT Configuration
WireGuard traffic is NAT'd to provide internet access to VPN clients:

```bash
# View NAT rule
iptables -t nat -L POSTROUTING -n -v | grep WireGuardNat
```

**Rule Details**:
- **Chain**: POSTROUTING (nat table)
- **Action**: MASQUERADE
- **Source**: 10.6.6.0/24
- **Output Interface**: eth0
- **Comment**: "WireGuardNat"

This rule is automatically added by the `PostUp` command in wg0.conf and removed by `PostDown`.

---

## Docker Management Containers

### Container: wg-gen-web
**Purpose**: Web-based UI for WireGuard management

**Container Details**:
- **Name**: `wg-gen-web-new` (previously `wg-gen-web`)
- **Image**: `vx3r/wg-gen-web:latest`
- **Status**: Running
- **Port Mapping**: `0.0.0.0:8080 -> 8080/tcp` (publicly accessible)
- **Volume Mount**: `/etc/wireguard:/data`
- **Capabilities**: NET_ADMIN

**Environment Variables**:
```bash
WG_CONF_DIR=/data
WG_INTERFACE_NAME=wg0.conf
SMTP_HOST=mail.vega-messenger.com
SMTP_PORT=587
SMTP_USERNAME=wireguard@accelior.com
SMTP_PASSWORD=6JYWxn3KZ9SI
SMTP_FROM="Wg Gen Web <sender@vega-messenger.com>"
WG_STATS_API=http://135.181.154.169:8182
```

**Access**:
- **URL**: http://wg.accelior.com:8080 or http://135.181.154.169:8080
- **Authentication**: Fake OAuth (no actual authentication)
  - Warning in logs: `"Oauth is set to fake, no actual authentication will be performed"`

**Features**:
- Add/remove WireGuard clients via web interface
- Generate QR codes for mobile clients
- View connection statistics (via wg-json-api integration)
- Email notifications for new clients
- Real-time peer status monitoring

### Container: wg-json-api
**Purpose**: JSON API for WireGuard statistics

**Container Details**:
- **Name**: `wg-json-api`
- **Image**: `james/wg-api:latest`
- **Status**: Running
- **Created**: 12 months ago
- **Port Mapping**: None (internal use only)
- **Capabilities**: Access to host WireGuard interface (`wg0`)

**Functionality**:
- Provides real-time statistics about WireGuard peers
- Used by wg-gen-web for status page
- API endpoint: http://135.181.154.169:8182 (not publicly exposed)

### Docker Commands
```bash
# View running containers
docker ps | grep wg

# View logs
docker logs wg-gen-web-new
docker logs wg-json-api

# Restart containers
docker restart wg-gen-web-new
docker restart wg-json-api

# Stop containers
docker stop wg-gen-web-new wg-json-api

# Remove and recreate (if needed)
docker rm wg-gen-web-new
docker run -d --name wg-gen-web-new \
  --cap-add NET_ADMIN \
  -e WG_CONF_DIR=/data \
  -e WG_INTERFACE_NAME=wg0.conf \
  -v /etc/wireguard:/data \
  -p 0.0.0.0:8080:8080 \
  vx3r/wg-gen-web:latest
```

---

## Network Configuration

### Server Network Details
- **Public IPv4**: 135.181.154.169
- **Public IPv6**: 2a01:4f9:c011:21a9::/64
- **Hostname**: wg.accelior.com
- **DNS**: static.169.154.181.135.clients.your-server.de
- **External Interface**: eth0

### VPN Network
- **Network**: 10.6.6.0/24
- **Gateway**: 10.6.6.1 (WireGuard server)
- **Available IPs**: 10.6.6.2 - 10.6.6.254
- **DNS for Clients**: Configurable per client (default: system DNS)

### Firewall Rules
```bash
# Allow WireGuard UDP port
ufw allow 51820/udp comment 'WireGuard VPN'

# Allow web UI (if needed publicly)
ufw allow 8080/tcp comment 'WireGuard Web UI'

# Check firewall status
ufw status
```

### IP Forwarding
IP forwarding is enabled for WireGuard to route traffic:
```bash
# Check current setting
sysctl net.ipv4.ip_forward

# Should return: net.ipv4.ip_forward = 1
```

Configured in `/etc/sysctl.conf` or via WireGuard PostUp commands.

---

## Access & Authentication

### SSH Access
- **Authentication**: SSH key-based (password auth disabled)
- **Authorized Keys**: `/root/.ssh/authorized_keys`
- **Current Key**: `jm@JMs-MacBook-Air.local` (fingerprint: `ef:04:56:55:7b:7b:39:c8:92:1a:cb:69:3b:f3:40:2e`)

### Web UI Access
- **URL**: http://wg.accelior.com:8080 or http://135.181.154.169:8080
- **Authentication**: Disabled (fake OAuth mode)
- **Security Note**: No actual authentication is performed. Consider:
  - Setting up proper OAuth provider (GitHub, Google, etc.)
  - Using SSH tunnel: `ssh -L 8080:127.0.0.1:8080 root@wg.accelior.com`
  - Restricting access via firewall rules

### Hetzner Cloud API
- **CLI Tool**: `hcloud` (installed on local machine)
- **Context**: default
- **Token Location**: `~/.config/hcloud/cli.toml`
- **Usage**:
  ```bash
  hcloud server list
  hcloud server describe wg.accelior.com
  hcloud server enable-rescue wg.accelior.com
  ```

---

## Backup & Recovery

### Configuration Backups

**Manual Backup**:
```bash
# Backup WireGuard config
ssh root@wg.accelior.com 'cp /etc/wireguard/wg0.conf /root/wg0.conf.backup.$(date +%Y%m%d-%H%M%S)'
```

**Current Backups**:
- `/root/wg0.conf.backup.20251008-212351` (created 2025-10-08)

**Backup Contents**:
- Full WireGuard configuration including all peer configurations
- Private keys and preshared keys
- Network settings and iptables rules

### Disaster Recovery via Hetzner Rescue

If the server becomes inaccessible:

1. **Enable Rescue Mode**:
   ```bash
   hcloud server enable-rescue wg.accelior.com --ssh-key jm@JMs-MacBook-Air.local
   hcloud server reset wg.accelior.com
   ```

2. **Wait for Boot** (~20-30 seconds):
   ```bash
   sleep 20
   ssh root@wg.accelior.com
   ```

3. **Mount and Access Files**:
   ```bash
   mount /dev/sda1 /mnt
   cat /mnt/etc/wireguard/wg0.conf
   # Copy files or make changes
   umount /mnt
   ```

4. **Exit Rescue Mode**:
   ```bash
   hcloud server disable-rescue wg.accelior.com
   hcloud server reboot wg.accelior.com
   ```

### Full Server Backup
Consider implementing automated backups of:
- `/etc/wireguard/` directory
- Docker container configurations
- Any custom scripts

Use Hetzner Backup service or external backup solution.

---

## Troubleshooting

### Common Issues

#### 1. Clients Can't Connect
**Symptoms**: Clients timeout when trying to connect

**Diagnosis**:
```bash
# Check WireGuard is running
wg show
systemctl status wg-quick@wg0

# Check port is listening
netstat -ulnp | grep 51820

# Check firewall
ufw status | grep 51820
```

**Solutions**:
- Restart WireGuard: `systemctl restart wg-quick@wg0`
- Check firewall allows UDP 51820
- Verify client config matches server public key

#### 2. Clients Connect but No Internet
**Symptoms**: VPN connects but can't access internet

**Diagnosis**:
```bash
# Check IP forwarding
sysctl net.ipv4.ip_forward

# Check NAT rules
iptables -t nat -L POSTROUTING -n -v | grep WireGuard
```

**Solutions**:
```bash
# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Manually add NAT rule
iptables -t nat -A POSTROUTING -s 10.6.6.0/24 -o eth0 -j MASQUERADE
```

#### 3. Web UI Not Accessible
**Symptoms**: Can't access web UI at port 8080

**Diagnosis**:
```bash
# Check container is running
docker ps | grep wg-gen-web

# Check port binding
netstat -tlnp | grep 8080

# Check container logs
docker logs wg-gen-web-new
```

**Solutions**:
```bash
# Restart container
docker restart wg-gen-web-new

# If port binding issue, recreate with correct port
docker stop wg-gen-web-new
docker rm wg-gen-web-new
# Run new container with -p 0.0.0.0:8080:8080
```

#### 4. "Method Not Allowed" Error on Web UI
**Cause**: Browser accessing wrong endpoint or OAuth misconfiguration

**Solutions**:
- Access root path: http://wg.accelior.com:8080/
- Clear browser cache / use incognito mode
- Check browser console (F12) for actual error
- Verify OAuth is set to "fake" mode in container logs

### Useful Commands

```bash
# View WireGuard status
wg show
wg show wg0

# View detailed peer information
wg show wg0 dump

# Restart WireGuard without downtime
wg syncconf wg0 <(wg-quick strip wg0)

# Add peer manually (better to use web UI)
wg set wg0 peer <public-key> allowed-ips 10.6.6.X/32

# Remove peer manually
wg set wg0 peer <public-key> remove

# Check system logs
journalctl -u wg-quick@wg0 -f

# Monitor real-time connections
watch -n 1 'wg show wg0'
```

### Performance Monitoring

```bash
# Check bandwidth usage per peer
wg show wg0 transfer

# Monitor interface traffic
ip -s link show wg0

# System resource usage
htop
docker stats wg-gen-web-new wg-json-api
```

---

## Server Specifications

**Hetzner Server (CX22)**:
- **CPU**: 2 vCores (shared, Intel Xeon Skylake)
- **RAM**: 4 GB
- **Disk**: 20 GB local SSD
- **OS**: Ubuntu 20.04.6 LTS (Focal Fossa)
- **Datacenter**: Helsinki 1 DC 2 (hel1-dc2)
- **Age**: 1659 days (~4.5 years, since 2021-03-24)
- **Traffic Limit**: 20 TB/month
- **Current Usage**: 56 GB outgoing, 55 GB incoming

**Network**:
- **Uplink**: 1 Gbps shared
- **IPv4**: 135.181.154.169
- **IPv6**: 2a01:4f9:c011:21a9::/64

---

## Notes & Considerations

### Security Recommendations
1. **Enable OAuth Authentication**: Configure proper OAuth provider instead of "fake" mode
2. **Restrict Web UI Access**:
   - Use SSH tunnel instead of public access
   - Or configure firewall to allow only specific IPs
3. **Regular Updates**: Keep WireGuard, Docker images, and Ubuntu updated
4. **Monitor Access**: Review logs regularly for suspicious activity
5. **Backup Keys**: Ensure private keys are backed up securely offline

### Future Improvements
1. **Migrate to WireGuard Easy**: Consider migrating to `wg-easy` for simpler management
2. **Automated Backups**: Implement scheduled backups of configs and keys
3. **Monitoring**: Add Prometheus + Grafana for metrics visualization
4. **High Availability**: Consider multi-server setup for redundancy
5. **IPv6 Support**: Enable IPv6 for WireGuard peers

### Related Documentation
- WireGuard Official Docs: https://www.wireguard.com/
- wg-gen-web GitHub: https://github.com/vx3r/wg-gen-web
- Hetzner Cloud Docs: https://docs.hetzner.com/cloud/

---

**Document Version**: 1.0
**Created**: 2025-10-08
**Last Modified**: 2025-10-08
**Author**: Technical Documentation (Claude Code)
