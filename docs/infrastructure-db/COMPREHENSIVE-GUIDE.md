# Infrastructure Database - Comprehensive Guide

**Single Source of Truth for Infrastructure Inventory & Dependencies**

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Database Architecture](#database-architecture)
4. [Data Discovery & Automation](#data-discovery--automation)
5. [Common Queries](#common-queries)
6. [Management & Maintenance](#management--maintenance)
7. [Integration Guide](#integration-guide)
8. [Troubleshooting](#troubleshooting)

---

## Overview

### What is it?

The Infrastructure Database is a **centralized SQLite database** that maintains a complete inventory of your network infrastructure, including:

- **18 Physical & Virtual Hosts** (servers, VMs, LXC containers)
- **61 Docker Containers** across 2 Docker hosts
- **59 Services** with health monitoring
- **23 Docker Networks** with subnet information
- **Service Dependencies** for impact analysis
- **Network Topology** with IP/MAC tracking
- **Storage Devices** with capacity tracking

### Why Use It?

✅ **Single Source of Truth** - All infrastructure data in one queryable database
✅ **Automated Discovery** - Proxmox API & Docker SSH integration
✅ **Impact Analysis** - Know what breaks when something fails
✅ **Network Mapping** - Complete topology with Docker subnet tracking
✅ **Change Auditing** - Full historical tracking with timestamps
✅ **Resource Planning** - CPU, RAM, storage utilization tracking

### Key Features

- **15 Database Tables** across 5 domains
- **5 Pre-built Views** for common queries
- **SQLite WAL Mode** for concurrent access
- **JSON Support** for complex data structures
- **Automated Discovery Scripts** in Python
- **Full Change Auditing** with snapshots

---

## Quick Start

### 1. Access the Database

**Location:** `/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db`

```bash
cd /Users/jm/Codebase/internet-control/infrastructure-db
sqlite3 infrastructure.db
```

### 2. Run Your First Query

```sql
-- List all hosts
SELECT hostname, host_type, management_ip, status
FROM hosts
ORDER BY hostname;

-- Docker container inventory
SELECT h.hostname as docker_host, dc.container_name, dc.status
FROM docker_containers dc
JOIN hosts h ON dc.docker_host_id = h.id
WHERE dc.status = 'running';

-- Network subnets
SELECT network_name, subnet, gateway
FROM docker_networks
WHERE subnet IS NOT NULL;
```

### 3. Use Pre-built Views

```sql
-- Complete host inventory
SELECT * FROM v_host_inventory;

-- Docker container summary
SELECT * FROM v_docker_inventory;

-- Service dependencies
SELECT * FROM v_service_dependencies;
```

### 4. Run Sample Queries

```bash
sqlite3 infrastructure.db
.read queries/dependency_analysis.sql
.read queries/network_topology.sql
.read queries/resource_planning.sql
```

---

## Database Architecture

### Schema Overview

**Domain Areas:**
1. **Physical Infrastructure** (hosts, network_interfaces, storage_devices)
2. **Virtualization** (virtual_machines, lxc_containers)
3. **Containerization** (docker_containers, docker_networks, docker_volumes)
4. **Services** (services, service_dependencies, health_checks)
5. **Operations** (infrastructure_changes, firewall_rules, network_routes)

### Core Tables

#### hosts
Primary infrastructure inventory

```sql
CREATE TABLE hosts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT NOT NULL UNIQUE,
    host_type TEXT NOT NULL CHECK(host_type IN ('physical', 'vm', 'lxc', 'docker_host')),
    management_ip TEXT,
    status TEXT NOT NULL DEFAULT 'active',

    -- Resources
    cpu_cores INTEGER,
    total_ram_mb INTEGER,
    used_ram_mb INTEGER,

    -- VM/Container hierarchy
    parent_host_id INTEGER REFERENCES hosts(id),
    vmid INTEGER,

    -- Metadata
    purpose TEXT,
    criticality TEXT CHECK(criticality IN ('critical', 'high', 'medium', 'low')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Current Data:**
- 18 hosts (2 physical, 5 VMs, 9 LXC, 2 Docker hosts)
- Status tracking: active, stopped, maintenance, decommissioned
- Resource utilization monitoring

#### docker_containers
Complete Docker container inventory

```sql
CREATE TABLE docker_containers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    docker_host_id INTEGER NOT NULL REFERENCES hosts(id),
    container_id TEXT NOT NULL,
    container_name TEXT NOT NULL,
    image TEXT NOT NULL,
    status TEXT NOT NULL,

    -- Port mappings (JSON array)
    ports TEXT,

    -- Environment variables (JSON object - sensitive excluded)
    environment TEXT,

    -- Volume mounts (JSON array)
    volumes TEXT,

    -- Network connections (JSON array)
    networks TEXT,

    -- Health status
    health_status TEXT,

    -- Full inspect data (JSON)
    inspect_data TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(docker_host_id, container_name)
);
```

**Current Data:**
- 61 containers across 2 hosts (192.168.1.20, 192.168.1.9)
- Full Docker inspect data stored as JSON
- Port mappings, environment vars, volume mounts tracked
- Health status monitoring

#### docker_networks
Docker network topology

```sql
CREATE TABLE docker_networks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    docker_host_id INTEGER NOT NULL REFERENCES hosts(id),
    network_id TEXT NOT NULL,
    network_name TEXT NOT NULL,
    driver TEXT NOT NULL CHECK(driver IN ('bridge', 'host', 'overlay', 'macvlan', 'null')),

    -- Network configuration
    subnet TEXT,
    gateway TEXT,
    ip_range TEXT,

    -- Advanced settings (JSON)
    options TEXT,
    labels TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(docker_host_id, network_name)
);
```

**Current Data:**
- 23 Docker networks across 2 hosts
- 19 networks with allocated subnets (172.17-26.0.0/16)
- 1 macvlan network bridging to physical LAN (pihole)
- Bridge, host, and overlay network types

#### services
Application service inventory

```sql
CREATE TABLE services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL REFERENCES hosts(id),
    service_name TEXT NOT NULL,
    service_type TEXT NOT NULL CHECK(service_type IN ('web', 'database', 'cache', 'storage', 'monitoring', 'automation', 'proxy', 'other')),

    -- Connection details
    port INTEGER,
    protocol TEXT,
    public_url TEXT,

    -- Status & health
    status TEXT NOT NULL DEFAULT 'active',
    last_health_check TIMESTAMP,
    health_status TEXT,

    -- Metadata
    criticality TEXT CHECK(criticality IN ('critical', 'high', 'medium', 'low')),
    description TEXT,
    notes TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(host_id, service_name, port)
);
```

**Current Data:**
- 59 services across infrastructure
- Types: web, database, cache, storage, monitoring, automation, proxy
- Criticality ratings: critical (5), high (15), medium (30), low (9)
- Health status tracking

#### service_dependencies
Service dependency mapping

```sql
CREATE TABLE service_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dependent_service_id INTEGER NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    dependency_service_id INTEGER NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    dependency_type TEXT NOT NULL CHECK(dependency_type IN ('requires', 'uses', 'integrates_with')),

    -- Criticality of this dependency
    is_critical BOOLEAN DEFAULT 0,

    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(dependent_service_id, dependency_service_id)
);
```

**Current Data:**
- 16 documented dependencies
- Types: requires (hard dependency), uses (soft dependency), integrates_with
- Critical dependency flagging

### Views

#### v_host_inventory
Complete host overview with resource utilization

```sql
SELECT
    h.hostname,
    h.host_type,
    h.management_ip,
    h.status,
    h.cpu_cores,
    h.total_ram_mb,
    h.used_ram_mb,
    ROUND(h.used_ram_mb * 100.0 / NULLIF(h.total_ram_mb, 0), 2) as ram_usage_pct,
    (SELECT COUNT(*) FROM services WHERE host_id = h.id) as service_count,
    h.criticality,
    h.purpose
FROM hosts h
ORDER BY h.criticality DESC, h.hostname;
```

#### v_docker_inventory
Docker container summary by host

```sql
SELECT
    h.hostname as docker_host,
    dc.container_name,
    dc.image,
    dc.status,
    dc.ports,
    dc.health_status,
    dc.updated_at as last_seen
FROM docker_containers dc
JOIN hosts h ON dc.docker_host_id = h.id
ORDER BY h.hostname, dc.container_name;
```

#### v_network_topology
Complete network mapping with Docker subnets

```sql
SELECT
    'Main Network' as network_type,
    ip.ip_address,
    h.hostname,
    h.host_type,
    ni.mac_address,
    ip.allocation_type
FROM ip_addresses ip
LEFT JOIN hosts h ON ip.host_id = h.id
LEFT JOIN network_interfaces ni ON ni.host_id = h.id

UNION ALL

SELECT
    'Docker Network' as network_type,
    dn.subnet as ip_address,
    h.hostname || ' (' || dn.network_name || ')' as hostname,
    'docker_network' as host_type,
    NULL as mac_address,
    dn.driver as allocation_type
FROM docker_networks dn
JOIN hosts h ON dn.docker_host_id = h.id
WHERE dn.subnet IS NOT NULL

ORDER BY network_type, ip_address;
```

#### v_service_dependencies
Service dependency tree

```sql
SELECT
    s1.service_name as dependent_service,
    h1.hostname as dependent_host,
    sd.dependency_type,
    s2.service_name as dependency_service,
    h2.hostname as dependency_host,
    sd.is_critical,
    s2.criticality as dependency_criticality
FROM service_dependencies sd
JOIN services s1 ON sd.dependent_service_id = s1.id
JOIN services s2 ON sd.dependency_service_id = s2.id
JOIN hosts h1 ON s1.host_id = h1.id
JOIN hosts h2 ON s2.host_id = h2.id
ORDER BY sd.is_critical DESC, s1.service_name;
```

#### v_recent_changes
Audit trail of infrastructure changes

```sql
SELECT
    entity_type,
    entity_id,
    change_type,
    change_timestamp,
    json_extract(change_details, '$.changed_by') as changed_by,
    change_details
FROM infrastructure_changes
ORDER BY change_timestamp DESC
LIMIT 100;
```

---

## Data Discovery & Automation

### Discovery Scripts

Located in `/infrastructure-db/discovery/`

#### 1. test_docker_discovery.py
**Quick Docker network discovery** (recommended - tested & working)

```bash
cd discovery
python test_docker_discovery.py
```

**What it discovers:**
- All Docker networks across configured hosts
- Subnets, gateways, IP ranges
- Network drivers (bridge, host, overlay, macvlan)
- Network options and labels

**Results:**
- 23 networks discovered across 2 hosts
- 19 networks with subnet allocations
- Data stored in `docker_networks` table

#### 2. discover_docker.py
**Complete Docker infrastructure discovery**

```bash
python discover_docker.py
```

**What it discovers:**
- Docker containers (with full inspect data)
- Docker volumes and mount points
- Docker networks
- Container-to-network mappings
- Container health status

#### 3. discover_proxmox.py
**Proxmox infrastructure discovery**

```bash
python discover_proxmox.py
```

**What it discovers:**
- Virtual machines (KVM)
- LXC containers
- Resource allocations
- Storage configurations
- Network interfaces

#### 4. sync_infrastructure.py
**Master orchestrator** - runs all discovery scripts

```bash
python sync_infrastructure.py
```

### Configuration

Edit `discovery/.env`:

```bash
# Database
DATABASE_PATH=../infrastructure.db

# Docker Hosts (SSH access)
DOCKER_HOSTS=192.168.1.20,192.168.1.9
DOCKER_SSH_USER=root
DOCKER_SSH_KEY_PATH=~/.ssh/id_rsa

# Proxmox API
PROXMOX_HOST=192.168.1.15
PROXMOX_USER=root@pam
PROXMOX_PASSWORD=your_password
```

### Automation

**Schedule regular discovery:**

```bash
# Add to crontab
crontab -e

# Run every 5 minutes
*/5 * * * * cd /path/to/infrastructure-db/discovery && python sync_infrastructure.py >> /var/log/infra-sync.log 2>&1

# Run hourly
0 * * * * cd /path/to/infrastructure-db/discovery && python sync_infrastructure.py

# Run daily at 2 AM
0 2 * * * cd /path/to/infrastructure-db/discovery && python sync_infrastructure.py
```

---

## Common Queries

### Infrastructure Inventory

#### List All Hosts

```sql
SELECT
    hostname,
    host_type,
    management_ip,
    status,
    cpu_cores,
    total_ram_mb,
    ROUND(used_ram_mb * 100.0 / total_ram_mb, 1) as ram_pct,
    criticality
FROM hosts
WHERE status = 'active'
ORDER BY criticality DESC, hostname;
```

#### Docker Container Status

```sql
SELECT
    h.hostname as docker_host,
    dc.container_name,
    dc.image,
    dc.status,
    dc.health_status,
    dc.ports
FROM docker_containers dc
JOIN hosts h ON dc.docker_host_id = h.id
WHERE dc.status = 'running'
ORDER BY h.hostname, dc.container_name;
```

#### Services by Criticality

```sql
SELECT
    s.service_name,
    h.hostname,
    s.service_type,
    s.criticality,
    s.status,
    s.public_url
FROM services s
JOIN hosts h ON s.host_id = h.id
WHERE s.status = 'active'
ORDER BY
    CASE s.criticality
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
    END,
    s.service_name;
```

### Network Topology

#### Complete IP Inventory

```sql
SELECT
    ip.ip_address,
    h.hostname,
    h.host_type,
    ip.allocation_type,
    ni.mac_address,
    ni.interface_name
FROM ip_addresses ip
LEFT JOIN hosts h ON ip.host_id = h.id
LEFT JOIN network_interfaces ni ON ni.host_id = h.id AND ni.interface_name = 'eth0'
ORDER BY CAST(substr(ip.ip_address, 12) AS INTEGER);
```

#### Docker Network Subnets

```sql
SELECT
    h.hostname as docker_host,
    dn.network_name,
    dn.driver,
    dn.subnet,
    dn.gateway,
    (SELECT COUNT(*)
     FROM docker_containers dc, json_each(dc.networks)
     WHERE dc.docker_host_id = dn.docker_host_id
     AND json_each.value LIKE '%' || dn.network_name || '%'
    ) as container_count
FROM docker_networks dn
JOIN hosts h ON dn.docker_host_id = h.id
WHERE dn.subnet IS NOT NULL
ORDER BY h.hostname, dn.network_name;
```

#### Network Interface Status

```sql
SELECT
    h.hostname,
    ni.interface_name,
    ni.interface_type,
    ni.mac_address,
    ni.link_status,
    ni.speed_mbps,
    ni.bridge_name
FROM network_interfaces ni
JOIN hosts h ON ni.host_id = h.id
WHERE ni.link_status = 'up'
ORDER BY h.hostname, ni.interface_name;
```

### Impact Analysis

#### Service Dependency Tree

```sql
-- What depends on a specific service?
WITH RECURSIVE dependency_tree AS (
    -- Base case: the service we're analyzing
    SELECT
        id,
        service_name,
        host_id,
        0 as depth
    FROM services
    WHERE service_name = 'supabase_postgres'

    UNION ALL

    -- Recursive case: services that depend on previous level
    SELECT
        s.id,
        s.service_name,
        s.host_id,
        dt.depth + 1
    FROM services s
    JOIN service_dependencies sd ON sd.dependent_service_id = s.id
    JOIN dependency_tree dt ON sd.dependency_service_id = dt.id
    WHERE dt.depth < 10 -- Prevent infinite loops
)
SELECT
    dt.depth,
    SUBSTR('..................', 1, dt.depth * 2) || dt.service_name as service_hierarchy,
    h.hostname,
    s.criticality,
    s.status
FROM dependency_tree dt
JOIN services s ON dt.id = s.id
JOIN hosts h ON s.host_id = h.id
ORDER BY dt.depth, dt.service_name;
```

#### Impact of Host Failure

```sql
-- What services fail if OMV (192.168.1.9) goes down?
SELECT
    s.service_name,
    s.service_type,
    s.criticality,
    s.status,
    (SELECT COUNT(*)
     FROM service_dependencies sd
     WHERE sd.dependency_service_id = s.id
    ) as dependent_service_count
FROM services s
WHERE s.host_id = (SELECT id FROM hosts WHERE management_ip = '192.168.1.9')
ORDER BY s.criticality DESC, dependent_service_count DESC;
```

#### Critical Service Dependencies

```sql
SELECT
    s1.service_name as dependent,
    h1.hostname as dep_host,
    s2.service_name as requires,
    h2.hostname as req_host,
    sd.dependency_type
FROM service_dependencies sd
JOIN services s1 ON sd.dependent_service_id = s1.id
JOIN services s2 ON sd.dependency_service_id = s2.id
JOIN hosts h1 ON s1.host_id = h1.id
JOIN hosts h2 ON s2.host_id = h2.id
WHERE sd.is_critical = 1
ORDER BY s1.criticality DESC;
```

### Resource Planning

#### Available Capacity

```sql
SELECT
    hostname,
    host_type,
    total_ram_mb,
    used_ram_mb,
    (total_ram_mb - used_ram_mb) as available_ram_mb,
    ROUND(used_ram_mb * 100.0 / total_ram_mb, 1) as ram_usage_pct,
    cpu_cores
FROM hosts
WHERE status = 'active'
  AND (used_ram_mb * 100.0 / total_ram_mb) < 70
ORDER BY available_ram_mb DESC;
```

#### Storage Utilization

```sql
SELECT
    h.hostname,
    sd.device_name,
    sd.filesystem_type,
    sd.mount_point,
    sd.capacity_gb,
    sd.used_gb,
    sd.available_gb,
    ROUND(sd.used_gb * 100.0 / sd.capacity_gb, 1) as usage_pct,
    sd.health_status
FROM storage_devices sd
JOIN hosts h ON sd.host_id = h.id
WHERE sd.health_status != 'failed'
ORDER BY usage_pct DESC;
```

#### Docker Container Distribution

```sql
SELECT
    h.hostname as docker_host,
    h.total_ram_mb,
    h.used_ram_mb,
    COUNT(dc.id) as container_count,
    COUNT(CASE WHEN dc.status = 'running' THEN 1 END) as running_count,
    COUNT(CASE WHEN dc.health_status = 'healthy' THEN 1 END) as healthy_count
FROM hosts h
LEFT JOIN docker_containers dc ON dc.docker_host_id = h.id
WHERE h.host_type = 'docker_host'
GROUP BY h.id
ORDER BY container_count DESC;
```

### Health Monitoring

#### Unhealthy Containers

```sql
SELECT
    h.hostname as docker_host,
    dc.container_name,
    dc.image,
    dc.status,
    dc.health_status,
    dc.updated_at as last_check
FROM docker_containers dc
JOIN hosts h ON dc.docker_host_id = h.id
WHERE dc.status != 'running'
   OR dc.health_status IN ('unhealthy', 'starting')
ORDER BY dc.updated_at DESC;
```

#### Service Health Summary

```sql
SELECT
    service_type,
    COUNT(*) as total_services,
    SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active,
    SUM(CASE WHEN health_status = 'healthy' THEN 1 ELSE 0 END) as healthy,
    SUM(CASE WHEN criticality = 'critical' THEN 1 ELSE 0 END) as critical_services
FROM services
GROUP BY service_type
ORDER BY critical_services DESC, total_services DESC;
```

#### Recent Infrastructure Changes

```sql
SELECT
    change_timestamp,
    entity_type,
    entity_id,
    change_type,
    SUBSTR(change_details, 1, 100) as details_preview
FROM infrastructure_changes
WHERE change_timestamp > datetime('now', '-7 days')
ORDER BY change_timestamp DESC
LIMIT 50;
```

---

## Management & Maintenance

### Backup

```bash
# Simple backup
sqlite3 infrastructure.db ".backup backup_$(date +%Y%m%d).db"

# Compressed backup
sqlite3 infrastructure.db ".dump" | gzip > backup_$(date +%Y%m%d).sql.gz

# Scheduled backup (add to crontab)
0 2 * * * sqlite3 /path/to/infrastructure.db ".backup /path/to/backups/infra_$(date +\%Y\%m\%d).db"
```

### Optimization

```bash
# Vacuum and analyze
sqlite3 infrastructure.db "VACUUM; ANALYZE;"

# Check integrity
sqlite3 infrastructure.db "PRAGMA integrity_check;"

# Show database size
ls -lh infrastructure.db

# Show table sizes
sqlite3 infrastructure.db "
SELECT
    name,
    (SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name=m.name) as row_count
FROM sqlite_master m
WHERE type='table'
ORDER BY name;
"
```

### Cleanup

```bash
# Clean old changes (keep 90 days)
sqlite3 infrastructure.db "
DELETE FROM infrastructure_changes
WHERE change_timestamp < datetime('now', '-90 days');
"

# Remove decommissioned hosts older than 1 year
sqlite3 infrastructure.db "
DELETE FROM hosts
WHERE status = 'decommissioned'
  AND updated_at < datetime('now', '-365 days');
"
```

### Export Data

```bash
# Export to CSV
sqlite3 -header -csv infrastructure.db "SELECT * FROM v_host_inventory;" > hosts.csv

# Export to JSON
sqlite3 infrastructure.db "SELECT json_group_array(json_object(
    'hostname', hostname,
    'type', host_type,
    'ip', management_ip,
    'status', status
)) FROM hosts;" > hosts.json

