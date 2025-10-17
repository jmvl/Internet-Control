# Docker Containers Overview - OMV Server

## Container Infrastructure Summary

The infrastructure runs Docker containers across two primary hosts:
- **OMV NAS Server (192.168.1.9)**: Media management, monitoring, and custom applications
- **Docker VM (192.168.1.20)**: Development tools, database interfaces, and workflow automation

## Active Containers

### OMV NAS Server (192.168.1.9)

| Container Name | Image | Status | Ports | Purpose | Documentation |
|----------------|-------|--------|-------|---------|---------------|
| **immich_server** | ghcr.io/immich-app/immich-server:v1.141.1 | ✅ Healthy | 2283:2283 | Photo/video management | [📁 immich/](immich/) |
| **immich_machine_learning** | ghcr.io/immich-app/immich-machine-learning:v1.141.1 | ✅ Healthy | Internal | AI photo recognition | [📁 immich/](immich/) |
| **immich_postgres** | tensorchord/pgvecto-rs:pg14-v0.2.0 | ⚠️ Unhealthy* | 5432 (internal) | Database with vector search | [📁 immich/](immich/) |
| **immich_redis** | redis:6.2-alpine | ✅ Healthy | 6379 (internal) | Cache and sessions | [📁 immich/](immich/) |
| **calibre-web** | lscr.io/linuxserver/calibre-web:latest | ✅ Running | 8083:8083 | E-book library management | [📁 calibre/](calibre/) |
| **uptime-kuma** | louislam/uptime-kuma:1 | ✅ Healthy | 3010:3001 | Service monitoring | [📁 uptime-kuma/](uptime-kuma/) |
| **portainer** | portainer/portainer-ce:latest | ✅ Running | 8000:8000, 9443:9443 | Container management | [📁 portainer/](portainer/) |
| **portainer_agent** | portainer/agent:latest | ✅ Running | 9001:9001 | Container monitoring | [📁 portainer/](portainer/) |
| **nginx-proxy-manager** | jc21/nginx-proxy-manager:latest | ✅ Running | 80:80, 81:81, 443:443 | Reverse proxy & SSL | [📁 nginx-proxy-manager/](nginx-proxy-manager/) |
| **WeddingShare** | cirx08/wedding_share:latest | ✅ Running | 8080:5000 | Photo gallery app | [📁 wedding-share/](wedding-share/) |

*PostgreSQL shows "unhealthy" status but is fully functional

### Docker VM (192.168.1.20)

| Container Name | Image | Status | Ports | Purpose | Documentation |
|----------------|-------|--------|-------|---------|---------------|
| **mathesar_service** | mathesar/mathesar:latest | ✅ Healthy | 8080:8000* | PostgreSQL web interface | [📁 mathesar/](mathesar/) |
| **mathesar_db** | pgautoupgrade/pgautoupgrade:17-bookworm | ✅ Healthy | 5432 (internal) | Database for Mathesar | [📁 mathesar/](mathesar/) |
| **caddy-reverse-proxy** | mathesar/mathesar-caddy:latest | ⚠️ Bypassed | 443:443 (unused) | Web server (HTTPS issues) | [📁 mathesar/](mathesar/) |
| **supabase-db** | supabase/postgres:15.8.1 | ✅ Healthy | 5432:5432 | Supabase PostgreSQL | [📁 Supabase/](Supabase/) |
| **supabase-kong** | kong:2.8.1 | ✅ Healthy | 8000:8000, 8443:8443 | API Gateway | [📁 Supabase/](Supabase/) |
| **supabase-auth** | supabase/gotrue:v2.158.1 | ✅ Healthy | Internal | Authentication service | [📁 Supabase/](Supabase/) |
| **supabase-rest** | postgrest/postgrest:v12.2.0 | ✅ Running | 3000 (internal) | REST API for PostgreSQL | [📁 Supabase/](Supabase/) |
| **supabase-storage** | supabase/storage-api:v1.11.1 | ✅ Healthy | 5000 (internal) | File storage service | [📁 Supabase/](Supabase/) |
| **n8n** | n8nio/n8n:latest | ✅ Running | 5678:5678 | Workflow automation | - |
| **netdata** | netdata/netdata:latest | ✅ Healthy | 19999:19999 | System monitoring | [📁 netdata/](netdata/) |
| **frigate** | ghcr.io/blakeblackshear/frigate:stable | ✅ Running | 5000:5000, 8554:8554, 8555:8555 | AI-powered NVR | [📁 docker/frigate.md](docker/frigate.md) |
| **ispyagentdvr** | doitandbedone/ispyagentdvr:latest | ⏸️ Stopped | 8090:8090* | Network video recording (replaced by Frigate) | [📁 docker/ispyagentdvr.md](docker/ispyagentdvr.md) |
| **portainer** | portainer/portainer-ce:latest | ✅ Running | 8000:8000, 9443:9443 | Container management | [📁 portainer/](portainer/) |

