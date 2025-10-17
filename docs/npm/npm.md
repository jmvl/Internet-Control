# Nginx Proxy Manager (NPM) Documentation

## Overview
Nginx Proxy Manager provides a web-based interface for managing Nginx reverse proxy configurations. It simplifies SSL certificate management, proxy host configuration, and provides an intuitive GUI for complex Nginx configurations. It runs as a Docker container on the OMV node (192.168.1.9) and serves as the primary entry point for all external web traffic.

## System Information
- **Host**: OpenMediaVault NAS (192.168.1.9)
- **Container**: `nginx-proxy-manager-nginx-proxy-manager-1`
- **Image**: `jc21/nginx-proxy-manager:latest`
- **Web Interface**: http://192.168.1.9:81 (Admin Panel) - https://nginx.home.accelior.com/
- **HTTP Proxy**: Port 80 (HTTP traffic)
- **HTTPS Proxy**: Port 443 (HTTPS traffic)
- **Status**: Up 3 weeks
- **Access**: SSH `root@192.168.1.9` or `root@omv`

## Container Configuration

### Basic Settings
| Component | Value | Purpose |
|-----------|-------|---------|
| **Container Name** | nginx-proxy-manager-nginx-proxy-manager-1 | Reverse proxy service |
| **Image** | jc21/nginx-proxy-manager:latest | Official NPM image |
| **Admin Panel** | 80-81:80-81 | Management interface |
| **HTTP/HTTPS** | 80:80, 443:443 | Proxy traffic ports |
| **Restart Policy** | unless-stopped | Auto-restart on boot |

### Environment Variables
```bash
OPENRESTY_VERSION=1.27.1.1               # OpenResty (Nginx) version
CROWDSEC_OPENRESTY_BOUNCER_VERSION=0.1.7 # CrowdSec integration
SUPPRESS_NO_CONFIG_WARNING=1             # Suppress config warnings
S6_BEHAVIOUR_IF_STAGE2_FAILS=1           # Service management
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
```

### Port Configuration
```
External Ports:
- 80 (HTTP) → Container port 80
- 81 (Admin) → Container port 81
- 443 (HTTPS) → Container port 443

IPv6 Support: Enabled on all ports
```

### Container Status
```bash
CONTAINER ID   IMAGE                                 COMMAND   CREATED        STATUS       PORTS
4ca94dda70a7   jc21/nginx-proxy-manager:latest      "/init"   2 months ago   Up 3 weeks   0.0.0.0:80-81->80-81/tcp, [::]:80-81->80-81/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp
```

## Core Features

### Reverse Proxy Management
- **Proxy Hosts**: Configure reverse proxy for internal services
- **SSL Termination**: Automatic SSL certificate management
- **Load Balancing**: Distribute traffic across multiple backends
- **Custom Locations**: Advanced routing and location blocks
- **WebSocket Support**: Proxy WebSocket connections

### SSL Certificate Management
- **Let's Encrypt Integration**: Automatic SSL certificate generation
- **Wildcard Certificates**: Support for wildcard SSL certificates
- **Custom Certificates**: Upload and manage custom SSL certificates
- **Auto-Renewal**: Automatic certificate renewal before expiration
- **Multiple Providers**: Support for various certificate authorities

### Security Features
- **Access Lists**: IP-based access control
- **HTTP Authentication**: Basic authentication for services
- **SSL Force**: Redirect HTTP to HTTPS automatically
- **Header Management**: Custom HTTP headers
- **Rate Limiting**: Request rate limiting capabilities

## Directory Structure

### Configuration Files
```
/data/nginx/proxy_host/          # Dynamic proxy host configurations
/data/nginx/custom/              # Custom nginx configurations
/data/nginx/dead_host/           # Disabled/dead host configurations
/data/nginx/redirection_host/    # URL redirection configurations
/data/nginx/stream/              # TCP/UDP stream configurations
/data/nginx/temp/                # Temporary files
```

### SSL Certificates
```
/etc/letsencrypt/live/           # Let's Encrypt certificates
/etc/letsencrypt/archive/        # Certificate archives
/data/nginx/custom_ssl/          # Custom SSL certificates
```

### Logs
```
/data/logs/                      # NPM access and error logs
/data/logs/proxy-host-*_access.log    # Individual proxy host access logs
/data/logs/proxy-host-*_error.log     # Individual proxy host error logs
```

## Current Infrastructure Integration

### Proxied Services
Based on the infrastructure, NPM manages various internal services:

