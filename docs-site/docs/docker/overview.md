# Docker Container Platform Overview

The Internet Control Infrastructure runs on a comprehensive Docker container platform hosted across multiple servers, providing a robust microservices architecture for all application services.

## Platform Architecture

### Primary Docker Host (192.168.1.20)
**Role**: Main container orchestration platform
**Hardware**: 12 CPU cores, 10GB RAM, 60GB storage

#### Supabase Full Stack
Complete backend-as-a-service deployment:

- **PostgreSQL Database** (15.8.1) - Primary database with vector support
- **Supabase Studio** - Admin dashboard and database management
- **Auth Service** - User authentication and authorization
- **Storage API** - File storage and management
- **REST API** (PostgREST) - Auto-generated REST API from database schema
- **Realtime Service** - WebSocket subscriptions for live data
- **Kong Gateway** (ports 8000/8443) - API gateway and load balancer
- **Edge Functions** - Serverless function runtime (Deno-based)
- **Analytics** (Logflare, port 4000) - Log aggregation and analytics

#### Development & Automation
- **n8n** (port 5678) - Workflow automation platform
- **Gotenberg** - Document conversion service
- **Vector** - Log processing and transformation
- **ImgProxy** - Image processing and optimization

### OMV Storage Host (192.168.1.9)
**Role**: Media management and storage services
**Hardware**: Multi-drive NAS with RAID redundancy

#### Media & Content Management
- **Immich Server** (port 2283) - AI-powered photo and video management
- **Calibre** (ports 8082/8083) - E-book library management
- **Wallabag** (port 8880) - Read-later web application

#### Infrastructure Services
- **Nginx Proxy Manager** (ports 80/81/443) - Reverse proxy with SSL
- **Syncthing** (ports 8384/22000/21027) - File synchronization
- **Uptime Kuma** (port 3010) - Service monitoring and alerting
- **Portainer** (ports 8000/9443) - Container management interface

## Service Categories

### Backend Services
```yaml
Database Stack:
  - PostgreSQL 15.8.1 (Supabase)
  - Redis (Immich, Wallabag)
  - MariaDB (Wallabag)

API Services:
  - PostgREST (Auto-generated REST API)
  - Supabase Auth (Authentication)
  - Supabase Storage (File management)
  - Kong Gateway (API management)
```

### Development Tools
```yaml
Automation:
  - n8n: Workflow automation
  - Gotenberg: Document conversion
  - Vector: Log processing

Monitoring:
  - Uptime Kuma: Service monitoring
  - Logflare: Analytics and logging
  - Portainer: Container management
```

### Media & Content
```yaml
Photo Management:
  - Immich: AI-powered photo organization
  - Immich ML: Machine learning engine
  - ImgProxy: Image optimization

Content Management:
  - Calibre: E-book library
  - Wallabag: Read-later service
  - Syncthing: File synchronization
```

## Container Orchestration

### Docker Compose Architecture
Each service group is managed via dedicated `docker-compose.yml` files:

```bash
/srv/docker-compose/
├── supabase/docker-compose.yml    # Complete Supabase stack
├── immich/docker-compose.yml      # Photo management stack
├── media/docker-compose.yml       # Calibre, Wallabag, etc.
├── infrastructure/docker-compose.yml  # Nginx, monitoring
└── automation/docker-compose.yml  # n8n, processing services
```

### Persistent Storage Strategy
```yaml
Volume Mapping:
  Critical Data: → RAID Mirror (/srv/raid)
  Media Files: → MergerFS Pool (/srv/mergerfs/MergerFS)
  Config Files: → Docker Volumes (/srv/docker-volume)
  Logs: → Centralized logging via Vector/Logflare
```

## Service Status & Health

### Production Services ✅
- **Supabase Stack**: PostgreSQL, Auth, Storage, REST API
- **Immich Photo Management**: Server, ML engine, Redis cache
- **n8n Automation**: Workflow platform with 5678 web interface
- **Nginx Proxy Manager**: SSL termination and reverse proxy
- **Uptime Kuma**: Real-time service monitoring

### Services Requiring Attention ⚠️
- **Realtime Service**: WebSocket subscriptions currently unhealthy
- **Wallabag MariaDB**: Database connectivity issues

### Resource Utilization
```yaml
Primary Host (192.168.1.20):
  CPU: 12 cores allocated
  Memory: 10GB RAM
  Storage: 60GB local + network storage

Storage Host (192.168.1.9):
  Storage: 21TB total (18TB pool + 3.7TB RAID)
  Utilization: 80% MergerFS, 50% RAID mirror
```

## Container Management

### Common Operations
```bash
# Check all running containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View service logs
docker compose -f /path/to/compose.yml logs -f service-name

# Restart unhealthy service
docker compose -f /path/to/compose.yml restart service-name

# Update container images
docker compose -f /path/to/compose.yml pull
docker compose -f /path/to/compose.yml up -d
```

### Health Monitoring
All containers are monitored via **Uptime Kuma** (http://192.168.1.9:3010) providing:
- Real-time health status
- Performance metrics
- Automated alerting
- Historical uptime data

### Backup Strategy
```yaml
Database Backups:
  - PostgreSQL: Automated dumps via Supabase
  - Configuration: Docker volume snapshots
  - Media Files: BTRFS snapshots on RAID mirror

Container Images:
  - Local registry: GitLab container registry
  - External images: Cached locally
  - Version pinning: All production services
```

## Network Integration

### Service Discovery
```yaml
Internal DNS:
  Pi-hole (192.168.1.5): Local domain resolution

Reverse Proxy:
  Nginx Proxy Manager: SSL termination
  Kong Gateway: API gateway for Supabase

Load Balancing:
  Multiple container replicas for critical services
```

### Security Model
```yaml
Network Isolation:
  - Container-to-container communication via Docker networks
  - External access through reverse proxy only
  - API authentication via Supabase Auth

Access Control:
  - Service-specific API keys
  - Database user segregation
  - Container privilege restrictions
```

## Deployment Pipeline

### CI/CD Integration
- **GitLab Runner**: Automated builds and deployments
- **Container Registry**: GitLab-hosted private registry
- **Health Checks**: Automated verification post-deployment

### Update Strategy
1. **Blue-Green Deployments**: Zero-downtime updates
2. **Database Migrations**: Automated via Supabase
3. **Configuration Management**: Version-controlled compose files
4. **Rollback Capability**: Tagged container versions

For detailed service configuration and management procedures, refer to the individual service documentation sections.