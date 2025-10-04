# Nginx Reverse Proxy Configuration for Agent DVR (cam.home.accelior.com)

## Overview
This document outlines the planned Nginx Proxy Manager configuration for providing secure external access to Agent DVR surveillance platform via the domain `cam.home.accelior.com`. The reverse proxy will be configured on the OMV NAS server (192.168.1.9) using the existing Nginx Proxy Manager container.

## Infrastructure Context

### Current Network Architecture
```
Internet (External Clients)
    ↓
[DNS] cam.home.accelior.com → Public IP (77.109.89.47)
    ↓
[OpenWrt Router] 192.168.1.2
    ↓
[OPNsense Firewall] 192.168.1.3 (Port Forward 443 → 192.168.1.9:443)
    ↓
[OMV Nginx Proxy Manager] 192.168.1.9:443 (SSL Termination)
    ↓
[Docker VM - Agent DVR] 192.168.1.20:8090 (Backend Service)
    ↓
[IP Cameras] 192.168.1.x (Camera Network)
```

### Nginx Proxy Manager Details
- **Host**: OMV NAS (192.168.1.9)
- **Container**: nginx-proxy-manager-nginx-proxy-manager-1
- **Admin Interface**: http://192.168.1.9:81
- **HTTP Port**: 80 (redirects to HTTPS)
- **HTTPS Port**: 443 (SSL termination)
- **Status**: Running, Up 3 weeks

## Configuration Requirements

### Proxy Host Configuration

#### Basic Settings
```yaml
Domain Configuration:
  Domain Names: cam.home.accelior.com
  Scheme: http
  Forward Hostname/IP: 192.168.1.20
  Forward Port: 8090
  Cache Assets: No (for real-time video)
  Block Common Exploits: Yes
  Websockets Support: Yes (Required for WebRTC)
  Access List: Internal Network Only (Optional)
```

#### SSL Configuration
```yaml
SSL Certificate:
  Provider: Let's Encrypt
  Email: admin@accelior.com
  Force SSL: Yes
  HTTP/2 Support: Yes
  HSTS Enabled: Yes
  HSTS Subdomains: No
```

#### Advanced Settings
```yaml
Custom Nginx Configuration:
  - Increase proxy timeouts for video streaming
  - Configure WebSocket upgrade headers
  - Set appropriate buffer sizes for large video frames
  - Enable CORS if needed for external camera access
```

## Detailed Configuration Steps

### Step 1: DNS Configuration

#### External DNS (Domain Registrar)
```
Record Type: A
Hostname: cam.home.accelior.com
IP Address: 77.109.89.47 (Public IP)
TTL: 3600 (1 hour)
```

#### Internal DNS (Pi-hole - 192.168.1.5)
```
# Optional: Local DNS override for internal network
Record Type: A
Hostname: cam.home.accelior.com
IP Address: 192.168.1.9
```
**Purpose**: Direct internal traffic to NPM without leaving the network

### Step 2: OPNsense Firewall Configuration

#### Port Forwarding Rule
```
Rule Name: HTTPS to NPM
Interface: WAN
Protocol: TCP
Source: Any
Source Port: Any
Destination: WAN Address (77.109.89.47)
Destination Port: 443
Redirect Target IP: 192.168.1.9
Redirect Target Port: 443
```

#### Firewall Rule (LAN → Agent DVR)
```
Rule Name: NPM to Agent DVR
Interface: LAN
Protocol: TCP
Source: 192.168.1.9 (NPM)
Destination: 192.168.1.20 (Docker VM)
Destination Port: 8090
Action: Allow
```

### Step 3: Nginx Proxy Manager Configuration

#### Access NPM Admin Interface
```bash
# Open web browser
URL: http://192.168.1.9:81

# Login credentials (if default, change immediately)
Username: admin@example.com
Password: changeme
```

#### Create Proxy Host

##### Navigate to Proxy Hosts
1. Click "Hosts" in top menu
2. Click "Proxy Hosts" tab
3. Click "Add Proxy Host" button

