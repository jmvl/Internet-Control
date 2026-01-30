# Perplexica External Access Configuration

## Overview
This document details the complete configuration for external access to Perplexica via the domain `perplexica.acmea.tech`. The setup enables secure HTTPS access from anywhere on the internet using Cloudflare proxy and Nginx Proxy Manager.

**Configuration Date**: 2025-10-09
**External URL**: https://perplexica.acmea.tech
**Internal URL**: http://192.168.1.20:3000

## Architecture Overview

```
Internet Users
    ↓
Cloudflare Proxy (SSL Termination)
    ↓ (HTTPS - Cloudflare Universal SSL)
Public IP: 135.181.154.169
    ↓
OPNsense Firewall (192.168.1.3)
    ↓ (Port 80/443 forwarded)
Nginx Proxy Manager (192.168.1.9)
    ↓ (HTTP proxy to backend)
Perplexica Container (192.168.1.20:3000)
```

## Configuration Components

### 1. Cloudflare DNS Configuration

**DNS Record Details**:
- **Type**: A Record
- **Name**: perplexica
- **Domain**: acmea.tech
- **Full FQDN**: perplexica.acmea.tech
- **Content (IP)**: 135.181.154.169
- **Proxy Status**: Proxied (Orange Cloud ☁️)
- **TTL**: Auto
- **Zone ID**: 0eca1e8adfd8b1109320d67050d633ab

**Features Enabled**:
- ✅ Cloudflare Proxy (DDoS protection, CDN)
- ✅ Universal SSL (Automatic HTTPS)
- ✅ HTTP to HTTPS redirect (automatic)
- ✅ Automatic SSL certificate management

**DNS Propagation**:
```bash
# Verify DNS resolution
dig +short perplexica.acmea.tech

# Expected output (Cloudflare IPs):
# 172.67.159.242
# 104.21.49.69
```

**Cloudflare API Token Used**: `RZ5klBDFKSUqBSnb8lJgzuUzwbh4v5Yd8UwgpNzA`

### 2. Nginx Proxy Manager Configuration

**Proxy Host Entry**:
- **Domain Names**: perplexica.acmea.tech
- **Scheme**: http
- **Forward Hostname/IP**: 192.168.1.20
- **Forward Port**: 3000
- **Access List**: None (publicly accessible)
- **Block Common Exploits**: ✅ Enabled
- **Websockets Support**: ✅ Enabled
- **HTTP/2 Support**: ✅ Enabled
- **HSTS**: Disabled (handled by Cloudflare)
- **Database Record ID**: 34

**NPM Database Configuration**:
```sql
-- Proxy host entry in /data/database.sqlite
INSERT INTO proxy_host (
  created_on, modified_on, owner_user_id, is_deleted,
  domain_names, forward_host, forward_port, access_list_id,
  certificate_id, ssl_forced, caching_enabled, block_exploits,
  advanced_config, meta, allow_websocket_upgrade, http2_support,
  forward_scheme, enabled, hsts_enabled, hsts_subdomains
) VALUES (
  datetime('now'), datetime('now'), 1, 0,
  '["perplexica.acmea.tech"]', '192.168.1.20', 3000, 0,
  0, 0, 0, 1,
  '', '{"letsencrypt_agree":false,"dns_challenge":false}', 1, 1,
  'http', 1, 0, 0
);
```

**NPM Container Details**:
- **Container Name**: nginx-proxy-manager-nginx-proxy-manager-1
- **Host**: 192.168.1.9 (OMV Server)
- **Web UI**: http://192.168.1.121:81
- **Ports Exposed**: 80, 81, 443

### 3. Perplexica Backend Configuration

**Service Details**:
- **Container**: perplexica-app-1
- **Host IP**: 192.168.1.20
- **Port**: 3000
- **Protocol**: HTTP (internal)
- **Installation Path**: /opt/perplexica

**Container Configuration**:
```yaml
# From /opt/perplexica/docker-compose.yaml
app:
  image: itzcrazykns1337/perplexica:main
  environment:
    - SEARXNG_API_URL=http://searxng:8080
    - DATA_DIR=/home/perplexica
  ports:
    - 3000:3000
  networks:
    - perplexica-network
  volumes:
    - backend-dbstore:/home/perplexica/data
    - uploads:/home/perplexica/uploads
    - ./config.toml:/home/perplexica/config.toml
  restart: unless-stopped
```

## SSL/TLS Configuration

### Cloudflare SSL Mode

**Current SSL Mode**: Full (recommended) or Flexible

**SSL Chain**:
1. **Client → Cloudflare**: HTTPS with Cloudflare Universal SSL
2. **Cloudflare → Origin (Your Server)**: HTTP or HTTPS
3. **NPM → Perplexica**: HTTP (internal network, secure)

