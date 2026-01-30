# Radicale CalDAV/CardDAV Server Documentation

## Overview

Radicale is a CalDAV/CardDAV server providing calendar and contact synchronization capabilities for the infrastructure. It runs in a Docker container within the Hestia mail server environment and is accessible via the primary domain `radicale.home.accelior.com`.

## Architecture

### Container Infrastructure
- **Host**: Proxmox container 130 (mail.vega-messenger.com) at 192.168.1.30
- **Container Image**: `tomsquest/docker-radicale:latest`
- **Version**: 3.5.7.0 (Python 3.12.11)
- **Status**: Healthy
- **Docker Health**: Responding to health checks every 30 seconds
- **Last Updated**: October 9, 2025

### Network Configuration
```
External Traffic Flow (Production):
Internet → Dynamic DNS → OPNsense (WAN:443) → NPM (192.168.1.121:443) → Radicale Container (192.168.1.30:5232)
Domain: radicale.home.accelior.com

⚠️ Note: Path-based routing via mail.accelior.com/radicale/ is NOT configured.
Always use the production subdomain: radicale.home.accelior.com
```

### Port Mapping
- **Internal**: Container port 5232/tcp
- **External Binding**: 192.168.1.30:5232 → 5232/tcp
- **Nginx Proxy**: 192.168.1.30:443 → radicale proxy configuration

## DNS Configuration

### Domain Structure
```
Primary Domain:
radicale.home.accelior.com (Production subdomain - ONLY supported method)

DNS Records (accelior.com zone):
├── home.accelior.com           → A <WAN IP> (Dynamic DNS, TTL: 30s)
└── radicale.home.accelior.com  → CNAME home.accelior.com
```

### Dynamic DNS Configuration
**OPNsense Dynamic DNS Service:**
- **Domain**: home.accelior.com
- **Interface**: opt1
- **Provider**: Cloudflare v6
- **Updates**: Automatic WAN IP updates via Cloudflare API
- **TTL**: 30 seconds
- **Used By**: radicale.home.accelior.com (via CNAME)

## SSL/TLS Configuration

