# Frigate NVR - AI-Powered Network Video Recorder

## Overview

Frigate is an open-source AI-powered Network Video Recorder with real-time local object detection for IP cameras. It uses machine learning to identify people, vehicles, and other objects, providing intelligent motion detection and event recording.

**Deployment Location**: Docker VM (192.168.1.20, VMID 111)
**Installation Date**: 2025-10-08
**Status**: ✅ Running
**GPU Configuration**: ⚠️ Configured (AMD VAAPI) but not actively utilized

## Service Details

### Access Information
- **Web Interface**: http://192.168.1.20:5000
- **Container Name**: `frigate`
- **Image**: `ghcr.io/blakeblackshear/frigate:stable`
- **Restart Policy**: `unless-stopped`
- **Default Credentials**: `admin` / `f599aed8ff37ef87f1be4671211d9c05` (change after first login)

### Port Configuration
| Port | Protocol | Purpose | External Access |
|------|----------|---------|----------------|
| **5000** | TCP | Web UI & API | 0.0.0.0:5000 |
| **8554** | TCP | RTSP Restreaming | 0.0.0.0:8554 |
| **8555** | TCP/UDP | WebRTC | 0.0.0.0:8555 |

### Volume Mappings
```yaml
volumes:
  - /root/frigate/config:/config           # Configuration files
  - /root/frigate/storage:/media/frigate   # Recording storage
  - tmpfs:/tmp/cache                       # Temporary cache (1GB)
```

#### Storage Locations
- **Configuration**: `/root/frigate/config` - YAML configuration and database
- **Recording Storage**: `/root/frigate/storage` - Video recordings and snapshots
- **Temporary Cache**: tmpfs (1GB in-memory) - Frame processing and detection cache

## Key Features

### AI Object Detection
- **Real-time Detection**: Uses CPU-based TensorFlow Lite for object detection
- **Supported Objects**: Person, vehicle, bicycle, dog, cat, and 75+ COCO objects
- **Zones**: Define specific areas for detection and filtering
- **Masks**: Exclude areas from detection (e.g., timestamps, logos)

### Video Recording
- **24/7 Recording**: Continuous recording with configurable retention
- **Event Recording**: Motion-triggered recording with AI object filtering
- **Snapshot Generation**: Automatic snapshot capture on detection events
- **Timeline View**: Easy navigation through recordings and events

### Advanced Features
- **Motion Detection**: Hardware-accelerated motion detection
- **Object Tracking**: Multi-object tracking across video frames
- **Notifications**: MQTT, webhook, and third-party integrations
- **API Access**: RESTful API for automation and custom integrations
- **RTSP Restreaming**: Share camera streams to other devices
- **Mobile App**: Companion mobile app for iOS and Android

## Configuration

### Docker Compose
Located at: `/root/frigate/docker-compose.yml`

```yaml
version: "3.9"
services:
  frigate:
    container_name: frigate
    restart: unless-stopped
    image: ghcr.io/blakeblackshear/frigate:stable
    privileged: false
    shm_size: "256mb"
    devices:
      - /dev/dri/renderD128:/dev/dri/renderD128
      - /dev/dri/card0:/dev/dri/card0
    group_add:
      - "44"   # video group
      - "104"  # render group
    volumes:
      - /root/frigate/config:/config
      - /root/frigate/storage:/media/frigate
      - type: tmpfs
        target: /tmp/cache
        tmpfs:
          size: 1000000000
    ports:
      - "5000:5000"
      - "8554:8554"
      - "8555:8555/tcp"
      - "8555:8555/udp"
    environment:
      - TZ=America/Los_Angeles
      - LIBVA_DRIVER_NAME=radeonsi
      - FRIGATE_RTSP_PASSWORD=password
```

### Frigate Configuration
Located at: `/root/frigate/config/config.yml`

```yaml
mqtt:
  enabled: false

detectors:
  default:
    type: cpu

ffmpeg:
  hwaccel_args: preset-vaapi

cameras:
  front:
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://admin:jklqsd1970@192.168.1.81:554/h265Preview_01_main
          roles:
            - detect
            - record
    detect:
      enabled: true
      width: 1280
      height: 720
      fps: 5
    record:
      enabled: true
      retain:
        days: 7
        mode: motion

  garage:
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://admin:jklqsd1970@192.168.1.82:554/h265Preview_01_main
          roles:
            - detect
            - record
    detect:
      enabled: true
      width: 1280
      height: 720
      fps: 5
    record:
      enabled: true
      retain:
        days: 7
        mode: motion
```