##### Configure Details Tab
```
Domain Names:
  - cam.home.accelior.com

Scheme: http
Forward Hostname/IP: 192.168.1.20
Forward Port: 8090

☑ Cache Assets: Disabled (for real-time streaming)
☑ Block Common Exploits: Enabled
☑ Websockets Support: Enabled (Critical for WebRTC)
```

##### Configure SSL Tab
```
SSL Certificate: Request a new SSL Certificate

☑ Force SSL
☑ HTTP/2 Support
☑ HSTS Enabled
☐ HSTS Subdomains (not needed)

Email Address for Let's Encrypt: admin@accelior.com
☑ I Agree to the Let's Encrypt Terms of Service
```

##### Configure Advanced Tab
```nginx
# Custom Nginx Configuration

# Increase timeouts for video streaming
proxy_connect_timeout 600s;
proxy_send_timeout 600s;
proxy_read_timeout 600s;
send_timeout 600s;

# WebSocket support
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

# Proxy headers
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

# Buffer configuration for large video frames
proxy_buffering off;
proxy_buffer_size 4k;
proxy_buffers 8 4k;

# Client body size for video uploads (snapshots, etc)
client_max_body_size 100M;

# Disable buffering for SSE/WebRTC
proxy_buffering off;

# Additional headers for security
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

#### Save Configuration
1. Click "Save" button
2. NPM will automatically:
   - Generate Nginx configuration files
   - Request Let's Encrypt SSL certificate
   - Reload Nginx service

### Step 4: Access List Configuration (Optional)

#### Create Internal Network Access List
```
Access List Name: Internal Network Only
Satisfy: All
Pass Auth: No

Authorization:
  Allow: 192.168.1.0/24
  Deny: all
```

**Purpose**: Restrict access to internal network only for additional security

#### Apply Access List to Proxy Host
1. Edit cam.home.accelior.com proxy host
2. Navigate to "Access List" tab
3. Select "Internal Network Only" from dropdown
4. Save configuration

### Step 5: WebRTC Port Configuration

#### UDP Port Forwarding (OPNsense)
For WebRTC functionality, additional UDP ports may need forwarding:

```
Rule Name: WebRTC TURN Server
Interface: WAN
Protocol: UDP
Source: Any
Destination: WAN Address
Destination Port: 3478
Redirect Target: 192.168.1.20
Redirect Target Port: 3478

Rule Name: WebRTC Connections
Interface: WAN
Protocol: UDP
Source: Any
Destination: WAN Address
Destination Port: 50000-50100
Redirect Target: 192.168.1.20
Redirect Target Port: 50000-50100
```

**Note**: These may not be required if WebRTC operates through HTTPS tunnel

## Configuration Files

### Expected NPM Configuration File Location
```
File: /data/nginx/proxy_host/XX.conf
Path in Container: /data/nginx/proxy_host/
```

### Expected Configuration Content
```nginx
# ------------------------------------------------------------
# cam.home.accelior.com
# ------------------------------------------------------------

server {
  set $forward_scheme http;
  set $server         "192.168.1.20";
  set $port           8090;

  listen 80;
  listen [::]:80;

  server_name cam.home.accelior.com;

  # Force HTTPS redirect
  return 301 https://$host$request_uri;
}

server {
  set $forward_scheme http;
  set $server         "192.168.1.20";
  set $port           8090;

  listen 443 ssl http2;
  listen [::]:443 ssl http2;

  server_name cam.home.accelior.com;

  # Let's Encrypt SSL
  ssl_certificate /etc/letsencrypt/live/npm-XX/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/npm-XX/privkey.pem;

  # SSL Configuration
  ssl_session_timeout 1d;
  ssl_session_cache shared:MozSSL:10m;
  ssl_session_tickets off;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
  ssl_prefer_server_ciphers off;

  # HSTS
  add_header Strict-Transport-Security "max-age=63072000" always;

  # Proxy settings
  location / {
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # WebSocket support
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    # Timeouts for streaming
    proxy_connect_timeout 600s;
    proxy_send_timeout 600s;
    proxy_read_timeout 600s;

    # Disable buffering for real-time video
    proxy_buffering off;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;

    # Client body size
    client_max_body_size 100M;

    # Block exploits
    include /etc/nginx/snippets/block-exploits.conf;

    # Proxy pass
    proxy_pass $forward_scheme://$server:$port;
  }

  # Security headers
  add_header X-Frame-Options "SAMEORIGIN" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header X-XSS-Protection "1; mode=block" always;
}
```

## Testing and Verification

### Step 1: Internal Testing

#### Test HTTP to HTTPS Redirect
```bash
# From any internal machine
curl -I http://cam.home.accelior.com

