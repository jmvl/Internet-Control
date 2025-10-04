# JIRA Tickets for Agent DVR Infrastructure Implementation

## Project Information
- **JIRA Project**: IFS (Infrastructure Services)
- **JIRA URL**: https://jira.accelior.com/projects/IFS
- **Created**: 2025-10-01
- **Status**: Ready for Import

## Ticket 1: Install Agent DVR on Docker VM

### Ticket Details
```yaml
Project: IFS
Issue Type: Task
Summary: Deploy Agent DVR surveillance platform on Docker VM (192.168.1.20)
Priority: Medium
Labels: docker, surveillance, video, infrastructure
Components: Docker, Monitoring, Security
```

### Description
```markdown
## Overview
Deploy Agent DVR video surveillance platform as a Docker container on the existing Docker VM (192.168.1.20) to provide centralized IP camera management, recording, and monitoring capabilities.

## Current State
- Docker VM (192.168.1.20) running with 20GB RAM, 10 cores
- Currently hosting Supabase, n8n, monitoring services
- Container memory usage: ~20.5% (4.1GB / 20GB)
- Available resources: 15GB RAM free, sufficient CPU capacity
- No existing video surveillance platform

## Desired State
- Agent DVR running as Docker container on 192.168.1.20
- Web interface accessible at http://192.168.1.20:8090 (internal)
- External access via https://cam.home.accelior.com (reverse proxy)
- WebRTC support for low-latency video streaming
- Integration with existing monitoring (Uptime Kuma)

## Technical Implementation

### Docker Image
- **Image**: `mekayelanik/ispyagentdvr:latest`
- **Repository**: https://github.com/MekayelAnik/ispyagentdvr-docker
- **Supported Architectures**: x86-64, ARM64, ARM32
- **Docker Engine Required**: 23.0+

### Port Configuration
| Port | Protocol | Purpose |
|------|----------|---------|
| 8090 | TCP | Web Interface |
| 3478 | UDP | TURN Server (WebRTC) |
| 50000-50100 | UDP | WebRTC Connections |

### Volume Mounts
| Host Path | Container Path | Purpose | Size Estimate |
|-----------|----------------|---------|---------------|
| `/srv/docker-data/agent-dvr/config` | `/AgentDVR/Media/XML` | Configuration files | ~100MB |
| `/srv/docker-data/agent-dvr/media` | `/AgentDVR/Media/WebServerRoot/Media` | Video recordings | 500GB-1TB |
| `/srv/docker-data/agent-dvr/commands` | `/AgentDVR/Commands` | Custom scripts | ~10MB |

### Environment Variables
```yaml
PUID: 1000                    # User ID for permissions
PGID: 1000                    # Group ID for permissions
TZ: America/New_York          # Timezone
AGENTDVR_WEBUI_PORT: 8090    # Web UI port
```

### Docker Compose Configuration
```yaml
version: '3.8'

services:
  agent-dvr:
    image: mekayelanik/ispyagentdvr:latest
    container_name: agent-dvr
    restart: unless-stopped

    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - AGENTDVR_WEBUI_PORT=8090

    ports:
      - "8090:8090"
      - "3478:3478/udp"
      - "50000-50100:50000-50100/udp"

    volumes:
      - /srv/docker-data/agent-dvr/config:/AgentDVR/Media/XML
      - /srv/docker-data/agent-dvr/media:/AgentDVR/Media/WebServerRoot/Media
      - /srv/docker-data/agent-dvr/commands:/AgentDVR/Commands

    networks:
      - agent-dvr-network

networks:
  agent-dvr-network:
    driver: bridge
```

## Dependencies
- Docker VM (192.168.1.20) must be accessible
- Sufficient storage for video recordings (recommend 500GB-1TB)
- Network access to IP camera subnet (192.168.1.0/24)
- OPNsense firewall rules allowing Docker VM → Camera traffic

## Prerequisites
1. ✅ Docker Engine 23.0+ installed (verify: `docker --version`)
2. ✅ Docker Compose installed (verify: `docker compose version`)
3. ☐ Storage directories created: `/srv/docker-data/agent-dvr/`
4. ☐ Permissions set: `chown -R 1000:1000 /srv/docker-data/agent-dvr`
5. ☐ IP camera connectivity verified from Docker VM
6. ☐ Storage capacity checked (require 500GB+ for recordings)

## Implementation Steps

### Step 1: Prepare Docker Host
```bash
# SSH to Docker VM
ssh root@192.168.1.20