**Internal Services**:
- **Portainer**: Docker management (9443 → 443)
- **Immich**: Photo management (2283 → 443)
- **Calibre-Web**: E-book library (8083 → 443)
- **Uptime Kuma**: Monitoring (3010 → 443)
- **Wedding Share**: Photo gallery (8080 → 443)

**Management Interfaces**:
- **Proxmox**: Virtualization (8006 → 443)
- **OPNsense**: Firewall management (443 → 443)
- **Pi-hole**: DNS management (80 → 443)

## Proxy Host Configurations

### Current Active Configurations

#### Mail Services (Hestia Mail Server - 192.168.1.30)

**1. mail.accelior.com** (`/data/nginx/proxy_host/18.conf`)
```nginx
server_name: mail.accelior.com
backend: https://192.168.1.30:8083  # ❌ INCORRECT - Should be 8443
ssl: Let's Encrypt (npm-XX)
force_ssl: enabled
```

**2. mail.acmea.tech** (`/data/nginx/proxy_host/28.conf`)
```nginx
server_name: mail.acmea.tech
backend: http://192.168.1.30:80   # ❌ INCORRECT - Should be https://192.168.1.30:8443
ssl: Let's Encrypt (npm-XX)
force_ssl: enabled
```

**3. webmail.acmea.tech** (`/data/nginx/proxy_host/29.conf`)
```nginx
server_name: webmail.acmea.tech
backend: https://192.168.1.30:443  # ❌ INCORRECT - Should be 8443
ssl: Let's Encrypt (npm-XX)
force_ssl: enabled
```

#### Other Services

**4. ntop.acmea.tech** (`/data/nginx/proxy_host/14.conf`)
```nginx
server_name: ntop.acmea.tech
backend: http://192.168.1.20:3000
ssl: Let's Encrypt (npm-36)
purpose: Network monitoring interface
```

### Required Configuration Fixes

#### Webmail Services Fix
All webmail domains must be configured to point to the correct backend:

**Correct Configuration:**
```
Backend: https://192.168.1.30:8443
Scheme: HTTPS
Certificate Validation: Disabled (self-signed backend)
```

**Required Updates:**
1. mail.accelior.com: Change port from 8083 → 8443
2. mail.acmea.tech: Change to HTTPS and port 80 → 8443
3. webmail.acmea.tech: Change port from 443 → 8443

### Configuration Examples

#### Typical Proxy Host Configuration
```yaml
# Example Proxy Host
Domain Names: immich.domain.com
Scheme: http
Forward Hostname/IP: 192.168.1.9
Forward Port: 2283
Block Common Exploits: Yes
Websockets Support: Yes
Access List: Internal Only

# SSL Configuration
SSL Certificate: Let's Encrypt
Force SSL: Yes
HTTP/2 Support: Yes
HSTS Enabled: Yes
```

#### Access List Example
```yaml
# Internal Network Access List
Name: Internal Only
Satisfy: All
Pass Auth: No

Allow:
  192.168.1.0/24

Deny:
  all
```

## SSL Certificate Management

### Let's Encrypt Integration
NPM automatically manages Let's Encrypt certificates with the following features:
- Automatic certificate generation
- 90-day renewal automation
- Support for wildcard certificates
- HTTP-01 and DNS-01 challenge support

### Current Certificate Issues

#### Missing Webmail Subdomains
Some certificates need to include webmail subdomains:

**acmea.tech certificate should include:**
- acmea.tech
- www.acmea.tech
- webmail.acmea.tech ← Missing
- mail.acmea.tech

**accelior.com certificate should include:**
- accelior.com
- www.accelior.com
- webmail.accelior.com ← Missing
- mail.accelior.com

### Certificate Renewal
```bash
# Check certificate status
docker exec nginx-proxy-manager-nginx-proxy-manager-1 certbot certificates

# Manual renewal (if needed)
docker exec nginx-proxy-manager-nginx-proxy-manager-1 certbot renew --dry-run
```

## Web Interface Access

### Admin Panel
- **URL**: http://192.168.1.9:81
- **Default Login**: admin@example.com / changeme (first run)
- **Features**: Full proxy management interface
- **Mobile Support**: Responsive design for mobile management

### Management Capabilities
- **Proxy Host Creation**: Add new reverse proxy configurations
- **SSL Certificate Management**: Generate and manage certificates
- **Access List Management**: Configure IP-based access control
- **Stream Configuration**: TCP/UDP stream proxying
- **Custom Nginx Config**: Advanced Nginx configuration

## Data Storage and Persistence

### Configuration Storage
- **Database**: SQLite database for configuration
- **SSL Certificates**: Stored in container volumes
- **Nginx Configs**: Generated configuration files
- **Logs**: Access and error logs

