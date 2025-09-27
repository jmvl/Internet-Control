# Wedding Share Photo Gallery Application

## Overview
Wedding Share is a custom .NET web application designed for sharing event photos. It provides a simple, elegant interface for guests to view and download photos from weddings or other special events.

## System Information
- **Host**: OpenMediaVault NAS (192.168.1.9)
- **Web Interface**: http://192.168.1.9:8080
- **Container Image**: cirx08/wedding_share:latest
- **Status**: Up 3 weeks
- **Technology**: .NET Core web application

## Container Configuration

### Basic Settings
| Component | Value | Purpose |
|-----------|-------|---------|
| **Container Name** | WeddingShare | Photo gallery application |
| **Image** | cirx08/wedding_share:latest | Custom .NET application |
| **Port Mapping** | 8080:5000 | Web interface access |
| **Restart Policy** | unless-stopped | Auto-restart on boot |
| **Runtime** | .NET Core | Application framework |

### Environment Variables
```bash
GALLERY_MAX_FILE_SIZE_MB=10        # Maximum photo file size
GALLERY_SECRET_KEY=password        # Application secret key
TITLE=WeddingShare                 # Application title
LOGO=Url                          # Logo configuration
GALLERY_COLUMNS=4                 # Photo gallery column layout
```

### Port Configuration
- **Host Port**: 8080
- **Container Port**: 5000
- **Protocol**: HTTP
- **Access**: http://192.168.1.9:8080

## Application Features

### Photo Gallery Features
- **Multi-Column Layout**: Configurable gallery columns (currently 4)
- **Photo Viewing**: Full-size photo viewing with navigation
- **Download Support**: Direct photo download capabilities
- **Responsive Design**: Mobile and desktop compatibility
- **File Size Limits**: Configurable maximum file size (10MB)

### User Interface
- **Clean Design**: Simple, elegant photo gallery interface
- **Event Branding**: Customizable title and logo
- **Navigation**: Easy photo browsing and navigation
- **Mobile Responsive**: Optimized for mobile device viewing
- **Fast Loading**: Optimized photo loading and display

### Administrative Features
- **Photo Upload**: Administrative photo upload capabilities
- **Gallery Management**: Organize and manage photo collections
- **Event Configuration**: Customize event details and branding
- **User Access**: Control access to photo galleries
- **Storage Management**: Efficient photo storage and organization

## Data Storage

### Photo Storage
- **Storage Location**: Container internal storage
- **File Formats**: JPEG, PNG, and other image formats
- **File Size Limit**: 10MB per photo (configurable)
- **Organization**: Organized by event or gallery
- **Backup**: Include in container backup procedures

### Application Data
- **Configuration**: Environment variables and app settings
- **User Data**: Gallery configurations and user preferences
- **Metadata**: Photo metadata and gallery organization
- **Logs**: Application logs for monitoring and debugging

## Access and Usage

### Web Interface
- **Public Access**: http://192.168.1.9:8080
- **Gallery View**: Grid-based photo display
- **Photo Viewer**: Full-screen photo viewing
- **Download Options**: Individual photo downloads
- **Event Information**: Display event details and branding

### Mobile Access
- **Mobile Optimized**: Responsive design for smartphones
- **Touch Navigation**: Touch-friendly photo navigation
- **Download Support**: Mobile photo downloading
- **Fast Loading**: Optimized for mobile data connections
- **Offline Viewing**: Downloaded photos for offline access

## Integration with Infrastructure

### Network Integration
- **Internal Access**: Available on LAN via 192.168.1.9:8080
- **Proxy Support**: Can be configured behind Nginx Proxy Manager
- **SSL Support**: HTTPS via reverse proxy configuration
- **Custom Domain**: Domain mapping via proxy manager

### Monitoring Integration
- **Uptime Monitoring**: Monitor via Uptime Kuma
- **Health Checks**: HTTP health monitoring on port 8080
- **Performance Monitoring**: Response time and availability tracking
- **Log Monitoring**: Application log analysis

### Backup Integration
- **Container Backup**: Include in Docker backup procedures
- **Photo Backup**: Backup photo storage volumes
- **Configuration Backup**: Backup environment variables
- **Disaster Recovery**: Restore procedures for complete recovery