# Expected: 301 redirect to https://
```

#### Test HTTPS Access
```bash
# From any internal machine
curl -I https://cam.home.accelior.com

# Expected: 200 OK with SSL certificate
```

#### Test SSL Certificate
```bash
# Check SSL certificate details
openssl s_client -connect cam.home.accelior.com:443 -servername cam.home.accelior.com

# Verify:
# - Certificate issued by Let's Encrypt
# - Valid dates
# - Correct common name (cam.home.accelior.com)
```

#### Test Backend Connectivity
```bash
# From NPM container
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  curl -I http://192.168.1.20:8090

# Expected: 200 OK from Agent DVR
```

### Step 2: External Testing

#### Test DNS Resolution
```bash
# From external network or use online tool
nslookup cam.home.accelior.com

# Expected: Resolves to 77.109.89.47 (public IP)
```

#### Test External HTTPS Access
```bash
# From external network
curl -I https://cam.home.accelior.com

# Expected: 200 OK with SSL certificate
```

#### Test Web Interface
```
# Open web browser
URL: https://cam.home.accelior.com

# Expected: Agent DVR login page loads
# Verify: SSL certificate is valid (green lock icon)
```

### Step 3: WebRTC Testing

#### Test Video Streaming
1. Login to Agent DVR via https://cam.home.accelior.com
2. Navigate to camera live view
3. Verify video stream loads without errors
4. Check browser console for WebSocket/WebRTC errors

#### Test from Mobile Device
1. Connect mobile device to external network (cellular)
2. Access https://cam.home.accelior.com
3. Test video streaming performance
4. Verify low latency with WebRTC

## Monitoring and Maintenance

### NPM Access Logs

#### View Access Logs
```bash
# Real-time access logs
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  tail -f /data/logs/proxy-host-XX_access.log

# Filter for cam.home.accelior.com
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  grep "cam.home.accelior.com" /data/logs/proxy-host-XX_access.log
```

#### Analyze Traffic Patterns
```bash
# Count requests by IP
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  awk '{print $1}' /data/logs/proxy-host-XX_access.log | sort | uniq -c | sort -rn

# Count requests by endpoint
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  awk '{print $7}' /data/logs/proxy-host-XX_access.log | sort | uniq -c | sort -rn
```

### Error Monitoring

#### View Error Logs
```bash
# Real-time error logs
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  tail -f /data/logs/proxy-host-XX_error.log

# Check for common errors
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  grep -E "(502|503|504)" /data/logs/proxy-host-XX_error.log
```

### SSL Certificate Monitoring

#### Check Certificate Status
```bash
# View certificate details
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  certbot certificates | grep -A 10 "cam.home.accelior.com"

# Expected output:
# Certificate Name: npm-XX
# Domains: cam.home.accelior.com
# Expiry Date: [date] (XX days remaining)
```

#### Test Certificate Renewal
```bash
# Dry-run certificate renewal
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  certbot renew --dry-run
```

### Performance Monitoring

#### Monitor Backend Response Times
```bash
# Check backend connectivity
time curl -I http://192.168.1.20:8090

# Expected: <100ms response time
```

#### Monitor Bandwidth Usage
```bash
# Monitor network traffic on OMV
iftop -i eth0 -f "port 443"

# Watch for high bandwidth during video streaming
```

### Uptime Kuma Integration

#### Add HTTP Monitor
```yaml
Monitor Type: HTTP(s)
Friendly Name: Agent DVR (cam.home.accelior.com)
URL: https://cam.home.accelior.com
Heartbeat Interval: 60 seconds
Retries: 3
Timeout: 30 seconds

