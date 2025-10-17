# CouchDB Documentation

## Overview

Apache CouchDB is a NoSQL document-oriented database that stores data as JSON documents. This installation provides a single-node CouchDB instance running in Docker on the container platform (192.168.1.20).

## Service Information

| Property | Value |
|----------|-------|
| **Host** | 192.168.1.20 |
| **Port** | 5984 |
| **Version** | 3.5.0 |
| **Container Name** | couchdb |
| **Image** | couchdb:3 |
| **Internal Web Interface** | http://192.168.1.20:5984/_utils |
| **Internal API Endpoint** | http://192.168.1.20:5984 |
| **Public Web Interface** | https://couchdb.acmea.tech/_utils |
| **Public API Endpoint** | https://couchdb.acmea.tech |
| **Reverse Proxy** | Nginx Proxy Manager (192.168.1.9) |
| **SSL Certificate** | Let's Encrypt (Auto-renewed by NPM) |
| **Access Mode** | Internal (LAN) + Public (Internet via HTTPS) |

## Public Access Configuration

### Overview

CouchDB is exposed to the internet via **Nginx Proxy Manager (NPM)** reverse proxy with Let's Encrypt SSL/TLS encryption. The database port (5984) remains internal-only for security.

### Architecture

```
Internet → OPNsense:443 → NPM:443 (192.168.1.9) → CouchDB:5984 (192.168.1.20)
                ↓
          Let's Encrypt SSL
          DNS: couchdb.acmea.tech
```

### DNS Configuration

**Domain**: `couchdb.acmea.tech`
- **Type**: CNAME record
- **Target**: `base.acmea.tech` (DynDNS managed by OPNsense)
- **Cloudflare Mode**: DNS-only (grey cloud) - NOT proxied
- **TTL**: Auto

### Nginx Proxy Manager Configuration

**Reverse Proxy Settings**:
- **Domain Name**: `couchdb.acmea.tech`
- **Forward Hostname/IP**: `192.168.1.20`
- **Forward Port**: `5984`
- **Scheme**: `http` (internal connection, SSL terminates at NPM)
- **WebSocket Support**: Enabled (for CouchDB change feeds and long-polling)
- **SSL Certificate**: Let's Encrypt (automatically issued and renewed)
- **Force SSL**: Enabled (HTTP redirects to HTTPS)
- **HTTP/2 Support**: Enabled
- **Block Exploits**: Enabled

**Custom Nginx Configuration** (if needed for CouchDB-specific settings):
```nginx
# Allow large document uploads
client_max_body_size 100M;

# WebSocket timeout for change feeds
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;

# Preserve original headers
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-Server $host;
```

### Firewall Configuration

**OPNsense NAT Port Forward**:
- **Interface**: WAN
- **Protocol**: TCP
- **Destination**: WAN Address
- **Destination Port**: 443
- **Redirect Target IP**: 192.168.1.9 (NPM)
- **Redirect Target Port**: 443
- **Description**: HTTPS to Nginx Proxy Manager

**Note**: Port 5984 is NOT forwarded from WAN - it remains internal-only.

### Security Considerations

1. **SSL/TLS Encryption**: All public traffic encrypted via Let's Encrypt certificates
2. **Authentication Required**: CouchDB admin authentication enforced for all operations
3. **No Direct Database Exposure**: Port 5984 only accessible on internal network
4. **Proxy-Level Security**: NPM provides additional security layer (block exploits, rate limiting)
5. **Cloudflare DNS-only**: Direct connection to your IP (no Cloudflare CDN layer)

### Access Methods

#### Public HTTPS Access (Recommended)
```bash
# Server info (anonymous)
curl https://couchdb.acmea.tech/

# List databases (authenticated)
curl -u admin:password https://couchdb.acmea.tech/_all_dbs

# Fauxton Web UI
https://couchdb.acmea.tech/_utils
```

#### Internal LAN Access (Faster, no SSL overhead)
```bash
# Server info
curl http://192.168.1.20:5984/

# List databases
curl -u admin:password http://192.168.1.20:5984/_all_dbs

# Fauxton Web UI
http://192.168.1.20:5984/_utils
```

### Testing Public Access

```bash
# Test DNS resolution
nslookup couchdb.acmea.tech

# Test HTTPS connection
curl -v https://couchdb.acmea.tech/

# Test SSL certificate
openssl s_client -connect couchdb.acmea.tech:443 -servername couchdb.acmea.tech

# Test API endpoint with authentication
curl -u admin:password https://couchdb.acmea.tech/_all_dbs
```

