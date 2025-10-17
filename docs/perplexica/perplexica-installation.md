# Perplexica Installation Documentation

## Overview
Perplexica is an AI-powered search engine that provides an open-source alternative to Perplexity AI. It combines web search capabilities with AI language models to provide conversational search results.

## System Information
- **Host**: Docker Debian Container (192.168.1.20, VMID: 111)
- **Installation Date**: 2025-10-08
- **Installation Method**: Docker Compose
- **Installation Path**: `/opt/perplexica`

## Service Architecture

### Container Stack
Perplexica consists of two main services:

| Service | Container Name | Image | Port Mapping | Status |
|---------|---------------|--------|--------------|--------|
| **Frontend/Backend** | perplexica-app-1 | itzcrazykns1337/perplexica:main | 3000:3000 | Running |
| **Search Engine** | perplexica-searxng-1 | searxng/searxng:latest | 4001:8080 | Running |

### Port Configuration
- **Port 3000**: Perplexica web interface (frontend + backend API)
- **Port 4001**: SearxNG metasearch engine API
  - ⚠️ **Note**: Changed from default port 4000 due to conflict with Supabase Logflare analytics

### Network Architecture
```
User → http://192.168.1.20:3000 → Perplexica App
                                      ↓
                         Internal Network (perplexica-network)
                                      ↓
                                  SearxNG
                                      ↓
                            External Search Engines
```

## Installation Details

### Directory Structure
```
/opt/perplexica/
├── docker-compose.yaml       # Container orchestration configuration
├── config.toml               # Perplexica application configuration
└── searxng/
    └── settings.yml          # SearxNG metasearch engine settings
```

### Docker Compose Configuration
```yaml
services:
  searxng:
    image: docker.io/searxng/searxng:latest
    volumes:
      - ./searxng:/etc/searxng:rw
    ports:
      - 4001:8080
    networks:
      - perplexica-network
    restart: unless-stopped

  app:
    image: itzcrazykns1337/perplexica:main
    environment:
      - SEARXNG_API_URL=http://searxng:8080
      - DATA_DIR=/home/perplexica
    ports:
      - 3000:3000
    networks:
      - perplexica-network
    volumes:
      - backend-dbstore:/home/perplexica/data
      - uploads:/home/perplexica/uploads
      - ./config.toml:/home/perplexica/config.toml
    restart: unless-stopped

networks:
  perplexica-network:

volumes:
  backend-dbstore:
  uploads:
```

### Configuration Files

#### Perplexica Configuration (config.toml)
```toml
[GENERAL]
SIMILARITY_MEASURE = "cosine"
KEEP_ALIVE = "5m"

[MODELS.OPENAI]
API_KEY = ""

[MODELS.GROQ]
API_KEY = ""

[MODELS.ANTHROPIC]
API_KEY = ""

[MODELS.GEMINI]
API_KEY = ""

[MODELS.CUSTOM_OPENAI]
API_KEY = ""
API_URL = ""
MODEL_NAME = ""

[MODELS.OLLAMA]
API_URL = ""

[MODELS.DEEPSEEK]
API_KEY = ""

[MODELS.AIMLAPI]
API_KEY = ""

[MODELS.LM_STUDIO]
API_URL = ""

[MODELS.LEMONADE]
API_URL = ""
API_KEY = ""

[API_ENDPOINTS]
SEARXNG = "http://searxng:8080"
```

#### SearxNG Configuration (searxng/settings.yml)
```yaml
use_default_settings: true
general:
  instance_name: "Perplexica Search"
search:
  safe_search: 0
  autocomplete: ""
server:
  secret_key: "<generated-secret-key>"
  limiter: false
  image_proxy: true
ui:
  static_use_hash: true
engines:
  - name: google
    disabled: false
```

## Access Information

### Web Interfaces
- **Perplexica**: http://192.168.1.20:3000
  - Main search interface with AI-powered responses
  - Features: Home, Discover, Library, Settings
  - Dark mode support with theme toggle

- **SearxNG**: http://192.168.1.20:4001
  - Direct access to metasearch engine
  - Aggregates results from multiple search engines
  - Privacy-focused search without tracking

### Docker Management
```bash
# Navigate to installation directory
cd /opt/perplexica

# View container status
docker compose ps

# View container logs
docker compose logs -f

# Restart services
docker compose restart

# Stop services
docker compose down

# Stop and remove all data
docker compose down -v

# Update images
docker compose pull
docker compose up -d
```

## AI Model Configuration

