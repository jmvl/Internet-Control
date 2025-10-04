# Agent DVR - Video Surveillance Platform Documentation

## Overview
Agent DVR is an advanced video surveillance platform supporting IP cameras, motion detection, and recording capabilities. This document covers the planned installation and configuration of Agent DVR as a Docker container on the Docker VM infrastructure.

## System Information
- **Planned Host**: Docker VM (192.168.1.20)
- **Container Name**: agent-dvr
- **Image**: mekayelanik/ispyagentdvr:latest
- **Web Interface**: http://192.168.1.20:8090 (internal) / https://cam.home.accelior.com (external)
- **Status**: Planned installation
- **Access Domain**: cam.home.accelior.com (via Nginx Proxy Manager on 192.168.1.9)

## Agent DVR Features

### Core Capabilities
- **Multi-Camera Support**: Connect and manage multiple IP cameras
- **Motion Detection**: AI-powered motion detection and alerts
- **Video Recording**: Continuous and motion-triggered recording
- **Live Streaming**: Real-time camera feed viewing
- **WebRTC Support**: Low-latency video streaming
- **Multi-Platform**: Supports Windows, macOS, Linux, Docker, and Raspberry Pi

### Advanced Features
- **Hardware Acceleration**: Support for Nvidia, AMD, Intel GPUs
- **Multi-Architecture**: x86-64, ARM64, ARM32 support
- **Remote Access**: Secure remote viewing capabilities
- **Alerts and Notifications**: Motion detection alerts
- **Recording Schedules**: Time-based recording configuration
- **PTZ Control**: Pan-Tilt-Zoom camera control

## Infrastructure Architecture

### Deployment Context
```
Internet
    ↓
[OpenWrt Router] 192.168.1.2
    ↓
[OPNsense Firewall] 192.168.1.3
    ↓
[OMV Nginx Proxy Manager] 192.168.1.9:443 (cam.home.accelior.com)
    ↓
[Docker VM] 192.168.1.20:8090 (Agent DVR Container)
    ↓
[IP Cameras] - Various locations on 192.168.1.0/24 network
```

### Network Integration
- **Internal Access**: http://192.168.1.20:8090
- **External Access**: https://cam.home.accelior.com (via NPM reverse proxy)
- **Camera Network**: 192.168.1.0/24 (LAN access to IP cameras)
- **WebRTC Ports**: UDP 50000-50100 for low-latency streaming
- **TURN Server**: UDP 3478 for NAT traversal

## Docker Configuration

### Docker Compose Configuration
```yaml
version: '3.8'

services:
  agent-dvr:
    image: mekayelanik/ispyagentdvr:latest
    container_name: agent-dvr
    restart: unless-stopped

    # Environment variables
    environment:
      - PUID=1000                      # User ID for file permissions
      - PGID=1000                      # Group ID for file permissions
      - TZ=America/New_York            # Timezone configuration
      - AGENTDVR_WEBUI_PORT=8090      # Web UI port

    # Port mappings
    ports:
      - "8090:8090"                    # Web UI
      - "3478:3478/udp"                # TURN server
      - "50000-50100:50000-50100/udp"  # WebRTC connections

    # Volume mounts
    volumes:
      - /srv/docker-data/agent-dvr/config:/AgentDVR/Media/XML
      - /srv/docker-data/agent-dvr/media:/AgentDVR/Media/WebServerRoot/Media
      - /srv/docker-data/agent-dvr/commands:/AgentDVR/Commands

    # Network configuration
    networks:
      - agent-dvr-network

    # Optional: Hardware acceleration (if GPU available)
    # devices:
    #   - /dev/dri:/dev/dri              # Intel GPU
    # deploy:
    #   resources:
    #     reservations:
    #       devices:
    #         - driver: nvidia           # Nvidia GPU
    #           count: 1
    #           capabilities: [gpu]

networks:
  agent-dvr-network:
    driver: bridge

```

