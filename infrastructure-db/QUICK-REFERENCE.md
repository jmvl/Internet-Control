# Infrastructure Database - Quick Reference

## Database Status

**Location:** `/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db`

**Current Inventory:**
- ✅ 18 Hosts (physical, VMs, containers)
- ✅ 11 Network interfaces
- ✅ 8 Storage devices
- ✅ 31 Docker containers
- ✅ 50 Services
- ✅ 16 Service dependencies
- ✅ 14 IP addresses

**Last Updated:** 2025-10-17

## Quick Commands

### Interactive Database Access

```bash
# Open database for queries
cd /Users/jm/Codebase/internet-control/infrastructure-db
sqlite3 infrastructure.db

# Pretty output
sqlite3 -header -column infrastructure.db
```

### Common Queries

**List all active hosts:**
```bash
sqlite3 -header -column infrastructure.db "SELECT hostname, host_type, management_ip, status FROM hosts WHERE status = 'active';"
```

**Docker container status:**
```bash
sqlite3 -header -column infrastructure.db "SELECT container_name, image, status, health_status FROM docker_containers ORDER BY health_status;"
```

**Network inventory:**
```bash
sqlite3 -header -column infrastructure.db "SELECT ip_address, h.hostname, h.host_type FROM ip_addresses ip LEFT JOIN hosts h ON ip.host_id = h.id ORDER BY ip_address;"
```

**Service health overview:**
```bash
sqlite3 -header -column infrastructure.db "SELECT service_name, status, criticality FROM services ORDER BY criticality, status;"
```

### Pre-Built Query Files

```bash
# Dependency analysis
sqlite3 infrastructure.db < queries/dependency_analysis.sql

# Network topology
sqlite3 infrastructure.db < queries/network_topology.sql

# Resource planning
sqlite3 infrastructure.db < queries/resource_planning.sql
```

## Discovery Scripts

### Manual Discovery

```bash
cd discovery

# Discover Docker hosts (requires SSH access)
python discover_docker.py

# Discover Proxmox infrastructure (requires API credentials)
python discover_proxmox.py

# Run complete sync
python sync_infrastructure.py
```

### Configuration

Edit `discovery/.env`:
```bash
DB_PATH=../infrastructure.db
PROXMOX_HOST=192.168.1.10
PROXMOX_USER=root@pam
PROXMOX_PASSWORD=your_password
DOCKER_HOSTS=root@192.168.1.20,root@192.168.1.9
SSH_KEY_PATH=~/.ssh/id_rsa
```

### Automated Scheduling

```bash
# Add to crontab for 5-minute updates
*/5 * * * * cd /Users/jm/Codebase/internet-control/infrastructure-db/discovery && python sync_infrastructure.py >> sync.log 2>&1
```

## Useful Queries

### Impact Analysis

**What breaks if OMV (192.168.1.9) goes down?**
```sql
SELECT DISTINCT s.service_name, s.criticality
FROM services s
WHERE s.id IN (
    SELECT sd.dependent_service_id
    FROM service_dependencies sd
    JOIN services dep ON sd.dependency_service_id = dep.id
    WHERE dep.host_id = (SELECT id FROM hosts WHERE management_ip = '192.168.1.9')
)
OR s.host_id = (SELECT id FROM hosts WHERE management_ip = '192.168.1.9');
```

### Dependency Tree

**Show what Supabase Studio depends on:**
```sql
SELECT
    dependent.service_name as depends_on,
    dependent.service_type,
    sd.dependency_type
FROM services s
JOIN service_dependencies sd ON s.id = sd.dependent_service_id
JOIN services dependent ON sd.dependency_service_id = dependent.id
WHERE s.service_name = 'Supabase Studio';
```

### Resource Availability

**Find hosts with available capacity:**
```sql
SELECT
    hostname,
    total_ram_mb,
    used_ram_mb,
    (total_ram_mb - COALESCE(used_ram_mb, 0)) as available_ram_mb,
    ROUND((COALESCE(used_ram_mb, 0) * 100.0) / total_ram_mb, 2) as utilization_pct
FROM hosts
WHERE status = 'active'
  AND total_ram_mb IS NOT NULL
  AND (COALESCE(used_ram_mb, 0) * 100.0) / total_ram_mb < 60
ORDER BY available_ram_mb DESC;
```

### Container Health