### Troubleshooting Public Access

#### DNS Not Resolving
```bash
# Verify DNS propagation
dig couchdb.acmea.tech
nslookup couchdb.acmea.tech 8.8.8.8

# Check Cloudflare DNS settings
# Ensure CNAME points to base.acmea.tech
# Ensure grey cloud (DNS-only) mode is enabled
```

#### SSL Certificate Errors
```bash
# Check NPM certificate status via web UI
# http://192.168.1.9:81

# Force certificate renewal (if needed)
ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  certbot renew --force-renewal'
```

#### 502 Bad Gateway
```bash
# Verify CouchDB is running
ssh root@192.168.1.20 'docker ps --filter name=couchdb'

# Check CouchDB health
curl http://192.168.1.20:5984/_up

# Check NPM proxy host configuration
ssh root@192.168.1.9 'ls -la /srv/raid/config/nginx/data/nginx/proxy_host/'

# Check NPM logs
ssh root@192.168.1.9 'docker logs --tail 50 nginx-proxy-manager-nginx-proxy-manager-1'
```

#### Connection Timeout
```bash
# Verify OPNsense port forwarding for port 443
# Check Firewall → NAT → Port Forward

# Test internal NPM HTTPS
curl -k --resolve "couchdb.acmea.tech:443:192.168.1.9" https://couchdb.acmea.tech/

# Verify public IP
curl ifconfig.me
# Should match base.acmea.tech resolution
```

## Installation Details

### Docker Compose Configuration

**Location**: `/root/couchdb/docker-compose.yml`

The service is deployed using Docker Compose with the following configuration:

```yaml
version: "3.8"

services:
  couchdb:
    image: couchdb:3
    container_name: couchdb
    restart: unless-stopped
    environment:
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=Reenact.Drizzle.Bats4
    volumes:
      - couchdb_data:/opt/couchdb/data
      - couchdb_config:/opt/couchdb/etc/local.d
    ports:
      - "5984:5984"
    networks:
      - couchdb_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5984/_up"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    configs:
      - source: single_node_config
        target: /opt/couchdb/etc/local.d/single_node.ini

volumes:
  couchdb_data:
    driver: local
  couchdb_config:
    driver: local

networks:
  couchdb_network:
    driver: bridge

configs:
  single_node_config:
    content: |
      [couchdb]
      single_node=true

      [chttpd]
      bind_address = 0.0.0.0

      [httpd]
      bind_address = 0.0.0.0
```

### Configuration Mode

The installation runs in **single-node mode** with the following characteristics:

- **Single Node**: Configured with `single_node=true` for simplified single-server deployment
- **System Databases**: Automatically creates `_users` and `_replicator` system databases on startup
- **Network Binding**: Binds to all interfaces (0.0.0.0) for network accessibility
- **Data Persistence**: Uses Docker volumes for persistent data storage

### Storage Volumes

| Volume | Purpose | Mount Point |
|--------|---------|-------------|
| `couchdb_data` | Database files and document storage | `/opt/couchdb/data` |
| `couchdb_config` | Configuration files | `/opt/couchdb/etc/local.d` |

## Authentication

### Default Credentials

- **Username**: `admin`
- **Password**: `Reenact.Drizzle.Bats4`

⚠️ **Security Notice**: The password has been updated from the default. Store credentials securely and avoid committing them to version control.

### Updating Admin Password

```bash
# Edit docker-compose.yml
ssh root@192.168.1.20 'cd /root/couchdb && nano docker-compose.yml'

# Update COUCHDB_PASSWORD value
# Then restart the container
ssh root@192.168.1.20 'cd /root/couchdb && docker compose restart'
```

## Management Commands

### Container Management

```bash
# Start CouchDB
ssh root@192.168.1.20 'cd /root/couchdb && docker compose up -d'

# Stop CouchDB
ssh root@192.168.1.20 'cd /root/couchdb && docker compose down'

# Restart CouchDB
ssh root@192.168.1.20 'cd /root/couchdb && docker compose restart'

# View logs
ssh root@192.168.1.20 'docker logs couchdb'

# Follow logs in real-time
ssh root@192.168.1.20 'docker logs -f couchdb'

# Check container status
ssh root@192.168.1.20 'docker ps --filter name=couchdb'

# View container health
ssh root@192.168.1.20 'docker inspect couchdb --format="{{.State.Health.Status}}"'
```

### Database Operations