### Environment Variables
- **TZ**: `America/Los_Angeles` - Timezone for event timestamps
- **LIBVA_DRIVER_NAME**: `radeonsi` - AMD VAAPI driver for hardware acceleration
- **FRIGATE_RTSP_PASSWORD**: Password for RTSP restreaming authentication

## GPU Acceleration

### Hardware Configuration
**Hardware**: AMD Renoir integrated GPU
**Status**: ⚠️ Configured but not actively utilized

The container has GPU access configured via `/dev/dri` device passthrough:
- **Device**: `/dev/dri/card0` and `/dev/dri/renderD128` passed through to container
- **Groups**: Container runs with `video` (GID 44) and `render` (GID 104) group permissions
- **LXC Passthrough**: AMD GPU passed from Proxmox host (pve2) to LXC container 111
- **VAAPI Configuration**: FFmpeg configured with `preset-vaapi` hardware acceleration

### Current Performance
Despite VAAPI configuration, GPU utilization remains at 0%. This is a known issue with AMD VAAPI on NVR platforms:

- **CPU Usage**: ~80-86% (Frigate container) for 2 cameras @ 720p/5fps
- **GPU Usage**: 0% (hardware acceleration not engaging)
- **Memory**: ~900MB for container
- **FFmpeg Flags**: Processes show VAAPI hwaccel flags but GPU remains idle

### Known AMD VAAPI Limitations
Community reports indicate challenges with AMD VAAPI and Frigate:
- FFmpeg processes show VAAPI flags but GPU decoder shows 0% usage
- CPU usage remains high (20-30% per camera) despite configuration
- CPU cores boost under load indicating software decoding/encoding
- This appears to be a platform limitation rather than configuration issue

### Verify GPU Access
```bash
# Check GPU devices inside container
ssh root@192.168.1.20 'docker exec frigate ls -la /dev/dri/'

# Expected output:
# crw-rw---- 1 root video  226,   0 card0
# crw-rw---- 1 root render 226, 128 renderD128

# Check FFmpeg hardware acceleration flags
ssh root@192.168.1.20 'docker exec frigate ps aux | grep ffmpeg'

# Monitor GPU usage
ssh root@192.168.1.20 'cat /sys/class/drm/card0/device/gpu_busy_percent'
```

## Camera Configuration

### Active Cameras
| Camera Name | IP Address | Resolution | FPS | RTSP Stream |
|-------------|-----------|------------|-----|-------------|
| **Front** | 192.168.1.81 | 1280x720 | 5 | rtsp://admin:***@192.168.1.81:554/h265Preview_01_main |
| **Garage** | 192.168.1.82 | 1280x720 | 5 | rtsp://admin:***@192.168.1.82:554/h265Preview_01_main |

### Adding New Cameras
1. Edit `/root/frigate/config/config.yml` on Docker host
2. Add camera configuration under `cameras:` section:
```yaml
cameras:
  camera_name:
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://username:password@camera_ip:554/stream_path
          roles:
            - detect
            - record
    detect:
      enabled: true
      width: 1920
      height: 1080
      fps: 5
    record:
      enabled: true
      retain:
        days: 7
        mode: motion
```
3. Restart Frigate container:
```bash
ssh root@192.168.1.20 'cd /root/frigate && docker compose restart'
```

### RTSP Stream URLs
**Reolink Camera Formats**:
- **Main Stream (H.265)**: `rtsp://admin:password@camera_ip:554/h265Preview_01_main`
- **Sub Stream (H.264)**: `rtsp://admin:password@camera_ip:554/h264Preview_01_sub`

**Other Common Formats**:
- **Hikvision**: `rtsp://admin:password@camera_ip:554/Streaming/Channels/101`
- **Dahua**: `rtsp://admin:password@camera_ip:554/cam/realmonitor?channel=1&subtype=0`
- **Amcrest**: `rtsp://admin:password@camera_ip:554/cam/realmonitor?channel=1&subtype=1`