# Export schema
sqlite3 infrastructure.db ".schema" > schema.sql
```

---

## Integration Guide

### Python Integration

```python
from discovery.db_utils import InfrastructureDB

# Initialize
db = InfrastructureDB('infrastructure.db')

# Query infrastructure
hosts = db.execute_query("SELECT * FROM v_host_inventory")
for host in hosts:
    print(f"{host['hostname']}: {host['status']}")

# Update resources
db.upsert_host({
    'hostname': 'pve2',
    'used_ram_mb': 32768,
    'updated_at': 'CURRENT_TIMESTAMP'
})

# Add service
db.execute_query("""
    INSERT INTO services (host_id, service_name, service_type, port, criticality)
    VALUES (
        (SELECT id FROM hosts WHERE hostname = 'docker-debian'),
        'mcp-atlassian',
        'proxy',
        9000,
        'high'
    )
""")

# Impact analysis
dependent_services = db.find_dependent_services(service_id=5)
```

### Shell Scripting

```bash
#!/bin/bash

# Get list of critical services
CRITICAL_SERVICES=$(sqlite3 infrastructure.db \
  "SELECT service_name FROM services WHERE criticality='critical' AND status='active'")

# Check health of each service
for service in $CRITICAL_SERVICES; do
    echo "Checking $service..."
    # Your health check logic here