**Recommended Cloudflare SSL Settings**:
- **SSL/TLS encryption mode**: Full (or Full Strict with origin certificate)
- **Always Use HTTPS**: ✅ On
- **Automatic HTTPS Rewrites**: ✅ On
- **Minimum TLS Version**: 1.2
- **Opportunistic Encryption**: ✅ On
- **TLS 1.3**: ✅ On

### Optional: NPM Let's Encrypt Certificate

To add an origin certificate for Full (Strict) SSL mode:

1. **Access NPM Web UI**: http://192.168.1.121:81
2. **Navigate to**: SSL Certificates → Add SSL Certificate
3. **Configure**:
   - **Domain Names**: perplexica.acmea.tech
   - **Email**: admin@acmea.tech
   - **Use a DNS Challenge**: No (use HTTP-01)
   - **Agree to Terms**: ✅
4. **Click**: Save
5. **Edit Proxy Host**: Link the new certificate
6. **Enable**:
   - ✅ Force SSL
   - ✅ HTTP/2 Support
   - ✅ HSTS Enabled

## Firewall Configuration

### Required Port Forwarding (OPNsense)

**Port Forwarding Rules** (192.168.1.3):
```
Interface: WAN
Protocol: TCP
Destination: WAN Address
Destination Port: 80 (HTTP)
Redirect Target IP: 192.168.1.9 (NPM)
Redirect Target Port: 80
Description: HTTP to Nginx Proxy Manager

Interface: WAN
Protocol: TCP
Destination: WAN Address
Destination Port: 443 (HTTPS)
Redirect Target IP: 192.168.1.9 (NPM)
Redirect Target Port: 443
Description: HTTPS to Nginx Proxy Manager
```

**Firewall Rules** (if not already configured):
```
Action: Pass
Interface: WAN
Protocol: TCP
Source: Any
Destination: WAN Address
Destination Port: 80, 443
Description: Allow HTTP/HTTPS traffic
```

## Automated Setup Scripts

### Cloudflare DNS Setup Script

**Location**: `/tmp/cloudflare-dns-setup.sh`

**Usage**:
```bash
export CF_API_TOKEN="RZ5klBDFKSUqBSnb8lJgzuUzwbh4v5Yd8UwgpNzA"
bash /tmp/cloudflare-dns-setup.sh
```

**Script Features**:
- Automatically retrieves Zone ID for acmea.tech
- Creates or updates DNS A record
- Enables Cloudflare proxy
- Validates configuration

### NPM Database Update

**Direct Database Modification**:
```bash
# On OMV server (192.168.1.9)
docker cp nginx-proxy-manager-nginx-proxy-manager-1:/data/database.sqlite /tmp/npm.db

# Add proxy host via SQL
sqlite3 /tmp/npm.db < /tmp/add_perplexica.sql

# Copy back and restart
docker cp /tmp/npm.db nginx-proxy-manager-nginx-proxy-manager-1:/data/database.sqlite
docker restart nginx-proxy-manager-nginx-proxy-manager-1
```

## Testing and Verification

### DNS Resolution Check

```bash
# Test DNS resolution
dig perplexica.acmea.tech

# Should return Cloudflare proxy IPs:
# perplexica.acmea.tech. 300 IN A 172.67.159.242
# perplexica.acmea.tech. 300 IN A 104.21.49.69
```

### HTTP/HTTPS Access Check

```bash
# Test HTTP access (should redirect to HTTPS)
curl -I http://perplexica.acmea.tech

# Test HTTPS access
curl -I https://perplexica.acmea.tech

# Test full page load
curl https://perplexica.acmea.tech
```

### Browser Testing

1. **Open Browser**: Navigate to https://perplexica.acmea.tech
2. **Verify SSL**: Check for green padlock icon
3. **Test Functionality**:
   - Search feature working
   - AI responses loading
   - No console errors
4. **Check Certificate**: Click padlock → Valid Cloudflare certificate

### Internal Network Testing

```bash
# Test from internal network
curl -I http://192.168.1.20:3000

# Test NPM proxy
curl -I http://192.168.1.9/

# Check container status
ssh root@192.168.1.20 "cd /opt/perplexica && docker compose ps"
```

## Troubleshooting

### Issue: Site Not Accessible

**Symptoms**: "This site can't be reached" or timeout errors

**Resolution Steps**:
1. **Check DNS propagation**:
   ```bash
   dig perplexica.acmea.tech @1.1.1.1
   ```

2. **Verify Cloudflare proxy status**:
   - Login to Cloudflare dashboard
   - Check DNS record shows orange cloud

3. **Check NPM container**:
   ```bash
   ssh root@192.168.1.9 "docker ps | grep nginx"
   ```