*Direct service access (bypassing Caddy proxy)

## Stopped/Inactive Containers

| Container | Last Status | Purpose | Notes |
|-----------|-------------|---------|-------|
| **wallabag-redis-1** | Exited (137) | Cache for Wallabag | Part of Wallabag stack |
| **wallabag** (stack) | Stopped | Read-later web app | MariaDB issues |
| **syncthing** | Not running | File synchronization | Available but not active |

## Service Categories

### 🖼️ Media Management
- **Immich Stack** (4 containers): AI-powered photo and video management
- **Calibre-Web**: E-book library with web interface
- **Wedding Share**: Custom photo gallery for events

### 🔧 Infrastructure Management  
- **Portainer + Agent**: Docker container management GUI
- **Nginx Proxy Manager**: Reverse proxy with SSL automation
- **Uptime Kuma**: Service monitoring and alerting

### 💾 Data Services
- **PostgreSQL**: Primary database for Immich
- **Redis**: Caching layer for applications

## Network Architecture

### Port Allocation
| Port | Service | Access Type | Purpose |
|------|---------|-------------|---------|
| **80** | Nginx Proxy Manager | Public | HTTP traffic routing |
| **443** | Nginx Proxy Manager | Public | HTTPS traffic routing |
| **81** | Nginx Proxy Manager | Internal | Admin interface |
| **2283** | Immich | Internal/Proxy | Photo management interface |
| **3010** | Uptime Kuma | Internal | Monitoring dashboard |
| **3478** | iSpy Agent DVR | Internal | STUN for WebRTC (UDP) - inactive |
| **5000** | Frigate | Internal | AI NVR web UI |
| **5678** | n8n | Internal | Workflow automation |
| **8000** | Portainer | Internal | Container management (HTTP) |
| **8080** | Wedding Share | Internal | Photo gallery |
| **8083** | Calibre-Web | Internal | E-book library |
| **8090** | iSpy Agent DVR | Internal | Video surveillance - inactive |
| **8554** | Frigate | Internal | RTSP restreaming |
| **8555** | Frigate | Internal | WebRTC (TCP/UDP) |
| **9001** | Portainer Agent | Internal | Container monitoring |
| **9443** | Portainer | Internal | Container management (HTTPS) |
| **19999** | Netdata | Internal | System monitoring |
| **50000-50100** | iSpy Agent DVR | Internal | TURN for WebRTC (UDP) |

### Network Bridges
- **immich_default**: Immich stack networking
- **nginx-proxy-manager_default**: Reverse proxy network
- **uptime-kuma_default**: Monitoring network
- **bridge**: Default Docker network

## Storage Configuration

### Volume Management
| Service | Volume Type | Host Path | Purpose |
|---------|-------------|-----------|---------|
| **Immich** | Bind Mount | `/srv/raid/immich-lib/` | Photo library and database |
| **Calibre-Web** | Bind Mount | `/srv/raid/Calibre/` | E-book library |
| **Portainer** | Docker Volume | `portainer_data` | Configuration data |
| **Uptime Kuma** | Docker Volume | `uptime-kuma_uptime-kuma` | Monitoring data |
| **NPM** | Docker Volume | Various | Proxy configs and certs |