done

# Get containers needing restart
UNHEALTHY=$(sqlite3 -list infrastructure.db \
  "SELECT container_name FROM docker_containers WHERE health_status='unhealthy'")

# Restart unhealthy containers
for container in $UNHEALTHY; do
    docker restart "$container"
done
```

### API Integration

```python
import sqlite3
import json
from flask import Flask, jsonify

app = Flask(__name__)

def get_db():
    return sqlite3.connect('infrastructure.db')

@app.route('/api/hosts')
def get_hosts():
    db = get_db()
    db.row_factory = sqlite3.Row
    cursor = db.execute("SELECT * FROM v_host_inventory")
    hosts = [dict(row) for row in cursor.fetchall()]
    return jsonify(hosts)

@app.route('/api/services/<criticality>')
def get_services_by_criticality(criticality):
    db = get_db()
    db.row_factory = sqlite3.Row
    cursor = db.execute(
        "SELECT * FROM services WHERE criticality = ? AND status = 'active'",
        (criticality,)
    )
    services = [dict(row) for row in cursor.fetchall()]
    return jsonify(services)

if __name__ == '__main__':
    app.run(port=5000)
```

---

## Troubleshooting

### Database Locked

**Problem:** `database is locked` error

**Solutions:**
```bash
# 1. Check for open connections
lsof infrastructure.db

