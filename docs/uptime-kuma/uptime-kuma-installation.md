# Uptime Kuma Monitoring System

## Overview
Uptime Kuma is a self-hosted monitoring tool that tracks the uptime and performance of websites, APIs, and services. It provides real-time monitoring, alerting, and status page capabilities for the entire infrastructure.

## System Information
- **Host**: OpenMediaVault NAS (192.168.1.9)
- **Web Interface**: http://192.168.1.9:3010
- **Container Image**: louislam/uptime-kuma:1
- **Status**: Up 3 weeks (healthy)
- **Installation Method**: Docker container

## Container Configuration

### Basic Settings
| Component | Value | Purpose |
|-----------|-------|---------|
| **Container Name** | uptime-kuma | Monitoring service |
| **Image** | louislam/uptime-kuma:1 | Official Uptime Kuma image |
| **Port Mapping** | 3010:3001 | Web interface access |
| **Restart Policy** | unless-stopped | Auto-restart on boot |
| **Health Status** | Healthy | Container health check passing |

### Environment Variables
- **NODE_VERSION**: 18.20.3 (Node.js runtime)
- **YARN_VERSION**: 1.22.19 (Package manager)
- **UPTIME_KUMA_IS_CONTAINER**: 1 (Container environment flag)

### Volume Configuration
```
Docker Volume: uptime-kuma_uptime-kuma → Container: /app/data
Host Access: /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data
```

## Monitoring Capabilities

### Supported Monitor Types
- **HTTP/HTTPS**: Website and API endpoint monitoring
- **TCP Port**: Service port availability monitoring  
- **Ping**: ICMP ping monitoring for network connectivity
- **DNS**: DNS resolution monitoring
- **Push**: Webhook-based monitoring for custom services
- **Steam Game Server**: Game server status monitoring
- **Docker Container**: Container health monitoring

### Infrastructure Monitoring

**Currently Monitored Services** (based on infrastructure):
- **Immich**: Photo management service (192.168.1.9:2283)
- **Calibre-Web**: E-book library (192.168.1.9:8083)
- **Portainer**: Docker management (192.168.1.9:9443)
- **Nginx Proxy Manager**: Reverse proxy (192.168.1.9:81)
- **Pi-hole**: DNS filtering (192.168.1.5)
- **OPNsense**: Firewall web interface (192.168.1.3)
- **Proxmox**: Virtualization host (192.168.1.10:8006)

### Alert Mechanisms
- **Email Notifications**: SMTP-based email alerts
- **Discord**: Discord channel notifications
- **Slack**: Slack workspace integration
- **Telegram**: Telegram bot notifications
- **Webhook**: Custom webhook notifications
- **Pushover**: Mobile push notifications

## Features and Functionality

### Real-Time Monitoring
- **Live Dashboard**: Real-time service status overview
- **Response Time Tracking**: Historical response time graphs
- **Uptime Percentage**: Service availability statistics
- **Status History**: Detailed incident timeline
- **Multi-Protocol Support**: Various monitoring protocols

### Status Page Features
- **Public Status Page**: Share service status with users
- **Custom Branding**: Customize appearance and branding
- **Incident Management**: Create and manage incident reports
- **Maintenance Windows**: Schedule maintenance notifications
- **Multiple Status Pages**: Separate pages for different services

### Analytics and Reporting
- **Uptime Statistics**: Daily, weekly, monthly uptime reports
- **Performance Metrics**: Response time analysis
- **Availability Reports**: Service availability summaries
- **Incident Analysis**: Downtime pattern analysis
- **Export Capabilities**: Data export for external analysis

## Web Interface Access

### Dashboard Access
- **URL**: http://192.168.1.9:3010
- **Authentication**: Username/password protected
- **Mobile Responsive**: Mobile-friendly interface
- **Real-Time Updates**: Live status updates without refresh
- **Dark/Light Mode**: Customizable interface themes

### User Management
- **Admin Account**: Full system administration
- **Multiple Users**: Support for multiple monitoring users
- **Role-Based Access**: Different permission levels
- **API Access**: RESTful API for external integrations

## Configuration and Setup

### Monitor Configuration Examples
```yaml
# HTTP/HTTPS Monitor
Name: Immich Photo Service
URL: https://192.168.1.9:2283
Method: GET
Interval: 60 seconds
Timeout: 30 seconds

# TCP Port Monitor  
Name: PostgreSQL Database
Host: 192.168.1.9
Port: 5432
Interval: 300 seconds

# Ping Monitor
Name: OPNsense Firewall
Host: 192.168.1.3
Interval: 60 seconds
```

### Notification Setup
```yaml
# Email Notification
SMTP Host: smtp.gmail.com
Port: 587
Username: monitoring@domain.com
Password: app_password
From: monitoring@domain.com
To: admin@domain.com

# Discord Webhook
Webhook URL: https://discord.com/api/webhooks/xxx/xxx
```

## Data Storage and Persistence

### Database Storage
- **Database Type**: SQLite database
- **Data Location**: `/srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data`
- **Database File**: `kuma.db` (SQLite database)
- **Configuration**: Stored in database
- **Historical Data**: Monitor history and statistics