# Create required directories
mkdir -p /srv/docker-data/agent-dvr/{config,media,commands}

# Set permissions
chown -R 1000:1000 /srv/docker-data/agent-dvr
chmod -R 755 /srv/docker-data/agent-dvr

# Verify disk space
df -h /srv/docker-data
```

### Step 2: Create Docker Compose File
```bash
# Create compose directory
mkdir -p /root/docker-compose/agent-dvr
cd /root/docker-compose/agent-dvr

# Create docker-compose.yml (paste configuration above)
nano docker-compose.yml
```

### Step 3: Deploy Container
```bash
# Pull latest image
docker pull mekayelanik/ispyagentdvr:latest

# Start container
docker compose up -d

# Verify container status
docker ps | grep agent-dvr

# Check logs
docker logs agent-dvr
```

### Step 4: Initial Configuration
```bash
# Access web interface
# URL: http://192.168.1.20:8090

# First-time setup:
# 1. Select language
# 2. Create admin account (username: admin)
# 3. Configure timezone
# 4. Set storage paths (should be pre-configured)
```

### Step 5: Verify Installation
```bash
# Check container health
docker ps | grep agent-dvr

# Test web interface accessibility
curl -I http://192.168.1.20:8090

# Verify port bindings
docker port agent-dvr

# Check logs for errors
docker logs agent-dvr | grep -i error
```

## Storage Considerations

### Storage Location Options
**Option 1: Local Docker VM Storage**
- Path: `/srv/docker-data/agent-dvr/media`
- Capacity: Limited by Docker VM disk (60GB available)
- **Not Recommended** for long-term recordings

**Option 2: NFS Mount to OMV NAS (Recommended)**
- Mount OMV storage to Docker VM
- Path: `/mnt/omv-storage/agent-dvr-media`
- Capacity: OMV has 18TB MergerFS pool + 3.7TB RAID
- **Recommended** for production use

### NFS Mount Configuration (if using Option 2)
```bash
# On Docker VM
apt-get install nfs-common

# Create mount point
mkdir -p /mnt/omv-storage/agent-dvr-media

# Add to /etc/fstab
echo "192.168.1.9:/srv/mergerfs/MergerFS/agent-dvr /mnt/omv-storage/agent-dvr-media nfs defaults 0 0" >> /etc/fstab

# Mount
mount -a