```bash
# List all databases
curl -u admin:changeme_secure_password http://192.168.1.20:5984/_all_dbs

# Get server info
curl http://192.168.1.20:5984/

# Get node configuration
curl -u admin:changeme_secure_password http://192.168.1.20:5984/_node/_local/_config

# Create a new database
curl -X PUT -u admin:changeme_secure_password http://192.168.1.20:5984/mydb

# Delete a database
curl -X DELETE -u admin:changeme_secure_password http://192.168.1.20:5984/mydb

# Get database info
curl -u admin:changeme_secure_password http://192.168.1.20:5984/mydb

# List all active tasks
curl -u admin:changeme_secure_password http://192.168.1.20:5984/_active_tasks
```

## Web Interface (Fauxton)

CouchDB includes Fauxton, a modern web-based administration interface.

**Access**: http://192.168.1.20:5984/_utils

### Features

- **Database Browser**: View and manage databases
- **Document Editor**: Create, read, update, and delete documents
- **Query Interface**: Run Mango queries and views
- **Replication Manager**: Configure and monitor replication
- **Configuration Editor**: Modify server settings
- **Active Tasks Monitor**: View running compaction and indexing tasks

## API Usage

### Basic Document Operations

#### Create a Document

```bash
# Create document with auto-generated ID
curl -X POST -u admin:changeme_secure_password \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}' \
  http://192.168.1.20:5984/mydb

# Create document with specific ID
curl -X PUT -u admin:changeme_secure_password \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane Doe","email":"jane@example.com"}' \
  http://192.168.1.20:5984/mydb/jane_001
```

#### Read a Document

```bash
# Get document by ID
curl -u admin:changeme_secure_password \
  http://192.168.1.20:5984/mydb/jane_001

# Get all documents
curl -u admin:changeme_secure_password \
  http://192.168.1.20:5984/mydb/_all_docs?include_docs=true
```

#### Update a Document

```bash
# Update requires document ID and current revision
curl -X PUT -u admin:changeme_secure_password \
  -H "Content-Type: application/json" \
  -d '{"_rev":"1-abc123","name":"Jane Smith","email":"jsmith@example.com"}' \
  http://192.168.1.20:5984/mydb/jane_001
```

#### Delete a Document

```bash
# Delete requires document ID and current revision
curl -X DELETE -u admin:changeme_secure_password \
  http://192.168.1.20:5984/mydb/jane_001?rev=2-def456
```

### Mango Query API

CouchDB supports MongoDB-style queries using the Mango query language.

```bash
# Create an index
curl -X POST -u admin:changeme_secure_password \
  -H "Content-Type: application/json" \
  -d '{"index":{"fields":["email"]},"name":"email-index"}' \
  http://192.168.1.20:5984/mydb/_index

# Query documents
curl -X POST -u admin:changeme_secure_password \
  -H "Content-Type: application/json" \
  -d '{"selector":{"email":{"$regex":".*@example.com"}},"limit":10}' \
  http://192.168.1.20:5984/mydb/_find
```

## Features and Capabilities

### Core Features

- **Document Storage**: JSON document storage with flexible schemas
- **HTTP/JSON API**: RESTful API for all operations
- **Multi-Version Concurrency Control (MVCC)**: Optimistic locking with revision tracking
- **MapReduce Views**: Custom indexing using JavaScript functions
- **Mango Queries**: Declarative JSON query language
- **Replication**: Master-master replication with conflict detection
- **Attachments**: Binary file storage attached to documents
- **Change Feeds**: Real-time notification of document changes

### CouchDB 3.5.0 Capabilities

Based on the server response, this installation includes:

- **access-ready**: Server is fully initialized and ready
- **partitioned**: Support for partitioned databases for better scalability
- **pluggable-storage-engines**: Custom storage engine support
- **reshard**: Database resharding for cluster rebalancing
- **scheduler**: Enhanced replication scheduler

## Backup and Recovery

### Manual Backup

```bash
# Backup all databases using replication
ssh root@192.168.1.20 'curl -X POST -u admin:changeme_secure_password \
  -H "Content-Type: application/json" \
  -d "{\"source\":\"http://admin:changeme_secure_password@localhost:5984/mydb\",\"target\":\"./backup/mydb.couch\",\"create_target\":true}" \
  http://localhost:5984/_replicate'

# Export database to JSON
ssh root@192.168.1.20 'curl -u admin:changeme_secure_password \
  "http://localhost:5984/mydb/_all_docs?include_docs=true" > mydb_backup.json'
```

