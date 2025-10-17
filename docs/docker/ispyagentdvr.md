# iSpy Agent DVR - Network Video Recording

> **⚠️ SERVICE STATUS**: This container has been **stopped** and replaced by [Frigate NVR](frigate.md) due to GPU acceleration issues. The container is preserved for reference but is no longer active. See [Frigate documentation](frigate.md) for the current NVR solution.

## Overview

iSpy Agent DVR is a standalone free-to-use NVR (Network Video Recorder) software for IP camera management. It provides a comprehensive video surveillance solution with support for multiple camera types, motion detection, recording, and remote access capabilities.

**Deployment Location**: Docker VM (192.168.1.20, VMID 111)
**Installation Date**: 2025-10-08
**Status**: ⏸️ Stopped (replaced by Frigate)
**GPU Acceleration**: ⚠️ Configured but not functional

## Service Details

### Access Information
- **Web Interface**: http://192.168.1.20:8090
- **Container Name**: `ispyagentdvr`
- **Image**: `doitandbedone/ispyagentdvr:latest`
- **Restart Policy**: `unless-stopped`

### Port Configuration
| Port | Protocol | Purpose | External Access |
|------|----------|---------|----------------|
| **8090** | TCP | Web UI | 0.0.0.0:8090 |
| **3478** | UDP | STUN for WebRTC | 0.0.0.0:3478 |
| **50000-50100** | UDP | TURN for WebRTC | 0.0.0.0:50000-50100 |

**Note**: All ports are exposed on the Docker host (192.168.1.20). Access to the web interface from other network devices is available at http://192.168.1.20:8090.

### Volume Mappings
```yaml
volumes:
  - /root/ispyagentdvr/config:/agent/Media/XML/
  - /root/ispyagentdvr/media:/agent/Media/WebServerRoot/Media/
  - /root/ispyagentdvr/commands:/agent/Commands/
```

#### Storage Locations
- **Configuration**: `/root/ispyagentdvr/config` - XML configuration files
- **Media Storage**: `/root/ispyagentdvr/media` - Recorded video footage and snapshots
- **Commands**: `/root/ispyagentdvr/commands` - Custom command scripts

## Key Features

### Video Management
- **Multi-Camera Support**: Manage multiple IP cameras from a single interface
- **Motion Detection**: Configurable motion detection with customizable sensitivity
- **Recording Modes**: Continuous, motion-triggered, and scheduled recording
- **Live Streaming**: Real-time video streaming via WebRTC
- **Snapshot Capture**: Periodic snapshot capture and archiving

### Network Capabilities
- **WebRTC Streaming**: Low-latency video streaming using WebRTC protocol
- **STUN/TURN Support**: NAT traversal for remote access
- **Multi-User Access**: Support for multiple simultaneous viewers
- **Mobile Access**: Responsive web interface for mobile devices

### Advanced Features
- **Object Detection**: AI-powered object recognition (person, vehicle, etc.)
- **Alert System**: Email and webhook notifications on motion events
- **Timeline Playback**: Easy navigation through recorded footage
- **Cloud Integration**: Optional cloud storage backup

## Configuration

### Docker Compose
Located at: `/root/ispyagentdvr/docker-compose.yml`

```yaml
services:
  ispyagentdvr:
    image: doitandbedone/ispyagentdvr:latest
    container_name: ispyagentdvr
    restart: unless-stopped
    ports:
      - "8090:8090"           # Web UI
      - "3478:3478/udp"       # STUN for WebRTC
      - "50000-50100:50000-50100/udp"  # TURN for WebRTC
    volumes:
      - /root/ispyagentdvr/config:/agent/Media/XML/
      - /root/ispyagentdvr/media:/agent/Media/WebServerRoot/Media/
      - /root/ispyagentdvr/commands:/agent/Commands/
    devices:
      - /dev/dri:/dev/dri     # GPU passthrough for hardware acceleration
    group_add:
      - "44"                  # video group
      - "104"                 # render group
    environment:
      - TZ=America/Los_Angeles
    networks:
      - ispyagentdvr_network

networks:
  ispyagentdvr_network:
    driver: bridge
```

