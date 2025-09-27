# Radicale CalDAV/CardDAV Server Documentation

## Overview

Radicale is a CalDAV/CardDAV server providing calendar and contact synchronization capabilities for the infrastructure. It runs in a Docker container within the Hestia mail server environment and is accessible via multiple domain endpoints.

## Architecture

### Container Infrastructure
- **Host**: Proxmox container 130 (mail.vega-messenger.com)
- **Container Image**: `tomsquest/docker-radicale`
- **Status**: Up 4+ weeks (healthy)
- **Docker Health**: Responding to health checks every 30 seconds

### Network Configuration
```
External Traffic Flow:
Internet → Dynamic DNS → OPNsense (77.109.89.47:443) → NPM (192.168.1.9:443) → Hestia Nginx (192.168.1.30:443) → Radicale Container (192.168.1.30:5232)
```

### Port Mapping
- **Internal**: Container port 5232/tcp
- **External Binding**: 192.168.1.30:5232 → 5232/tcp
- **Nginx Proxy**: 192.168.1.30:443 → radicale proxy configuration

## DNS Configuration

### Domain Structure
```
Primary Domains:
├── mail.accelior.com/radicale/.web/     (Working, mail server domain)
└── radicale.acmea.tech/                 (Target domain, DNS propagation issues)

DNS Records (acmea.tech zone):
├── base.acmea.tech         → A 77.109.89.47 (TTL: 60s)
└── radicale.acmea.tech     → CNAME base.acmea.tech (TTL: 300s)
```

### Dynamic DNS Configuration
**OPNsense Dynamic DNS Services:**
1. **Legacy Service (home.accelior.com)**:
   - Interface: opt1
   - Provider: Cloudflare v6
   - Updates: home.accelior.com → Current WAN IP
   - TTL: 30 seconds

2. **Modern Service (base.acmea.tech)**:
   - Interface: wan
   - Provider: Cloudflare
   - Token: nNZSTw1xMqoy39mRSXoWvG5fWq7ztJpHTj3Krrgb
   - Updates: base.acmea.tech → Current WAN IP
   - TTL: 300 seconds

## SSL/TLS Configuration

### Certificate Details
- **Issuer**: Let's Encrypt (E8)
- **Subject**: radicale.acmea.tech
- **Validity**: September 16, 2025 → December 15, 2025
- **Key Type**: ECDSA P-384
- **SAN**: radicale.acmea.tech

### Certificate Chain
```
Certificate Authority: Let's Encrypt (E8)
├── Serial: 05:74:e7:ba:85:6f:1b:f6:d7:c9:72:46:c8:a3:60:ef:6e:39
├── Signature Algorithm: ecdsa-with-SHA384
├── Key Usage: Digital Signature (critical)
├── Extended Key Usage: TLS Web Server Authentication, TLS Web Client Authentication
└── Certificate Transparency: 2 SCT entries present
```

## Service Configuration

### Docker Container Details
```yaml
Container: radicale
Image: tomsquest/docker-radicale
Status: Up 4 weeks (healthy)
Created: August 20, 2025 at 20:23:28 UTC
Ports: 192.168.1.30:5232->5232/tcp
Health Check: Every 30 seconds
```

### Internal Service Endpoints
- **Direct Access**: `http://192.168.1.30:5232/.web/`
- **HTTPS Proxy**: `https://192.168.1.30/radicale/`
- **Authentication**: HTTP Basic Auth via `/home/accelior/conf/mail/.htpasswd`

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

### Internal Nginx Configuration (192.168.1.30)
```nginx
# Proxy configuration in Hestia Nginx
location /radicale/ {
    proxy_pass http://localhost:5232/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Authentication required
    auth_basic "Radicale - Password Required";
    auth_basic_user_file /home/accelior/conf/mail/.htpasswd;
}
```

### NPM Configuration (192.168.1.9)
**Proxy Host Configuration:**
- **ID**: 18
- **Domain**: mail.accelior.com
- **Forward Scheme**: HTTPS
- **Forward Host**: 192.168.1.30
- **Forward Port**: 443
- **SSL Certificate**: Let's Encrypt (npm-16)

**Required NPM Fix for radicale.acmea.tech:**
```nginx
# New proxy host needed for radicale.acmea.tech
# Forward to: 192.168.1.30:443
# SSL Certificate: Let's Encrypt for radicale.acmea.tech
```

## Client Configuration

### CalDAV/CardDAV Settings
```
Server URL: https://radicale.acmea.tech/ (or https://mail.accelior.com/radicale/)
Authentication: HTTP Basic Auth
Port: 443 (HTTPS)
SSL/TLS: Required
Discovery: Automatic via .well-known endpoints
```

### Supported Clients
- **iOS/macOS**: Native Calendar and Contacts apps
- **Android**: DAVx5, CalDAV-Sync, CardDAV-Sync
- **Desktop**: Mozilla Thunderbird + CardBook, Evolution, KDE Kontact
- **Web**: Browser access via .web interface

### DAVx5 Configuration
```
Account Type: CalDAV/CardDAV
Base URL: https://radicale.acmea.tech/
Username: [configured username]
Password: [configured password]
Auto-discovery: Enabled
```

## Troubleshooting

### Common Issues

#### 1. DNS Propagation Delays
**Symptoms**: Client connection failures, wrong IP resolution
**Diagnosis**:
```bash
# Check authoritative DNS
dig @cleo.ns.cloudflare.com radicale.acmea.tech

# Check public DNS
dig @8.8.8.8 radicale.acmea.tech
dig @1.1.1.1 radicale.acmea.tech
```
**Solution**: Wait for propagation or use hosts file entry

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

#### 4. Firewall/Network Issues
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

# HTTPS endpoint
curl -I https://radicale.acmea.tech/

# DNS resolution
nslookup radicale.acmea.tech
```

#### SSL/Certificate Validation
```bash
# Certificate details
openssl s_client -connect radicale.acmea.tech:443 -servername radicale.acmea.tech

# Certificate expiration
echo | openssl s_client -connect radicale.acmea.tech:443 2>/dev/null | openssl x509 -noout -dates
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

#### Configuration Backup
```bash
# Nginx configuration
cp /home/accelior/conf/mail/.htpasswd /backup/location/

# Docker container config
docker inspect radicale > /backup/radicale-config.json
```

#### Data Backup
```bash
# Radicale data directory (if persistent)
docker exec radicale tar -czf - /data | ssh backup-server 'cat > radicale-data.tar.gz'
```

## Performance Optimization

### Current Performance
- **Container Health**: Healthy (4+ weeks uptime)
- **Response Time**: Sub-second for web interface
- **SSL Performance**: ECDSA P-384 (optimal for mobile clients)

### Potential Improvements
1. **Container Security**: Add security options (no-new-privileges, capability dropping)
2. **Rate Limiting**: Implement rate limiting for CalDAV endpoints
3. **Monitoring**: Add to Uptime Kuma for service monitoring
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
1. **NPM Configuration**: Add dedicated proxy host for radicale.acmea.tech
2. **Monitoring Integration**: Add to existing Uptime Kuma setup
3. **Security Hardening**: Implement container security best practices
4. **Documentation**: Create client configuration guides

### Scalability Considerations
- **Multi-domain Support**: Easy addition of new domains
- **Load Balancing**: Potential for multiple Radicale instances
- **High Availability**: Database backend for shared storage
- **Backup Integration**: Automated backup to existing backup infrastructure

---

**Last Updated**: September 18, 2025
**Document Version**: 1.0
**Maintainer**: Infrastructure Team