### Docker CLI Deployment
```bash
# Create required directories
mkdir -p /srv/docker-data/agent-dvr/{config,media,commands}

# Run Agent DVR container
docker run -d \
  --name=agent-dvr \
  --restart=unless-stopped \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=America/New_York \
  -e AGENTDVR_WEBUI_PORT=8090 \
  -p 8090:8090 \
  -p 3478:3478/udp \
  -p 50000-50100:50000-50100/udp \
  -v /srv/docker-data/agent-dvr/config:/AgentDVR/Media/XML \
  -v /srv/docker-data/agent-dvr/media:/AgentDVR/Media/WebServerRoot/Media \
  -v /srv/docker-data/agent-dvr/commands:/AgentDVR/Commands \
  mekayelanik/ispyagentdvr:latest
```

## Environment Variables

| Variable | Default | Purpose | Notes |
|----------|---------|---------|-------|
| **PUID** | 1000 | User ID for file permissions | Match host user ID |
| **PGID** | 1000 | Group ID for file permissions | Match host group ID |
| **TZ** | UTC | Timezone for recordings | Format: America/New_York |
| **AGENTDVR_WEBUI_PORT** | 8090 | Web UI port | Must match port mapping |

## Volume Mounts

### Configuration Directory
- **Host Path**: `/srv/docker-data/agent-dvr/config`
- **Container Path**: `/AgentDVR/Media/XML`
- **Purpose**: Camera configurations, settings, and database
- **Permissions**: Read/Write by PUID/PGID user
- **Backup Priority**: Critical - contains all configuration

### Media Storage
- **Host Path**: `/srv/docker-data/agent-dvr/media`
- **Container Path**: `/AgentDVR/Media/WebServerRoot/Media`
- **Purpose**: Video recordings and snapshots
- **Permissions**: Read/Write by PUID/PGID user
- **Backup Priority**: High - contains recorded footage
- **Storage Requirements**: Plan for 50-500GB+ depending on cameras and retention

### Commands Directory
- **Host Path**: `/srv/docker-data/agent-dvr/commands`
- **Container Path**: `/AgentDVR/Commands`
- **Purpose**: Custom command scripts and automation
- **Permissions**: Read/Execute by PUID/PGID user
- **Backup Priority**: Medium - contains automation scripts

## Port Configuration

### Required Ports

| Port | Protocol | Purpose | Accessibility | Notes |
|------|----------|---------|---------------|-------|
| **8090** | TCP | Web Interface | Internal LAN | HTTP web UI |
| **3478** | UDP | TURN Server | Internal/External | NAT traversal for WebRTC |
| **50000-50100** | UDP | WebRTC | Internal/External | Real-time video streaming |

### Network Requirements
- **Camera Access**: Agent DVR must access IP cameras on LAN (192.168.1.0/24)
- **Internet Access**: Required for remote viewing and WebRTC
- **Firewall Rules**: OPNsense must allow camera traffic to Docker VM
- **Reverse Proxy**: Nginx Proxy Manager on 192.168.1.9 for external HTTPS access

## Storage Requirements

### Disk Space Planning

#### Minimum Requirements
- **Configuration**: 100 MB
- **Application**: 500 MB
- **Recordings (1 camera, 7 days)**: 50-100 GB
- **Total Minimum**: 51 GB

#### Recommended Requirements
- **Configuration**: 100 MB
- **Application**: 500 MB
- **Recordings (4 cameras, 30 days)**: 500 GB - 1 TB
- **Total Recommended**: 500 GB - 1 TB

#### Storage Calculation
```
Storage per camera per day = Resolution × FPS × Compression × Hours
Example (1080p, 15fps, H.264):
  ~5-10 GB per camera per day
  ~150-300 GB per camera per month (30 days)
  ~600 GB - 1.2 TB for 4 cameras per month
```

### Storage Location
- **Docker VM**: Limited to 60GB root filesystem
- **Recommended**: Mount OMV NAS storage for media recordings
- **Path**: `/srv/docker-data/agent-dvr/media` → NFS/CIFS mount to OMV

## Resource Requirements

### CPU
- **Minimum**: 2 cores
- **Recommended**: 4-6 cores
- **Per Camera**: ~0.5-1 core for transcoding without hardware acceleration
- **With GPU**: Minimal CPU usage for video encoding/decoding

### Memory
- **Minimum**: 2 GB RAM
- **Recommended**: 4 GB RAM
- **Per Camera**: ~200-500 MB depending on resolution and features

### GPU Acceleration (Optional)

#### Nvidia GPU
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```
**Requirements**: Nvidia Container Toolkit installed on host

#### Intel GPU
```yaml
devices:
  - /dev/dri:/dev/dri