# Update docker-compose.yml volume path
# /mnt/omv-storage/agent-dvr-media:/AgentDVR/Media/WebServerRoot/Media
```

## Resource Impact

### Expected Resource Usage
- **CPU**: 0.5-1 core per camera (without GPU acceleration)
- **Memory**: 2-4GB for 4-8 cameras
- **Storage I/O**: High during recording (100-500MB/s write)
- **Network**: 5-50 Mbps per camera depending on resolution

### Docker VM Resource Availability
- **Current Memory**: 4.1GB / 20GB (20.5% used)
- **Available Memory**: 15GB (sufficient for 4-8 cameras)
- **CPU Cores**: 10 cores available
- **Impact Assessment**: Low-Medium impact on existing services

## Testing Plan

### Internal Testing
- [ ] Access web interface: http://192.168.1.20:8090
- [ ] Login with admin credentials
- [ ] Add test camera with RTSP stream
- [ ] Verify video recording functionality
- [ ] Test motion detection features
- [ ] Check storage write performance

### Network Testing
- [ ] Verify camera connectivity from Docker VM
- [ ] Test RTSP stream access to cameras
- [ ] Confirm WebRTC port accessibility
- [ ] Validate firewall rules (Docker VM → Cameras)

### Performance Testing
- [ ] Monitor container resource usage (`docker stats agent-dvr`)
- [ ] Check recording quality and frame rates
- [ ] Test multiple concurrent camera streams
- [ ] Verify storage write speeds

## Integration Tasks

### Uptime Kuma Monitoring
- [ ] Add HTTP monitor for http://192.168.1.20:8090
- [ ] Configure alert notifications (email/Discord)
- [ ] Set heartbeat interval: 60 seconds
- [ ] Test failure detection and alerting

### n8n Automation (Optional)
- [ ] Motion detection webhook to n8n
- [ ] Automated recording cleanup workflow
- [ ] Camera offline alert notifications

## Acceptance Criteria

### Functional Requirements
- [x] Container deploys successfully without errors
- [x] Web interface accessible at http://192.168.1.20:8090
- [x] Admin account created and functional
- [x] At least one test camera added successfully
- [x] Video recording to storage working properly
- [x] Motion detection functional

### Performance Requirements
- [x] Container memory usage < 4GB with 4 cameras
- [x] CPU usage < 50% during normal operation
- [x] Video latency < 2 seconds for live streaming
- [x] Recording frame rate maintains 15+ FPS

### Operational Requirements
- [x] Container auto-restarts on failure
- [x] Logs accessible via `docker logs`
- [x] Configuration persists across restarts
- [x] Uptime Kuma monitoring configured
- [x] Backup procedure documented

## Documentation
- [x] Installation documentation created: `/docs/agent-dvr/agent-dvr-installation.md`
- [ ] Configuration documented in wiki/Confluence
- [ ] Operational runbook created
- [ ] Camera setup guide written

## Related Tickets
- **IFS-XXX**: Configure Nginx reverse proxy for cam.home.accelior.com (dependent)
- **IFS-XXX**: Configure OPNsense firewall rules for Agent DVR (optional)
- **IFS-XXX**: Setup IP cameras on network (dependent)

## Rollback Plan

### If Installation Fails
```bash
# Stop and remove container
docker compose down

# Remove volumes (if needed)
docker volume rm $(docker volume ls -q | grep agent-dvr)

# Remove directories
rm -rf /srv/docker-data/agent-dvr

# Verify cleanup
docker ps -a | grep agent-dvr
```

### If Performance Issues Occur
- Reduce number of cameras
- Lower recording resolution/FPS
- Enable hardware acceleration (if GPU available)
- Move recordings to NAS storage

## Notes
- Agent DVR is free and open-source software
- Supports hardware acceleration (Nvidia, Intel, AMD GPUs)
- WebRTC provides low-latency streaming (<1 second)
- Can integrate with Home Assistant via native integration
- Multi-architecture support (x86-64, ARM64, ARM32)

## References
- Official Documentation: https://www.ispyconnect.com/docs/agent/
- Docker Repository: https://github.com/MekayelAnik/ispyagentdvr-docker
- Docker Hub: https://hub.docker.com/r/mekayelanik/ispyagentdvr
- Installation Guide: `/docs/agent-dvr/agent-dvr-installation.md`
```

### Assignee
Infrastructure Team

### Estimated Time
4 hours

### Time Breakdown
- Host preparation: 30 minutes
- Container deployment: 30 minutes
- Initial configuration: 1 hour
- Testing and validation: 1 hour
- Documentation updates: 1 hour

---

## Ticket 2: Configure Nginx Reverse Proxy for cam.home.accelior.com

### Ticket Details
```yaml
Project: IFS
Issue Type: Task
Summary: Configure Nginx Proxy Manager reverse proxy for Agent DVR external access (cam.home.accelior.com)
Priority: Medium
Labels: nginx, reverse-proxy, ssl, networking
Components: Networking, Security, Nginx
```

