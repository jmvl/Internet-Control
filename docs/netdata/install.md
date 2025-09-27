# Netdata Installation Guide

## Overview
This guide documents the installation and configuration of Netdata on the Docker VM (192.168.1.20) for comprehensive infrastructure monitoring.

## Target Environment
- **Host**: docker-debian container (VM 111)
- **IP Address**: 192.168.1.20
- **Resources**: 12 cores, 10GB RAM, 60GB storage
- **Purpose**: Monitor entire infrastructure including Proxmox, containers, and network

## Pre-Installation Requirements

### System Requirements
- Docker and Docker Compose installed
- Sufficient disk space for metrics storage (2GB allocated)
- Network connectivity to all monitored systems

### Security Considerations
- Netdata will have access to Docker socket for container monitoring
- Host system monitoring requires privileged access
- Web interface exposed on port 19999

## Installation Steps

### 1. Deploy Netdata Container

```bash
# Connect to Docker VM
ssh root@192.168.1.20

# Create netdata directory
mkdir -p /opt/netdata
cd /opt/netdata

# Copy docker-compose.yml and netdata.conf
# (Files provided in this documentation)

# Start Netdata
docker compose up -d
```

### 2. Verify Installation

```bash
# Check container status
docker compose ps

# Check logs
docker compose logs netdata

# Test web interface
curl -I http://192.168.1.20:19999
```

### 3. Access Web Interface

- **URL**: http://192.168.1.20:19999
- **Network Access**: Available from any device on 192.168.1.0/24 network
- **Default Authentication**: None (secure via network isolation)

## Configuration Details

### Docker Compose Configuration
- **Image**: netdata/netdata:stable (official Netdata Docker image)
- **Port**: 19999 (standard Netdata web port)
- **Volumes**: Persistent configuration, data, and cache storage
- **Monitoring**: Docker socket access for container monitoring
- **Security**: SYS_PTRACE and SYS_ADMIN capabilities for system monitoring

### Netdata Configuration (`netdata.conf`)
- **Update Interval**: 1 second (real-time monitoring)
- **History Retention**: 24 hours of detailed metrics
- **Storage**: 2GB allocated for metrics database
- **Docker Monitoring**: Enabled for all containers
- **Network Access**: Restricted to local network (192.168.1.*)

### Monitored Components

#### Docker Containers (on 192.168.1.20)
- n8n workflow automation
- Gotenberg document conversion
- Full Supabase stack (12+ services)
- Portainer container management

#### System Metrics
- CPU usage and load
- Memory utilization
- Disk I/O and space
- Network traffic
- Container resource consumption

#### Infrastructure Integration
- **Proxmox Host**: Can be monitored via SNMP or additional agent
- **OMV NAS**: Monitorable via network metrics and SNMP
- **OPNsense**: Network traffic visible through interface monitoring
- **Pi-hole**: DNS metrics available via API integration

## Monitoring Capabilities

### Real-Time Dashboards
- **System Overview**: CPU, memory, disk, network at-a-glance
- **Container Monitoring**: Resource usage per Docker container
- **Network Traffic**: Bandwidth utilization and connection tracking
- **Application Performance**: Service-specific metrics and health

### Alerting Features
- **Threshold Alerts**: CPU, memory, disk space warnings
- **Service Health**: Container down/restart notifications  
- **Network Issues**: Bandwidth spikes, connection failures
- **Custom Alerts**: Configurable via health.d configuration

### Data Export
- **Metrics API**: RESTful API for external integrations
- **Prometheus Export**: Compatible with Prometheus/Grafana
- **Webhook Alerts**: Integration with n8n automation workflows
- **CSV Export**: Historical data export for analysis

## Integration with Existing Infrastructure

### n8n Automation Integration
```javascript
// Example n8n webhook for Netdata alerts
{
  "url": "http://192.168.1.20:5678/webhook/netdata-alert",
  "method": "POST",
  "headers": {
    "Content-Type": "application/json"
  }
}
```

### Uptime Kuma Complement
- **Netdata**: Detailed metrics and performance monitoring
- **Uptime Kuma**: Service availability and uptime tracking
- **Combined**: Comprehensive monitoring solution

### OPNsense Integration
- Network traffic correlation with firewall logs
- Bandwidth usage validation against traffic shaper rules
- Connection tracking and analysis

## Maintenance

### Regular Tasks
- **Weekly**: Review alert thresholds and adjust as needed
- **Monthly**: Clean old metrics data if storage becomes an issue
- **Quarterly**: Update Netdata container image

### Backup Considerations
- Configuration files backed up as part of infrastructure documentation
- Metrics data is ephemeral (24-hour retention)
- Dashboard customizations stored in persistent volumes

### Troubleshooting
- **Container Issues**: Check Docker logs and resource allocation
- **Permission Problems**: Verify Docker socket access and capabilities
- **Network Access**: Confirm firewall rules allow port 19999
- **Performance**: Monitor container resource usage vs. host capacity

## Security Notes

### Network Security
- Web interface restricted to local network only
- No external internet access required for basic operation
- Docker socket access limited to monitoring (read-only where possible)

### Data Privacy
- All metrics stored locally on Docker VM
- No external data transmission unless cloud features enabled
- Historical data automatically pruned after retention period

### Access Control
- Consider implementing reverse proxy authentication via Nginx Proxy Manager
- Network-level access control via OPNsense firewall rules
- Container isolation through Docker networking

This installation provides comprehensive monitoring for the entire internet-control infrastructure while maintaining security and performance standards.