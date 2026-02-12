# WireGuard User Management Quick Start

**Server**: wg.accelior.com (135.181.154.169)
**Primary User Interface**: http://wg.accelior.com:8888/app/#/users

## Quick Access

### Create New VPN User (Primary Method)
1. Open: **http://wg.accelior.com:8888/app/#/users**
2. Log in with your credentials
3. Click "New Client" or "Add Client"
4. Enter client name (e.g., "iPhone-John", "MacBook-Jane")
5. Download the configuration file OR scan the QR code with mobile app
6. Send the config/QR to the user
7. Done! User can now connect to the VPN

### Alternative Interfaces
| Interface | URL | Purpose |
|-----------|-----|---------|
| **User Management** | http://wg.accelior.com:8888/app/#/users | Create/manage VPN users |
| **WireGuard Easy** | http://wg.accelior.com:51821 | Statistics and monitoring |
| **Legacy (wg-gen-web)** | http://wg.accelior.com:8080 | Deprecated - do not use |

## Client Connection Details

When users connect, they will use:
- **Server**: wg.accelior.com
- **Port**: 51820/udp
- **Network**: 10.6.6.0/24

## Common Operations

### View Active Users
1. Open: http://wg.accelior.com:8888/app/#/users
2. View the list of connected peers with real-time status

### Remove a User
1. Open: http://wg.accelior.com:8888/app/#/users
2. Find the user in the list
3. Click "Delete" or "Remove"
4. Confirm deletion
5. User's access is immediately revoked

### View Bandwidth/Statistics
1. Open: http://wg.accelior.com:51821
2. Log in with password
3. View per-client bandwidth usage and connection statistics

## Troubleshooting

### User Can't Connect
1. Verify config file was downloaded correctly
2. Check server is accessible: `ping wg.accelior.com`
3. Verify WireGuard port is open: `telnet wg.accelior.com 51820`
4. Check user is still listed in the management interface

### Management Interface Not Accessible
```bash
# Check if services are running
ssh root@wg.accelior.com 'docker ps | grep wg'

# View service logs
ssh root@wg.accelior.com 'docker logs wg-gen-web-new'
```

### Generate New Config for Existing User
1. Remove the existing user from the interface
2. Create a new user with the same name
3. Download new config/QR code
4. Send to user (old config will no longer work)

## Security Notes

- **Change default passwords** on all management interfaces
- **Use SSH tunnels** for remote management when possible
- **Regularly review** the list of active users
- **Remove inactive users** to maintain security
- **Backup configurations** regularly

## SSH Access for Advanced Operations

```bash
# Connect to WireGuard server
ssh root@wg.accelior.com

# Check WireGuard status
docker exec wg-easy wg show

# View all connected peers
docker exec wg-easy wg show wg0

# Check NAT rules
docker exec wg-easy sh -c "iptables -t nat -L POSTROUTING -n -v"

# View container logs
docker logs wg-gen-web-new --tail 50
```

## Documentation Index

- **Full Documentation**: [README.md](README.md)
- **Migration Guide**: [wireguard-easy-migration.md](wireguard-easy-migration.md)
- **Technical Details**: [wireguard-technical-documentation.md](wireguard-technical-documentation.md)
- **Quick Reference**: [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
- **Troubleshooting**: [nat-network-fix-2025-10-09.md](nat-network-fix-2025-10-09.md)

---

**Last Updated**: 2026-02-05
**Status**: ✅ Active
**Primary Port**: 8888
