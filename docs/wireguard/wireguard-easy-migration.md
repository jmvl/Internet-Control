# WireGuard Easy Migration Guide

**Migration Date**: 2025-10-08
**From**: wg-gen-web + native WireGuard
**To**: WireGuard Easy (wg-easy)

## Migration Summary

Successfully migrated from the legacy wg-gen-web setup to WireGuard Easy for improved management, security, and user experience.

## What Changed

### Old Setup (Removed)
- ❌ Native WireGuard (wg-quick@wg0 service)
- ❌ wg-gen-web Docker container (port 8080)
- ❌ wg-json-api Docker container
- ❌ Fake OAuth authentication (no security)
- ❌ Complex two-container architecture

### New Setup (Active)
- ✅ WireGuard Easy (single Docker container)
- ✅ **Web UI**: http://wg.accelior.com:51821 (port 51821)
- ✅ **WireGuard Port**: UDP 51820 (unchanged)
- ✅ **Password Authentication**: Secure bcrypt password hash
- ✅ **Modern UI**: Mobile-friendly, real-time statistics
- ✅ **Simplified Architecture**: Single container with built-in everything

## Access Information

### Web UI Access
- **URL**: http://wg.accelior.com:51821 or http://135.181.154.169:51821
- **Password**: `ChangeThisPassword123!` (CHANGE THIS IMMEDIATELY!)
- **Port**: 51821 (TCP)

### WireGuard VPN
- **Server**: wg.accelior.com:51820 (UDP)
- **VPN Network**: 10.6.6.0/24
- **Default DNS**: 1.1.1.1 (Cloudflare)

## Configuration Details

### Docker Container
**Name**: wg-easy
**Image**: ghcr.io/wg-easy/wg-easy:latest
**Volumes**: /opt/wg-easy:/etc/wireguard
**Ports**:
- 51820/udp (WireGuard VPN)
- 51821/tcp (Web UI)

### Environment Variables
```bash
WG_HOST=wg.accelior.com
PASSWORD_HASH=$2a$12$VU3yuon2/fEDX0Eh5d7x7.9Lnw0EXJeH9voyd2JuRFa8fohlsO3WO
WG_PORT=51820
WG_DEFAULT_ADDRESS=10.6.6.x
WG_DEFAULT_DNS=1.1.1.1
WG_ALLOWED_IPS=0.0.0.0/0
WG_PERSISTENT_KEEPALIVE=25
UI_TRAFFIC_STATS=true
UI_CHART_TYPE=2
```

## Client Migration Required

### Important: All 13 Existing Clients Need New Configs

The server has a **new public key**, so all existing clients must update their configurations.

**Old Server Public Key** (no longer valid):
```
UKOhgqwTPaPc0Vn13Pw480jroa56Szg59HMYwoLdzlM=
```

**New Server Public Key**:
Access the web UI at http://wg.accelior.com:51821 to get the current server public key.

### How to Migrate Clients

**Option 1: Web UI (Recommended)**
1. Log into http://wg.accelior.com:51821
2. Click "New Client" for each device
3. Name the client (e.g., "iPhone-John", "Laptop-Office")
4. Download config file or scan QR code
5. Update device with new configuration

**Option 2: Manual Configuration**
1. Get new server public key from web UI
2. Update client config `[Peer]` section:
   - Change `PublicKey` to new server key
   - Keep same `Address` (10.6.6.x)
   - Keep same `Endpoint` (wg.accelior.com:51820)

## Backup Information

All old configurations backed up to:
- **Location**: `/root/wireguard-backups/20251008-214954/`
- **Includes**: All client configs, server config, peer information
- **Peer Snapshot**: `/root/wireguard-backups/current-peers-*.txt`

### Old Client IPs (for reference)
Reference the backup files to see which IPs were assigned to which clients.

## Post-Migration Steps

### Immediate Actions
1. ✅ Change default password in web UI
2. ✅ Update firewall rules (if needed) to allow port 51821
3. ✅ Test web UI access from browser
4. ✅ Create test client and verify VPN connection

### Client Rollout Plan
1. Create new client configs in web UI for all 13 clients
2. Send new configs/QR codes to users
3. Have users test and confirm connectivity
4. Remove old client entries once migrated