### Storage Locations
- **Primary Storage**: `/srv/raid/` (BTRFS RAID mirror)
- **Docker Volumes**: `/srv/docker-volume/volumes/`
- **Container Data**: Persistent across container recreations

## Resource Usage Summary

### Memory Allocation (Approximate)
- **Immich Stack**: ~1.5GB (server + ML + DB + Redis)
- **Nginx Proxy Manager**: ~100-200MB
- **Portainer**: ~50-100MB
- **Uptime Kuma**: ~100-150MB  
- **Calibre-Web**: ~50-100MB
- **Wedding Share**: ~50-100MB
- **Total**: ~2-2.5GB RAM usage

### CPU Usage
- **Low**: Proxy, monitoring, management containers
- **Medium**: Database operations, web interfaces
- **High**: ML processing (Immich), image conversion (Calibre)

## Management and Monitoring

### Container Management
- **Primary**: Portainer web interface (https://192.168.1.9:9443)
- **CLI**: Direct Docker commands on OMV host
- **Compose**: Docker Compose files via Portainer stacks

### Health Monitoring
- **Uptime Kuma**: Monitors all web interfaces
- **Docker Health Checks**: Built-in container health monitoring
- **Log Monitoring**: Centralized logging via Docker logs

### Update Management
- **Automated**: Containers with `unless-stopped` restart policy
- **Manual**: Pull latest images and recreate containers
- **Staged**: Test updates on non-critical services first

## Security Overview

### Network Security
- **Internal Access**: All services on private LAN
- **Reverse Proxy**: NPM provides secure external access
- **SSL Certificates**: Automated Let's Encrypt certificates
- **Access Control**: IP-based restrictions where needed

### Container Security
- **User Privileges**: Containers run as non-root users where possible
- **Volume Permissions**: Proper file ownership and permissions
- **Network Isolation**: Services isolated in separate networks
- **Regular Updates**: Keep container images updated

## Backup Strategy

### Data Backup
- **Storage**: BTRFS RAID mirror provides redundancy
- **Application Data**: Docker volumes included in backup procedures
- **Databases**: Automated database backups (Immich, Uptime Kuma)
- **Configurations**: Container configurations and compose files

### Disaster Recovery
- **Container Recreation**: Documented procedures for each service
- **Data Restoration**: Volume backup and restore procedures
- **Configuration Backup**: Compose files and environment variables
- **Testing**: Regular backup testing and validation

## Future Expansion

### Planned Additions
- **Wallabag**: Fix MariaDB issues and restart stack
- **Syncthing**: Activate file synchronization if needed
- **Additional Monitoring**: Grafana/Prometheus stack
- **Media Services**: Jellyfin or Plex media server

### Scalability Considerations
- **Resource Monitoring**: Watch CPU and memory usage trends
- **Storage Growth**: Monitor storage usage and expansion needs
- **Network Performance**: Consider gigabit network limitations
- **Service Dependencies**: Plan for service interdependencies

## Documentation Status

### ✅ Complete Documentation
- [📁 Immich](immich/) - Photo management platform
- [📁 Calibre](calibre/) - E-book library management
- [📁 Portainer](portainer/) - Docker management platform
- [📁 Uptime Kuma](uptime-kuma/) - Service monitoring
- [📁 Nginx Proxy Manager](nginx-proxy-manager/) - Reverse proxy
- [📁 Wedding Share](wedding-share/) - Photo gallery application
- [📁 Mathesar](mathesar/) - PostgreSQL web interface

### 📝 Existing Documentation
- [📁 Netdata](netdata/) - System monitoring (Docker VM)

### 🔄 To Be Updated
- Wallabag stack documentation (when service is restored)
- Syncthing documentation (when activated)

This container ecosystem provides a comprehensive self-hosted infrastructure with photo management, monitoring, reverse proxy capabilities, and custom applications, all running efficiently on the OMV NAS platform.