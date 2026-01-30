# Infrastructure Database - Optimized ER Diagram
Generated: 2026-01-29 (Post-Migration 001)

## ASCII ER Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        INFRASTRUCTURE DATABASE - ENTITY RELATIONSHIP DIAGRAM                    │
│                              (POST MIGRATION 001 - MODERATE REFACTORING)                         │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│     NETWORKS     │
├──────────────────┤
│ id (PK)          │───┐
│ network_name     │   │
│ cidr             │   │
│ vlan_id          │   │
│ gateway          │   │
│ security_zone    │   │
│ ...              │   │
└──────────────────┘   │
                        │
        ┌───────────────┴────────────────┐
        │                               │
        ▼                               ▼
┌──────────────────┐         ┌──────────────────┐
│   IP_ADDRESSES   │         │  NETWORK_ROUTES  │
├──────────────────┤         ├──────────────────┤
│ id (PK)          │         │ id (PK)          │
│ ip_address       │         │ source_network_id│
│ network_id (FK)  │◄────────│ destination      │
│ interface_id (FK│─┐       │ gateway_ip       │
│ host_id (FK)     │ │       │ gateway_host_id  │
│ allocation_type  │ │       │ ...              │
│ ...              │ │       └──────────────────┘
└──────────────────┘ │
        │             │
        │             └──────────────────────────────────────┐
        │                                                    │
        ▼                                                    ▼
┌──────────────────────────────┐                   ┌──────────────────┐
│      NETWORK_INTERFACES      │                   │     HOSTS       │◄─────────────┐
├──────────────────────────────┤                   ├──────────────────┤              │
│ id (PK)                      │                   │ id (PK)          │              │
│ host_id                      │                   │ hostname         │              │
│ interface_name               │                   │ host_type        │              │
│ interface_type               │                   │ management_ip    │              │
│ mac_address                  │                   │ status           │              │
│ parent_interface_id (self-ref│                   │ parent_host_id   │              │
│ ...                          │                   │ cpu_cores        │              │
└──────────────────────────────┘                   │ total_ram_mb     │              │
        │                                          │ vmid             │              │
        │                                          │ criticality      │              │
        │                                          │ ...              │              │
        │                                          └──────────────────┘              │
        │                                                   │                        │
        │                              ┌────────────────────┼────────────────────┐   │
        │                              │                    │                    │   │
        ▼                              ▼                    ▼                    ▼   ▼
┌──────────────────┐      ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ STORAGE_DEVICES  │      │ PROXMOX_         │  │  DOCKER_         │  │  FIREWALL_RULES  │
│                  │      │ CONTAINERS       │  │  NETWORKS        │  ├──────────────────┤
├──────────────────┤      ├──────────────────┤  ├──────────────────┤  │ id (PK)          │
│ id (PK)          │      │ id (PK)          │  │ id (PK)          │  │ firewall_host_id│
│ host_id (FK)     │      │ host_id (FK)     │  │ docker_host_id   │  │ rule_number      │
│ device_name      │      │ proxmox_host_id  │  │ network_name     │  │ action           │
│ device_type      │      │ vmid             │  │ subnet           │  │ protocol         │
│ capacity_gb      │      │ container_type   │  │ gateway          │  │ source_network   │
│ filesystem_type  │      │   'vm'|'lxc'     │  │ ...              │  │ destination_net  │
│ mount_point      │      │ vm_type (vm)     │  └──────────────────┘  │ enabled          │
│ ...              │      │ os_template (lxc)│           │            │ ...              │
└──────────────────┘      │ ...              │           │            └──────────────────┘
                          │ *NEW: merged     │           │
                          │  virtual_machines│           │
                          │  + lxc_containers│           │
                          └──────────────────┘           │
                                   │                     │
                                   │                     │
                                   ▼                     ▼
                          ┌──────────────────┐  ┌──────────────────┐
                          │ DOCKER_CONTAINERS│  │ DOCKER_VOLUMES   │
                          ├──────────────────┤  ├──────────────────┤
                          │ id (PK)          │  │ id (PK)          │
                          │ docker_host_id   │  │ docker_host_id   │
                          │ container_id     │  │ volume_name      │
                          │ container_name   │  │ driver           │
                          │ image            │  │ mount_point      │
                          │ status           │  │ ...              │
                          │ health_status    │  └──────────────────┘
                          │ ports (JSON)     │           │
                          │ networks (JSON)  │           │
                          │ ...              │           │
                          └──────────────────┘           │
                                   │                     │
                                   │                     │
                                   ▼                     │
                          ┌──────────────────────┐      │
                          │ DOCKER_CONTAINER_    │◄─────┘
                          │     VOLUMES (UPDATED) │
                          ├──────────────────────┤
                          │ id (PK)              │
                          │ docker_container_id  │ *RENAMED from
                          │ docker_volume_id     │  container_id
                          │ container_path       │  volume_id
                          │ host_path            │
                          │ read_only            │
                          └──────────────────────┘
                                   │
                                   │
                                   ▼
┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│     SERVICES     │◄────────┤SERVICE_DEPENDENC│────────►│     SERVICES     │
│   (UPDATED)      │         │                 │         └──────────────────┘
├──────────────────┤         ├──────────────────┤                 ▲
│ id (PK)          │         │ id (PK)          │                 │
│ service_name     │         │ dependent_id     │                 │
│ service_type     │         │ dependency_id    │                 │
│ host_id (FK)     │         │ dependency_type  │                 │
│ container_id (FK │         └──────────────────┘                 │
│   SET NULL)      │                                           │
│ status           │         ┌──────────────────┐                 │
│ criticality      │         │  HEALTH_CHECKS   │                 │
│ ...              │         ├──────────────────┤                 │
│ *UPDATED SCHEMA: │         │ id (PK)          │                 │
│  - Added FK      │         │ service_id (FK)  │─────────────────┘
│    cascades      │         │ status           │
│  - Matches       │         │ response_time_ms │
│    actual data   │         │ ...              │
└──────────────────┘         │ *AUTO CLEANUP    │
        │                    │  TRIGGER ADDED   │
        │                    └──────────────────┘
        ▼
┌──────────────────┐
│INFRASTRUCTURE_   │
│    CHANGES       │
├──────────────────┤
│ id (PK)          │
│ change_timestamp │
│ entity_type      │
│ entity_id        │
│ ...              │
│ *AUTO CLEANUP    │
│  TRIGGER ADDED   │
└──────────────────┘
```

## Migration 001 Changes Summary

### New Tables
| Table | Description | Source |
|-------|-------------|--------|
| `proxmox_containers` | **Consolidated VM/LXC container data** | Merged from `virtual_machines` + `lxc_containers` |

### Dropped Tables
| Table | Reason |
|-------|--------|
| `virtual_machines` | Merged into `proxmox_containers` |
| `lxc_containers` | Merged into `proxmox_containers` |

### Updated Tables
| Table | Changes |
|-------|---------|
| `docker_container_volumes` | **Renamed columns**: `container_id` → `docker_container_id`, `volume_id` → `docker_volume_id` |
| `services` | **Added FK cascades**: `ON DELETE SET NULL` for `host_id` and `container_id` |

### New Indexes
| Index | Table | Columns | Purpose |
|-------|-------|---------|---------|
| `idx_docker_host_status` | docker_containers | (docker_host_id, status) | Query containers by host + status |
| `idx_docker_host_health` | docker_containers | (docker_host_id, health_status) | Query containers by host + health |
| `idx_svcdeps_dependent_type` | service_dependencies | (dependent_service_id, dependency_type) | Query dependencies by dependent + type |
| `idx_svcdeps_dependency_type` | service_dependencies | (dependency_service_id, dependency_type) | Query dependents by dependency + type |
| `idx_changes_timestamp_type` | infrastructure_changes | (change_timestamp DESC, entity_type) | Query recent changes by type |
| `idx_health_service_timestamp` | health_checks | (service_id, check_timestamp DESC) | Query recent health checks |
| `idx_ip_network_allocation` | ip_addresses | (network_id, allocation_type) | Query IPs by network + allocation |

### New Triggers
| Trigger | Table | Purpose |
|---------|-------|---------|
| `tr_health_checks_cleanup` | health_checks | Auto-delete records older than 90 days (keeps latest 10k) |
| `tr_infrastructure_changes_cleanup` | infrastructure_changes | Auto-delete records older than 180 days (keeps latest 5k) |
| `tr_proxmox_update_version` | proxmox_containers | Audit trail for configuration changes |
| `tr_update_timestamp_proxmox` | proxmox_containers | Auto-update timestamp on modify |

### Updated Views
| View | Changes |
|------|---------|
| `v_host_inventory` | Added `proxmox_containers_count` column |
| `v_docker_inventory` | Updated to use renamed `docker_container_id` column |

## Data Quality Improvements

### Foreign Key Cascades Added
```
services.host_id          → hosts(id)           ON DELETE SET NULL
services.container_id     → docker_containers   ON DELETE SET NULL
docker_container_volumes.docker_container_id → docker_containers ON DELETE CASCADE
docker_container_volumes.docker_volume_id    → docker_volumes     ON DELETE CASCADE
```

### Constraint Validation
All CHECK constraints now match actual data:
- `service_type`: Includes 'dns', 'dhcp', 'firewall', 'backup'
- `status`: Includes 'healthy', 'degraded', 'down', 'unknown'

## Performance Improvements

### Query Optimization
- **Composite indexes** eliminate full table scans on common queries
- **Automatic cleanup triggers** prevent log table bloat
- **Better FK cascade rules** prevent orphaned records

### Estimated Performance Gains
| Query Type | Before | After | Improvement |
|------------|--------|-------|-------------|
| Get running containers by host | Full scan | Index seek | ~100x faster |
| Get service dependencies by type | Full scan | Index seek | ~50x faster |
| Get recent changes by entity type | Full scan | Index seek | ~75x faster |
| Health checks query (old records) | Growing slow | Auto-cleanup | Constant time |

## Maintenance Automation

### Cleanup Triggers (Automatic)
- **Health checks**: Keep last 90 days + max 10,000 records
- **Infrastructure changes**: Keep last 180 days + max 5,000 records
- **Triggers fire** on every INSERT, automatically cleaning old data

### No Manual Maintenance Required
Previously required manual cleanup:
```sql
-- OLD: Manual cleanup required
DELETE FROM health_checks WHERE check_timestamp < datetime('now', '-90 days');
DELETE FROM infrastructure_changes WHERE change_timestamp < datetime('now', '-180 days');
```

**NEW: Automatic cleanup via triggers**

## Next Steps

1. **PVE2 Scraper**: Create script to scrape Proxmox API for fresh LXC/VM data
2. **Geek Map Integration**: Update HTML page to use new `proxmox_containers` table
3. **Data Validation**: Run integrity checks to ensure no orphaned records

## Rollback Plan

If needed, restore from backup:
```bash
# Backups created:
# - infrastructure.db.backup-20260129-173618 (original)
# - infrastructure.db.pre-migration-YYYYMMDD-HHMMSS (pre-migration)

cp infrastructure.db.backup-20260129-173618 infrastructure.db
```