### Security Recommendations
1. **Change Password**: Use strong password and update `PASSWORD_HASH`
   ```bash
   # Generate new hash
   docker run --rm ghcr.io/wg-easy/wg-easy wgpw "YourNewStrongPassword"

   # Update container with new hash
   docker stop wg-easy && docker rm wg-easy
   # Then recreate with new PASSWORD_HASH
   ```

2. **Restrict Web UI Access**: Consider firewall rules or VPN-only access to port 51821

3. **Enable HTTPS**: Set up reverse proxy with SSL certificate

4. **Regular Backups**: Backup `/opt/wg-easy` directory regularly

## Management Commands

### Docker Management
```bash
# View logs
docker logs wg-easy -f

# Restart container
docker restart wg-easy

# Stop/Start
docker stop wg-easy
docker start wg-easy

# View status
docker ps | grep wg-easy
```

### WireGuard Status
```bash
# SSH into server
ssh root@wg.accelior.com

# Check WireGuard status
docker exec wg-easy wg show

# View active peers
docker exec wg-easy wg show wg0
```

### Backup Current Config
```bash
# Backup WireGuard Easy data
ssh root@wg.accelior.com 'tar -czf /root/wg-easy-backup-$(date +%Y%m%d).tar.gz /opt/wg-easy'

# Download backup
scp root@wg.accelior.com:/root/wg-easy-backup-*.tar.gz ~/backups/
```

## Troubleshooting

### Web UI Not Accessible
```bash
# Check container is running
docker ps | grep wg-easy

# Check logs for errors
docker logs wg-easy --tail 50

# Verify port is listening
netstat -tlnp | grep 51821
```

### VPN Not Connecting
```bash
# Check WireGuard interface
docker exec wg-easy wg show

# Verify firewall allows UDP 51820
ufw status | grep 51820

# Check container networking
docker exec wg-easy ip addr show wg0
```

### Password Hash Issues
If you see "DO NOT USE PASSWORD ENVIRONMENT VARIABLE" error:
```bash
# Generate new hash
docker run --rm ghcr.io/wg-easy/wg-easy wgpw "YourPassword"

# Use the output as PASSWORD_HASH environment variable
```

## Benefits of New Setup

### Improvements
- ✅ **Better Security**: Built-in password authentication
- ✅ **Modern UI**: Clean, intuitive, mobile-responsive
- ✅ **Real-time Stats**: Live bandwidth and connection info
- ✅ **Easier Management**: Single container, no API issues
- ✅ **Active Development**: Regular updates and bug fixes
- ✅ **Better QR Codes**: Instant generation for mobile clients
- ✅ **Traffic Graphs**: Visual bandwidth usage charts

### What You Gain
- Simpler troubleshooting (one container vs two)
- Better user experience for admin tasks
- No more "fake OAuth" security concerns
- Built-in connection statistics
- Active community support

## Rollback Plan (If Needed)

If you need to roll back to the old setup:

1. **Stop WireGuard Easy**:
   ```bash
   docker stop wg-easy && docker rm wg-easy
   ```

2. **Restore Old Config**:
   ```bash
   cp /root/wireguard-backups/20251008-214954/wg0.conf /etc/wireguard/
   ```

3. **Start Old Service**:
   ```bash
   systemctl enable wg-quick@wg0
   systemctl start wg-quick@wg0
   ```

4. **Restart Old Containers** (if desired):
   ```bash
   # See backup documentation for old container configs
   ```

## Next Steps

1. **Log into web UI**: http://wg.accelior.com:51821
2. **Change default password** in settings
3. **Create first test client** to verify functionality
4. **Plan client migration** - coordinate with users for config updates
5. **Update Confluence documentation** with new URLs and procedures
6. **Update local documentation** in repository

---

**Migration Status**: ✅ Complete
**Clients Migrated**: 0 of 13 (migration in progress)
**Backup Location**: `/root/wireguard-backups/20251008-214954/`

**Document Version**: 1.0
**Last Updated**: 2025-10-08
**Performed By**: Infrastructure Team