## Security Considerations

### Application Security
- **Secret Key**: Application uses secret key for security
- **File Upload Limits**: Protection against large file uploads
- **Access Control**: Network-level access control
- **Input Validation**: Secure file upload handling

### Network Security
- **Internal Network**: Accessible only on internal network
- **Proxy Protection**: Can be protected by reverse proxy
- **SSL Termination**: HTTPS via proxy for external access
- **Firewall Rules**: Network-level access restrictions

## Performance and Resource Usage

### System Requirements
- **Memory Usage**: ~50-100MB RAM (.NET Core application)
- **CPU Usage**: Low CPU usage for photo serving
- **Storage**: Variable based on photo collection size
- **Network**: Bandwidth dependent on photo sizes and concurrent users

### Optimization Features
- **Photo Compression**: Optimized photo serving
- **Caching**: Static file caching for better performance
- **Responsive Loading**: Progressive photo loading
- **Mobile Optimization**: Optimized for mobile viewing

## Maintenance Operations

### Container Management
```bash
# Check container status
docker ps | grep WeddingShare

# View application logs
docker logs WeddingShare --tail 50

# Restart application
docker restart WeddingShare

# Update container
docker pull cirx08/wedding_share:latest
docker stop WeddingShare
docker rm WeddingShare
# Recreate with same configuration
```

### Application Maintenance
```bash
# Monitor application health
curl -I http://192.168.1.9:8080

# Check disk usage (photos)
docker exec WeddingShare df -h

# View application configuration
docker exec WeddingShare env | grep GALLERY
```

### Backup Procedures
```bash
# Create container backup
docker commit WeddingShare wedding_share_backup:$(date +%Y%m%d)

# Export container configuration
docker inspect WeddingShare > wedding_share_config_$(date +%Y%m%d).json

# Backup photo data (if using volumes)
docker run --rm \
  --volumes-from WeddingShare \
  -v /srv/raid/backups:/backup \
  alpine tar czf /backup/wedding_share_photos_$(date +%Y%m%d).tar.gz /app/photos
```

## Configuration Management

### Environment Configuration
Current configuration settings:
- **Max File Size**: 10MB per photo
- **Gallery Layout**: 4-column grid
- **Application Title**: "WeddingShare"
- **Logo**: URL-based logo configuration
- **Secret Key**: Configured for application security

### Customization Options
```bash
# Update gallery layout
GALLERY_COLUMNS=6                 # Change to 6 columns

# Update file size limit
GALLERY_MAX_FILE_SIZE_MB=20       # Increase to 20MB

# Update branding
TITLE="Event Photo Gallery"       # Change application title
```

## Troubleshooting

### Common Issues
1. **Application Not Loading**: Check container status and port availability
2. **Photo Upload Failures**: Verify file size limits and permissions
3. **Slow Performance**: Check storage and network performance
4. **Configuration Issues**: Verify environment variables

### Diagnostic Commands
```bash
# Check application status
docker ps | grep WeddingShare

# Test web interface
curl -I http://192.168.1.9:8080

# Check application logs
docker logs WeddingShare | grep -i error

# Monitor resource usage
docker stats WeddingShare

# Check network connectivity
curl -v http://192.168.1.9:8080
```

### Log Analysis
```bash
# Recent application logs
docker logs WeddingShare --tail 100

# Monitor for errors
docker logs WeddingShare | grep -E "(error|fail|exception)"

# Real-time log monitoring
docker logs WeddingShare -f
```

## Development and Deployment

### Custom Application
- **Source**: Custom .NET application (cirx08/wedding_share)
- **Framework**: .NET Core web application
- **Deployment**: Docker container deployment
- **Updates**: Container image updates via Docker Hub
- **Customization**: Environment variable configuration

### Future Enhancements
- **Multi-Event Support**: Support for multiple event galleries
- **User Authentication**: User login and access control
- **Admin Interface**: Web-based administration panel
- **Enhanced Upload**: Drag-and-drop photo upload interface
- **Social Features**: Comments and photo sharing

This Wedding Share application provides a simple, elegant solution for sharing event photos with guests while maintaining full control over photo storage and access.