## Management Operations

### Container Management
```bash
# Check container status
ssh root@192.168.1.20 'docker ps | grep frigate'

# View container logs
ssh root@192.168.1.20 'docker logs frigate'

# Follow logs in real-time
ssh root@192.168.1.20 'docker logs -f frigate'

# Restart container
ssh root@192.168.1.20 'cd /root/frigate && docker compose restart'

# Stop container
ssh root@192.168.1.20 'cd /root/frigate && docker compose stop'

# Start container
ssh root@192.168.1.20 'cd /root/frigate && docker compose up -d'

# Recreate container (configuration changes)
ssh root@192.168.1.20 'cd /root/frigate && docker compose down && docker compose up -d'
```

### Configuration Reload
```bash
# Reload configuration without container restart
curl -X POST http://192.168.1.20:5000/api/config/reload

# Check configuration validity
ssh root@192.168.1.20 'docker exec frigate frigate config validate'
```

### Update Container
```bash
# Pull latest image and recreate container
ssh root@192.168.1.20 'cd /root/frigate && docker compose pull && docker compose up -d'
```

## Storage Management

### Recording Storage
Video recordings are stored in `/root/frigate/storage/` with automatic cleanup based on retention policies:

```bash
# Check storage usage
ssh root@192.168.1.20 'du -sh /root/frigate/storage/'

# Check recordings by camera
ssh root@192.168.1.20 'du -sh /root/frigate/storage/recordings/*'

# Check snapshot storage
ssh root@192.168.1.20 'du -sh /root/frigate/storage/snapshots/'
```

### Retention Configuration
Configure in `/root/frigate/config/config.yml`:
```yaml
record:
  enabled: true
  retain:
    days: 7          # Keep recordings for 7 days
    mode: motion     # Only keep motion events (or "all" for continuous)
  events:
    retain:
      default: 10    # Keep event clips for 10 days
      mode: motion
```

### Manual Cleanup
```bash
# Remove recordings older than 30 days
ssh root@192.168.1.20 'find /root/frigate/storage/recordings/ -type f -mtime +30 -delete'

# Clear all snapshots
ssh root@192.168.1.20 'rm -rf /root/frigate/storage/snapshots/*'
```

## API Usage

### REST API Endpoints
```bash
# Get events from last hour
curl http://192.168.1.20:5000/api/events?limit=100&has_snapshot=1

# Get camera statistics
curl http://192.168.1.20:5000/api/stats

# Get latest snapshot for camera
curl http://192.168.1.20:5000/api/front/latest.jpg -o snapshot.jpg

# Get configuration
curl http://192.168.1.20:5000/api/config
```

### RTSP Restreaming
Access restreamed cameras:
```bash
# Camera RTSP restream URL
rtsp://192.168.1.20:8554/front
rtsp://192.168.1.20:8554/garage

# Test with VLC or ffplay
ffplay rtsp://192.168.1.20:8554/front
```

## Troubleshooting

### Container Won't Start
```bash
# Check container logs for errors
ssh root@192.168.1.20 'docker logs frigate'

# Verify configuration syntax
ssh root@192.168.1.20 'docker exec frigate frigate config validate'

# Check volume permissions
ssh root@192.168.1.20 'ls -la /root/frigate/'
```

### Camera Not Connecting
```bash
# Test RTSP stream directly
ffplay rtsp://admin:password@192.168.1.81:554/h265Preview_01_main

# Check Frigate logs for specific camera
ssh root@192.168.1.20 'docker logs frigate 2>&1 | grep "front"'

# Verify camera network connectivity
ping 192.168.1.81
```

### High CPU Usage
- **Current Behavior**: 80-86% CPU with 2 cameras is expected due to AMD VAAPI limitations
- **Optimization Options**:
  1. Lower detection FPS (5fps → 3fps)
  2. Reduce detection resolution
  3. Use substreams for detection
  4. Disable detection for less critical cameras
  5. Consider Intel QuickSync hardware (better Linux support)