Accepted Status Codes: 200, 301, 302

Notifications:
  - Email: admin@accelior.com
  - Discord: #alerts channel
```

## Troubleshooting

### Common Issues

#### Issue 1: SSL Certificate Generation Fails
**Symptoms**: Let's Encrypt certificate request fails

**Diagnosis**:
```bash
# Check NPM logs
docker logs nginx-proxy-manager-nginx-proxy-manager-1 | grep -i certbot

# Test DNS resolution
nslookup cam.home.accelior.com

# Test port 80 accessibility (required for HTTP challenge)
curl -I http://cam.home.accelior.com
```

**Solutions**:
- Verify DNS resolves to public IP (77.109.89.47)
- Confirm port 80 forwarding from OPNsense to NPM
- Check Let's Encrypt rate limits (5 certs per domain per week)
- Ensure no firewall blocking outbound connections from NPM

#### Issue 2: 502 Bad Gateway
**Symptoms**: HTTPS works but returns 502 error

**Diagnosis**:
```bash
# Check if Agent DVR is running
ssh root@192.168.1.20 'docker ps | grep agent-dvr'

# Test backend connectivity from NPM
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  curl -I http://192.168.1.20:8090

# Check NPM error logs
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  tail -50 /data/logs/proxy-host-XX_error.log
```

**Solutions**:
- Verify Agent DVR container is running
- Check firewall rules allow 192.168.1.9 → 192.168.1.20:8090
- Confirm port 8090 not blocked by Docker VM firewall
- Restart NPM container if configuration changed

#### Issue 3: Video Streaming Not Working
**Symptoms**: Login works but video streams fail to load

**Diagnosis**:
```bash
# Check browser console for WebSocket errors
# Look for: "WebSocket connection failed" or "WebRTC connection failed"

# Verify WebSocket upgrade headers
curl -i -N -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  https://cam.home.accelior.com

# Check UDP ports for WebRTC
ss -ulnp | grep -E "(3478|5000[0-9])"
```

**Solutions**:
- Verify "Websockets Support" enabled in NPM proxy host
- Confirm WebSocket upgrade headers in custom config
- Check UDP ports 3478, 50000-50100 forwarded correctly
- Disable proxy buffering in NPM advanced settings

#### Issue 4: Slow Performance
**Symptoms**: Video lag, high latency, buffering issues

**Diagnosis**:
```bash
# Check network latency
ping -c 10 192.168.1.20

# Monitor NPM resource usage
docker stats nginx-proxy-manager-nginx-proxy-manager-1

# Check bandwidth
iftop -i eth0 -f "port 443"
```

**Solutions**:
- Verify proxy_buffering is disabled
- Increase proxy timeout values
- Check OMV NAS not under heavy load
- Consider direct port forwarding to Agent DVR (bypass NPM)
- Enable hardware acceleration in Agent DVR

#### Issue 5: External Access Not Working
**Symptoms**: Works internally but fails from external network

**Diagnosis**:
```bash
# Test from external network
curl -I https://cam.home.accelior.com

# Check DNS resolution from external
nslookup cam.home.accelior.com 8.8.8.8

# Verify port forwarding on OPNsense
# Check: Firewall → NAT → Port Forward
```

**Solutions**:
- Verify DNS A record points to correct public IP
- Confirm port 443 forwarding on OPNsense
- Check ISP not blocking port 443
- Verify public IP hasn't changed (dynamic DNS update needed)

## Security Considerations

### Access Control

#### Implement IP Whitelisting
```
# In NPM Access List
Allow: 192.168.1.0/24 (Internal network)
Allow: XX.XX.XX.XX/32 (Specific external IPs)
Deny: all
```

#### Enable HTTP Authentication (Optional)
```
# In NPM proxy host settings
☑ Enable HTTP Basic Authentication
Username: viewer
Password: [strong password]
```

### Rate Limiting

#### Implement Request Rate Limiting
```nginx
# In NPM Advanced configuration
limit_req_zone $binary_remote_addr zone=cam_limit:10m rate=10r/s;
limit_req zone=cam_limit burst=20 nodelay;
```

### SSL Security

#### Enforce Strong SSL Configuration
```nginx
# Already included in NPM default config
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
ssl_prefer_server_ciphers off;
```

#### Enable HSTS
```
# Enabled in NPM SSL tab
☑ HSTS Enabled
```

### Firewall Rules

#### Restrict Source IPs (OPNsense)
```
# Modify port forwarding rule
Source: Specific IP/Network (not "Any")
```

#### Log and Monitor Access
```
# Enable logging on OPNsense firewall rule
☑ Log packets that are handled by this rule
```

## Backup and Recovery

### Configuration Backup

#### Backup NPM Configuration
```bash
# Backup NPM data directory
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  tar -czf /tmp/npm-backup.tar.gz /data