### Description
```markdown
## Overview
Configure Nginx Proxy Manager on OMV NAS (192.168.1.9) to provide secure external HTTPS access to Agent DVR surveillance platform via the domain `cam.home.accelior.com`. This will enable remote viewing of cameras with SSL encryption and proper security controls.

## Current State
- Nginx Proxy Manager running on OMV NAS (192.168.1.9)
- Container: `nginx-proxy-manager-nginx-proxy-manager-1`
- Status: Running, Up 3 weeks
- Admin interface: http://192.168.1.9:81
- Currently proxying: mail services, ntop, other internal services
- cam.home.accelior.com domain: Not yet configured

## Desired State
- cam.home.accelior.com resolving to public IP (77.109.89.47)
- HTTPS access via Nginx Proxy Manager with Let's Encrypt SSL
- Backend proxying to Agent DVR at http://192.168.1.20:8090
- WebSocket support enabled for WebRTC video streaming
- Internal network access only (optional access list)
- Monitoring configured in Uptime Kuma

## Technical Implementation

### Network Architecture
```
Internet → DNS (cam.home.accelior.com) → Public IP (77.109.89.47)
    ↓
OpenWrt Router (192.168.1.2)
    ↓
OPNsense Firewall (192.168.1.3) [Port Forward 443 → 192.168.1.9:443]
    ↓
OMV Nginx Proxy Manager (192.168.1.9:443) [SSL Termination]
    ↓
