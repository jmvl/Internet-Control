# Infrastructure Database System

SQLite-based infrastructure management database with automated discovery and dependency tracking.

## Quick Start

```bash
# 1. Initialize database (✅ COMPLETED)
sqlite3 infrastructure.db < schema.sql
sqlite3 infrastructure.db < seed_data.sql

# 2. Set up discovery (✅ COMPLETED)
cd discovery
pip install -r requirements.txt
cp .env.example .env
# Edit .env with credentials

# 3. Run discovery (✅ DOCKER NETWORKS DISCOVERED)
python test_docker_discovery.py  # Quick Docker network discovery
python sync_infrastructure.py     # Full sync (all sources)
```

## Current Status (2025-10-17)

**Database:** `/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db`

**Discovered & Loaded:**
- ✅ 15 Active hosts (physical, VMs, LXC containers, Docker hosts)
- ✅ 14 IP addresses on main network (192.168.1.0/24)
- ✅ 23 Docker networks (19 with allocated subnets)
- ✅ 31 Docker containers across 2 hosts
- ✅ 50 Services with health monitoring
- ✅ 16 Service dependencies mapped
- ✅ 11 Network interfaces
- ✅ 8 Storage devices

**Network Discovery:**
- ✅ Main LAN topology (192.168.1.0/24)
- ✅ Docker bridge networks on 192.168.1.20 (Supabase stack: 172.18.0.0/16, n8n: 172.19.0.0/16, +9 more)
- ✅ Docker bridge networks on 192.168.1.9 (Immich: 172.18.0.0/16, Nginx PM: 172.19.0.0/16, +6 more)
- ✅ Macvlan network (pihole_macvlan on physical network)

**Documentation:**
- ✅ Complete network topology: `NETWORK-TOPOLOGY.md`
- ✅ Quick reference guide: `QUICK-REFERENCE.md`
- ✅ Automated discovery scripts with WAL mode for concurrency

## Directory Structure

```
infrastructure-db/
├── schema.sql                     # Database schema (15 tables, 5 views)
├── seed_data.sql                  # Initial data from documentation
├── infrastructure.db              # SQLite database (active, WAL mode)
├── NETWORK-TOPOLOGY.md            # Complete network visualization
├── QUICK-REFERENCE.md             # Quick command reference
├── discovery/                     # Automated discovery scripts
│   ├── requirements.txt           # Python dependencies (installed)
│   ├── .env                       # Configuration (active)
│   ├── db_utils.py                # Database utilities (WAL mode, upsert methods)
│   ├── discover_proxmox.py        # Proxmox API discovery
│   ├── discover_docker.py         # Docker SSH discovery (full)
│   ├── test_docker_discovery.py   # Quick Docker network discovery (working)
│   └── sync_infrastructure.py     # Master sync orchestrator
├── queries/                       # Sample SQL queries
│   ├── dependency_analysis.sql    # Impact analysis, dependency trees
│   ├── network_topology.sql       # IP inventory, routing, VLANs
│   └── resource_planning.sql      # Capacity planning, utilization
└── README.md                      # This file
```

## Core Features

- **15 database tables** across 5 domains (physical, network, virtualization, services, operations)
- **Automated discovery** from Proxmox API and Docker hosts via SSH
- **Docker network discovery** - 23 networks with subnet/gateway information
- **Dependency tracking** with recursive queries for impact analysis
- **Network topology** mapping with IP/MAC tracking + Docker subnets
- **Resource monitoring** (CPU, RAM, storage)
- **Change auditing** with full historical tracking (WAL mode enabled)
- **5 pre-built views** for common queries
- **Concurrency support** via SQLite WAL mode with 30-second timeouts

## Common Operations

### Query Infrastructure

```bash
# Interactive SQL
sqlite3 infrastructure.db

# Run sample queries
.read queries/dependency_analysis.sql
.read queries/network_topology.sql
.read queries/resource_planning.sql
```

### Automated Discovery

```bash
cd discovery

# Quick Docker network discovery (recommended - tested and working)
python test_docker_discovery.py

# Full Docker discovery (containers, volumes, networks)
python discover_docker.py

# Proxmox infrastructure
python discover_proxmox.py

# Complete sync (all sources)
python sync_infrastructure.py
```