4. **Verify port forwarding on OPNsense**:
   - Firewall → NAT → Port Forward
   - Ensure ports 80/443 forwarded to 192.168.1.9

5. **Check Perplexica container**:
   ```bash
   ssh root@192.168.1.20 "docker compose -f /opt/perplexica/docker-compose.yaml ps"
   ```

### Issue: SSL Certificate Errors

**Symptoms**: "Your connection is not private" warnings

**Resolution**:
1. **Check Cloudflare SSL mode**: Should be "Full" or "Flexible"
2. **Verify Universal SSL is active**: SSL/TLS → Overview → Universal SSL
3. **Clear browser cache**: Hard refresh (Cmd+Shift+R / Ctrl+Shift+R)
4. **Wait for SSL provisioning**: Can take up to 24 hours for new domains

### Issue: 502 Bad Gateway

**Symptoms**: Nginx returns 502 error

**Resolution**:
1. **Check Perplexica is running**:
   ```bash
   curl http://192.168.1.20:3000
   ```

2. **Restart Perplexica**:
   ```bash
   ssh root@192.168.1.20 "cd /opt/perplexica && docker compose restart"
   ```

3. **Check NPM logs**:
   ```bash
   ssh root@192.168.1.9 "docker logs nginx-proxy-manager-nginx-proxy-manager-1 --tail 100"
   ```

4. **Verify NPM proxy host configuration**:
   - Web UI → Proxy Hosts → Edit perplexica.acmea.tech
   - Confirm Forward Hostname: 192.168.1.20
   - Confirm Forward Port: 3000

### Issue: WebSocket Connection Failures

**Symptoms**: Real-time features not working, "WebSocket connection failed"

**Resolution**:
1. **Enable WebSocket in NPM**:
   - Edit Proxy Host
   - Custom Locations → / → Websockets Support: ✅

2. **Check Cloudflare settings**:
   - Network → WebSockets: ✅ On

3. **Verify proxy configuration**:
   ```sql
   SELECT allow_websocket_upgrade FROM proxy_host
   WHERE domain_names LIKE '%perplexica.acmea.tech%';
   -- Should return: 1
   ```

### Issue: Slow Performance

**Symptoms**: Site loads slowly, timeouts

**Resolution**:
1. **Enable Cloudflare caching**:
   - Caching → Configuration → Caching Level: Standard

2. **Enable HTTP/2** in NPM:
   - Edit Proxy Host → SSL → HTTP/2 Support: ✅

3. **Check Perplexica resource usage**:
   ```bash
   ssh root@192.168.1.20 "docker stats --no-stream"
   ```

4. **Review Cloudflare analytics**:
   - Analytics & Logs → Traffic insights

## Security Considerations

### Cloudflare Protection Features

**Enabled by Default**:
- ✅ DDoS protection (automatic)
- ✅ Rate limiting (via Cloudflare)
- ✅ SSL/TLS encryption
- ✅ IP obfuscation (origin IP hidden)

**Recommended Security Settings**:
1. **Enable Security Level**: Medium or High
   - Security → Settings → Security Level

2. **Enable Bot Fight Mode**:
   - Security → Bots → Bot Fight Mode

3. **Configure WAF Rules**:
   - Security → WAF → Create custom rules

4. **Enable Always Use HTTPS**:
   - SSL/TLS → Edge Certificates → Always Use HTTPS

### Access Control (Optional)

**Option 1: Cloudflare Access** (Zero Trust):
```
1. Navigate to Zero Trust dashboard
2. Create Access Application
3. Configure authentication method
4. Add application domain: perplexica.acmea.tech
5. Set access policies (email, IP, country)
```

**Option 2: NPM Access List**:
```
1. NPM Web UI → Access Lists → Add Access List
2. Configure username/password or IP whitelist
3. Edit Proxy Host → Access List → Select created list
```

**Option 3: IP Whitelisting**:
```bash
# Add to NPM proxy host custom configuration
allow YOUR_IP_ADDRESS;
deny all;
```

### Network Security

**Internal Network Isolation**:
- Perplexica container: Isolated Docker network
- NPM: Separate host from application containers
- No direct internet access to Perplexica port 3000

**Firewall Best Practices**:
- Only expose ports 80/443 on WAN interface
- Block direct access to 192.168.1.20:3000 from WAN
- Enable intrusion detection on OPNsense
- Regular firewall rule audits

## Maintenance

### Regular Maintenance Tasks

**Weekly**:
- Monitor access logs in Cloudflare analytics
- Check NPM and Perplexica container health
- Review SSL certificate status

**Monthly**:
- Update Docker images:
  ```bash
  cd /opt/perplexica
  docker compose pull
  docker compose up -d
  ```