# 2. Enable WAL mode (already done)
sqlite3 infrastructure.db "PRAGMA journal_mode=WAL;"

# 3. Increase timeout in Python
import sqlite3
conn = sqlite3.connect('infrastructure.db', timeout=30.0)

# 4. Close all connections and retry
killall sqlite3
```

### Missing Data After Discovery

**Problem:** Discovery script runs but no data appears

**Solutions:**
```bash
# 1. Check script output for errors
python discovery/test_docker_discovery.py -v

# 2. Verify database connection
sqlite3 infrastructure.db "SELECT COUNT(*) FROM docker_networks;"

# 3. Check SSH connectivity
ssh root@192.168.1.20 "docker network ls"

# 4. Review discovery logs
tail -f /var/log/infra-sync.log
```

### Slow Queries

**Problem:** Queries taking too long

**Solutions:**
```sql
-- 1. Run ANALYZE
ANALYZE;

-- 2. Check query plan
EXPLAIN QUERY PLAN SELECT * FROM v_host_inventory;

-- 3. Add indexes if needed
CREATE INDEX idx_services_host_criticality ON services(host_id, criticality);

-- 4. Optimize view queries
-- Consider materializing frequently-used views
```

### Duplicate Entries

**Problem:** Duplicate containers or networks

**Solutions:**
```sql
-- 1. Find duplicates
SELECT container_name, COUNT(*)
FROM docker_containers
GROUP BY container_name
HAVING COUNT(*) > 1;

