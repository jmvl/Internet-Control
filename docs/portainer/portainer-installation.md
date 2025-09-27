# Portainer Docker Management Platform

## Overview
Portainer provides a web-based GUI for managing Docker containers, images, networks, and volumes on the OMV NAS server. It consists of two components: the main Portainer CE server and a Portainer Agent for container management.

## System Information
- **Host**: OpenMediaVault NAS (192.168.1.9)
- **Main Interface**: http://192.168.1.9:9443 (HTTPS)
- **HTTP Interface**: http://192.168.1.9:8000
- **Agent Port**: 9001
- **Installation Method**: Standalone Docker containers

## Container Architecture

### Portainer CE Server
| Component | Value | Purpose |
|-----------|-------|---------|
| **Container Name** | portainer | Main management server |
| **Image** | portainer/portainer-ce:latest | Community Edition |
| **Web Interface** | 8000 (HTTP), 9443 (HTTPS) | Management interface |
| **Data Persistence** | portainer_data volume | Configuration and data |
| **Docker Socket** | /var/run/docker.sock | Docker API access |

### Portainer Agent
| Component | Value | Purpose |
|-----------|-------|---------|
| **Container Name** | portainer_agent | Container monitoring agent |
| **Image** | portainer/agent:latest | Lightweight agent |
| **Port** | 9001 | Agent communication |
| **Docker Socket** | /var/run/docker.sock | Container monitoring |

## Current Configuration

### Volume Mounts - Portainer Server
```
Host Path: /var/run/docker.sock → Container: /var/run/docker.sock
Docker Volume: portainer_data → Container: /data
```

### Volume Mounts - Portainer Agent
```
Host Path: /var/run/docker.sock → Container: /var/run/docker.sock
Host Path: /var/lib/docker/volumes → Container: /var/lib/docker/volumes
Host Path: / → Container: /host (read-only)
```

### Port Bindings
- **8000/tcp**: HTTP web interface
- **9443/tcp**: HTTPS web interface  
- **9001/tcp**: Agent communication port
- **9000/tcp**: Internal port (not exposed)

## Managed Containers

Portainer currently manages these container stacks:
- **Immich** (Photo management) - 4 containers
- **Calibre-Web** (E-book library) - 1 container  
- **Nginx Proxy Manager** - 1 container
- **Uptime Kuma** (Monitoring) - 1 container
- **Wedding Share** (Custom app) - 1 container
- **Wallabag** (Read-later, stopped) - 3 containers
- **Syncthing** (File sync, stopped) - 1 container

## Features and Capabilities

### Container Management
- **Container Lifecycle**: Start, stop, restart, remove containers
- **Resource Monitoring**: CPU, memory, network usage
- **Log Viewing**: Real-time and historical container logs
- **Console Access**: Interactive terminal access to containers
- **Health Monitoring**: Container health status tracking

### Stack Management
- **Docker Compose**: Deploy and manage multi-container stacks
- **Template Library**: Pre-configured application templates
- **Stack Updates**: Update entire application stacks
- **Environment Variables**: Manage container configurations

### Image Management
- **Image Registry**: Pull images from Docker Hub and other registries
- **Local Images**: Manage locally built and cached images
- **Image Scanning**: Security vulnerability scanning
- **Cleanup Tools**: Remove unused images and containers

### Network Management
- **Network Creation**: Create custom Docker networks
- **Network Inspection**: View network configurations and connections
- **Bridge Networks**: Manage bridge network settings
- **Container Networking**: Connect containers to networks

### Volume Management
- **Volume Creation**: Create and manage Docker volumes
- **Backup/Restore**: Volume backup and restoration
- **Volume Inspection**: View volume usage and mount points
- **Cleanup Tools**: Remove unused volumes

## Access and Authentication

### Web Interface Access
- **Primary URL**: https://192.168.1.9:9443
- **Alternative URL**: http://192.168.1.9:8000
- **Authentication**: Username/password authentication
- **User Roles**: Admin, Standard, Read-only access levels
- **Session Management**: Configurable session timeouts

