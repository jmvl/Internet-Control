# Immich Installation Documentation

## Overview
Immich is a self-hosted photo and video management solution running on OMV NAS (192.168.1.9) using Docker containers.

## System Information
- **Host**: OpenMediaVault NAS (192.168.1.9)
- **Installation Method**: Docker containers
- **Web Interface**: http://192.168.1.9:2283
- **Current Version**: v1.138.1
- **Database**: PostgreSQL 14.10 with pgvecto-rs extension

## Architecture

### Container Stack
| Container | Image | Status | Ports | Purpose |
|-----------|-------|--------|-------|---------|
| **immich_server** | ghcr.io/immich-app/immich-server:v1.138.1 | ✅ Healthy | 2283:2283 | Main application server |
| **immich_postgres** | tensorchord/pgvecto-rs:pg14-v0.2.0 | ❌ Unhealthy* | 5432 (internal) | Database with vector search |
| **immich_machine_learning** | ghcr.io/immich-app/immich-machine-learning:v1.138.1 | ✅ Healthy | Internal | AI recognition/tagging |
| **immich_redis** | redis:6.2-alpine | ✅ Healthy | 6379 (internal) | Cache and sessions |

*PostgreSQL shows "unhealthy" status but is fully functional

## Storage Configuration

### Primary Storage (BTRFS RAID Mirror)
**Base Path**: `/srv/raid/immich-lib/` on OMV host

```
Storage Structure:
├── postgres/
│   └── data/           # PostgreSQL database files
├── library/            # Original photo/video files  
├── upload/             # Upload staging area
├── thumbs/             # Generated thumbnails
├── encoded-video/      # Processed video files
├── profile/            # User profile images
├── backups/            # Database backup files
└── db-dumps/           # Manual database exports
```

### Container Volume Mounts
| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `/srv/raid/immich-lib` | `/usr/src/app/upload` | Main data storage |
| `/srv/raid/immich-lib/postgres/data` | `/var/lib/postgresql/data` | Database files |
| Docker volume | `/data` | Application data |

### Storage Capacity
- **Total RAID Capacity**: 3.7TB
- **Current Usage**: 50% (1.9TB used, 1.9TB free)
- **Asset Count**: 57,383 photos and videos
- **Backup Strategy**: Daily automated database backups

## Network Configuration

### Access Information
- **Web Interface**: http://192.168.1.9:2283
- **Internal Network**: Docker bridge network
- **Database Access**: Internal only (port 5432)
- **Machine Learning**: Internal API communication
- **Redis**: Internal caching (port 6379)

### Security
- **External Access**: Web interface only (port 2283)
- **Database**: Not exposed externally
- **Authentication**: Immich user management system
- **File Permissions**: Proper ownership and access controls

## Installation Method

### Docker Compose Structure
The installation uses Docker containers managed through the OMV Docker plugin:

```yaml
# Approximate structure based on container inspection
services:
  immich_server:
    image: ghcr.io/immich-app/immich-server:v1.138.1
    ports:
      - "2283:2283"
    volumes:
      - /srv/raid/immich-lib:/usr/src/app/upload
    depends_on:
      - immich_postgres
      - immich_redis

  immich_postgres:
    image: tensorchord/pgvecto-rs:pg14-v0.2.0
    volumes:
      - /srv/raid/immich-lib/postgres/data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: immich
      POSTGRES_USER: postgres

  immich_machine_learning:
    image: ghcr.io/immich-app/immich-machine-learning:v1.138.1
    volumes:
      - model-cache:/cache

  immich_redis:
    image: redis:6.2-alpine
```

## Features and Capabilities

### Core Features
- **Photo Management**: Upload, organize, and view photos
- **Video Support**: Video playback and thumbnail generation
- **AI Recognition**: Automatic face detection and object recognition
- **Search**: Powerful search capabilities with AI tagging
- **Albums**: Custom photo albums and sharing
- **Backup**: Mobile app backup functionality

### AI and Machine Learning
- **Face Recognition**: Automatic person detection and clustering
- **Object Detection**: Smart tagging of objects in photos
- **Location Data**: GPS metadata extraction and mapping
- **Duplicate Detection**: Automatic duplicate photo identification
- **Smart Search**: Natural language search queries

### Backup and Recovery
- **Database Backups**: Automated daily backups at 2:00 AM
- **File Storage**: Photos stored on redundant BTRFS RAID mirror
- **Export Options**: Bulk photo export and download
- **Metadata Preservation**: EXIF data and original file integrity

## Maintenance and Updates

### Regular Maintenance
- **Database Backups**: Automatic daily backups
- **Log Rotation**: Container logs managed by Docker
- **Storage Monitoring**: BTRFS filesystem health checks
- **Version Updates**: Check for new releases regularly

### Update Process
1. **Backup Current State**: Ensure recent database backup
2. **Update Images**: Pull new container versions
3. **Restart Containers**: Apply updates with restart
4. **Verify Functionality**: Test web interface and features

### Monitoring
- **Web Interface**: Check http://192.168.1.9:2283 accessibility
- **Database Health**: Monitor PostgreSQL connectivity
- **Storage Usage**: Watch RAID storage capacity
- **Performance**: Monitor thumbnail generation and AI processing

## Troubleshooting

### Common Issues
1. **Web Interface Inaccessible**: Check container status and port binding
2. **Upload Failures**: Verify storage permissions and available space  
3. **Slow Performance**: Check machine learning container resources
4. **Database Issues**: Verify PostgreSQL container health

### Health Check Commands
```bash
# Check container status
docker ps | grep immich

# View container logs
docker logs immich_server
docker logs immich_postgres

# Test database connectivity
docker exec immich_postgres pg_isready -U postgres

# Check storage usage
df -h /srv/raid/immich-lib
```

### Recovery Procedures
- **Database Recovery**: Restore from automated backups
- **File Recovery**: BTRFS snapshots and RAID redundancy
- **Configuration Reset**: Container recreation from images
- **Data Migration**: Export/import procedures for major updates

## Performance Optimization

### Resource Allocation
- **CPU Usage**: Machine learning container uses significant CPU for AI processing
- **Memory**: Redis caching improves performance
- **Storage I/O**: RAID mirror provides redundancy with good read performance
- **Network**: Gigabit Ethernet for fast photo uploads

### Optimization Tips
- **Thumbnail Pre-generation**: Enable background thumbnail creation
- **Machine Learning**: Adjust AI processing schedules for off-peak hours
- **Database Tuning**: PostgreSQL configuration optimization
- **Storage**: Regular BTRFS maintenance and defragmentation

## Security Considerations

### Access Control
- **User Management**: Immich built-in user system
- **Network Security**: Internal container network isolation
- **File Permissions**: Proper Unix file permissions
- **Backup Security**: Encrypted backup storage options

### Best Practices
- **Regular Updates**: Keep containers updated for security patches
- **Access Logs**: Monitor web interface access patterns
- **Backup Verification**: Test backup restore procedures
- **Network Isolation**: Consider VPN access for remote connectivity

This installation provides a robust, self-hosted photo management solution with AI capabilities, automated backups, and redundant storage for data protection.