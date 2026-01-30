# Infrastructure Database - Current ER Diagram
Generated: 2026-01-29

## ASCII ER Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        INFRASTRUCTURE DATABASE - ENTITY RELATIONSHIP DIAGRAM                    │
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
│ STORAGE_DEVICES  │      │VIRTUAL_MACHINES  │  │  LXC_CONTAINERS  │  │  FIREWALL_RULES  │
├──────────────────┤      ├──────────────────┤  ├──────────────────┤  ├──────────────────┤
│ id (PK)          │      │ id (PK)          │  │ id (PK)          │  │ id (PK)          │
│ host_id (FK)     │      │ host_id (FK)     │  │ host_id (FK)     │  │ firewall_host_id │
│ device_name      │      │ proxmox_host_id  │  │ proxmox_host_id  │  │ rule_number      │
│ device_type      │      │ vmid             │  │ vmid             │  │ action           │
│ capacity_gb      │      │ vm_type          │  │ os_template      │  │ protocol         │
│ filesystem_type  │      │ os_type          │  │ unprivileged     │  │ source_network   │
│ mount_point      │      │ ...              │  │ ...              │  │ destination_net  │
│ ...              │      └──────────────────┘  └──────────────────┘  │ enabled          │
└──────────────────┘                                                  │ ...              │
                                                                       └──────────────────┘


┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│  DOCKER_NETWORKS │         │ DOCKER_CONTAINERS│         │ DOCKER_VOLUMES   │
├──────────────────┤         ├──────────────────┤         ├──────────────────┤
│ id (PK)          │         │ id (PK)          │         │ id (PK)          │
│ docker_host_id   │◄────┐   │ docker_host_id   │◄────┐   │ docker_host_id   │
│ network_name     │     │   │ container_id     │     │   │ volume_name      │
│ network_id       │     │   │ container_name   │     │   │ driver           │
│ subnet           │     │   │ image           │     │   │ mount_point      │
│ gateway          │     │   │ status          │     │   │ ...              │
│ ...              │     │   │ health_status   │     │   └──────────────────┘
└──────────────────┘     │   │ networks (JSON) │     │           │
                          │   │ ports (JSON)    │     │           │
                          │   │ ...             │     │           │
                          │   └──────────────────┘     │           │
                          │           │                │           │
                          │           │                │           │
                          │           ▼                │           ▼
                          │   ┌──────────────────┐     │   ┌───────────────────────┐
                          │   │ DOCKER_CONTAINER  │     │   │ DOCKER_CONTAINER_     │
                          │   │    _VOLUMES       │────┼──►│     VOLUMES (JUNCTION) │
                          │   ├──────────────────┤     │   ├───────────────────────┤
                          │   │ id (PK)          │     │   │ id (PK)               │
                          │   │ container_id (FK)│─────┘   │ container_id (FK)     │
                          │   │ volume_id (FK)   │─────────►│ volume_id (FK)        │
                          │   │ mount_path       │         │ mount_path            │
                          │   │ ...              │         │ read_only             │
                          │   └──────────────────┘         │ ...                   │
                          │                                 └───────────────────────┘
                          │
                          └──────────────────────────────────────────────┐
                                                                 │
                                                                 ▼
┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│     SERVICES     │◄────────┤SERVICE_DEPENDENC│────────►│     SERVICES     │
├──────────────────┤         ├──────────────────┤         └──────────────────┘
│ id (PK)          │         │ id (PK)          │               ▲
│ service_name     │         │ dependent_id     │               │
│ service_type     │         │ dependency_id    │               │
│ host_id (FK)     │         │ dependency_type  │               │
│ container_id (FK)│         └──────────────────┘               │
│ endpoint_url     │                                           │
│ status           │         ┌──────────────────┐               │
│ criticality      │         │  HEALTH_CHECKS   │               │
│ ...              │         ├──────────────────┤               │
└──────────────────┘         │ id (PK)          │               │
        │                    │ service_id (FK)  │───────────────┘
        │                    │ status           │
        │                    │ response_time_ms │
        ▼                    │ ...              │
┌──────────────────┐         └──────────────────┘
│INFRASTRUCTURE_   │
│    CHANGES       │
├──────────────────┤
│ id (PK)          │
│ change_timestamp │
│ entity_type      │
│ entity_id        │
│ ...              │
└──────────────────┘
```

## Legend
```
 (PK) = Primary Key
 (FK) = Foreign Key
 ───► = One-to-Many relationship
 ◄──► = Many-to-Many relationship (via junction table)
 ──┐ = Self-referencing relationship
```

## Table Statistics (as of 2026-01-29)
```
┌─────────────────────────┬─────────┐
│ Table                   │ Rows    │
├─────────────────────────┼─────────┤
│ hosts                   │ 23      │
│ docker_containers       │ 80      │
│ services                │ 77      │
│ networks                │ 2       │
│ ip_addresses            │ 17      │
│ service_dependencies    │ 26      │
├─────────────────────────┼─────────┤
│ TOTAL TABLES            │ 21      │
│ TOTAL VIEWS             │ 5       │
│ DATABASE SIZE           │ 428KB   │
└─────────────────────────┴─────────┘
```

## Identified Issues & Optimization Opportunities

### 1. Structural Issues
```
❌ REDUNDANT TABLES:
   - virtual_machines + lxc_containers have identical structure
   → Could be consolidated into a single "proxmox_containers" table

❌ NAMING INCONSISTENCIES:
   - docker_container_volumes.container_id references docker_containers.id
   → Should be docker_container_id for clarity

❌ UNDERUTILIZED TABLES (based on low row counts):
   - networks: only 2 rows (could be hardcoded)
   - firewall_rules: appears empty
```

### 2. Index Optimization
```
✓ GOOD: Single-column indexes on foreign keys
⚠️  MISSING: Composite indexes for common query patterns
   - (host_id, status) for docker_containers
   - (dependent_service_id, dependency_service_id) for service_dependencies
   - (change_timestamp, entity_type) for infrastructure_changes
```

### 3. Data Quality Issues
```
⚠️  POTENTIAL ORPHANS:
   - docker_container_volumes may reference deleted containers
   - service_dependencies may reference deleted services

⚠️  STALE DATA:
   - infrastructure_changes table grows unbounded
   - health_checks table grows unbounded
```

## Proposed Clean-up Actions

1. **Consolidate VM/LXC tables** into single `proxmox_containers` table
2. **Add composite indexes** for common query patterns
3. **Add foreign key cascades** where missing
4. **Create cleanup jobs** for health_checks and infrastructure_changes
5. **Add data validation** constraints
6. **Rename ambiguous columns** for clarity