### Volume Backup

```bash
# Stop CouchDB
ssh root@192.168.1.20 'cd /root/couchdb && docker compose down'

# Backup data volume
ssh root@192.168.1.20 'docker run --rm \
  -v couchdb_couchdb_data:/data \
  -v /root/backups:/backup \
  alpine tar czf /backup/couchdb-data-$(date +%Y%m%d).tar.gz -C /data .'

# Restart CouchDB
ssh root@192.168.1.20 'cd /root/couchdb && docker compose up -d'
```

### Restore from Volume Backup

```bash
# Stop CouchDB
ssh root@192.168.1.20 'cd /root/couchdb && docker compose down'

# Restore data volume
ssh root@192.168.1.20 'docker run --rm \
  -v couchdb_couchdb_data:/data \
  -v /root/backups:/backup \
  alpine sh -c "cd /data && tar xzf /backup/couchdb-data-20251013.tar.gz"'

# Start CouchDB
ssh root@192.168.1.20 'cd /root/couchdb && docker compose up -d'
```

## Monitoring and Maintenance

### Health Check

```bash
# Container health status
ssh root@192.168.1.20 'docker inspect couchdb --format="{{.State.Health.Status}}"'

# CouchDB up endpoint
curl http://192.168.1.20:5984/_up

# Node stats
curl -u admin:changeme_secure_password http://192.168.1.20:5984/_node/_local/_stats
```

### Performance Monitoring

```bash
# Active tasks (compaction, indexing, replication)
curl -u admin:changeme_secure_password http://192.168.1.20:5984/_active_tasks

# System information
curl -u admin:changeme_secure_password http://192.168.1.20:5984/_node/_local/_system

# Database statistics
curl -u admin:changeme_secure_password http://192.168.1.20:5984/mydb
```

### Log Management

```bash
# View recent logs
ssh root@192.168.1.20 'docker logs --tail 100 couchdb'

# Follow logs
ssh root@192.168.1.20 'docker logs -f couchdb'

# Export logs to file
ssh root@192.168.1.20 'docker logs couchdb > /root/couchdb-logs-$(date +%Y%m%d).log'
```

### Database Compaction

CouchDB uses MVCC which requires periodic compaction to reclaim disk space.

```bash
# Compact database
curl -X POST -u admin:changeme_secure_password \
  -H "Content-Type: application/json" \
  http://192.168.1.20:5984/mydb/_compact

# Compact views
curl -X POST -u admin:changeme_secure_password \
  -H "Content-Type: application/json" \
  http://192.168.1.20:5984/mydb/_compact/design_doc_name

# View compaction status
curl -u admin:changeme_secure_password http://192.168.1.20:5984/_active_tasks
```

## Troubleshooting

### Common Issues

#### Container Not Starting

```bash
# Check logs for errors
ssh root@192.168.1.20 'docker logs couchdb'

# Verify port availability
ssh root@192.168.1.20 'netstat -tuln | grep 5984'

# Check volume permissions
ssh root@192.168.1.20 'docker volume inspect couchdb_couchdb_data'
```

#### Connection Refused

```bash
# Verify container is running
ssh root@192.168.1.20 'docker ps --filter name=couchdb'

# Check container network
ssh root@192.168.1.20 'docker inspect couchdb --format="{{.NetworkSettings.Networks}}"'

# Test local connectivity
ssh root@192.168.1.20 'curl http://localhost:5984/'

# Test network connectivity
curl http://192.168.1.20:5984/
```

#### Authentication Failures

```bash
# Verify admin credentials in environment
ssh root@192.168.1.20 'docker exec couchdb env | grep COUCHDB'

# Check admin user in configuration
ssh root@192.168.1.20 'docker exec couchdb curl -s http://localhost:5984/_node/_local/_config/admins'
```

#### High Memory Usage

```bash
# Check container resource usage
ssh root@192.168.1.20 'docker stats couchdb --no-stream'

# View database disk usage
curl -u admin:changeme_secure_password http://192.168.1.20:5984/_all_dbs
# Then check each database size
curl -u admin:changeme_secure_password http://192.168.1.20:5984/mydb

# Consider compacting databases
curl -X POST -u admin:changeme_secure_password http://192.168.1.20:5984/mydb/_compact
```

### Debug Mode