```yaml
# Example optimization: Use substream for detection
cameras:
  front:
    ffmpeg:
      inputs:
        - path: rtsp://admin:password@192.168.1.81:554/h264Preview_01_sub
          roles:
            - detect
        - path: rtsp://admin:password@192.168.1.81:554/h265Preview_01_main
          roles:
            - record
```

### Object Detection Issues
```bash
# Check detection statistics
curl http://192.168.1.20:5000/api/stats | jq '.cameras.front.detection_fps'

# View recent detections
curl http://192.168.1.20:5000/api/events?limit=10

# Adjust detection sensitivity in config.yml
cameras:
  front:
    detect:
      threshold: 0.7  # Higher = fewer false positives (default 0.5)
```

### Storage Full
```bash
# Check disk space
ssh root@192.168.1.20 'df -h'

# Reduce retention period in config.yml
record:
  retain:
    days: 3  # Reduce from 7 to 3 days

# Manually clear old recordings
ssh root@192.168.1.20 'find /root/frigate/storage/recordings/ -type f -mtime +7 -delete'
```

## Backup and Recovery

### Configuration Backup
```bash
# Backup configuration
ssh root@192.168.1.20 'tar -czf frigate-config-$(date +%Y%m%d).tar.gz /root/frigate/config/'

# Backup docker-compose.yml
ssh root@192.168.1.20 'cp /root/frigate/docker-compose.yml /root/frigate/docker-compose.yml.bak'
```

### Database Backup
```bash
# Backup Frigate database
ssh root@192.168.1.20 'cp /root/frigate/config/frigate.db /root/frigate/config/frigate.db.bak'
```

### Restore Configuration
```bash
# Restore from backup
ssh root@192.168.1.20 'tar -xzf frigate-config-20251008.tar.gz -C /'

# Restart container
ssh root@192.168.1.20 'cd /root/frigate && docker compose restart'
```

### Critical Recording Backup
For important events, configure external backup to NAS:
```bash
# Copy recordings to OMV NAS
ssh root@192.168.1.20 'rsync -av /root/frigate/storage/ root@192.168.1.9:/srv/raid/frigate-backups/'
```

## Monitoring and Alerts

### Uptime Kuma Integration
Add Frigate to Uptime Kuma monitoring:
1. Navigate to http://192.168.1.9:3010
2. Add monitor:
   - **Type**: HTTP(s)
   - **Name**: Frigate NVR
   - **URL**: http://192.168.1.20:5000
   - **Interval**: 60 seconds
   - **Max Retry**: 3

### Health Check
```bash
# Test web interface availability
curl -s -o /dev/null -w "%{http_code}" http://192.168.1.20:5000
# Expected: 200

# Check container health
ssh root@192.168.1.20 'docker inspect frigate --format="{{.State.Status}}"'
# Expected: running

# Check API health
curl http://192.168.1.20:5000/api/stats | jq '.service.version'
```

### Performance Monitoring
```bash
# Container resource usage
ssh root@192.168.1.20 'docker stats --no-stream frigate'

# Detection performance
curl http://192.168.1.20:5000/api/stats | jq '{cameras: .cameras | map_values({detection_fps, process_fps, camera_fps})}'

# Storage usage trends
ssh root@192.168.1.20 'df -h /root/frigate/storage'
```

## Performance Considerations

### Resource Usage (Current)
- **CPU**: ~80-86% for 2 cameras @ 720p/5fps (software decoding)
- **Memory**: ~900MB container usage
- **GPU**: 0% (VAAPI configured but not utilized)
- **Disk I/O**: Moderate during recording, high during event scrubbing
- **Network**: ~5-10 Mbps per H.265 camera stream

### Optimization Strategies

#### 1. Detection FPS Reduction
```yaml
cameras:
  front:
    detect:
      fps: 3  # Reduce from 5 to 3 fps (40% less processing)
```

#### 2. Use Substreams for Detection
```yaml
cameras:
  front:
    ffmpeg:
      inputs:
        - path: rtsp://admin:password@192.168.1.81:554/h264Preview_01_sub  # Lower res
          roles: [detect]
        - path: rtsp://admin:password@192.168.1.81:554/h265Preview_01_main # High res
          roles: [record]
```