```
**Requirements**: Intel VA-API drivers on host

#### AMD GPU
```yaml
devices:
  - /dev/dri:/dev/dri
```
**Requirements**: Mesa VA-API drivers on host

## Installation Prerequisites

### Docker Host Preparation
1. **Verify Docker Installation**
   ```bash
   ssh root@192.168.1.20
   docker --version  # Should be 23.0+
   docker compose version
   ```

2. **Create Storage Directories**
   ```bash
   mkdir -p /srv/docker-data/agent-dvr/{config,media,commands}
   chown -R 1000:1000 /srv/docker-data/agent-dvr
   chmod -R 755 /srv/docker-data/agent-dvr
   ```

3. **Verify Network Connectivity**
   ```bash
   # Test connectivity to camera network
   ping 192.168.1.x  # Replace with camera IP

   # Test internet access for remote viewing
   ping 8.8.8.8
   ```

4. **Check Available Resources**
   ```bash
   # Check available disk space
   df -h /srv/docker-data

   # Check CPU cores and memory
   nproc
   free -h
   ```

### Network Preparation

#### OPNsense Firewall Rules
- Allow traffic from Docker VM (192.168.1.20) to camera subnet
- Allow UDP ports 3478, 50000-50100 for WebRTC
- NAT port forwarding for external access (if needed)

#### Nginx Proxy Manager Configuration
- Create proxy host for `cam.home.accelior.com`
- Backend: `http://192.168.1.20:8090`
- SSL certificate: Let's Encrypt
- WebSocket support: Enabled
- Access list: Internal network only (optional)

## Initial Configuration

### Post-Installation Steps

1. **Access Web Interface**
   ```
   http://192.168.1.20:8090
   ```

2. **First-Time Setup Wizard**
   - Select language
   - Create admin account
   - Configure storage paths
   - Set timezone

3. **Add IP Cameras**
   - Navigate to Cameras → Add
   - Enter camera RTSP URL
   - Configure authentication
   - Test connection
   - Save configuration

4. **Configure Recording Settings**
   - Motion detection sensitivity
   - Recording schedule (continuous vs motion-triggered)
   - Retention policies
   - Storage location

5. **Setup Remote Access**
   - Enable WebRTC
   - Configure TURN server
   - Test external access via cam.home.accelior.com

## Integration with Existing Infrastructure

### Docker VM (192.168.1.20)
- **Container Platform**: Existing n8n, Supabase, monitoring services
- **Resource Consideration**: Monitor memory usage (currently 20.5% of 20GB)
- **Network**: Same vmbr0 bridge as other services
- **Storage**: Coordinate with existing Docker volume structure

### OMV NAS (192.168.1.9)
- **Storage Integration**: Option to store recordings on OMV RAID storage
- **Nginx Proxy Manager**: Reverse proxy for external access
- **Backup Integration**: Include Agent DVR config in backup procedures

### Network Infrastructure
- **OpenWrt (192.168.1.2)**: Wi-Fi access to mobile clients
- **OPNsense (192.168.1.3)**: Firewall rules and traffic shaping
- **Pi-hole (192.168.1.5)**: DNS resolution for cam.home.accelior.com

## Service Management

### Container Operations

#### Start/Stop Container
```bash
# Start container
docker start agent-dvr

# Stop container
docker stop agent-dvr

# Restart container
docker restart agent-dvr

# View container status
docker ps | grep agent-dvr
```

#### View Logs
```bash
# Real-time logs
docker logs -f agent-dvr

# Last 100 lines
docker logs --tail 100 agent-dvr

# Web-based logs
# Navigate to: http://192.168.1.20:8090/logs.html
```

#### Update Container
```bash
# Pull latest image
docker pull mekayelanik/ispyagentdvr:latest

# Stop and remove old container
docker stop agent-dvr
docker rm agent-dvr

# Recreate with updated image (using docker-compose)
docker compose up -d agent-dvr
```

### Configuration Backup

#### Manual Backup
```bash
# Backup configuration directory
tar -czf agent-dvr-config-backup-$(date +%Y%m%d).tar.gz \
  /srv/docker-data/agent-dvr/config

# Backup to remote storage (OMV NAS)
scp agent-dvr-config-backup-*.tar.gz root@192.168.1.9:/srv/raid/docker-backups/
```