- Review and rotate Cloudflare API tokens
- Check for security updates on NPM
- Audit firewall rules and access patterns

**Quarterly**:
- Backup NPM configuration:
  ```bash
  docker cp nginx-proxy-manager-nginx-proxy-manager-1:/data /backup/npm-$(date +%Y%m%d)
  ```
- Review Cloudflare security settings
- Test disaster recovery procedures
- Update documentation

### Monitoring

**Recommended Monitoring Tools**:
1. **Uptime Kuma** (on 192.168.1.9):
   - Add HTTPS monitor for https://perplexica.acmea.tech
   - Alert on downtime via email/Slack

2. **Cloudflare Analytics**:
   - Monitor request counts
   - Track error rates
   - Review security threats blocked

3. **NPM Logs**:
   ```bash
   docker logs -f nginx-proxy-manager-nginx-proxy-manager-1
   ```

### Backup Procedures

**NPM Configuration Backup**:
```bash
#!/bin/bash
# Backup NPM database and certificates
DATE=$(date +%Y%m%d-%H%M%S)
ssh root@192.168.1.9 "docker exec nginx-proxy-manager-nginx-proxy-manager-1 tar czf /tmp/npm-backup-$DATE.tar.gz /data"
scp root@192.168.1.9:/tmp/npm-backup-$DATE.tar.gz /backup/npm/
```

**Perplexica Backup**:
```bash
# Already covered in perplexica-installation.md
cd /opt/perplexica
docker compose down
tar czf /backup/perplexica-$(date +%Y%m%d).tar.gz .
docker compose up -d
```

## Configuration Files Reference

### Cloudflare Zone Settings
- **Zone ID**: 0eca1e8adfd8b1109320d67050d633ab
- **Zone Name**: acmea.tech
- **DNS Record Type**: A
- **API Token**: RZ5klBDFKSUqBSnb8lJgzuUzwbh4v5Yd8UwgpNzA

### NPM Database Schema
```sql
-- Proxy Host Table Structure
CREATE TABLE `proxy_host` (
  `id` integer not null primary key autoincrement,
  `created_on` datetime not null,
  `modified_on` datetime not null,
  `owner_user_id` integer not null,
  `is_deleted` integer not null default '0',
  `domain_names` json not null,
  `forward_host` varchar(255) not null,
  `forward_port` integer not null,
  `access_list_id` integer not null default '0',
  `certificate_id` integer not null default '0',
  `ssl_forced` integer not null default '0',
  `caching_enabled` integer not null default '0',
  `block_exploits` integer not null default '0',
  `advanced_config` text not null default '',
  `meta` json not null,
  `allow_websocket_upgrade` integer not null default '0',
  `http2_support` integer not null default '0',
  `forward_scheme` varchar(255) not null default 'http',
  `enabled` integer not null default '1',
  `locations` json,
  `hsts_enabled` integer not null default '0',
  `hsts_subdomains` integer not null default '0'
);
```

## Related Documentation

### Infrastructure Documentation
- **Main Infrastructure**: `/docs/infrastructure.md`
- **Perplexica Installation**: `/docs/perplexica/perplexica-installation.md`
- **OMV Server Setup**: `/docs/omv/omv-overview.md`
- **OPNsense Firewall**: `/docs/OPNsense/opnsense-overview.md`
- **Docker Management**: `/docs/docker/docker-maintenance.md`

### External Resources
- **Cloudflare Docs**: https://developers.cloudflare.com/
- **Nginx Proxy Manager**: https://nginxproxymanager.com/
- **Perplexica GitHub**: https://github.com/ItzCrazyKns/Perplexica
- **Let's Encrypt**: https://letsencrypt.org/docs/

## Status

**Current Status**: ✅ **Configured**

**Configuration Summary**:
- ✅ Cloudflare DNS record created and proxied
- ✅ NPM proxy host configured
- ✅ Websocket and HTTP/2 support enabled
- ✅ Block exploits protection enabled
- ⏳ SSL certificate (Cloudflare Universal SSL active, optional: NPM Let's Encrypt)
- ⏳ External access testing (requires verification from internet-connected device)

**Next Steps**:
1. ✅ **DNS Configuration**: Complete
2. ✅ **NPM Proxy Host**: Complete
3. ⚠️ **OPNsense Port Forwarding**: Verify ports 80/443 forwarded to 192.168.1.9
4. ⏳ **SSL Certificate**: Configure Cloudflare SSL mode to "Full" or add NPM certificate
5. ⏳ **External Testing**: Test access from external network
6. 📋 **Monitoring**: Add to Uptime Kuma for health monitoring

**Deployment Date**: 2025-10-09
**Last Updated**: 2025-10-09
**Maintained By**: Infrastructure Team