**Recent Discovery Results (2025-10-17):**
- Discovered 23 Docker networks across 2 hosts
- Mapped 19 subnets (172.17-26.0.0/16 ranges)
- Found 1 macvlan network bridging to physical LAN
- All data stored in `docker_networks` table

### Schedule Automation

```bash
# Add to crontab for 5-minute syncs
*/5 * * * * cd /path/to/infrastructure-db/discovery && python sync_infrastructure.py
```

## Key Queries

**Impact Analysis:**
```sql
-- What fails if OMV goes down?
SELECT s.service_name, s.criticality
FROM services s WHERE s.id IN (
    SELECT sd.dependent_service_id FROM service_dependencies sd
    JOIN services dep ON sd.dependency_service_id = dep.id
    WHERE dep.host_id = (SELECT id FROM hosts WHERE management_ip = '192.168.1.9')
);
```

**Resource Availability:**
```sql
-- Hosts with capacity for new workloads
SELECT hostname, (total_ram_mb - used_ram_mb) as available_mb
FROM hosts WHERE status = 'active' AND (used_ram_mb * 100.0 / total_ram_mb) < 60;
```

**Network Topology:**
```sql
-- Complete IP inventory (main network)
SELECT ip_address, h.hostname, h.host_type, ip.allocation_type
FROM ip_addresses ip LEFT JOIN hosts h ON ip.host_id = h.id
ORDER BY ip_address;

-- Docker network subnets
SELECT h.hostname as docker_host, dn.network_name, dn.subnet, dn.gateway
FROM docker_networks dn
JOIN hosts h ON dn.docker_host_id = h.id
WHERE dn.subnet IS NOT NULL
ORDER BY h.hostname, dn.network_name;
```

## Database Schema Highlights

- **hosts**: Physical servers, VMs, LXC, Docker hosts with resource tracking
- **docker_containers**: Full inspect data (env vars, volumes, networks, health)
- **docker_networks**: Network topology with subnets, gateways, drivers (bridge/host/overlay/macvlan/null)
- **docker_volumes**: Volume mappings and mount points
- **services**: Application services with health monitoring
- **service_dependencies**: N:N relationships with dependency types
- **infrastructure_changes**: Complete audit trail with JSON snapshots

## Documentation

Full documentation: `/docs/infrastructure-db/README.md`

- Detailed schema reference
- Advanced query examples
- Python API integration
- Troubleshooting guide
- Future roadmap

## Requirements

- Python 3.8+
- SQLite 3.35+ (for JSON functions)
- SSH access to Docker hosts
- Proxmox API credentials

## Maintenance

```bash
# Backup
sqlite3 infrastructure.db ".backup backup_$(date +%Y%m%d).db"

# Optimize
sqlite3 infrastructure.db "VACUUM; ANALYZE;"

# Clean old changes (keep 90 days)
sqlite3 infrastructure.db "DELETE FROM infrastructure_changes WHERE change_timestamp < datetime('now', '-90 days');"
```

## Integration Examples

```python
from discovery.db_utils import InfrastructureDB

db = InfrastructureDB('infrastructure.db')

# Query infrastructure
hosts = db.execute_query("SELECT * FROM v_host_inventory")

# Update resources
db.upsert_host({'hostname': 'pve2', 'used_ram_mb': 32768})

# Impact analysis
affected = db.find_dependent_services(service_id=5)
```

## Recent Updates

**2025-10-17:**
- ✅ Database initialized with seed data (15 hosts, 31 containers, 50 services)
- ✅ Docker network discovery implemented and tested
- ✅ 23 Docker networks discovered across 2 hosts with subnet information
- ✅ Added `test_docker_discovery.py` for quick network discovery
- ✅ Enhanced `db_utils.py` with WAL mode and upsert methods for volumes/networks
- ✅ Fixed schema to support "null" driver type for Docker networks
- ✅ Created `NETWORK-TOPOLOGY.md` with complete infrastructure visualization

Created: 2025-10-17
Version: 1.1
Last Discovery: 2025-10-17