#### Automated Backup (Recommended)
```bash
# Add to cron job on Docker VM
0 2 * * * tar -czf /root/backups/agent-dvr-config-$(date +\%Y\%m\%d).tar.gz /srv/docker-data/agent-dvr/config
```

## Troubleshooting

### Common Issues

#### Container Fails to Start
**Symptoms**: Container exits immediately after starting

**Diagnosis**:
```bash
# Check container logs
docker logs agent-dvr

# Check container status
docker ps -a | grep agent-dvr

# Verify permissions
ls -la /srv/docker-data/agent-dvr/
```

**Solutions**:
- Verify PUID/PGID match host user
- Check directory permissions (755 for directories, 644 for files)
- Ensure sufficient disk space
- Verify port 8090 not already in use

#### Cannot Access Web Interface
**Symptoms**: http://192.168.1.20:8090 times out or connection refused

**Diagnosis**:
```bash
# Check if container is running
docker ps | grep agent-dvr

# Check port binding
docker port agent-dvr

# Test local connectivity
curl -I http://localhost:8090
```

**Solutions**:
- Verify container is running
- Check firewall rules on Docker VM
- Ensure no port conflicts with other services
- Verify network bridge configuration

#### Camera Connection Issues
**Symptoms**: Unable to add or connect to IP cameras

**Diagnosis**:
```bash
# Test camera connectivity from Docker VM
docker exec agent-dvr ping <camera_IP>

# Test RTSP stream
docker exec agent-dvr curl -v rtsp://<camera_IP>:554/stream
```

**Solutions**:
- Verify camera IP address and network accessibility
- Check camera RTSP credentials
- Confirm firewall rules allow traffic to camera subnet
- Test RTSP URL format (varies by camera manufacturer)

#### High CPU/Memory Usage
**Symptoms**: Container consuming excessive resources

**Diagnosis**:
```bash
# Monitor container resources
docker stats agent-dvr

# Check running processes in container
docker top agent-dvr
```

**Solutions**:
- Enable hardware acceleration (GPU)
- Reduce camera resolution or frame rate
- Adjust motion detection sensitivity
- Limit number of concurrent recordings

#### Storage Running Out
**Symptoms**: Recordings fail, disk space errors

**Diagnosis**:
```bash
# Check disk space
df -h /srv/docker-data/agent-dvr/media

# Check recording sizes
du -sh /srv/docker-data/agent-dvr/media/*
```

**Solutions**:
- Configure retention policies (auto-delete old recordings)
- Reduce recording resolution or quality
- Move media storage to NAS with more capacity
- Implement recording schedules (motion-triggered vs continuous)

### Performance Optimization

#### Enable Hardware Acceleration
```bash
# For Intel GPU (add to docker-compose.yml)
devices:
  - /dev/dri:/dev/dri

# Verify GPU access
docker exec agent-dvr ls -la /dev/dri
```

#### Optimize Recording Settings
- **Resolution**: Use 1080p instead of 4K for most cameras
- **Frame Rate**: 15 FPS sufficient for most surveillance
- **Encoding**: H.264 provides good balance of quality and size
- **Motion Detection**: Use to trigger recordings instead of continuous

#### Network Optimization
- **Camera VLAN**: Consider separate VLAN for camera traffic
- **QoS**: Configure traffic prioritization on OPNsense
- **Bandwidth**: Monitor camera bandwidth usage
- **Local Storage**: Prefer local recording over network streaming

## Security Considerations

### Network Security
- **Access Control**: Use Nginx Proxy Manager access lists for external access
- **SSL/TLS**: HTTPS only for external access via cam.home.accelior.com
- **Firewall Rules**: Restrict access to web interface and WebRTC ports
- **Camera Isolation**: Consider separate VLAN for IP cameras

### Authentication
- **Strong Passwords**: Use complex passwords for Agent DVR admin account
- **Camera Credentials**: Secure camera admin credentials
- **API Keys**: Protect API access keys if using integrations

### Data Protection
- **Encryption**: Consider encrypting stored recordings
- **Backup**: Regular backups of configuration and critical footage
- **Retention**: Define and enforce retention policies
- **Access Logs**: Monitor access logs for suspicious activity

## Monitoring and Alerting

### Health Checks

