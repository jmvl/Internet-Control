# Calibre-Web Docker Installation Documentation

## Overview
Calibre-Web is a web application providing a clean interface for browsing, reading and downloading e-books from an existing Calibre database. It runs as a Docker container on the OMV NAS (192.168.1.9).

## System Information
- **Host**: OpenMediaVault NAS (192.168.1.9)
- **Installation Method**: Docker container via Portainer
- **Web Interface**: http://192.168.1.9:8083
- **Container Image**: lscr.io/linuxserver/calibre-web:latest
- **Container Name**: calibre-web

## Architecture

### Container Configuration
| Component | Value | Purpose |
|-----------|-------|---------|
| **Image** | lscr.io/linuxserver/calibre-web:latest | LinuxServer.io maintained Calibre-Web |
| **Port** | 8083:8083 | Web interface access |
| **User/Group** | 1000:1000 (jm) | File permissions matching |
| **Timezone** | Etc/UTC | Container timezone |
| **Restart Policy** | unless-stopped | Auto-restart on boot |

### Volume Mounts
| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `/srv/raid/Calibre` | `/config` | Application configuration and database |
| `/srv/raid/Calibre/Calibre_JM` | `/books` | Calibre e-book library |

## Storage Configuration

### Data Locations
**Base Path**: `/srv/raid/Calibre/` (BTRFS RAID mirror storage)

```
Calibre Storage Structure:
├── app.db                  # Calibre-Web application database (118KB)
├── calibre-web.log         # Application logs
├── gdrive.db              # Google Drive integration (if configured)
├── client_secrets.json    # OAuth secrets
├── .key                   # Security key file
└── Calibre_JM/            # Main e-book library
    ├── metadata.db        # Calibre library database (1.4MB)
    ├── [Author Folders]/  # Books organized by author
    │   └── [Book Files]   # EPUB, PDF, MOBI, etc.
    └── [Book Directories] # Individual book storage
```

### Library Statistics
- **Database Size**: 1.4MB metadata.db (last updated: July 25, 2025)
- **Library Path**: `/srv/raid/Calibre/Calibre_JM/`
- **Authors**: Organized in individual author directories
- **Formats**: Support for EPUB, PDF, MOBI, AZW3, and other e-book formats
- **Storage**: Hosted on redundant BTRFS RAID mirror

## Installation History

### Initial Setup Issue (Resolved)
**Problem**: Container was created with incorrect volume mounts pointing to `/mnt/omv-mirrordisk/` instead of `/srv/raid/`

**Resolution Applied**: September 12, 2025
1. Stopped existing container
2. Backed up docker-compose.yml configuration
3. Updated volume mounts to correct paths:
   ```yaml
   volumes:
     - /srv/raid/Calibre:/config              # Was: /mnt/omv-mirrordisk/Calibre
     - /srv/raid/Calibre/Calibre_JM:/books    # Was: /mnt/omv-mirrordisk/Calibre/Calibre_JM
   ```
4. Recreated container with proper database access

### Docker Compose Configuration

**File Location**: `/srv/docker-volume/volumes/portainer_data/_data/compose/32/docker-compose.yml`

```yaml
services:
  calibre-web:
    image: lscr.io/linuxserver/calibre-web:latest
    container_name: calibre-web
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
      - DOCKER_MODS=linuxserver/mods:universal-calibre #optional
      - OAUTHLIB_RELAX_TOKEN_SCOPE=1 #optional
    volumes:
      - /srv/raid/Calibre:/config
      - /srv/raid/Calibre/Calibre_JM:/books
    ports:
      - 8083:8083
    restart: unless-stopped
```

### Environment Variables
- **PUID/PGID**: 1000 (matches 'jm' user for proper file permissions)
- **TZ**: Etc/UTC (timezone configuration)
- **DOCKER_MODS**: universal-calibre (adds Calibre dependencies for e-book conversion)
- **OAUTHLIB_RELAX_TOKEN_SCOPE**: 1 (OAuth compatibility for Google Drive)

## Features and Capabilities

### Core Features
- **Web-based Library**: Browse and search e-book collection via web interface
- **Multiple Formats**: Support for EPUB, PDF, MOBI, AZW3, and other formats
- **Online Reader**: Built-in e-book reader for EPUB and other supported formats
- **Download Management**: Direct download of books in various formats
- **User Management**: Multiple user accounts with different permission levels
- **Series Management**: Organize books by series with proper ordering

### Advanced Features
- **E-book Conversion**: Convert between different e-book formats
- **Metadata Editing**: Edit book metadata, covers, and descriptions
- **Custom Columns**: Support for custom book attributes
- **Search Capabilities**: Full-text search across book content and metadata
- **OPDS Feed**: Syndication feed for e-reader apps
- **Google Drive Sync**: Optional cloud storage integration

### Integration Features
- **Calibre Compatibility**: Full compatibility with existing Calibre libraries
- **Send-to-Kindle**: Email books directly to Kindle devices
- **Social Features**: Reading progress, ratings, and reviews
- **API Access**: RESTful API for external integrations

## Access and Authentication

### Web Interface Access
- **URL**: http://192.168.1.9:8083
- **Initial Setup**: Redirects to database configuration on first run
- **Login Required**: Authentication required for library access
- **Mobile Friendly**: Responsive design for mobile and tablet access

