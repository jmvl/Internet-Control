# WireGuard Quick Reference Guide

**Server**: wg.accelior.com (135.181.154.169)

## Quick Access

### SSH Access
```bash
ssh root@wg.accelior.com
```

### Web UI Access
- **Primary (User Creation)**: http://wg.accelior.com:8888/app/#/users
- **WireGuard Easy UI**: http://wg.accelior.com:51821
- **Legacy UI**: http://wg.accelior.com:8080
- **Auth**: Password authentication enabled

### SSH Tunnel (Secure Access)
```bash
# For user management (port 8888)
ssh -L 8888:127.0.0.1:8888 root@wg.accelior.com -N
# Then access: http://localhost:8888/app/#/users

# For WireGuard Easy UI (port 51821)
ssh -L 51821:127.0.0.1:51821 root@wg.accelior.com -N
# Then access: http://localhost:51821
```

---

## Common Operations

### WireGuard Service Management
```bash
# Status
systemctl status wg-quick@wg0

# Restart
systemctl restart wg-quick@wg0

# Stop/Start
systemctl stop wg-quick@wg0
systemctl start wg-quick@wg0

# Enable/Disable at boot
systemctl enable wg-quick@wg0
systemctl disable wg-quick@wg0
```

### View WireGuard Status
```bash
# Quick status
wg show

# Detailed status
wg show wg0

# Show with transfer statistics
wg show wg0 transfer

# Real-time monitoring
watch -n 1 'wg show wg0'
```

### Docker Container Management
```bash
# View running containers
docker ps | grep wg

# Restart web UI
docker restart wg-gen-web-new

# View logs
docker logs wg-gen-web-new --tail 50
docker logs wg-gen-web-new -f  # Follow logs

# Stop containers
docker stop wg-gen-web-new wg-json-api

# Start containers
docker start wg-gen-web-new wg-json-api
```

### Configuration Files
```bash
# View WireGuard config
cat /etc/wireguard/wg0.conf

# Edit config (be careful!)
nano /etc/wireguard/wg0.conf
# After editing, reload:
systemctl restart wg-quick@wg0

# Backup config
cp /etc/wireguard/wg0.conf /root/wg0.conf.backup.$(date +%Y%m%d-%H%M%S)
```

### Add/Remove Peers (via Web UI)
1. Access web UI: **http://wg.accelior.com:8888/app/#/users** (primary)
2. Click "Add Client" button
3. Enter client name and email
4. Download config or scan QR code
5. Client connects automatically

**Alternative Interfaces**:
- WireGuard Easy UI: http://wg.accelior.com:51821
- Legacy UI: http://wg.accelior.com:8080

### Network Troubleshooting
```bash
# Check interface status
ip a show wg0

# Check NAT rules
iptables -t nat -L POSTROUTING -n -v | grep WireGuard

# Check IP forwarding
sysctl net.ipv4.ip_forward

# Check listening ports
netstat -ulnp | grep 51820
netstat -tlnp | grep 8080

# Check firewall
ufw status
```

---

## Emergency Commands

### Service Won't Start
```bash
# Check logs
journalctl -u wg-quick@wg0 -n 50

# Check config syntax
wg-quick up wg0 --dry-run

# Force reload
systemctl daemon-reload
systemctl restart wg-quick@wg0
```

### Clients Can't Connect
```bash
# Verify service is running
wg show

# Check port is open
nc -zvu localhost 51820

# Check firewall
ufw allow 51820/udp
```

### Web UI Not Working
```bash
# Check container status
docker ps -a | grep wg

# Restart container
docker restart wg-gen-web-new

# If container is stopped
docker start wg-gen-web-new

# Recreate container (nuclear option)
docker stop wg-gen-web-new
docker rm wg-gen-web-new
# Then recreate using command in main documentation
```

---

## Backup & Recovery

### Quick Backup
```bash
# Backup config
cp /etc/wireguard/wg0.conf /root/wg0.conf.backup.$(date +%Y%m%d-%H%M%S)

# Download backup to local machine
scp root@wg.accelior.com:/etc/wireguard/wg0.conf ~/wg0.conf.backup
```

### Restore from Backup
```bash
# Upload config
scp ~/wg0.conf.backup root@wg.accelior.com:/etc/wireguard/wg0.conf

# Restart service
ssh root@wg.accelior.com 'systemctl restart wg-quick@wg0'
```

---

## Hetzner Cloud CLI

### Server Management
```bash
# List servers
hcloud server list

# Server details
hcloud server describe wg.accelior.com

# Reboot server
hcloud server reboot wg.accelior.com

# Power off/on
hcloud server poweroff wg.accelior.com
hcloud server poweron wg.accelior.com
```

### Emergency Access
```bash
# Enable rescue mode
hcloud server enable-rescue wg.accelior.com --ssh-key jm@JMs-MacBook-Air.local
hcloud server reset wg.accelior.com

# Wait 20 seconds, then SSH
sleep 20
ssh root@wg.accelior.com

# Mount main disk
mount /dev/sda1 /mnt

# Access files
ls /mnt/etc/wireguard/

# Exit rescue mode
hcloud server disable-rescue wg.accelior.com
hcloud server reboot wg.accelior.com
```

---

## Network Details

| Component | Details |
|-----------|---------|
| **Public IP** | 135.181.154.169 |
| **Hostname** | wg.accelior.com |
| **VPN Network** | 10.6.6.0/24 |
| **Gateway** | 10.6.6.1 |
| **WireGuard Port** | 51820/udp |
| **User Management** | 8888/tcp (Primary) |
| **WireGuard Easy UI** | 51821/tcp |
| **Legacy UI** | 8080/tcp |
| **Active Peers** | 13 clients |

---

## Key Files & Locations

| Path | Description |
|------|-------------|
| `/etc/wireguard/wg0.conf` | Main WireGuard configuration |
| `/root/wg0.conf.backup.*` | Configuration backups |
| `/etc/systemd/system/wg-quick@.service` | Systemd service file |
| `~/.config/hcloud/cli.toml` | Hetzner CLI config (local) |
| `/var/log/syslog` | System logs (includes WireGuard) |

---

## Useful Links

- **Main Documentation**: `docs/wireguard/wireguard-technical-documentation.md`
- **WireGuard Official**: https://www.wireguard.com/
- **wg-gen-web**: https://github.com/vx3r/wg-gen-web
- **Hetzner Cloud**: https://console.hetzner.cloud/

---

**Last Updated**: 2026-02-05