### Environment Variables
- **TZ**: `America/Los_Angeles` - Timezone for timestamping recordings

### GPU Acceleration

**Hardware**: AMD Renoir integrated GPU
**Status**: ✅ Enabled

The container has direct access to the host GPU via `/dev/dri` device passthrough, enabling:
- **Hardware video encoding/decoding** (H.264, H.265/HEVC)
- **Reduced CPU usage** with multiple camera streams
- **Better performance** for motion detection and AI features
- **Smoother WebRTC streaming** with hardware acceleration

#### GPU Configuration Details
- **Device**: `/dev/dri/card0` and `/dev/dri/renderD128` passed through to container
- **Groups**: Container runs with `video` (GID 44) and `render` (GID 104) group permissions
- **LXC Passthrough**: AMD GPU passed from Proxmox host (pve2) to LXC container 111

#### Verify GPU Access
```bash
# Check GPU devices inside container
ssh root@192.168.1.20 'docker exec ispyagentdvr ls -la /dev/dri/'

# Expected output:
# crw-rw---- 1 root video  226,   0 card0
# crw-rw---- 1 root render 226, 128 renderD128
```

#### Hardware Encoding Configuration
To enable hardware acceleration in iSpy Agent DVR:
1. Navigate to **Settings** → **Server**
2. Under **Video Encoder**, select:
   - **H.264**: `h264_vaapi` (AMD GPU hardware encoder)
   - **H.265**: `hevc_vaapi` (AMD GPU hardware encoder)
3. Enable **Hardware Acceleration** checkbox
4. Save and restart recording to apply changes

#### Performance Benefits
With GPU acceleration enabled:
- **CPU Usage**: ~5-10% per camera (vs 20-30% without GPU)
- **Encoding Performance**: Real-time encoding for up to 8-10 1080p streams
- **Power Efficiency**: Lower overall system power consumption
- **Simultaneous Streams**: Support for more concurrent camera streams

## Management Operations

### Container Management
```bash
# Check container status
ssh root@192.168.1.20 'docker ps | grep ispyagentdvr'

# View container logs
ssh root@192.168.1.20 'docker logs ispyagentdvr'

# Follow logs in real-time
ssh root@192.168.1.20 'docker logs -f ispyagentdvr'

# Restart container
ssh root@192.168.1.20 'cd /root/ispyagentdvr && docker compose restart'

# Stop container
ssh root@192.168.1.20 'cd /root/ispyagentdvr && docker compose stop'

# Start container
ssh root@192.168.1.20 'cd /root/ispyagentdvr && docker compose up -d'

# Remove and recreate container
ssh root@192.168.1.20 'cd /root/ispyagentdvr && docker compose down && docker compose up -d'
```

### Update Container
```bash
# Pull latest image and recreate container
ssh root@192.168.1.20 'cd /root/ispyagentdvr && docker compose pull && docker compose up -d'
```

## Storage Management

### Media Storage
Video recordings are stored in `/root/ispyagentdvr/media/` on the Docker host. Monitor storage usage to prevent disk space exhaustion:

```bash
# Check media storage size
ssh root@192.168.1.20 'du -sh /root/ispyagentdvr/media/'

# List recent recordings
ssh root@192.168.1.20 'ls -lth /root/ispyagentdvr/media/ | head -20'
```

### Cleanup Old Recordings
Configure automatic cleanup within the iSpy Agent DVR web interface:
1. Navigate to Settings → Storage
2. Set maximum storage size
3. Enable automatic deletion of old recordings
4. Configure retention period (days)

### Manual Cleanup
```bash
# Remove recordings older than 30 days
ssh root@192.168.1.20 'find /root/ispyagentdvr/media/ -type f -mtime +30 -delete'
```

## Network Configuration

### Firewall Rules
If using OPNsense/firewall, create rules to allow:
- **Incoming**: TCP 8090 (Web UI)
- **Incoming**: UDP 3478 (STUN)
- **Incoming**: UDP 50000-50100 (TURN)

### Port Conflicts
Verified no conflicts with existing services:
- Port 8090 is unique to iSpy Agent DVR
- UDP ports do not conflict with other services