#### 3. Adjust Detection Resolution
```yaml
cameras:
  front:
    detect:
      width: 640   # Reduce from 1280
      height: 480  # Reduce from 720
```

#### 4. Define Detection Zones
```yaml
cameras:
  front:
    zones:
      driveway:
        coordinates: 100,100,500,100,500,400,100,400
    objects:
      filters:
        person:
          mask: 0,0,100,0,100,720,0,720  # Exclude areas
```

### Scaling Guidelines
- **Per Camera Impact**: ~40% CPU usage per 720p/5fps camera
- **Recommended Max**: 3-4 cameras at current settings on this hardware
- **Hardware Upgrade Path**: Consider Intel NUC with QuickSync for better GPU support

## Security Recommendations

### Authentication
- **Change Default Password**: Immediately change default admin password after first login
- **Web Interface**: Frigate uses basic authentication for API and web interface
- **RTSP Streams**: Authenticated with FRIGATE_RTSP_PASSWORD environment variable

### Network Security
- **Internal Access Only**: Keep Frigate on internal network (192.168.1.0/24)
- **Reverse Proxy**: Use Nginx Proxy Manager for external access with SSL
- **VPN Access**: Use WireGuard/OpenVPN for remote access instead of port forwarding
- **Camera Isolation**: Place cameras on isolated VLAN if possible

### Regular Maintenance
- Update Frigate regularly: `docker compose pull && docker compose up -d`
- Review event logs for anomalies
- Monitor storage usage to prevent disk exhaustion
- Backup configuration before major updates

## Integration Options

### Home Assistant
```yaml
# configuration.yaml
frigate:
  host: 192.168.1.20
  port: 5000
```

### MQTT (Optional)
Enable MQTT in `config.yml` for advanced integrations:
```yaml
mqtt:
  enabled: true
  host: 192.168.1.x
  user: frigate
  password: password
```

### Notifications
Use webhooks for custom notifications:
```yaml
cameras:
  front:
    review:
      alerts:
        required_zones: []
      detections:
        required_zones: []
```

## Related Infrastructure

### Docker VM (192.168.1.20)
- **Platform**: Debian-based LXC container on Proxmox
- **Resources**: 12 CPU cores, 10GB RAM, 60GB storage
- **Network**: 192.168.1.20/24 via vmbr0 (LAN bridge)
- **Other Services**: Supabase, n8n, Netdata, Portainer, iSpy Agent DVR (stopped)

### Network Path
```
Cameras → [Switch] → [OPNsense Firewall] → [Docker VM] → Frigate NVR
```

### Camera Network
- **Front Camera**: 192.168.1.81 (Reolink, H.265)
- **Garage Camera**: 192.168.1.82 (Reolink, H.265)
- **Network**: All cameras on same LAN subnet

## Support and Documentation

### Official Resources
- **Website**: https://frigate.video
- **Documentation**: https://docs.frigate.video
- **GitHub**: https://github.com/blakeblackshear/frigate
- **Docker Hub**: https://hub.docker.com/r/blakeblackshear/frigate

### Community Support
- **Discord**: Frigate Community Server
- **GitHub Discussions**: https://github.com/blakeblackshear/frigate/discussions
- **Reddit**: r/frigate_nvr

## Change Log

### 2025-10-08 - Initial Deployment
- ✅ Deployed Frigate NVR on Docker VM (192.168.1.20)
- ✅ Configured AMD Renoir GPU passthrough with VAAPI support
- ✅ Added two cameras: Front (192.168.1.81) and Garage (192.168.1.82)
- ✅ Configured 720p @ 5fps detection with 7-day retention
- ✅ Container status: Running and healthy
- ⚠️ GPU acceleration configured but not actively utilized (known AMD VAAPI limitation)
- 📊 Performance: ~82% CPU usage for 2 cameras (software decoding)
- 🔐 Default admin credentials created (change recommended)

### iSpy Agent DVR Migration
- **Reason**: iSpy Agent DVR GPU acceleration non-functional despite correct configuration
- **Status**: iSpy container stopped (not deleted) at `/root/ispyagentdvr/`
- **Alternative**: Frigate provides better AI detection and open-source flexibility
- **Port Reallocation**: Port 8090 (iSpy) freed, Frigate using port 5000