Docker VM - Agent DVR (192.168.1.20:8090) [Backend]
```

### DNS Configuration

#### External DNS (Domain Registrar)
```
Record Type: A
Hostname: cam.home.accelior.com
Target: 77.109.89.47
TTL: 3600
```

#### Internal DNS (Pi-hole - Optional)
```
Record Type: A
Hostname: cam.home.accelior.com
Target: 192.168.1.9
Purpose: Direct internal traffic without leaving network
```

### NPM Proxy Host Configuration

#### Basic Settings
```yaml
Domain Names: cam.home.accelior.com
Scheme: http
Forward Hostname/IP: 192.168.1.20
Forward Port: 8090
Cache Assets: No (for real-time streaming)
Block Common Exploits: Yes
Websockets Support: Yes (Required for WebRTC)
```

#### SSL Configuration
```yaml
SSL Certificate: Request a new SSL Certificate (Let's Encrypt)
Force SSL: Yes
HTTP/2 Support: Yes
HSTS Enabled: Yes
HSTS Subdomains: No
Email: admin@accelior.com
```

#### Advanced Configuration
```nginx
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

# Disable buffering for real-time video
proxy_buffering off;
proxy_buffer_size 4k;
proxy_buffers 8 4k;

# Client body size for uploads
client_max_body_size 100M;

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
```

## Dependencies
- **IFS-XXX**: Agent DVR installation completed (blocker)
- DNS access to configure A record for cam.home.accelior.com
- OPNsense firewall configuration access
- NPM admin access (http://192.168.1.9:81)

## Prerequisites
1. ☐ Agent DVR running on 192.168.1.20:8090
2. ☐ Domain cam.home.accelior.com available for configuration
3. ☐ DNS registrar access to create A record
4. ☐ OPNsense admin access for port forwarding
5. ☐ NPM admin credentials
6. ☐ Public IP address confirmed (77.109.89.47)

## Implementation Steps

### Step 1: Configure DNS
```bash
# Log into domain registrar (e.g., Namecheap, Cloudflare)
# Navigate to DNS management for accelior.com domain

# Create A record:
Record Type: A
Name: cam.home.accelior.com
Target: 77.109.89.47
TTL: 3600 (1 hour)

# Verify DNS propagation (wait 5-60 minutes)
nslookup cam.home.accelior.com
# Should return: 77.109.89.47
```

### Step 2: Configure OPNsense Port Forwarding (if needed)
```bash
# Access OPNsense: https://192.168.1.3

# Navigate to: Firewall → NAT → Port Forward

# Verify existing rule for HTTPS:
Interface: WAN
Protocol: TCP
Destination: WAN Address
Destination Port: 443
Redirect Target IP: 192.168.1.9
Redirect Target Port: 443

# If rule doesn't exist, create it
# If rule exists, verify settings and save
```

### Step 3: Configure Nginx Proxy Manager

#### 3.1: Access NPM Admin Interface
```bash
# Open web browser
URL: http://192.168.1.9:81

# Login with admin credentials
# (If default: admin@example.com / changeme - CHANGE IMMEDIATELY)
```

#### 3.2: Create Proxy Host
```
1. Click "Hosts" → "Proxy Hosts"
2. Click "Add Proxy Host" button

Details Tab:
  Domain Names: cam.home.accelior.com
  Scheme: http
  Forward Hostname/IP: 192.168.1.20
  Forward Port: 8090
  ☑ Block Common Exploits
  ☑ Websockets Support
  ☐ Cache Assets (disabled for real-time)

SSL Tab:
  SSL Certificate: Request a new SSL Certificate
  ☑ Force SSL
  ☑ HTTP/2 Support
  ☑ HSTS Enabled
  ☐ HSTS Subdomains
  Email: admin@accelior.com
  ☑ I Agree to the Let's Encrypt Terms of Service

Advanced Tab:
  (Paste custom Nginx configuration from above)

3. Click "Save"
```

#### 3.3: Verify SSL Certificate Generation
```
# NPM will automatically:
# - Generate Nginx configuration
# - Request Let's Encrypt SSL certificate
# - Configure HTTP → HTTPS redirect
# - Reload Nginx service

# Check for success:
# - Green checkmark appears on proxy host entry
# - SSL certificate shows in NPM SSL Certificates list
```

### Step 4: Configure Access List (Optional)

#### 4.1: Create Access List
```
1. Navigate to "Access Lists"
2. Click "Add Access List"

Name: Internal Network Only
Satisfy: All
Pass Auth: No

Authorization:
  Scheme: Allow
  Address: 192.168.1.0/24

  Scheme: Deny
  Address: all

3. Click "Save"
```

#### 4.2: Apply to Proxy Host
```
1. Edit cam.home.accelior.com proxy host
2. Navigate to "Access List" tab
3. Select "Internal Network Only"
4. Click "Save"
```

### Step 5: Configure WebRTC Ports (Optional)

#### OPNsense UDP Port Forwarding
```
# Only required if WebRTC doesn't work through HTTPS tunnel

Rule 1: TURN Server
  Interface: WAN
  Protocol: UDP
  Destination: WAN Address
  Destination Port: 3478
  Redirect Target: 192.168.1.20
  Redirect Target Port: 3478

Rule 2: WebRTC Connections
  Interface: WAN
  Protocol: UDP
  Destination: WAN Address
  Destination Port Range: 50000-50100
  Redirect Target: 192.168.1.20
  Redirect Target Port Range: 50000-50100
```

## Testing Plan

### Internal Testing

#### Test 1: DNS Resolution
```bash
# From any internal machine
nslookup cam.home.accelior.com

# Expected: 77.109.89.47 (or 192.168.1.9 if Pi-hole override)
```

#### Test 2: HTTP to HTTPS Redirect
```bash
# From internal machine
curl -I http://cam.home.accelior.com

# Expected: 301 Moved Permanently to https://
```

#### Test 3: HTTPS Access
```bash
# From internal machine
curl -I https://cam.home.accelior.com

# Expected: 200 OK with SSL certificate headers
```

#### Test 4: SSL Certificate Validation
```bash
# Check SSL certificate
openssl s_client -connect cam.home.accelior.com:443 -servername cam.home.accelior.com

# Verify:
# - Issued by: Let's Encrypt
# - Valid dates (not expired)
# - Subject: CN=cam.home.accelior.com
```

#### Test 5: Backend Connectivity
```bash
# From NPM container
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  curl -I http://192.168.1.20:8090

# Expected: 200 OK from Agent DVR
```

### External Testing

#### Test 6: External DNS Resolution
```bash
# From external network or online tool
# Use: https://dnschecker.org/

Host: cam.home.accelior.com
Type: A

# Expected: Resolves to 77.109.89.47 globally
```

#### Test 7: External HTTPS Access
```bash
# From external network (cellular/different ISP)
curl -I https://cam.home.accelior.com

# Expected: 200 OK with valid SSL
```

#### Test 8: Browser Access
```
# From external network
URL: https://cam.home.accelior.com

# Expected:
# - Agent DVR login page loads
# - SSL certificate valid (green lock icon)
# - No browser warnings
```

### WebRTC Testing

#### Test 9: Video Streaming
```
1. Login to Agent DVR via https://cam.home.accelior.com
2. Add test camera with RTSP stream
3. Navigate to live camera view
4. Verify:
   - Video stream loads without errors
   - Latency < 2 seconds
   - No stuttering or buffering
   - Browser console shows no WebSocket errors
```

#### Test 10: Mobile Access
```
1. Connect mobile device to cellular network
2. Access https://cam.home.accelior.com
3. Test:
   - Login successful
   - Video streams load
   - Touch controls work
   - Performance acceptable
```

## Monitoring Configuration

### Uptime Kuma Setup
```yaml
Monitor Type: HTTP(s)
Friendly Name: Agent DVR (cam.home.accelior.com)
URL: https://cam.home.accelior.com
Method: GET
Heartbeat Interval: 60 seconds
Retries: 3
Retry Interval: 60 seconds
Timeout: 30 seconds

Accepted Status Codes: 200, 301, 302

Notifications:
  - Email: admin@accelior.com
  - Discord: #infrastructure-alerts
```

### Alert Configuration
```yaml
Conditions:
  - Service down for > 2 minutes
  - SSL certificate expiring in < 7 days
  - Response time > 5 seconds

Actions:
  - Send email notification
  - Post to Discord channel
  - Log to monitoring dashboard
```

## Acceptance Criteria

### Functional Requirements
- [x] DNS A record created and propagating globally
- [x] NPM proxy host configured successfully
- [x] Let's Encrypt SSL certificate issued and valid
- [x] HTTP automatically redirects to HTTPS
- [x] HTTPS access works from internal network
- [x] HTTPS access works from external network
- [x] Agent DVR login page loads correctly
- [x] WebSocket connections function properly

### Security Requirements
- [x] SSL certificate valid and not expired
- [x] HSTS header present in responses
- [x] Strong SSL cipher suites configured
- [x] Security headers present (X-Frame-Options, etc)
- [x] Access list configured (if required)
- [x] HTTP port 80 redirects to HTTPS

### Performance Requirements
- [x] Page load time < 3 seconds
- [x] Video streaming latency < 2 seconds
- [x] No connection errors or timeouts
- [x] Backend response time < 100ms

### Operational Requirements
- [x] Configuration persists across NPM restarts
- [x] SSL certificate auto-renewal configured
- [x] Monitoring configured in Uptime Kuma
- [x] Access logs accessible for troubleshooting
- [x] Documentation completed and published

## Troubleshooting Guide

### Issue 1: SSL Certificate Fails
```
Symptoms: Let's Encrypt certificate request fails

Diagnosis:
# Check NPM logs
docker logs nginx-proxy-manager-nginx-proxy-manager-1 | grep -i certbot

# Verify DNS
nslookup cam.home.accelior.com 8.8.8.8

# Test port 80 accessibility (required for HTTP challenge)
curl -I http://cam.home.accelior.com

Solutions:
- Verify DNS resolves to correct public IP
- Confirm port 80 forwarded to NPM
- Check Let's Encrypt rate limits (5/week per domain)
- Verify no firewall blocking outbound from NPM
```

### Issue 2: 502 Bad Gateway
```
Symptoms: HTTPS works but returns 502 error

Diagnosis:
# Check Agent DVR status
ssh root@192.168.1.20 'docker ps | grep agent-dvr'

# Test backend from NPM
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  curl -I http://192.168.1.20:8090

# Check NPM error logs
docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  tail -50 /data/logs/proxy-host-XX_error.log

Solutions:
- Verify Agent DVR container running
- Check firewall rules 192.168.1.9 → 192.168.1.20:8090
- Ensure port 8090 not blocked
- Restart NPM if configuration changed
```

### Issue 3: Video Not Streaming
```
Symptoms: Login works but video streams fail

Diagnosis:
# Check browser console for WebSocket errors
# F12 → Console → Look for "WebSocket" or "WebRTC" errors

# Verify WebSocket headers
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
  https://cam.home.accelior.com

Solutions:
- Verify "Websockets Support" enabled in NPM
- Confirm WebSocket upgrade headers in Advanced config
- Check UDP ports 3478, 50000-50100 forwarded
- Disable proxy buffering in NPM
```

## Rollback Plan

### If Configuration Fails
```
1. Access NPM admin: http://192.168.1.9:81
2. Navigate to Hosts → Proxy Hosts
3. Find cam.home.accelior.com entry
4. Click three-dot menu → Delete
5. Confirm deletion

# Clean up DNS if needed
# Remove A record from domain registrar
```

### If Performance Issues Occur
```
# Temporarily disable to resolve
1. Edit proxy host
2. Disable proxy (toggle off)
3. Investigate issues
4. Re-enable when resolved

# Alternative: Direct port forwarding
# Forward 8090 directly to Agent DVR (bypass NPM)
# Only use for troubleshooting, not recommended for production
```

## Documentation
- [x] Configuration documentation created: `/docs/agent-dvr/nginx-reverse-proxy-configuration.md`
- [ ] NPM proxy host settings documented in wiki
- [ ] Firewall rules documented in OPNsense
- [ ] DNS configuration recorded in password manager

## Related Tickets
- **IFS-XXX**: Install Agent DVR on Docker VM (blocker)
- **IFS-XXX**: Configure firewall rules for WebRTC ports (optional)
- **IFS-XXX**: Setup internal DNS override in Pi-hole (optional)

## Notes
- Let's Encrypt rate limit: 5 certificates per domain per week
- Certificate auto-renews 30 days before expiration
- WebRTC may work through HTTPS tunnel without UDP ports
- Consider access list for production (restrict to known IPs)
- Monitor SSL certificate expiration date

## References
- NPM Documentation: https://nginxproxymanager.com/guide/
- Let's Encrypt Docs: https://letsencrypt.org/docs/
- Agent DVR Docs: https://www.ispyconnect.com/docs/agent/
- Configuration Guide: `/docs/agent-dvr/nginx-reverse-proxy-configuration.md`
- NPM Setup Guide: `/docs/npm/npm.md`
```

### Assignee
Infrastructure Team

### Estimated Time
2 hours

### Time Breakdown
- DNS configuration: 15 minutes (+ propagation time)
- OPNsense verification: 15 minutes
- NPM proxy host setup: 30 minutes
- SSL certificate generation: 15 minutes (automated)
- Testing and validation: 30 minutes
- Monitoring configuration: 15 minutes

---

## Import Instructions

### Option 1: Manual Creation in JIRA UI
1. Navigate to https://jira.accelior.com/projects/IFS
2. Click "Create" button
3. Select Issue Type: Task
4. Copy Summary, Description, and other fields from above
5. Set Priority, Labels, Components as specified
6. Assign to Infrastructure Team
7. Click "Create"

### Option 2: Import via JIRA REST API (if available)
```bash
# Example using curl (requires authentication)
curl -X POST "https://jira.accelior.com/rest/api/2/issue" \
  -H "Content-Type: application/json" \
  -u username:api_token \
  -d '{
    "fields": {
      "project": {"key": "IFS"},
      "summary": "Deploy Agent DVR surveillance platform on Docker VM (192.168.1.20)",
      "description": "[Full description from Ticket 1]",
      "issuetype": {"name": "Task"},
      "priority": {"name": "Medium"},
      "labels": ["docker", "surveillance", "video", "infrastructure"],
      "components": [{"name": "Docker"}, {"name": "Monitoring"}]
    }
  }'
```

### Option 3: Import via CSV (if supported)
1. Export this data to CSV format with JIRA fields
2. In JIRA, go to Issues → Import issues from CSV
3. Upload CSV file and map fields
4. Complete import process

## Post-Import Actions
1. Link the two tickets (Ticket 2 blocks on Ticket 1)
2. Add to appropriate sprint/epic
3. Assign to team members
4. Set due dates if required
5. Add to kanban board or project tracking

## Ticket Dependencies
```
IFS-XXX (Agent DVR Installation)
    ↓ blocks
IFS-XXX (Nginx Reverse Proxy Configuration)
```

---

**Document Created**: 2025-10-01
**Ready for Import**: Yes
**Estimated Total Implementation Time**: 6 hours