### Volume Management
```bash
# NPM data volumes (typical setup)
nginx-proxy-manager_data → /data
nginx-proxy-manager_letsencrypt → /etc/letsencrypt
```

## Performance Optimization

### Nginx Configuration
- **Worker Processes**: Optimized for available CPU cores
- **Connection Limits**: Configured for expected load
- **Buffer Sizes**: Optimized for typical request sizes
- **Caching**: Static content caching where appropriate

### Resource Usage
- **Memory**: ~100-200MB RAM usage
- **CPU**: Low CPU usage for proxy operations
- **Network**: Dependent on proxied traffic volume
- **Storage**: Minimal for configuration and certificates

## Administration

### Docker Management
```bash
# Container status
docker ps | grep nginx-proxy-manager

# View logs
docker logs nginx-proxy-manager-nginx-proxy-manager-1

# Restart container
docker restart nginx-proxy-manager-nginx-proxy-manager-1

# Execute commands in container
docker exec -it nginx-proxy-manager-nginx-proxy-manager-1 /bin/bash
```

### Configuration Inspection
```bash
# View proxy configurations
docker exec nginx-proxy-manager-nginx-proxy-manager-1 find /data/nginx/proxy_host -name "*.conf"

# Check specific domain configuration
docker exec nginx-proxy-manager-nginx-proxy-manager-1 cat /data/nginx/proxy_host/18.conf

# Search for domain in configurations
docker exec nginx-proxy-manager-nginx-proxy-manager-1 grep -r "domain.com" /data/nginx/proxy_host/
```

## Traffic Flow Architecture

### Reverse Proxy Chain
```
Internet
    ↓
Router/Firewall (Dynamic IP: 77.109.89.47)
    ↓
OPNsense Firewall (192.168.1.3) - Port forwarding 80/443
    ↓
OMV Nginx Proxy Manager (192.168.1.9:80/443)
    ↓
Backend Services:
    - Hestia Mail Server (192.168.1.30:8443) - Webmail/Mail
    - Docker Services (192.168.1.20:XXXX) - Various apps
    - Other internal services
```

### Load Balancing
NPM supports multiple load balancing algorithms:
- Round Robin (default)
- Least Connections
- IP Hash
- Health checks with automatic failover

## Security Features

### Access Lists
NPM supports IP-based access control:
- Whitelist/blacklist IP ranges
- Geographic restrictions
- Password protection
- Custom authentication methods

### Security Headers
Automatic security headers can be configured:
- HSTS (HTTP Strict Transport Security)
- CSP (Content Security Policy)
- X-Frame-Options
- X-Content-Type-Options

### Rate Limiting
Built-in rate limiting capabilities:
- Requests per second/minute/hour
- Connection limits
- Bandwidth throttling

## Monitoring and Troubleshooting

### Log Analysis
```bash
# Real-time access logs
docker exec nginx-proxy-manager-nginx-proxy-manager-1 tail -f /data/logs/proxy-host-18_access.log

# Error logs for specific proxy
docker exec nginx-proxy-manager-nginx-proxy-manager-1 tail -f /data/logs/proxy-host-18_error.log

# Nginx error logs
docker exec nginx-proxy-manager-nginx-proxy-manager-1 tail -f /var/log/nginx/error.log
```

### Health Checks
```bash
# Test proxy functionality
curl -H "Host: mail.acmea.tech" http://192.168.1.9/

# Check SSL certificate
openssl s_client -connect 192.168.1.9:443 -servername mail.acmea.tech

# Verify backend connectivity
docker exec nginx-proxy-manager-nginx-proxy-manager-1 curl -k https://192.168.1.30:8443
```

### Common Issues

#### Backend Connection Failures
- Check backend service status
- Verify port configuration
- Test direct backend connectivity
- Review firewall rules

#### SSL Certificate Problems
- Verify domain DNS resolution
- Check Let's Encrypt rate limits
- Ensure HTTP challenge accessibility
- Review certificate domain coverage

#### Performance Issues
- Monitor backend response times
- Check NPM resource usage
- Review access logs for traffic patterns
- Consider load balancing configuration

## Backup and Recovery

### Configuration Backup
```bash
# Backup NPM data directory
docker exec nginx-proxy-manager-nginx-proxy-manager-1 tar -czf /tmp/npm-backup.tar.gz /data

# Copy backup from container
docker cp nginx-proxy-manager-nginx-proxy-manager-1:/tmp/npm-backup.tar.gz ./npm-backup-$(date +%Y%m%d).tar.gz
```