# Copy backup to local storage
docker cp nginx-proxy-manager-nginx-proxy-manager-1:/tmp/npm-backup.tar.gz \
  ./npm-backup-$(date +%Y%m%d).tar.gz

# Copy to OMV for safekeeping
scp npm-backup-*.tar.gz root@192.168.1.9:/srv/raid/docker-backups/
```

#### Backup Specific Proxy Host Configuration
```bash
# Backup single proxy host config
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  cat /data/nginx/proxy_host/XX.conf > cam-proxy-host.conf
```

### Disaster Recovery

#### Restore NPM Configuration
```bash
# Stop NPM container
docker stop nginx-proxy-manager-nginx-proxy-manager-1

# Restore configuration
docker cp npm-backup-YYYYMMDD.tar.gz \
  nginx-proxy-manager-nginx-proxy-manager-1:/tmp/

docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  tar -xzf /tmp/npm-backup-YYYYMMDD.tar.gz -C /

# Restart NPM
docker restart nginx-proxy-manager-nginx-proxy-manager-1
```

#### Recreate Proxy Host Manually
1. Access NPM admin at http://192.168.1.9:81
2. Navigate to Hosts → Proxy Hosts
3. Click "Add Proxy Host"
4. Follow configuration steps from this document

## Maintenance Schedule

### Daily Tasks
- Monitor access logs for unusual activity
- Check SSL certificate validity
- Verify Agent DVR backend accessibility

### Weekly Tasks
- Review error logs for issues
- Check bandwidth usage patterns
- Test external access functionality

### Monthly Tasks
- Update NPM container image if available
- Review and optimize configuration
- Test disaster recovery procedures
- Backup NPM configuration

### Quarterly Tasks
- Review and update access control lists
- Audit SSL certificate configuration
- Review firewall rules and port forwarding
- Performance optimization review

## Related Documentation

### Infrastructure Documentation
- [Agent DVR Installation](/docs/agent-dvr/agent-dvr-installation.md) - Backend service setup
- [Nginx Proxy Manager](/docs/npm/npm.md) - NPM general configuration
- [Infrastructure Overview](/docs/infrastructure.md) - Network architecture
- [OPNsense Setup](/docs/OPNsense/OPNsense_setup.md) - Firewall configuration

### Operational Documentation
- [Docker Containers Overview](/docs/docker-containers-overview.md) - Container ecosystem
- [Uptime Kuma](/docs/uptime-kuma/uptime-kuma-installation.md) - Monitoring setup
- [OMV Storage](/docs/infrastructure.md#openmediavault-storage-server-19216819) - Storage configuration

## Support Resources

### Nginx Proxy Manager
- **Documentation**: https://nginxproxymanager.com/guide/
- **GitHub**: https://github.com/NginxProxyManager/nginx-proxy-manager
- **Docker Hub**: https://hub.docker.com/r/jc21/nginx-proxy-manager

### Let's Encrypt
- **Documentation**: https://letsencrypt.org/docs/
- **Rate Limits**: https://letsencrypt.org/docs/rate-limits/
- **Community Forum**: https://community.letsencrypt.org/

---

**Document Status**: Planning/Pre-Implementation
**Created**: 2025-10-01
**Last Updated**: 2025-10-01
**Next Review**: Post-Implementation
**Maintainer**: Infrastructure Team