**Show unhealthy containers:**
```sql
SELECT
    dc.container_name,
    h.hostname as docker_host,
    dc.status,
    dc.health_status,
    dc.image
FROM docker_containers dc
JOIN hosts h ON dc.docker_host_id = h.id
WHERE dc.health_status IN ('unhealthy', 'starting')
   OR (dc.status = 'running' AND dc.health_status IS NULL);
```

### Service Criticality

**Critical services status:**
```sql
SELECT
    service_name,
    service_type,
    h.hostname,
    status,
    endpoint_url
FROM services s
LEFT JOIN hosts h ON s.host_id = h.id
WHERE criticality = 'critical'
ORDER BY status DESC, service_name;
```

## Maintenance

### Backup Database

```bash
# Create timestamped backup
sqlite3 infrastructure.db ".backup infrastructure_backup_$(date +%Y%m%d_%H%M%S).db"

# Export to SQL
sqlite3 infrastructure.db .dump > infrastructure_backup.sql
```

### Optimize Database

```bash
# Reclaim space and rebuild indexes
sqlite3 infrastructure.db "VACUUM; ANALYZE;"
```

### Clean Old History

```bash
# Keep only last 90 days of changes
sqlite3 infrastructure.db "DELETE FROM infrastructure_changes WHERE change_timestamp < datetime('now', '-90 days');"
```

## Python API Usage

```python
from discovery.db_utils import InfrastructureDB

# Initialize database connection
db = InfrastructureDB('/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db')

# Query hosts
hosts = db.execute_query("SELECT * FROM v_host_inventory")
for host in hosts:
    print(f"{host['hostname']}: {host['ram_utilization_pct']}% RAM")

# Update host resources
db.upsert_host({
    'hostname': 'pve2',
    'used_ram_mb': 32768
}, changed_by='manual_update')

# Find service dependencies
service_id = 5
affected = db.find_dependent_services(service_id)
print(f"Services depending on this: {len(affected)}")
```

## Views Reference

Pre-built views for common queries:

- `v_host_inventory` - Complete host list with resource utilization
- `v_network_topology` - Network layout with IP allocations
- `v_service_dependencies` - Service dependency relationships
- `v_docker_inventory` - Docker container inventory with health
- `v_recent_changes` - Infrastructure changes (last 30 days)

### Using Views

```sql
-- Host inventory with utilization
SELECT * FROM v_host_inventory WHERE ram_utilization_pct > 75;

-- Network topology
SELECT * FROM v_network_topology WHERE vlan_id = 10;

-- Service dependencies
SELECT * FROM v_service_dependencies WHERE dependency_criticality = 'critical';

-- Docker inventory
SELECT * FROM v_docker_inventory WHERE health_status = 'unhealthy';

-- Recent changes
SELECT * FROM v_recent_changes WHERE change_type = 'update';
```

## Troubleshooting

### Database Locked

```bash
# Check for active connections
lsof infrastructure.db

# Wait or kill stale connections
```

### Discovery Script Fails

```bash
# Verify SSH connectivity
ssh root@192.168.1.20 'docker ps'

# Test Proxmox API
curl -k https://192.168.1.10:8006/api2/json/version

# Check credentials
cat discovery/.env
```

### Missing Data

```bash
# Verify seed data loaded
sqlite3 infrastructure.db "SELECT COUNT(*) FROM hosts;"

# Expected: 18 hosts

# Re-run seed data if needed
sqlite3 infrastructure.db < seed_data.sql
```

## Key Files

```
infrastructure-db/
├── infrastructure.db              # SQLite database (active)
├── schema.sql                     # Database schema definition
├── seed_data.sql                  # Initial data from docs
├── QUICK-REFERENCE.md            # This file
├── README.md                      # Overview and setup
├── discovery/
│   ├── .env                       # Configuration (not in git)
│   ├── db_utils.py                # Database utilities
│   ├── discover_docker.py         # Docker discovery
│   ├── discover_proxmox.py        # Proxmox discovery
│   └── sync_infrastructure.py     # Master sync script
└── queries/
    ├── dependency_analysis.sql    # Impact analysis queries
    ├── network_topology.sql       # Network queries
    └── resource_planning.sql      # Capacity planning
```

## Support

- **Full Documentation:** `/docs/infrastructure-db/README.md`
- **Schema Reference:** `schema.sql` (with inline comments)
- **Main Infrastructure Docs:** `/docs/infrastructure.md`
- **Quick Start:** `/QUICK-START.md`