```bash
# Enable debug logging
ssh root@192.168.1.20 'docker exec couchdb curl -X PUT \
  -u admin:changeme_secure_password \
  -d "\"debug\"" \
  http://localhost:5984/_node/_local/_config/log/level'

# View debug logs
ssh root@192.168.1.20 'docker logs -f couchdb'

# Restore normal logging
ssh root@192.168.1.20 'docker exec couchdb curl -X PUT \
  -u admin:changeme_secure_password \
  -d "\"info\"" \
  http://localhost:5984/_node/_local/_config/log/level'
```

## Security Considerations

### Network Security

- **Port Exposure**: Port 5984 is exposed on all interfaces (0.0.0.0)
- **Recommendation**: Use firewall rules or reverse proxy for production
- **Internal Access**: Consider restricting to LAN (192.168.1.0/24) if not publicly needed

### Authentication

- **Admin Party Mode**: Disabled (admin user required)
- **Password Security**: Default password should be changed immediately
- **User Management**: Create additional users via Fauxton or API

### Best Practices

1. **Change Default Password**: Update `COUCHDB_PASSWORD` immediately
2. **Regular Backups**: Implement automated backup schedule
3. **SSL/TLS**: Use reverse proxy (nginx) for HTTPS in production
4. **Firewall Rules**: Restrict access to trusted networks only
5. **Update Strategy**: Monitor for security updates and apply regularly

## Integration Examples

### Node.js (nano library)

```javascript
const nano = require('nano')('http://admin:changeme_secure_password@192.168.1.20:5984');

// Create database
const db = nano.db.use('myapp');

// Insert document
await db.insert({ name: 'John', email: 'john@example.com' }, 'user_001');

// Query documents
const result = await db.find({
  selector: { email: { $regex: '.*@example.com' } }
});
```

### Python (couchdb library)

```python
import couchdb

# Connect to server
server = couchdb.Server('http://admin:changeme_secure_password@192.168.1.20:5984/')

# Create/connect to database
db = server.create('myapp') if 'myapp' not in server else server['myapp']

# Insert document
doc = {'name': 'John', 'email': 'john@example.com'}
db.save(doc)

# Query documents
for row in db.view('_all_docs', include_docs=True):
    print(row.doc)
```

### curl Scripts

```bash
#!/bin/bash
# Example: Bulk document import

BASE_URL="http://admin:changeme_secure_password@192.168.1.20:5984"
DB_NAME="myapp"

# Create database
curl -X PUT "$BASE_URL/$DB_NAME"

# Bulk insert
curl -X POST "$BASE_URL/$DB_NAME/_bulk_docs" \
  -H "Content-Type: application/json" \
  -d '{
    "docs": [
      {"name": "Alice", "email": "alice@example.com"},
      {"name": "Bob", "email": "bob@example.com"},
      {"name": "Charlie", "email": "charlie@example.com"}
    ]
  }'
```

## Performance Tuning

### Configuration Optimization

```bash
# Increase max_dbs_open for large deployments
ssh root@192.168.1.20 'docker exec couchdb curl -X PUT \
  -u admin:changeme_secure_password \
  -d "\"500\"" \
  http://localhost:5984/_node/_local/_config/couchdb/max_dbs_open'

# Adjust compaction settings
ssh root@192.168.1.20 'docker exec couchdb curl -X PUT \
  -u admin:changeme_secure_password \
  -d "\"true\"" \
  http://localhost:5984/_node/_local/_config/compactions/enabled'
```

### Resource Limits

To set Docker resource limits, modify the docker-compose.yml:

```yaml
services:
  couchdb:
    # ... other config ...
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
```

## Related Documentation

- **Infrastructure Overview**: `/docs/infrastructure.md`
- **Docker Services**: `/docs/docker-containers-overview.md`
- **Official CouchDB Docs**: https://docs.couchdb.org/
- **CouchDB API Reference**: https://docs.couchdb.org/en/stable/api/index.html

## Deployment History

| Date | Version | Changes |
|------|---------|---------|
| 2025-10-13 | 3.5.0 | Initial deployment on 192.168.1.20 with single-node configuration |
| 2025-10-13 | 3.5.0 | Added public HTTPS access via NPM reverse proxy at https://couchdb.acmea.tech |

## Support and Resources

- **Official Documentation**: https://docs.couchdb.org/
- **Apache CouchDB Website**: https://couchdb.apache.org/
- **GitHub Repository**: https://github.com/apache/couchdb
- **Docker Hub**: https://hub.docker.com/_/couchdb
- **Community Forums**: https://lists.apache.org/list.html?user@couchdb.apache.org