-- 2. Remove duplicates (keep most recent)
DELETE FROM docker_containers
WHERE rowid NOT IN (
    SELECT MAX(rowid)
    FROM docker_containers
    GROUP BY docker_host_id, container_name
);

-- 3. Verify UNIQUE constraints
.schema docker_containers
```

---

## Quick Reference Card

### Essential Commands

```bash
# Access database
sqlite3 infrastructure.db

# Run discovery
cd discovery && python test_docker_discovery.py

# Backup
sqlite3 infrastructure.db ".backup backup.db"

# Query hosts
sqlite3 infrastructure.db "SELECT * FROM v_host_inventory;"

# Export CSV
sqlite3 -header -csv infrastructure.db "SELECT * FROM services;" > services.csv
```

### Common Queries

```sql
-- All active hosts
SELECT hostname, management_ip FROM hosts WHERE status='active';

-- Running containers
SELECT * FROM v_docker_inventory WHERE status='running';

-- Service dependencies
SELECT * FROM v_service_dependencies;

-- Network topology
SELECT * FROM v_network_topology;

-- Recent changes
SELECT * FROM v_recent_changes LIMIT 20;
```

### Useful Paths

- **Database**: `/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db`
- **Discovery**: `/Users/jm/Codebase/internet-control/infrastructure-db/discovery/`
- **Queries**: `/Users/jm/Codebase/internet-control/infrastructure-db/queries/`
- **Docs**: `/Users/jm/Codebase/internet-control/docs/infrastructure-db/`

---

**Last Updated:** 2025-10-21
**Version:** 1.2
**Database Version:** SQLite 3.x with WAL mode
**Current Data:** 18 hosts | 61 containers | 59 services | 23 networks