### User Management
- **Admin Account**: Configure during initial setup
- **User Permissions**: Granular control over download, upload, edit permissions
- **Guest Access**: Optional anonymous browsing capabilities
- **LDAP Integration**: Support for external authentication systems

## Maintenance and Administration

### Container Management
```bash
# View container status
docker ps | grep calibre-web

# Check container logs
docker logs calibre-web

# Restart container
docker restart calibre-web

# Update container
cd /srv/docker-volume/volumes/portainer_data/_data/compose/32
docker-compose pull
docker-compose up -d
```

### Database Management
```bash
# Access Calibre library database
docker exec calibre-web ls -la /books/metadata.db

# Check application configuration
docker exec calibre-web ls -la /config/app.db

# Backup library database
cp /srv/raid/Calibre/Calibre_JM/metadata.db /srv/raid/Calibre/backups/
```

### Log Management
- **Application Logs**: `/srv/raid/Calibre/calibre-web.log`
- **Container Logs**: `docker logs calibre-web`
- **Log Rotation**: Automatic log rotation by container system
- **Debug Mode**: Enable via web interface for detailed logging

## Performance Optimization

### Resource Allocation
- **Memory Usage**: Approximately 200-300MB RAM
- **CPU Usage**: Low CPU usage for normal browsing, higher during conversions
- **Storage I/O**: BTRFS RAID mirror provides good read performance
- **Network**: Gigabit Ethernet for fast book downloads

### Optimization Settings
- **Database Optimization**: Regular Calibre database optimization
- **Cover Generation**: Thumbnail caching for faster browsing
- **Conversion Queue**: Background processing for format conversions
- **Static Files**: Nginx proxy for static content delivery (if configured)

## Security Considerations

### Access Control
- **User Authentication**: Required for library access
- **File Permissions**: Proper Unix permissions (1000:1000)
- **Network Security**: Internal network access only (port 8083)
- **SSL/TLS**: Consider reverse proxy with SSL for external access

### Data Protection
- **Backup Strategy**: Library stored on RAID mirror for redundancy
- **Database Backups**: Regular metadata.db backups recommended
- **Configuration Backup**: Include app.db in backup procedures
- **Version Control**: Track docker-compose.yml changes

## Troubleshooting

### Common Issues

#### 1. Empty Library/Database Not Found
**Symptoms**: Web interface shows no books or database error
**Cause**: Incorrect volume mount paths
**Solution**: Verify docker-compose.yml volume mounts point to `/srv/raid/Calibre`

#### 2. Permission Errors
**Symptoms**: Cannot write files, upload errors
**Cause**: PUID/PGID mismatch with file ownership
**Solution**: Ensure PUID=1000, PGID=1000 matches file ownership

#### 3. Web Interface Not Accessible
**Symptoms**: Cannot connect to port 8083
**Cause**: Container not running or port conflict
**Solution**: Check container status and port availability

#### 4. Conversion Failures
**Symptoms**: E-book format conversion errors
**Cause**: Missing Calibre dependencies
**Solution**: Ensure DOCKER_MODS=universal-calibre is configured

### Diagnostic Commands
```bash
# Check container health
docker ps | grep calibre-web
docker logs calibre-web --tail 20

# Verify volume mounts
docker inspect calibre-web | grep -A 10 Mounts

# Check database accessibility
docker exec calibre-web ls -la /books/metadata.db

# Test web interface
curl -I http://192.168.1.9:8083

# Check file permissions
ls -la /srv/raid/Calibre/Calibre_JM/metadata.db
```

### Recovery Procedures
- **Container Recreation**: Use docker-compose down/up to recreate
- **Database Recovery**: Restore metadata.db from backup
- **Configuration Reset**: Replace app.db with clean configuration
- **Library Migration**: Export/import procedures for major updates

## Updates and Upgrades

### Container Updates
1. **Backup Current State**: Backup configuration and database
2. **Pull New Image**: `docker-compose pull`
3. **Restart Container**: `docker-compose up -d`
4. **Verify Functionality**: Test web interface and book access

### Calibre Library Updates
- **Metadata Sync**: Changes made in Calibre desktop sync automatically
- **New Books**: Add books via Calibre desktop for proper metadata
- **Database Integrity**: Regular Calibre database maintenance

### Version Compatibility
- **Calibre Desktop**: Maintain compatible Calibre desktop version
- **Database Format**: Ensure metadata.db format compatibility
- **Feature Parity**: Some features require specific Calibre versions

## Integration with Infrastructure

### Network Configuration
- **Internal Access**: Accessible on LAN via 192.168.1.9:8083
- **Reverse Proxy**: Can be configured behind Nginx Proxy Manager
- **SSL Termination**: External SSL via proxy for secure remote access
- **VPN Access**: Secure remote access via network VPN

### Backup Integration
- **Storage Location**: Part of BTRFS RAID mirror backup strategy
- **Automated Backups**: Include in OMV automated backup procedures
- **Snapshot Support**: BTRFS snapshots provide point-in-time recovery
- **Off-site Backup**: Consider cloud backup for critical library data

### Monitoring Integration
- **Uptime Monitoring**: Can be monitored via Uptime Kuma
- **Log Aggregation**: Include logs in centralized logging system
- **Health Checks**: HTTP health checks on port 8083
- **Performance Monitoring**: Track resource usage and response times

This Calibre-Web installation provides a robust, web-based interface for managing and accessing the existing e-book library with full integration into the home infrastructure.