#### Container Health
```bash
# Check container status
docker ps | grep agent-dvr

# Monitor resource usage
docker stats agent-dvr --no-stream

# Check logs for errors
docker logs agent-dvr | grep -i error
```

#### Service Availability
- **Uptime Kuma**: Add monitoring check for http://192.168.1.20:8090
- **Alert Channels**: Configure email/Discord alerts for downtime
- **Heartbeat**: Monitor container uptime and restarts

### Performance Metrics
- **CPU Usage**: Should be <50% with hardware acceleration
- **Memory Usage**: Typical 2-4GB for 4 cameras
- **Disk I/O**: Monitor write speed for recordings
- **Network Bandwidth**: Track camera bandwidth consumption

### Operational Alerts
- **Recording Failures**: Alert on camera disconnections
- **Storage Warnings**: Alert at 80% disk usage
- **Motion Events**: Optional alerts for motion detection
- **System Health**: Monitor container restarts and errors

## Maintenance Schedule

### Daily Tasks
- Check container status and uptime
- Monitor storage usage
- Review motion detection alerts

### Weekly Tasks
- Review access logs for suspicious activity
- Verify all cameras recording properly
- Check recording retention policies

### Monthly Tasks
- Update Agent DVR container image
- Backup configuration files
- Review and optimize storage usage
- Test disaster recovery procedures

### Quarterly Tasks
- Review and update firewall rules
- Audit camera configurations
- Test external access functionality
- Validate backup integrity

## Integration Opportunities

### n8n Workflow Automation (192.168.1.20)
- **Motion Alerts**: Send notifications to Discord/Slack/Email
- **Recording Management**: Automated cleanup of old recordings
- **Camera Health**: Monitor camera online/offline status
- **Backup Automation**: Trigger backups to OMV NAS

### Uptime Kuma Monitoring (192.168.1.9)
- **HTTP Monitor**: Check web interface availability
- **Keyword Monitor**: Check for specific errors in logs
- **Ping Monitor**: Monitor container network connectivity
- **Status Page**: Public status for cam.home.accelior.com

### Home Assistant (Future)
- **Camera Integration**: Agent DVR has native Home Assistant integration
- **Automation**: Trigger actions based on motion detection
- **Dashboard**: Display camera feeds on Home Assistant dashboard

## Future Enhancements

### Planned Improvements
- **Object Detection**: Enable AI-powered object detection
- **Face Recognition**: Configure face recognition for alerts
- **Multi-Site Support**: Connect cameras from multiple locations
- **Cloud Backup**: Automated backup to cloud storage
- **Mobile App**: Configure mobile app access

### Scalability Considerations
- **Additional Cameras**: Plan for 8-16 cameras maximum per instance
- **Multiple Instances**: Consider multiple Agent DVR instances for large deployments
- **Load Balancing**: Distribute camera load across multiple servers
- **Dedicated Storage**: Move recordings to dedicated NAS or SAN

## Related Documentation

### Infrastructure Documentation
- [Infrastructure Overview](/docs/infrastructure.md) - Complete network architecture
- [Docker VM Setup](/docs/docker/pct-111-docker-setup.md) - Docker host configuration
- [Nginx Proxy Manager](/docs/npm/npm.md) - Reverse proxy configuration
- [Docker Containers Overview](/docs/docker-containers-overview.md) - Container ecosystem

### Service-Specific Documentation
- [n8n Automation](/docs/n8n/README.md) - Workflow automation integration
- [Uptime Kuma](/docs/uptime-kuma/uptime-kuma-installation.md) - Monitoring setup
- [OMV Storage](/docs/infrastructure.md#openmediavault-storage-server-19216819) - Storage configuration

## Support Resources

### Official Documentation
- **Agent DVR Documentation**: https://www.ispyconnect.com/docs/agent/
- **Docker Image Repository**: https://github.com/MekayelAnik/ispyagentdvr-docker
- **Official Website**: https://www.ispyconnect.com/

### Community Resources
- **GitHub Issues**: Report bugs and feature requests
- **Docker Hub**: https://hub.docker.com/r/mekayelanik/ispyagentdvr
- **Community Forum**: iSpy Connect community support

---

**Document Status**: Planning/Pre-Implementation
**Created**: 2025-10-01
**Last Updated**: 2025-10-01
**Next Review**: Post-Implementation
**Maintainer**: Infrastructure Team
