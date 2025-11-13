# Infrastructure Database System

A comprehensive SQLite-based infrastructure management system for tracking hosts, services, network topology, and dependencies across your entire infrastructure.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Database Schema](#database-schema)
- [Automated Discovery](#automated-discovery)
- [Query Examples](#query-examples)
- [Maintenance](#maintenance)

## Overview

This system provides:

- **Comprehensive Inventory**: Track physical hosts, VMs, containers, and services
- **Dependency Mapping**: Understand service dependencies and impact analysis
- **Network Topology**: Complete network layout with IP allocations and routing
- **Resource Planning**: Monitor resource utilization and capacity planning
- **Historical Tracking**: Audit trail of all infrastructure changes
- **Automated Discovery**: Scripts to auto-update from Proxmox and Docker hosts

## Features

### Core Capabilities

1. **Multi-Layer Infrastructure Tracking**
   - Physical servers and network devices
   - Virtual machines (Proxmox QEMU/KVM)
   - LXC containers
   - Docker containers with full configuration
   - Network infrastructure (bridges, VLANs, routing)

2. **Dependency Analysis**
   - Service-to-service dependency graphs
   - Impact analysis (what breaks if X fails?)
   - Critical path identification
   - Cross-host dependency visualization

3. **Network Management**
   - Complete IP address inventory
   - MAC address tracking
   - VLAN configuration
   - Routing table management
   - Network path tracing

4. **Resource Monitoring**
   - CPU and RAM allocation tracking
   - Storage capacity management
   - Container resource limits
   - Overcommit ratio calculations

5. **Automated Discovery**
   - Proxmox API integration
   - Docker host SSH inventory
   - Scheduled synchronization
   - Change detection and logging

## Quick Start

### ✅ Current Status (2025-10-17)

**Database:** `/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db`

**Inventory Loaded:**
- ✅ 18 Hosts (physical, VMs, LXC containers, Docker hosts)
- ✅ 11 Network interfaces
- ✅ 8 Storage devices (OMV: 6-disk BTRFS + MergerFS)
- ✅ 14 IP addresses (192.168.1.0/24 network)
- ✅ 31 Docker containers (2 hosts: pct111 & OMV)
- ✅ 50 Services with health monitoring
- ✅ 16 Service dependencies mapped

**Health Status:**
- docker-host-pct111: 17 containers (14 healthy, 1 unhealthy: supabase-realtime)
- docker-host-omv: 14 containers (6 healthy, 1 unhealthy: wallabag-mariadb)
- 9 critical services monitored

### 1. Initialize Database (✅ COMPLETED)

```bash
cd /Users/jm/Codebase/internet-control/infrastructure-db

# Create the database
sqlite3 infrastructure.db < schema.sql

# Load seed data from documentation
sqlite3 infrastructure.db < seed_data.sql
```

### 2. Set Up Discovery Scripts (✅ COMPLETED)

```bash
cd discovery

# Install Python dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your credentials
```

### 3. Run Initial Discovery (⏳ READY - requires credentials)

```bash
# Discover Proxmox infrastructure
python discover_proxmox.py

# Discover Docker containers
python discover_docker.py

# Or run complete sync
python sync_infrastructure.py
```

### 4. Query Your Infrastructure (✅ TESTED)

```bash
# Open database
sqlite3 ../infrastructure.db

# Run sample queries
.read ../queries/dependency_analysis.sql
.read ../queries/network_topology.sql
.read ../queries/resource_planning.sql
```

**Quick Reference:** See `QUICK-REFERENCE.md` for common commands and queries.

## Database Schema

### Domain Organization

The database is organized into 5 logical domains:

#### 1. Physical Infrastructure
- **hosts**: All physical/virtual hosts, VMs, containers
- **network_interfaces**: NICs, bridges, VLAN interfaces
- **storage_devices**: Disks, RAID arrays, filesystems

#### 2. Network Infrastructure
- **networks**: Subnets, VLANs, network segments
- **ip_addresses**: IP allocations (static/DHCP/reserved)
- **network_routes**: Routing tables and gateways
- **firewall_rules**: OPNsense/iptables rule inventory

#### 3. Virtualization Layer
- **virtual_machines**: Proxmox VMs (QEMU/KVM)
- **lxc_containers**: Proxmox LXC containers
- **docker_containers**: Container instances with config
- **docker_volumes**: Persistent volume mappings
- **docker_networks**: Docker bridge/overlay networks

#### 4. Application Services
- **services**: Application services and endpoints
- **service_dependencies**: Service dependency graph (N:N)

#### 5. Operations & Versioning
- **infrastructure_changes**: Complete audit log
- **health_checks**: Service health monitoring results

### Key Relationships

```
hosts (1) -----> (N) network_interfaces
hosts (1) -----> (N) storage_devices
hosts (1) -----> (N) ip_addresses
hosts (1) -----> (N) services
hosts (1) -----> (N) docker_containers
docker_containers (N) <-----> (N) docker_volumes
services (N) <-----> (N) service_dependencies
```

### Views

Pre-built views for common queries:

- `v_host_inventory`: Complete host inventory with utilization
- `v_network_topology`: Network layout with IP allocations
- `v_service_dependencies`: Service dependency tree
- `v_docker_inventory`: Docker container inventory with health
- `v_recent_changes`: Recent infrastructure changes (last 30 days)

## Automated Discovery

### Proxmox Discovery

Connects to Proxmox API and discovers:
- Cluster nodes with resource allocation
- VMs (QEMU/KVM) with network and storage config
- LXC containers with mount points and features

```bash
python discovery/discover_proxmox.py
```

### Docker Discovery

Connects via SSH to Docker hosts and discovers:
- Container instances with full inspect data
- Volume mappings and storage
- Network attachments
- Resource limits (CPU/RAM)
- Health status

```bash
python discovery/discover_docker.py
```

### Complete Sync

Orchestrates all discovery tasks:

```bash
python discovery/sync_infrastructure.py
```

Outputs beautiful terminal tables with:
- Discovery progress per component
- Success/failure status
- Infrastructure statistics
- Error details

### Scheduling Automated Sync

Set up cron job for periodic synchronization:

```bash
# Add to crontab (every 5 minutes)
*/5 * * * * cd /Users/jm/Codebase/internet-control/infrastructure-db/discovery && python sync_infrastructure.py >> sync.log 2>&1
```

## Query Examples

### Dependency Analysis

**What services fail if OMV goes down?**

```sql
SELECT s.service_name, s.service_type, s.criticality
FROM services s
WHERE s.id IN (
    SELECT sd.dependent_service_id
    FROM service_dependencies sd
    JOIN services dep ON sd.dependency_service_id = dep.id
    WHERE dep.host_id = (SELECT id FROM hosts WHERE management_ip = '192.168.1.9')
);
```

**Show dependency tree for Supabase:**

```sql
-- See queries/dependency_analysis.sql for full recursive CTE
```

### Network Topology

**List all IP allocations:**

```sql
SELECT ip.ip_address, h.hostname, h.host_type, ip.allocation_type
FROM ip_addresses ip
LEFT JOIN hosts h ON ip.host_id = h.id
ORDER BY ip.ip_address;
```

**Find available IPs in subnet:**

```sql
-- See queries/network_topology.sql for implementation
```

### Resource Planning

**Find hosts with available capacity:**

```sql
SELECT hostname, total_ram_mb, used_ram_mb,
       ROUND((used_ram_mb * 100.0) / total_ram_mb, 2) as utilization_pct
FROM hosts
WHERE status = 'active'
  AND (used_ram_mb * 100.0) / total_ram_mb < 60
ORDER BY utilization_pct;
```

**Storage capacity overview:**

```sql
SELECT h.hostname, SUM(sd.capacity_gb) as total_gb,
       SUM(sd.used_gb) as used_gb
FROM storage_devices sd
JOIN hosts h ON sd.host_id = h.id
GROUP BY h.hostname;
```

### Historical Analysis

**Recent infrastructure changes:**

```sql
SELECT change_timestamp, change_type, entity_type, description
FROM infrastructure_changes
WHERE change_timestamp >= datetime('now', '-7 days')
ORDER BY change_timestamp DESC;
```

## Maintenance

### Database Backup

```bash
# Backup database
sqlite3 infrastructure.db ".backup infrastructure_backup_$(date +%Y%m%d).db"

# Or export to SQL
sqlite3 infrastructure.db .dump > infrastructure_backup.sql
```

### Vacuum and Optimize

```bash
# Reclaim space and optimize
sqlite3 infrastructure.db "VACUUM; ANALYZE;"
```

### Clean Old Change History

```bash
# Keep only last 90 days of changes
sqlite3 infrastructure.db "DELETE FROM infrastructure_changes WHERE change_timestamp < datetime('now', '-90 days');"
```

### Update Service Health

```bash
# Manual health check (example)
sqlite3 infrastructure.db "
INSERT INTO health_checks (service_id, status, response_time_ms)
VALUES (
    (SELECT id FROM services WHERE service_name = 'Supabase Studio'),
    'healthy',
    120
);
"
```

## Advanced Usage

### Custom Queries

Create your own queries in the `queries/` directory:

```sql
-- queries/my_custom_query.sql
SELECT ...
FROM ...
WHERE ...
```

### Python Integration

```python
from discovery.db_utils import InfrastructureDB

db = InfrastructureDB('../infrastructure.db')

# Get all active hosts
hosts = db.execute_query("SELECT * FROM hosts WHERE status = 'active'")
for host in hosts:
    print(f"{host['hostname']}: {host['management_ip']}")

# Update host resources
db.upsert_host({
    'hostname': 'pve2',
    'used_ram_mb': 32768,
    'cpu_cores': 24
}, changed_by='manual_update')
```

### API Integration

Build REST API on top of the database:

```python
from flask import Flask, jsonify
from db_utils import InfrastructureDB

app = Flask(__name__)
db = InfrastructureDB('infrastructure.db')

@app.route('/api/hosts')
def get_hosts():
    hosts = db.execute_query("SELECT * FROM v_host_inventory")
    return jsonify(hosts)

@app.route('/api/services/dependencies/<service_name>')
def get_dependencies(service_name):
    deps = db.find_dependent_services(service_name)
    return jsonify(deps)
```

## Troubleshooting

### Database Locked Error

```bash
# Check for active connections
lsof infrastructure.db

# Kill stale connections or wait for completion
```

### Discovery Script Fails

```bash
# Check credentials
cat .env

# Test SSH connectivity
ssh root@192.168.1.20 'docker ps'

# Test Proxmox API
curl -k https://192.168.1.10:8006/api2/json/version
```

### Missing Data

```bash
# Verify seed data loaded
sqlite3 infrastructure.db "SELECT COUNT(*) FROM hosts;"

# Re-run seed data if needed
sqlite3 infrastructure.db < seed_data.sql
```

## Future Enhancements

- [ ] OPNsense API integration for firewall rule discovery
- [ ] Network device SNMP polling for interface statistics
- [ ] Service health monitoring automation
- [ ] Web UI for visualization and management
- [ ] Grafana dashboard integration
- [ ] Ansible dynamic inventory plugin
- [ ] Slack/Discord notifications for changes
- [ ] Backup automation and versioning

## Contributing

To add new infrastructure components:

1. Update `schema.sql` with new tables
2. Add seed data to `seed_data.sql`
3. Create discovery script in `discovery/`
4. Add sample queries to `queries/`
5. Update this documentation

## License

Internal use only - part of personal infrastructure management system.

## Support

For issues or questions, consult:
- `/docs/infrastructure.md` - Main infrastructure documentation
- `/docs/QUICK-START.md` - Emergency recovery procedures
- Schema comments in `schema.sql`
- Query examples in `queries/` directory