### Backup Considerations
- **Data Volume**: `uptime-kuma_uptime-kuma` Docker volume
- **Configuration Backup**: Export monitor configurations
- **Database Backup**: Regular SQLite database backups
- **Full System Backup**: Include in OMV backup procedures

## Performance and Resource Usage

### System Requirements
- **Memory Usage**: ~100-150MB RAM
- **CPU Usage**: Low CPU utilization (monitoring intervals)
- **Storage**: Minimal storage for database and logs
- **Network**: Low bandwidth for monitoring checks

### Optimization Settings
- **Monitor Intervals**: Balance between responsiveness and resource usage
- **Data Retention**: Configure history retention periods
- **Concurrent Checks**: Manage number of simultaneous monitors
- **Response Timeouts**: Optimize timeout values for network conditions

## Integration with Infrastructure

### Network Integration
- **Internal Monitoring**: Monitor internal services on LAN
- **External Monitoring**: Monitor external websites and APIs
- **VPN Monitoring**: Monitor VPN connectivity and tunnels
- **DNS Monitoring**: Monitor DNS resolution and response times

### Alert Integration
- **Email Server**: Integration with local mail server
- **Chat Platforms**: Discord, Slack, Telegram notifications
- **Mobile Alerts**: Push notifications via Pushover
- **Custom Webhooks**: Integration with other systems

### API Integration
- **REST API**: Programmatic access to monitoring data
- **Webhook Receivers**: Receive status updates from external services
- **Data Export**: Export monitoring data for analysis
- **Third-Party Integration**: Connect with other monitoring tools

## Maintenance and Administration

### Regular Maintenance
```bash
# Check container status
docker ps | grep uptime-kuma

# View container logs
docker logs uptime-kuma --tail 50

# Restart container
docker restart uptime-kuma

# Update container
docker pull louislam/uptime-kuma:1
docker stop uptime-kuma
docker rm uptime-kuma
# Recreate with same configuration
```

### Backup Procedures
```bash
# Backup Uptime Kuma data volume
docker run --rm \
  -v uptime-kuma_uptime-kuma:/source:ro \
  -v /srv/raid/backups:/backup \
  alpine tar czf /backup/uptime-kuma-$(date +%Y%m%d).tar.gz -C /source .

# Restore from backup
docker run --rm \
  -v uptime-kuma_uptime-kuma:/target \
  -v /srv/raid/backups:/backup \
  alpine tar xzf /backup/uptime-kuma-YYYYMMDD.tar.gz -C /target
```

### Database Maintenance
```bash
# Access container for database operations
docker exec -it uptime-kuma sh

# Database location inside container
ls -la /app/data/kuma.db

# SQLite database operations (if needed)
sqlite3 /app/data/kuma.db .schema
```

## Security Considerations

### Access Security
- **Authentication Required**: Login required for dashboard access
- **Password Security**: Strong password enforcement
- **Session Management**: Automatic session timeouts
- **Network Access**: Internal network access only (consider proxy for external)

### Monitoring Security
- **Credential Storage**: Secure storage of monitor credentials
- **SSL/TLS Monitoring**: Secure connections for monitored services
- **API Security**: Secure API endpoints and tokens
- **Data Privacy**: Monitor data stored locally

## Troubleshooting

### Common Issues
1. **Monitor False Positives**: Adjust timeout and interval settings
2. **Notification Failures**: Verify SMTP and webhook configurations
3. **Performance Issues**: Review number of concurrent monitors
4. **Database Corruption**: Restore from backup if database issues occur

### Diagnostic Commands
```bash
# Check Uptime Kuma status
docker ps | grep uptime-kuma

# Test web interface
curl -I http://192.168.1.9:3010

# Check container logs for errors
docker logs uptime-kuma | grep -i error

# Monitor resource usage
docker stats uptime-kuma

# Check data volume
docker volume inspect uptime-kuma_uptime-kuma
```

### Log Analysis
```bash
# Recent application logs
docker logs uptime-kuma --tail 100

# Monitor specific issues
docker logs uptime-kuma | grep -E "(error|fail|timeout)"

# Real-time log monitoring
docker logs uptime-kuma -f
```

## Integration Examples

### Status Page Setup
1. **Enable Public Status Page**: Configure in settings
2. **Custom Domain**: Set up custom domain or subdomain
3. **Service Groups**: Organize monitors into logical groups
4. **Incident Templates**: Prepare incident response templates

### Advanced Monitoring
```yaml
# API Monitor with Headers
Name: API Health Check
URL: https://192.168.1.9:2283/api/server-info
Method: GET
Headers: Authorization: Bearer token
Expected Status: 200
Response Body Check: "server_version"

# Database Connection Monitor
Name: PostgreSQL Health
Type: TCP
Host: 192.168.1.9
Port: 5432
Interval: 300 seconds
```

This Uptime Kuma installation provides comprehensive monitoring capabilities for the entire infrastructure with real-time alerting and status reporting features.