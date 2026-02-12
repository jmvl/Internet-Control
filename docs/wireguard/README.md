# WireGuard VPN Documentation

This directory contains comprehensive documentation for the WireGuard VPN server running on Hetzner Cloud.

## Server Information

- **Hostname**: wg.accelior.com
- **IP Address**: 135.181.154.169
- **Location**: Hetzner Helsinki DC (hel1-dc2)
- **OS**: Ubuntu 20.04.6 LTS
- **Server Type**: Hetzner CX22 (2 vCPU, 4GB RAM, 20GB SSD)
- **VPN Network**: 10.6.6.0/24
- **Management**: WireGuard Easy (wg-easy)
- **Previous Clients**: 13 clients (require new configs after migration)

## Documentation Files

### 🚀 [QUICKSTART-PORT-8888.md](QUICKSTART-PORT-8888.md) **← START HERE FOR USER MANAGEMENT**
**Quick start guide for creating VPN users** covering:
- Primary user management interface (port 8888)
- Create/remove VPN users
- View active users
- Troubleshooting user issues

### 📋 [wireguard-easy-migration.md](wireguard-easy-migration.md) **← MIGRATION & SETUP**
**Migration guide and current setup** covering:
- Migration summary (wg-gen-web → WireGuard Easy)
- New access URLs and credentials
- Client migration instructions
- Docker container configuration
- Management commands
- Troubleshooting new setup

**Use this for**: Understanding the current setup, accessing the web UI, migrating clients

### 📊 [bandwidth-tracking.md](bandwidth-tracking.md) **← BANDWIDTH TRACKING**
**Historical bandwidth monitoring system** covering:
- Automated hourly bandwidth logging
- View usage statistics per client
- Export data for analysis
- 90-day retention with auto-rotation
- Command-line tools for quick viewing

**Use this for**: Monitoring bandwidth usage, generating reports, tracking client activity

### 📘 [wireguard-technical-documentation.md](wireguard-technical-documentation.md)
**Legacy technical documentation** (outdated after migration):
- ⚠️ This documents the OLD setup (wg-gen-web + native WireGuard)
- Kept for reference and rollback procedures
- See migration guide for current setup

**Use this for**: Historical reference, rollback procedures if needed

### 📗 [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
**Legacy quick reference guide** (outdated after migration):
- ⚠️ Commands for OLD setup
- Kept for reference purposes
- See migration guide for current commands

**Use this for**: Historical reference only

## Quick Start

### Access WireGuard Easy Web UI
```bash
# Web UI access
URL: http://wg.accelior.com:51821
Password: ChangeThisPassword123! (CHANGE THIS!)

# Or via IP
URL: http://135.181.154.169:51821
```

### SSH Access
```bash
ssh root@wg.accelior.com
```

### Check WireGuard Status
```bash
# Via Docker
ssh root@wg.accelior.com 'docker exec wg-easy wg show'

# View logs
ssh root@wg.accelior.com 'docker logs wg-easy -f'
```

### Add New Client
1. Open web UI: **http://wg.accelior.com:8888/app/#/users** (Primary user management interface)
2. Log in with password
3. Click "New Client" button
4. Enter client name (e.g., "iPhone-John")
5. Download config file or scan QR code with mobile app
6. Done! Client can connect immediately

**Note**: Multiple WireGuard management interfaces are available:
- **Port 8888**: http://wg.accelior.com:8888/app/#/users (Primary - user creation)
- **Port 51821**: http://wg.accelior.com:51821 (WireGuard Easy UI)
- **Port 8080**: http://wg.accelior.com:8080 (Legacy wg-gen-web)

## Architecture Summary

```
┌─────────────────────────────────────────┐
│  Hetzner Server (wg.accelior.com)       │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   WireGuard Easy (Docker)         │ │
│  │   - WireGuard VPN: 51820/udp     │ │
│  │   - Web UI: 51821/tcp             │ │
│  │   - Network: 10.6.6.0/24          │ │
│  │   - Built-in statistics           │ │
│  │   - Password authentication       │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Key Points**:
- **Single Docker container** (ghcr.io/wg-easy/wg-easy)
- **Modern web UI** with real-time statistics
- **Secure authentication** with bcrypt password hash
- **Active development** with regular updates
- **Data stored** in /opt/wg-easy

## Related Documentation

- **Infrastructure Overview**: `/docs/infrastructure.md`
- **Quick Start Guide**: `/QUICK-START.md`
- **Architecture Details**: `/docs/architecture.md`

## Changelog

### 2026-02-05 - Documentation Update
- ✅ **Updated all documentation** to reflect port 8888 as primary user management interface
- ✅ **Added QUICKSTART-PORT-8888.md** for quick user creation reference
- ✅ **Documented multiple management interfaces** running on ports 8888, 51821, and 8080
- ✅ **Clarified current access URLs** across all documentation files

### 2025-10-08 (Evening) - WireGuard Easy Migration
- ✅ **Migrated to WireGuard Easy** from wg-gen-web
- ✅ Stopped native WireGuard service and old containers
- ✅ Created comprehensive migration guide
- ✅ Backed up all old configurations to `/root/wireguard-backups/`
- ✅ Deployed WireGuard Easy on ports 51820 (VPN) and 51821 (Web UI)
- ✅ Configured secure password authentication
- ⚠️ **All 13 clients require new configurations** (new server key)

### 2025-10-08 (Morning) - Initial Documentation
- Initial documentation created
- Documented hybrid architecture (native WireGuard + Docker management)
- Added quick reference guide
- Documented current state: 13 active peers
- Migrated web UI from localhost-only to public access (port 8080)
- Created backup of configuration

## Support

For troubleshooting WireGuard Easy:
1. Check the [Migration Guide](wireguard-easy-migration.md) for current setup details
2. View container logs: `docker logs wg-easy -f`
3. Check WireGuard status: `docker exec wg-easy wg show`
4. Web UI access issues: Verify port 51821 is accessible
5. VPN connection issues: Check port 51820/udp is open

For legacy setup (if rolled back):
1. Check [Legacy Documentation](wireguard-technical-documentation.md)
2. Review [Legacy Quick Reference](QUICK-REFERENCE.md)

## Security Notes

✅ **Current Security Features** (WireGuard Easy):
- ✅ **Password authentication** with bcrypt hash
- ✅ **Modern, maintained software** with active development
- ✅ **Built-in security best practices**
- ⚠️ **Change default password immediately!**

**Recommendations**:
- Change password in web UI settings
- Regularly backup `/opt/wg-easy` directory
- Monitor container logs for suspicious activity
- Keep Docker image updated: `docker pull ghcr.io/wg-easy/wg-easy:latest`
- Consider restricting web UI port 51821 to VPN or trusted IPs

---

**Documentation Version**: 1.1
**Last Updated**: 2026-02-05