### Database Backup
```bash
# NPM uses SQLite database
docker exec nginx-proxy-manager-nginx-proxy-manager-1 cp /data/database.sqlite /tmp/database-backup.sqlite
docker cp nginx-proxy-manager-nginx-proxy-manager-1:/tmp/database-backup.sqlite ./
```

## Maintenance Tasks

### Regular Maintenance
- **Weekly**: Review access logs for anomalies
- **Monthly**: Check SSL certificate status and renewal
- **Quarterly**: Update NPM container image
- **Annually**: Review and audit proxy configurations

### Maintenance Operations

#### Container Management
```bash
# Check NPM status
docker ps | grep nginx-proxy-manager

# View NPM logs
docker logs nginx-proxy-manager-nginx-proxy-manager-1 --tail 50

# Restart NPM
docker restart nginx-proxy-manager-nginx-proxy-manager-1

# Update NPM
docker-compose pull nginx-proxy-manager
docker-compose up -d nginx-proxy-manager
```

#### Certificate Management
```bash
# View certificates
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  ls -la /etc/letsencrypt/live/

# Renew certificates (automatic, but manual if needed)
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  certbot renew

# Check certificate expiration
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  certbot certificates
```

### Update Procedure
```bash
# Pull latest image
docker pull jc21/nginx-proxy-manager:latest

# Stop current container
docker stop nginx-proxy-manager-nginx-proxy-manager-1

# Remove old container (data persists in volumes)
docker rm nginx-proxy-manager-nginx-proxy-manager-1

# Start new container with updated image
docker-compose up -d nginx-proxy-manager
```

### Maintenance Tasks

#### Regular Maintenance
- **Weekly**: Review access logs for anomalies
- **Monthly**: Check SSL certificate status and renewal
- **Quarterly**: Update NPM container image
- **Annually**: Review and audit proxy configurations

## Integration with Infrastructure

### DNS Configuration
All proxied domains should resolve to the external IP (77.109.89.47):
```
mail.acmea.tech     → 77.109.89.47
webmail.acmea.tech  → 77.109.89.47
mail.accelior.com   → 77.109.89.47
```

### Firewall Rules (OPNsense)
Required port forwarding from WAN to NPM:
```
TCP 80  (WAN) → 192.168.1.9:80  (NPM HTTP)
TCP 443 (WAN) → 192.168.1.9:443 (NPM HTTPS)
```

### Backend Service Coordination
NPM relies on proper backend service configuration:
- Backend services must be accessible from 192.168.1.9
- SSL backends may use self-signed certificates (disable verification)
- Health checks should be configured for critical services

## Troubleshooting

### Common Issues
1. **Certificate Generation Failures**: Check DNS resolution and firewall
2. **Proxy Connection Errors**: Verify backend service availability
3. **Admin Panel Access**: Check port 81 availability and container status
4. **SSL Certificate Renewal**: Monitor certificate expiration and renewal

### Diagnostic Commands
```bash
# Check NPM container status
docker ps | grep nginx-proxy-manager

# Test admin panel
curl -I http://192.168.1.9:81

# Check certificate status
openssl s_client -connect domain.com:443 -servername domain.com

# Test proxy functionality
curl -I https://domain.com

# Check Nginx configuration
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  nginx -t
```

### Log Analysis
```bash
# Recent application logs
docker logs nginx-proxy-manager-nginx-proxy-manager-1 --tail 100

# Check for certificate errors
docker logs nginx-proxy-manager-nginx-proxy-manager-1 | grep -i cert

# Monitor proxy errors
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  grep -i error /data/logs/*_error.log
```

## Advanced Configuration

### Custom Nginx Configuration
```nginx
# Custom location block example
location /api/ {
    proxy_pass http://backend-api:3000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### Stream Configuration
```yaml
# TCP/UDP stream proxy
Incoming Port: 3306
Forward Host: 192.168.1.9
Forward Port: 3306
TCP Forwarding: Yes
UDP Forwarding: No
```

## Future Enhancements

### Planned Improvements
- Implement comprehensive access lists for security
- Add monitoring integration (Prometheus/Grafana)
- Configure automated backup procedures
- Implement advanced load balancing for high-availability services

### Migration Considerations
- Plan for IPv6 full support
- Consider container orchestration (Docker Swarm/Kubernetes)
- Evaluate NPM alternatives for enterprise requirements
- Implement Infrastructure as Code (Terraform/Ansible)

---

**Last Updated**: September 16, 2025
**Next Review**: October 16, 2025
**Maintainer**: System Administrator