### Certificate Details
- **Issuer**: Let's Encrypt
- **Subject**: radicale.home.accelior.com
- **Managed By**: Nginx Proxy Manager (192.168.1.121 - pve2 PCT 121)
- **Auto-renewal**: Enabled via NPM Let's Encrypt integration
- **Certificate ID**: npm-49
- **Key Type**: RSA (Let's Encrypt default)

### Certificate Management
- **Automatic Renewal**: NPM handles renewal 30 days before expiration
- **Certificate Storage**: `/etc/letsencrypt/live/npm-49/` (in NPM container)
- **Monitoring**: NPM dashboard shows expiration dates and renewal status

## Service Configuration

### Docker Container Details
```yaml
Container: radicale
Image: tomsquest/docker-radicale:latest
Version: 3.5.7.0
Python Runtime: 3.12.11
Status: Healthy
Ports: 192.168.1.30:5232->5232/tcp
Volumes:
  - /root/radicale/data:/data
  - /root/radicale/config:/config:ro
Restart Policy: unless-stopped
Health Check: curl -f http://localhost:5232/.web/ (every 30s)
Last Updated: October 9, 2025
```

### Service Endpoints
- **Production URL (REQUIRED)**: `https://radicale.home.accelior.com/.web/`
- **Direct Access (Internal)**: `http://192.168.1.30:5232/.web/` (troubleshooting only)
- **Authentication**: HTTP Basic Auth (optional on production, not required on direct access)

⚠️ **Important**: Path-based routing (`mail.accelior.com/radicale/`) is NOT available.
The nginx location block shown below is documentation only and not deployed.

## Authentication & Security

### Authentication Method
- **Type**: HTTP Basic Authentication
- **Realm**: "Radicale - Password Required"
- **Password File**: `/home/accelior/conf/mail/.htpasswd`
- **User Account**: Configured for accelior domain

### Security Headers
```http
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS, PROPFIND, PROPPATCH, REPORT, PUT, MOVE, DELETE, LOCK, UNLOCK
Access-Control-Allow-Headers: User-Agent, Authorization, Content-type, Depth, If-match, If-None-Match, Lock-Token, Timeout, Destination, Overwrite, Prefer, X-client, X-Requested-With
Access-Control-Expose-Headers: Etag, Preference-Applied, Vary
```

### Container Security
- **Privileged Mode**: No (not running privileged)
- **Network Binding**: Specific interface (192.168.1.30:5232)
- **Additional Security Options**: None configured (potential improvement area)

## Nginx Proxy Configuration

⚠️ **Status**: Path-based routing is NOT configured
**Reason**: Direct subdomain access via NPM is simpler and more maintainable

### Internal Nginx Configuration (192.168.1.30) - NOT DEPLOYED
The following configuration was considered but NOT implemented:
```nginx
# ❌ THIS CONFIGURATION IS NOT ACTIVE ❌
# Path-based routing is not configured
# Use radicale.home.accelior.com instead

# location /radicale/ {
#     proxy_pass http://localhost:5232/;
#     proxy_set_header Host $host;
#     proxy_set_header X-Real-IP $remote_addr;
#     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#     proxy_set_header X-Forwarded-Proto $scheme;
#
#     # Authentication required
#     auth_basic "Radicale - Password Required";
#     auth_basic_user_file /home/accelior/conf/mail/.htpasswd;
# }
```

### NPM Configuration (192.168.1.121)

**Primary Proxy Host (radicale.home.accelior.com):**
- **ID**: 36
- **Domain**: radicale.home.accelior.com
- **Forward Scheme**: HTTP
- **Forward Host**: 192.168.1.30
- **Forward Port**: 5232
- **SSL Certificate**: Let's Encrypt (npm-49)
- **Configuration**: `/data/nginx/proxy_host/36.conf`
- **NPM Host**: pve2 PCT 121 (192.168.1.121)

**Mail Domain Proxy (mail.accelior.com):**
- **ID**: 18
- **Domain**: mail.accelior.com
- **Forward Scheme**: HTTPS
- **Forward Host**: 192.168.1.30
- **Forward Port**: 443
- **SSL Certificate**: Let's Encrypt (npm-16)
- **Purpose**: Webmail access only (does NOT include /radicale/ path routing)

## Client Configuration

### CalDAV/CardDAV Settings
```
Server URL: https://radicale.home.accelior.com/
Authentication: HTTP Basic Auth (optional for now, no auth configured)
Port: 443 (HTTPS)
SSL/TLS: Required
Discovery: Automatic via .well-known endpoints

⚠️ Note: Only the subdomain URL above is supported.
Path-based routing via mail.accelior.com/radicale/ is NOT available.
```

### Supported Clients
- **iOS/macOS**: Native Calendar and Contacts apps
- **Android**: DAVx5, CalDAV-Sync, CardDAV-Sync
- **Desktop**: Mozilla Thunderbird + CardBook, Evolution, KDE Kontact
- **Web**: Browser access via `/.web/` interface

### DAVx5 Configuration
```
Account Type: CalDAV/CardDAV
Base URL: https://radicale.home.accelior.com/
Username: [optional - no auth currently]
Password: [optional - no auth currently]
Auto-discovery: Enabled
```

## Troubleshooting

### Common Issues

#### 1. DNS Propagation Delays & Pi-hole Cache
**Symptoms**: Client connection failures, DNS_PROBE_FINISHED_NXDOMAIN error
**Diagnosis**:
```bash
# Check authoritative DNS
dig @cleo.ns.cloudflare.com radicale.home.accelior.com

# Check Pi-hole resolution
dig @192.168.1.5 radicale.home.accelior.com

# Check public DNS
dig @8.8.8.8 radicale.home.accelior.com
dig @1.1.1.1 radicale.home.accelior.com
```
**Common Issue**: Pi-hole caches negative NXDOMAIN responses
**Solution**:
```bash
# Reload Pi-hole DNS to clear cache
ssh root@192.168.1.20 'docker exec pihole pihole reloaddns'
```
**Note**: Pi-hole runs as Docker container on 192.168.1.20, not directly on 192.168.1.5

#### 2. SSL Certificate Issues
**Diagnosis**:
```bash
# Check certificate
echo | openssl s_client -connect 77.109.89.47:443 -servername radicale.acmea.tech
```
**Common Causes**: Domain mismatch, expired certificate, NPM misconfiguration

#### 3. Authentication Failures
**Diagnosis**:
```bash
# Test direct access
curl -I http://192.168.1.30:5232/.web/

# Test with auth
curl -u username:password http://192.168.1.30:5232/.web/
```

#### 4. NPM Database Write Errors
**Symptoms**: "Internal error" when creating proxy hosts in NPM
**Error Log**: `SQLITE_READONLY: attempt to write a readonly database`
**Diagnosis**:
```bash
# Check NPM database permissions
ssh root@192.168.1.20 'docker exec npm ls -la /data/database.sqlite'
```
**Solution**:
```bash
# Fix database permissions
ssh root@192.168.1.20 'docker exec npm chmod 666 /data/database.sqlite'

# Restart NPM container
ssh root@192.168.1.20 'docker restart npm'
```
**Root Cause**: Database file permissions become read-only (644 instead of 666)

#### 5. Firewall/Network Issues
**Previous Issue**: fail2ban accumulated 400+ REJECT rules blocking web traffic
**Resolution**: Flush fail2ban chains, restore proper RETURN rule
**Prevention**: Monitor fail2ban rule accumulation

### Diagnostic Commands

#### Service Health Check
```bash
# Container status
ssh root@pve2 'pct exec 130 -- docker ps'

# Service response
curl -I http://192.168.1.30:5232/.web/

# Nginx proxy status
curl -I https://192.168.1.30/radicale/
```

#### Network Connectivity
```bash
# Port accessibility
nc -zv 192.168.1.30 5232

# HTTPS endpoint (primary)
curl -I https://radicale.home.accelior.com/.web/

# DNS resolution
dig radicale.home.accelior.com
nslookup radicale.home.accelior.com
```

#### SSL/Certificate Validation
```bash
# Certificate details
openssl s_client -connect radicale.home.accelior.com:443 -servername radicale.home.accelior.com

# Certificate expiration
echo | openssl s_client -connect radicale.home.accelior.com:443 2>/dev/null | openssl x509 -noout -dates

# NPM certificate check
ssh root@192.168.1.20 'docker exec npm ls -la /etc/letsencrypt/live/npm-49/'
```

## Maintenance

### Regular Tasks

#### Certificate Monitoring
- **Expiration**: December 15, 2025
- **Auto-renewal**: Via NPM Let's Encrypt integration
- **Monitoring**: Check certificate validity monthly

#### Container Health
- **Status**: Monitor via `docker ps` and health checks
- **Logs**: Check container logs for errors
- **Updates**: Update container image periodically

#### DNS Management
- **TTL Optimization**: Current 60s for A record, 300s for CNAME
- **Dynamic DNS**: Monitor OPNsense dynamic DNS service status
- **Propagation**: Test DNS changes across multiple resolvers

### Backup Procedures

#### Full Backup (Recommended)
```bash
# Complete backup of Radicale directory (data + config + compose)
ssh root@pve2 'pct exec 130 -- tar -czf /root/radicale-backup-$(date +%Y%m%d-%H%M%S).tar.gz /root/radicale/'

# Verify backup
ssh root@pve2 'pct exec 130 -- tar -tzf /root/radicale-backup-*.tar.gz | head -20'

# Latest backup location: /root/radicale-backup-20251009-214358.tar.gz (6.4MB)
```

#### Container Update Procedure
```bash
# 1. Backup current state
ssh root@pve2 'pct exec 130 -- tar -czf /root/radicale-backup-$(date +%Y%m%d-%H%M%S).tar.gz /root/radicale/'

# 2. Stop and remove old container
ssh root@pve2 'pct exec 130 -- docker stop radicale'
ssh root@pve2 'pct exec 130 -- docker rm radicale'

# 3. Pull latest image
ssh root@pve2 'pct exec 130 -- docker pull tomsquest/docker-radicale:latest'

# 4. Recreate container with same configuration
ssh root@pve2 'pct exec 130 -- docker run -d --name radicale \
  --restart unless-stopped \
  -p 192.168.1.30:5232:5232 \
  -v /root/radicale/data:/data \
  -v /root/radicale/config:/config:ro \
  --health-cmd="curl -f http://localhost:5232/.web/" \
  --health-interval=30s \
  tomsquest/docker-radicale:latest'

# 5. Verify health
ssh root@pve2 'pct exec 130 -- docker ps --filter name=radicale'
curl -I https://radicale.home.accelior.com/.web/
```

#### Configuration Backup
```bash
# Nginx configuration (if using path-based routing)
ssh root@pve2 'pct exec 130 -- cp /home/accelior/conf/mail/.htpasswd /root/backup/'

# Docker container config inspection
ssh root@pve2 'pct exec 130 -- docker inspect radicale > /root/radicale-config.json'
```

## Performance Optimization

### Current Performance
- **Container Health**: Healthy (4+ weeks uptime)
- **Response Time**: Sub-second for web interface
- **SSL Performance**: ECDSA P-384 (optimal for mobile clients)

### Potential Improvements
1. **Container Security**: Add security options (no-new-privileges, capability dropping)
2. **Rate Limiting**: Implement rate limiting for CalDAV endpoints
3. ✅ **Monitoring**: Added to Uptime Kuma (Monitor ID: 38) - Completed 2025-10-18
4. **Caching**: Implement nginx caching for static resources

## Security Considerations

### Current Security Measures
- **SSL/TLS**: Strong encryption with modern cipher suites
- **Authentication**: HTTP Basic Auth (sufficient for encrypted connections)
- **Network Isolation**: Container isolated to specific interface
- **Firewall**: OPNsense firewall protection

### Security Recommendations
1. **Enhanced Container Security**:
   ```yaml
   security_opt:
     - no-new-privileges:true
   cap_drop:
     - ALL
   cap_add:
     - CHOWN
     - DAC_OVERRIDE
     - SETGID
     - SETUID
   ```

2. **Rate Limiting**: Implement fail2ban rules for CalDAV-specific attacks
3. **IP Whitelisting**: Consider restricting access to known client IPs
4. **Monitoring**: Implement intrusion detection for CalDAV endpoints

## Architecture Decisions

### Why Radicale?
- **Lightweight**: Minimal resource usage
- **Standards Compliant**: Full CalDAV/CardDAV RFC compliance
- **Docker Ready**: Excellent containerization support
- **Multi-user**: Supports multiple user accounts
- **Web Interface**: Built-in management interface

### Infrastructure Integration
- **Hestia Integration**: Leverages existing mail server infrastructure
- **NPM Integration**: Unified SSL certificate management
- **OPNsense Integration**: Centralized firewall and routing
- **Dynamic DNS**: Automatic IP updates for changing ISP addresses

## Future Enhancements

### Planned Improvements
1. ✅ **Monitoring Integration**: Added to Uptime Kuma (2025-10-18)
2. **Security Hardening**: Implement container security best practices
3. **Documentation**: Create client configuration guides
4. **Authentication**: Consider enabling authentication for production use

### Scalability Considerations
- **Multi-domain Support**: Easy addition of new domains
- **Load Balancing**: Potential for multiple Radicale instances
- **High Availability**: Database backend for shared storage
- **Backup Integration**: Automated backup to existing backup infrastructure

---

## Change Log

### Version 2.2 - January 22, 2026
- ✅ **NPM Migration Updated**: Documentation updated for NPM migration to pve2 PCT 121
- **NPM Location Changed**: 192.168.1.9 (OMV) → 192.168.1.121 (pve2 PCT 121)
- **Network Flow Updated**: OPNsense → NPM (192.168.1.121) → Radicale (192.168.1.30)
- **Verified**: Radicale proxy and SSL certificate working correctly through new NPM
- **Reference**: See `/docs/npm/npm-migration-to-pve2-2026-01-20.md` for migration details

### Version 2.1 - October 18, 2025
- ✅ **Monitoring Added**: Integrated with Uptime Kuma (Monitor ID: 38)
- ⚠️ **Documentation Correction**: Removed references to non-existent path-based routing
- **Clarification**: Confirmed `radicale.home.accelior.com` is the ONLY supported access method
- **Status**: Production URL `https://radicale.home.accelior.com/.web/` verified working
- **Container**: Healthy, 8 days uptime as of 2025-10-18

### Version 2.0 - October 9, 2025
- Updated to Radicale 3.5.7.0 (from 3.5.4.0)
- Migrated primary access to subdomain: radicale.home.accelior.com
- Added NPM proxy host configuration (ID 36)
- Documented Pi-hole DNS cache troubleshooting
- Added NPM database permission issue resolution
- Updated backup and container update procedures
- Documented complete network flow for subdomain routing

### Version 1.0 - September 18, 2025
- Initial documentation
- ~~Path-based routing via mail.accelior.com/radicale/~~ (Never actually configured)
- Container version 3.5.4.0

---

**Last Updated**: January 22, 2026
**Document Version**: 2.2
**Maintainer**: Infrastructure Team