## Adding Cameras

### Supported Camera Types
- **RTSP**: Most IP cameras with RTSP streams
- **ONVIF**: Cameras with ONVIF protocol support
- **HTTP/MJPEG**: Cameras with HTTP MJPEG streams
- **Local USB**: USB webcams connected to Docker host

### Camera Configuration Steps
1. Access web interface at http://192.168.1.20:8090
2. Click "Add" → "Camera"
3. Enter camera details:
   - Name
   - Model/Manufacturer
   - Stream URL (e.g., `rtsp://192.168.1.100:554/stream1`)
   - Credentials (if required)
4. Configure recording settings
5. Test connection and adjust settings

### Example RTSP URL Formats
```
# Generic RTSP
rtsp://username:password@camera_ip:554/stream1

# Common manufacturers
rtsp://192.168.1.100:554/Streaming/Channels/101  # Hikvision
rtsp://192.168.1.100:554/cam/realmonitor?channel=1&subtype=0  # Dahua
rtsp://192.168.1.100:554/user=admin&password=&channel=1&stream=0  # Foscam
```

## Troubleshooting

### Container Won't Start
```bash
# Check container logs for errors
ssh root@192.168.1.20 'docker logs ispyagentdvr'

# Verify volume permissions
ssh root@192.168.1.20 'ls -la /root/ispyagentdvr/'

# Restart container
ssh root@192.168.1.20 'cd /root/ispyagentdvr && docker compose restart'
```

### Web Interface Not Accessible
```bash
# Check if container is running
ssh root@192.168.1.20 'docker ps | grep ispyagentdvr'

# Test port connectivity
curl -I http://192.168.1.20:8090

# Check firewall rules (if applicable)
```

### Camera Connection Issues
1. Verify camera network connectivity: `ping camera_ip`
2. Test RTSP stream with VLC or ffmpeg
3. Check camera credentials and stream URL
4. Verify network firewall allows outbound RTSP connections
5. Review iSpy Agent DVR logs for camera-specific errors

### Storage Issues
```bash
# Check disk space on Docker host
ssh root@192.168.1.20 'df -h'

# Check media directory size
ssh root@192.168.1.20 'du -sh /root/ispyagentdvr/media/'

# Remove old recordings if needed
ssh root@192.168.1.20 'find /root/ispyagentdvr/media/ -type f -mtime +30 -delete'
```

## Backup and Recovery

### Configuration Backup
```bash
# Backup configuration directory
ssh root@192.168.1.20 'tar -czf ispyagentdvr-config-$(date +%Y%m%d).tar.gz /root/ispyagentdvr/config/'

# Backup docker-compose.yml
ssh root@192.168.1.20 'cp /root/ispyagentdvr/docker-compose.yml /root/ispyagentdvr/docker-compose.yml.bak'
```

### Restore Configuration
```bash
# Restore from backup
ssh root@192.168.1.20 'tar -xzf ispyagentdvr-config-20251008.tar.gz -C /'

# Restart container
ssh root@192.168.1.20 'cd /root/ispyagentdvr && docker compose restart'
```

### Media Backup
For critical recordings, configure external backup to NAS storage:
```bash
# Copy recordings to OMV NAS
ssh root@192.168.1.20 'rsync -av /root/ispyagentdvr/media/ root@192.168.1.9:/srv/raid/ispyagentdvr-backups/'
```

## Monitoring and Alerts

### Uptime Kuma Integration
Add iSpy Agent DVR to Uptime Kuma monitoring:
1. Navigate to http://192.168.1.9:3010
2. Add monitor:
   - **Type**: HTTP(s)
   - **Name**: iSpy Agent DVR
   - **URL**: http://192.168.1.20:8090
   - **Interval**: 60 seconds
   - **Max Retry**: 3

### Health Check
```bash
# Test web interface availability
curl -s -o /dev/null -w "%{http_code}" http://192.168.1.20:8090
# Expected: 200

# Check container health
ssh root@192.168.1.20 'docker inspect ispyagentdvr --format="{{.State.Status}}"'
# Expected: running
```