### Security Features
- **HTTPS Support**: SSL/TLS encrypted web interface
- **User Management**: Multiple user accounts with role-based access
- **API Security**: Secure API endpoints for automation
- **Docker Socket Security**: Controlled access to Docker daemon

## Maintenance Operations

### Container Updates
```bash
# Update Portainer server
docker pull portainer/portainer-ce:latest
docker stop portainer
docker rm portainer
docker run -d --name portainer --restart always \
  -p 8000:8000 -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# Update Portainer agent
docker pull portainer/agent:latest
docker stop portainer_agent
docker rm portainer_agent
docker run -d --name portainer_agent --restart always \
  -p 9001:9001 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  -v /:/host:ro \
  portainer/agent:latest
```

### Backup Procedures
```bash
# Backup Portainer data volume
docker run --rm \
  -v portainer_data:/source:ro \
  -v /srv/raid/backups:/backup \
  alpine tar czf /backup/portainer-data-$(date +%Y%m%d).tar.gz -C /source .

# Restore Portainer data
docker run --rm \
  -v portainer_data:/target \
  -v /srv/raid/backups:/backup \
  alpine tar xzf /backup/portainer-data-YYYYMMDD.tar.gz -C /target
```

### Log Management
```bash
# View Portainer server logs
docker logs portainer --tail 100

# View Portainer agent logs
docker logs portainer_agent --tail 100

# Monitor real-time logs
docker logs portainer -f
```

## Performance and Monitoring

### Resource Usage
- **Portainer Server**: ~50-100MB RAM, low CPU usage
- **Portainer Agent**: ~20-30MB RAM, minimal CPU usage
- **Storage**: Data volume stores configurations and cached data
- **Network**: Low bandwidth usage except during image pulls

### Health Monitoring
- **Container Health**: Both containers report healthy status
- **Web Interface**: Responsive performance on gigabit network
- **Agent Connectivity**: Reliable communication with main server
- **Database**: SQLite database for configuration storage

## Integration with Infrastructure

### Network Integration
- **Internal Access**: Available on LAN via 192.168.1.9
- **Proxy Support**: Can be configured behind Nginx Proxy Manager
- **SSL Termination**: Built-in HTTPS support with self-signed certificates
- **API Access**: REST API for automation and external integrations

### Monitoring Integration
- **Uptime Kuma**: Monitor Portainer web interface availability
- **Log Aggregation**: Container logs accessible via Portainer interface
- **Alerting**: Configure alerts for container failures
- **Metrics**: Export Docker metrics for external monitoring systems

### Backup Integration
- **Volume Backup**: Include in regular backup procedures
- **Configuration Export**: Export stack configurations
- **Container Image Backup**: Local image storage and backup
- **Disaster Recovery**: Procedures for complete system rebuild

## Security Considerations

### Access Control
- **Authentication Required**: All access requires login
- **Role-Based Access**: Different permission levels for users
- **Session Security**: Configurable session timeouts
- **API Security**: Secure API tokens for external access

### Docker Socket Security
- **Direct Access**: Both containers have full Docker socket access
- **Privilege Escalation**: Can create privileged containers
- **Network Access**: Can modify container networking
- **Volume Access**: Can access all Docker volumes

### Best Practices
- **Regular Updates**: Keep Portainer updated for security patches
- **User Management**: Use separate accounts for different users
- **SSL Certificates**: Consider proper SSL certificates for production
- **Network Security**: Restrict access to management ports

## Troubleshooting

### Common Issues
1. **Web Interface Not Accessible**: Check container status and port bindings
2. **Agent Not Connecting**: Verify agent container is running on correct port
3. **Permission Errors**: Ensure Docker socket access permissions
4. **Stack Deployment Failures**: Check Docker Compose syntax and dependencies

### Diagnostic Commands
```bash
# Check Portainer status
docker ps | grep portainer

# Test web interface connectivity
curl -k https://192.168.1.9:9443
curl http://192.168.1.9:8000

# Check agent connectivity
curl http://192.168.1.9:9001

# Verify Docker socket access
docker exec portainer ls -la /var/run/docker.sock
```

This Portainer installation provides comprehensive Docker container management capabilities with a user-friendly web interface for the entire OMV infrastructure.