### Supported AI Providers
Perplexica supports multiple AI model providers. To enable a provider, add your API key to `config.toml`:

1. **OpenAI** (GPT-4, GPT-3.5)
2. **Groq** (Fast inference)
3. **Anthropic** (Claude models)
4. **Google Gemini**
5. **Ollama** (Self-hosted local models)
6. **DeepSeek**
7. **AIMLAPI**
8. **LM Studio** (Local model server)
9. **Lemonade**
10. **Custom OpenAI-compatible API**

### Configuring AI Models
Edit `/opt/perplexica/config.toml` and add your API keys:

```toml
[MODELS.OPENAI]
API_KEY = "sk-your-openai-key-here"

[MODELS.ANTHROPIC]
API_KEY = "sk-ant-your-claude-key-here"
```

After updating configuration, restart the service:
```bash
cd /opt/perplexica && docker compose restart app
```

## Storage Volumes

### Persistent Data Volumes
| Volume Name | Purpose | Location |
|-------------|---------|----------|
| `backend-dbstore` | Application database | Docker managed volume |
| `uploads` | User file uploads | Docker managed volume |
| `./searxng` | SearxNG configuration | Host directory mount |
| `./config.toml` | Perplexica configuration | Host file mount |

### Volume Management
```bash
# List volumes
docker volume ls | grep perplexica

# Inspect volume
docker volume inspect perplexica_backend-dbstore

# Backup volumes
docker run --rm -v perplexica_backend-dbstore:/source:ro \
  -v /backup:/backup alpine \
  tar czf /backup/perplexica-db-$(date +%Y%m%d).tar.gz -C /source .

# Restore volumes
docker run --rm -v perplexica_backend-dbstore:/target \
  -v /backup:/backup alpine \
  tar xzf /backup/perplexica-db-YYYYMMDD.tar.gz -C /target
```

## Troubleshooting

### Common Issues

#### 1. Container Won't Start - Port Conflict
**Symptoms**: Error message "Bind for 0.0.0.0:XXXX failed: port is already allocated"

**Solution**: Check which service is using the port and change the port mapping
```bash
# Check port usage
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep <port>

# Update port in docker-compose.yaml
# Then restart services
cd /opt/perplexica && docker compose up -d
```

#### 2. SearxNG Container Restarting
**Symptoms**: SearxNG container constantly restarting, logs show secret_key error

**Solution**: Generate a new secret key
```bash
# Generate new secret
SECRET_KEY=$(openssl rand -hex 32)

# Update settings.yml with the new key
# Restart services
cd /opt/perplexica && docker compose restart
```

#### 3. Search Not Working
**Symptoms**: Searches return no results or timeout

**Diagnostic Steps**:
```bash
# Check SearxNG logs
docker logs perplexica-searxng-1 --tail 50

# Test SearxNG directly
curl http://192.168.1.20:4001

# Check connectivity between containers
docker exec perplexica-app-1 ping searxng
```

#### 4. AI Responses Not Working
**Symptoms**: Search works but no AI-powered answers

**Solution**: Verify AI model configuration
```bash
# Check if API keys are configured
cat /opt/perplexica/config.toml | grep API_KEY

# Check app logs for API errors
docker logs perplexica-app-1 --tail 100 | grep -i error
```

### Log Files
```bash
# View all logs
cd /opt/perplexica && docker compose logs -f

# View specific service logs
docker logs perplexica-app-1 -f
docker logs perplexica-searxng-1 -f

# Export logs for analysis
docker logs perplexica-app-1 > /tmp/perplexica-app.log
docker logs perplexica-searxng-1 > /tmp/perplexica-searxng.log
```

## Network Integration

### Internal Network Access
- **Docker Network**: `perplexica-network` (bridge mode)
- **Container DNS**: Automatic service discovery within Docker network
- **Inter-container Communication**: SearxNG accessible to app via `http://searxng:8080`

### External Access Options

#### Option 1: Direct Access (Current)
- Access via host IP: http://192.168.1.20:3000
- No reverse proxy required
- Suitable for internal network use