## Performance Considerations

### Resource Usage
- **CPU**: Varies with number of cameras and recording quality (1-10% per camera)
- **Memory**: ~200-500MB base + ~50-100MB per active camera
- **Disk I/O**: High during recording and motion events
- **Network**: Depends on camera stream bitrates

### Optimization Tips
1. **Adjust Recording Quality**: Lower bitrate for less critical cameras
2. **Motion Detection Zones**: Define specific areas to reduce false triggers
3. **Frame Rate Limits**: Reduce FPS for less critical cameras
4. **Storage Rotation**: Enable automatic cleanup to prevent disk filling
5. **Disable AI Features**: Turn off object detection for resource-constrained systems

## Security Recommendations

### Authentication
- Enable password protection in iSpy Agent DVR settings
- Use strong, unique passwords for admin access
- Configure user accounts with appropriate permissions

### Network Security
- **Internal Access Only**: Keep iSpy Agent DVR on internal network
- **Reverse Proxy**: Use Nginx Proxy Manager for external access with SSL
- **VPN Access**: Use WireGuard/OpenVPN for remote access instead of port forwarding
- **Camera Isolation**: Place cameras on isolated VLAN if possible

### Regular Maintenance
- Update iSpy Agent DVR regularly for security patches
- Review access logs periodically
- Audit camera credentials and change passwords regularly
- Monitor for unauthorized access attempts

## Related Infrastructure

### Docker VM (192.168.1.20)
- **Platform**: Debian-based LXC container on Proxmox
- **Resources**: 12 CPU cores, 10GB RAM, 60GB storage
- **Network**: 192.168.1.20/24 via vmbr0 (LAN bridge)
- **Other Services**: Supabase, n8n, Netdata, Portainer

### Network Path
```
Cameras → [OpenWrt Router] → [OPNsense Firewall] → [Docker VM] → iSpy Agent DVR
```

## Support and Documentation

### Official Resources
- **Website**: https://www.ispyconnect.com/
- **Documentation**: https://www.ispyconnect.com/userguide-agent-dvr.aspx
- **Docker Hub**: https://hub.docker.com/r/doitandbedone/ispyagentdvr
- **GitHub**: https://github.com/doitandbedone/ispyagentdvr-docker

### Community Support
- **Forum**: https://www.ispyconnect.com/forum/
- **Discord**: iSpy Community Server
- **Reddit**: r/ispyagentdvr

## Change Log

### 2025-10-08 - Service Stopped (Replaced by Frigate)
- ⏸️ Container stopped due to non-functional GPU acceleration
- 🔄 Replaced by Frigate NVR (see [frigate.md](frigate.md))
- 📦 Container preserved at `/root/ispyagentdvr/` for reference
- ⚠️ GPU acceleration configured but never functioned despite:
  - Correct VAAPI configuration (hevc_vaapi)
  - GPU devices passed through properly
  - VAAPI drivers installed and functional
  - Per-camera GPU settings configured
- 📊 Performance issue: 245-315% CPU usage with 3 cameras
- 🎯 Root cause: iSpy software not utilizing VAAPI despite configuration
- ✅ Migration to Frigate successful with better AI detection capabilities

### 2025-10-08 - GPU Acceleration Configuration
- ✅ Enabled AMD Renoir GPU passthrough from Proxmox host to LXC container 111
- Added `/dev/dri` device passthrough in LXC configuration
- Updated docker-compose.yml with GPU device mapping and group permissions
- Configured video (GID 44) and render (GID 104) group access
- Verified GPU devices available inside container: card0, renderD128
- Container restarted successfully with GPU acceleration
- Updated documentation with GPU configuration details
- Minimal downtime: ~2 minutes during LXC container restart

### 2025-10-08 - Initial Installation
- Deployed iSpy Agent DVR on Docker VM (192.168.1.20)
- Configured ports: 8090 (HTTP), 3478 (STUN), 50000-50100 (TURN)
- Created docker-compose configuration at `/root/ispyagentdvr/`
- Verified web interface accessibility (HTTP 200)
- No port conflicts detected with existing services
- Container status: Running and healthy