#### Option 2: Reverse Proxy (Recommended for Production)
Configure Nginx Proxy Manager (192.168.1.9) to provide:
- SSL/TLS encryption via Let's Encrypt
- Custom domain access (e.g., https://search.accelior.com)
- Access control and authentication

**Nginx Proxy Manager Configuration**:
- **Domain**: search.accelior.com
- **Forward Hostname**: 192.168.1.20
- **Forward Port**: 3000
- **Block Common Exploits**: Yes
- **SSL**: Let's Encrypt certificate

## Performance Considerations

### Resource Usage
- **Perplexica App**: ~500-800MB RAM (varies with AI model calls)
- **SearxNG**: ~50-100MB RAM
- **CPU**: Low usage during idle, spikes during search operations
- **Storage**: ~500MB for images + data volumes

### Scaling Recommendations
- **Single User**: Current setup adequate
- **Multiple Users**: Consider adding:
  - Redis cache for SearxNG results
  - Rate limiting on search requests
  - Multiple SearxNG instances for load balancing

## Security Considerations

### Network Security
- **Internal Access Only**: Not exposed to internet by default
- **Container Isolation**: Services run in isolated Docker network
- **Secret Management**: API keys stored in config files (not environment variables)

### Security Best Practices
1. **Change SearxNG Secret Key**: Already configured with random generated key
2. **Restrict API Access**: Configure API key requirements in config.toml
3. **Regular Updates**: Update container images monthly
4. **Backup Configuration**: Regular backups of config files and volumes
5. **Monitor Logs**: Regular review of container logs for suspicious activity

### Recommended Security Enhancements
```bash
# Enable firewall rules (if not already configured)
ufw allow from 192.168.1.0/24 to 192.168.1.20 port 3000
ufw allow from 192.168.1.0/24 to 192.168.1.20 port 4001

# Set proper file permissions
chmod 600 /opt/perplexica/config.toml
chmod 600 /opt/perplexica/searxng/settings.yml
```

## Maintenance

### Regular Maintenance Tasks

#### Weekly
- Review container logs for errors
- Check container resource usage
- Test search functionality

#### Monthly
- Update Docker images
- Backup configuration and data volumes
- Review and rotate API keys if needed
- Clean up unused Docker images

### Update Procedure
```bash
# Pull latest images
cd /opt/perplexica
docker compose pull

# Backup current configuration
cp -r /opt/perplexica /opt/perplexica.backup-$(date +%Y%m%d)

# Restart with new images
docker compose up -d

# Verify services are running
docker compose ps

# Clean up old images
docker image prune -a
```

### Backup Procedure
```bash
# Full backup script
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/srv/backups/perplexica"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup configuration files
tar czf $BACKUP_DIR/perplexica-config-$DATE.tar.gz \
  /opt/perplexica/docker-compose.yaml \
  /opt/perplexica/config.toml \
  /opt/perplexica/searxng/

# Backup Docker volumes
docker run --rm \
  -v perplexica_backend-dbstore:/source:ro \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/perplexica-db-$DATE.tar.gz -C /source .

docker run --rm \
  -v perplexica_uploads:/source:ro \
  -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/perplexica-uploads-$DATE.tar.gz -C /source .

# List backups
ls -lh $BACKUP_DIR
```

## Integration with Infrastructure

### Infrastructure Context
- **Host Container**: docker-debian (VMID: 111)
  - **Resources**: 12 CPU cores, 10GB RAM, 60GB storage
  - **Other Services**: Supabase stack, n8n automation, Pi-hole DNS

- **Network Position**:
  ```
  Internet → OpenWrt (192.168.1.2)
           → OPNsense (192.168.1.3)
           → Docker Host (192.168.1.20)
              └── Perplexica (ports 3000, 4001)
  ```

### Service Discovery
- **Uptime Kuma Monitoring**: Can be added for health monitoring
- **Portainer Management**: Access via http://192.168.1.9:9443

## References

### Official Documentation
- **Perplexica GitHub**: https://github.com/ItzCrazyKns/Perplexica
- **SearxNG Documentation**: https://docs.searxng.org/
- **Docker Compose Reference**: https://docs.docker.com/compose/

### Related Infrastructure Documentation
- `/docs/infrastructure.md` - Complete network architecture
- `/docs/portainer/portainer-installation.md` - Container management
- `/docs/docker/docker-maintenance.md` - Docker best practices

## Status

**Current Status**: ✅ **Operational**
- Perplexica web interface accessible at http://192.168.1.20:3000
- SearxNG search engine accessible at http://192.168.1.20:4001
- Both containers running and healthy
- Ready for AI model configuration and use

**Next Steps**:
1. Configure AI model API keys in config.toml
2. Set up Nginx Proxy Manager reverse proxy for SSL access
3. Add monitoring to Uptime Kuma
4. Test search functionality with various queries
5. Configure automatic backups
