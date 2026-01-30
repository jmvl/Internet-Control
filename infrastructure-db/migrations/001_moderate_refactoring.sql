-- ============================================================================
-- Infrastructure Database Migration 001: Moderate Refactoring
-- Date: 2026-01-29
-- Author: Claude (glm-4.7)
--
-- WARNING: This script performs schema changes. Ensure you have a backup!
-- Backup created: infrastructure.db.backup-20260129-173618
--
-- Changes:
-- 1. Merge virtual_machines + lxc_containers → proxmox_containers
-- 2. Rename ambiguous columns in docker_container_volumes
-- 3. Add missing FK cascades to services table
-- 4. Add composite indexes for common queries
-- 5. Add validation constraints
-- 6. Create cleanup jobs for log tables
-- ============================================================================

BEGIN TRANSACTION;

-- ============================================================================
-- PRE-STEP: Drop views that reference tables we're modifying
-- ============================================================================

DROP VIEW IF EXISTS v_host_inventory;
DROP VIEW IF EXISTS v_docker_inventory;
DROP VIEW IF EXISTS v_network_topology;
DROP VIEW IF EXISTS v_service_dependencies;
DROP VIEW IF EXISTS v_recent_changes;

-- ============================================================================
-- STEP 1: Create new consolidated proxmox_containers table
-- ============================================================================

CREATE TABLE IF NOT EXISTS proxmox_containers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL UNIQUE REFERENCES hosts(id) ON DELETE CASCADE,
    proxmox_host_id INTEGER NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    vmid INTEGER NOT NULL,

    -- Container type
    container_type TEXT NOT NULL CHECK(container_type IN ('vm', 'lxc')),

    -- VM-specific configuration
    vm_type TEXT CHECK(vm_type IN ('qemu', 'kvm')),
    os_type TEXT,

    -- LXC-specific configuration
    os_template TEXT,
    unprivileged BOOLEAN DEFAULT 1,

    -- Common configuration
    network_interfaces TEXT,  -- JSON array
    boot_disk TEXT,
    additional_disks TEXT,    -- JSON array
    rootfs_storage TEXT,
    rootfs_size_gb INTEGER,
    mount_points TEXT,        -- JSON array
    network_config TEXT,      -- JSON

    -- Features
    nesting BOOLEAN DEFAULT 0,
    keyctl BOOLEAN DEFAULT 0,
    auto_start BOOLEAN DEFAULT 0,
    template BOOLEAN DEFAULT 0,

    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(proxmox_host_id, vmid),
    CHECK(
        (container_type = 'vm' AND vm_type IS NOT NULL) OR
        (container_type = 'lxc' AND os_template IS NOT NULL)
    )
);

-- ============================================================================
-- STEP 2: Migrate data from virtual_machines to proxmox_containers
-- ============================================================================

INSERT INTO proxmox_containers (
    host_id,
    proxmox_host_id,
    vmid,
    container_type,
    vm_type,
    os_type,
    network_interfaces,
    boot_disk,
    additional_disks,
    auto_start,
    template,
    created_at,
    updated_at
)
SELECT
    id,
    proxmox_host_id,
    vmid,
    'vm' as container_type,
    vm_type,
    os_type,
    network_interfaces,
    boot_disk,
    additional_disks,
    auto_start,
    template,
    created_at,
    updated_at
FROM virtual_machines;

-- ============================================================================
-- STEP 3: Migrate data from lxc_containers to proxmox_containers
-- ============================================================================

INSERT INTO proxmox_containers (
    host_id,
    proxmox_host_id,
    vmid,
    container_type,
    os_template,
    unprivileged,
    rootfs_storage,
    rootfs_size_gb,
    mount_points,
    network_config,
    nesting,
    keyctl,
    auto_start,
    created_at,
    updated_at
)
SELECT
    id,
    proxmox_host_id,
    vmid,
    'lxc' as container_type,
    os_template,
    unprivileged,
    rootfs_storage,
    rootfs_size_gb,
    mount_points,
    network_config,
    nesting,
    keyctl,
    auto_start,
    created_at,
    updated_at
FROM lxc_containers;

-- ============================================================================
-- STEP 4: Rename ambiguous columns in docker_container_volumes
-- ============================================================================

-- Create new table with renamed column (container_id -> docker_container_id, volume_id -> docker_volume_id)
CREATE TABLE IF NOT EXISTS docker_container_volumes_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    docker_container_id INTEGER NOT NULL REFERENCES docker_containers(id) ON DELETE CASCADE,
    docker_volume_id INTEGER REFERENCES docker_volumes(id) ON DELETE CASCADE,

    -- Mount configuration
    container_path TEXT NOT NULL,
    host_path TEXT,  -- For bind mounts
    read_only BOOLEAN DEFAULT 0,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(docker_container_id, container_path)
);

-- Migrate data
INSERT INTO docker_container_volumes_new (
    id,
    docker_container_id,
    docker_volume_id,
    container_path,
    host_path,
    read_only,
    created_at
)
SELECT
    id,
    container_id as docker_container_id,
    volume_id as docker_volume_id,
    container_path,
    host_path,
    read_only,
    created_at
FROM docker_container_volumes;

-- Drop old table and rename new one
DROP TABLE docker_container_volumes;
ALTER TABLE docker_container_volumes_new RENAME TO docker_container_volumes;

-- Recreate indexes
CREATE INDEX idx_dcv_container ON docker_container_volumes(docker_container_id);
CREATE INDEX idx_dcv_volume ON docker_container_volumes(docker_volume_id);

-- ============================================================================
-- STEP 5: Add missing FK cascades to services table
-- ============================================================================

-- Note: Current services table lacks ON DELETE SET NULL. Recreating with proper FKs.

CREATE TABLE IF NOT EXISTS services_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    service_name TEXT NOT NULL,
    service_type TEXT NOT NULL CHECK(service_type IN (
        'web', 'api', 'database', 'cache', 'queue', 'dns', 'dhcp',
        'firewall', 'proxy', 'monitoring', 'backup', 'storage', 'other'
    )),

    -- Hosting (with CASCADE/SET NULL)
    host_id INTEGER REFERENCES hosts(id) ON DELETE SET NULL,
    container_id INTEGER REFERENCES docker_containers(id) ON DELETE SET NULL,

    -- Endpoint configuration (keeping existing column names)
    protocol TEXT,
    port INTEGER,
    endpoint_url TEXT,

    -- Health monitoring (keeping existing column names)
    health_check_url TEXT,
    health_check_interval INTEGER DEFAULT 60,

    -- Service status (matching existing values)
    status TEXT CHECK(status IN ('healthy', 'degraded', 'down', 'unknown')) DEFAULT 'unknown',

    -- Dependency management
    criticality TEXT CHECK(criticality IN ('critical', 'high', 'medium', 'low')),

    -- Metadata
    version TEXT,
    description TEXT,
    documentation_url TEXT,

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Migrate data from old services table
INSERT INTO services_new (
    id, service_name, service_type, host_id, container_id,
    protocol, port, endpoint_url, health_check_url, health_check_interval,
    status, criticality, description, documentation_url, version,
    created_at, updated_at
)
SELECT
    id, service_name, service_type, host_id, container_id,
    protocol, port, endpoint_url, health_check_url, health_check_interval,
    status, criticality, description, documentation_url, version,
    created_at, updated_at
FROM services;

-- Drop old table and rename
DROP TABLE services;
ALTER TABLE services_new RENAME TO services;

-- Recreate indexes
CREATE INDEX idx_services_host ON services(host_id);
CREATE INDEX idx_services_container ON services(container_id);
CREATE INDEX idx_services_type ON services(service_type);
CREATE INDEX idx_services_status ON services(status);
CREATE INDEX idx_services_criticality ON services(criticality);

-- ============================================================================
-- STEP 6: Add composite indexes for common query patterns
-- ============================================================================

-- docker_containers: commonly query by host and status
CREATE INDEX IF NOT EXISTS idx_docker_host_status ON docker_containers(docker_host_id, status);

-- docker_containers: commonly query by host and health
CREATE INDEX IF NOT EXISTS idx_docker_host_health ON docker_containers(docker_host_id, health_status);

-- service_dependencies: commonly query both sides of relationship
CREATE INDEX IF NOT EXISTS idx_svcdeps_dependent_type ON service_dependencies(dependent_service_id, dependency_type);
CREATE INDEX IF NOT EXISTS idx_svcdeps_dependency_type ON service_dependencies(dependency_service_id, dependency_type);

-- infrastructure_changes: commonly query recent changes by type
CREATE INDEX IF NOT EXISTS idx_changes_timestamp_type ON infrastructure_changes(change_timestamp DESC, entity_type);

-- health_checks: commonly query recent checks for a service
CREATE INDEX IF NOT EXISTS idx_health_service_timestamp ON health_checks(service_id, check_timestamp DESC);

-- ip_addresses: commonly query by network and allocation type
CREATE INDEX IF NOT EXISTS idx_ip_network_allocation ON ip_addresses(network_id, allocation_type);

-- ============================================================================
-- STEP 7: Create cleanup triggers for log tables
-- ============================================================================

-- Cleanup old health checks (keep last 90 days, max 10000 records)
CREATE TRIGGER IF NOT EXISTS tr_health_checks_cleanup
AFTER INSERT ON health_checks
WHEN (SELECT COUNT(*) FROM health_checks WHERE check_timestamp < datetime('now', '-90 days')) > 10000
BEGIN
    DELETE FROM health_checks
    WHERE check_timestamp < datetime('now', '-90 days')
    AND id NOT IN (
        SELECT id FROM health_checks
        ORDER BY check_timestamp DESC
        LIMIT 10000
    );
END;

-- Cleanup old infrastructure changes (keep last 180 days, max 5000 records)
CREATE TRIGGER IF NOT EXISTS tr_infrastructure_changes_cleanup
AFTER INSERT ON infrastructure_changes
WHEN (SELECT COUNT(*) FROM infrastructure_changes WHERE change_timestamp < datetime('now', '-180 days')) > 5000
BEGIN
    DELETE FROM infrastructure_changes
    WHERE change_timestamp < datetime('now', '-180 days')
    AND id NOT IN (
        SELECT id FROM infrastructure_changes
        ORDER BY change_timestamp DESC
        LIMIT 5000
    );
END;

-- ============================================================================
-- STEP 8: Update views to use new table structure
-- ============================================================================

DROP VIEW IF EXISTS v_host_inventory;
CREATE VIEW v_host_inventory AS
SELECT
    h.id,
    h.hostname,
    h.host_type,
    h.management_ip,
    h.status,
    h.cpu_cores,
    h.total_ram_mb,
    h.used_ram_mb,
    ROUND((h.used_ram_mb * 100.0) / NULLIF(h.total_ram_mb, 0), 2) as ram_utilization_pct,
    h.criticality,
    ph.hostname as parent_hostname,
    COUNT(DISTINCT ch.id) as child_hosts_count,
    COUNT(DISTINCT s.id) as services_count,
    COUNT(DISTINCT pc.id) as proxmox_containers_count,
    COUNT(DISTINCT dc.id) as docker_containers_count
FROM hosts h
LEFT JOIN hosts ph ON h.parent_host_id = ph.id
LEFT JOIN hosts ch ON ch.parent_host_id = h.id
LEFT JOIN services s ON s.host_id = h.id
LEFT JOIN proxmox_containers pc ON pc.host_id = h.id
LEFT JOIN docker_containers dc ON dc.docker_host_id = h.id
GROUP BY h.id;

-- Update v_docker_inventory to use renamed columns
DROP VIEW IF EXISTS v_docker_inventory;
CREATE VIEW v_docker_inventory AS
SELECT
    dc.container_name,
    dc.image,
    dc.image_tag,
    dc.status,
    dc.health_status,
    h.hostname as docker_host,
    h.management_ip as host_ip,
    dc.ports,
    dc.networks,
    COUNT(DISTINCT dcv.id) as volume_mounts_count,
    s.service_name,
    s.status as service_status
FROM docker_containers dc
JOIN hosts h ON dc.docker_host_id = h.id
LEFT JOIN docker_container_volumes dcv ON dcv.docker_container_id = dc.id
LEFT JOIN services s ON s.container_id = dc.id
GROUP BY dc.id;

-- ============================================================================
-- STEP 9: Drop old tables (data already migrated)
-- ============================================================================

DROP TABLE IF EXISTS virtual_machines;
DROP TABLE IF EXISTS lxc_containers;

-- ============================================================================
-- STEP 10: Recreate triggers for updated tables
-- ============================================================================

-- Update timestamp trigger for proxmox_containers
CREATE TRIGGER IF NOT EXISTS tr_update_timestamp_proxmox
AFTER UPDATE ON proxmox_containers
FOR EACH ROW
BEGIN
    UPDATE proxmox_containers SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Audit trigger for proxmox_containers
CREATE TRIGGER IF NOT EXISTS tr_proxmox_update_version
AFTER UPDATE ON proxmox_containers
FOR EACH ROW
BEGIN
    INSERT INTO infrastructure_changes (
        change_type, entity_type, entity_id, changed_by, change_source,
        old_values, new_values, description
    )
    VALUES (
        'update', 'proxmox_container', NEW.id, 'system', 'automation',
        json_object(
            'vmid', OLD.vmid, 'container_type', OLD.container_type
        ),
        json_object(
            'vmid', NEW.vmid, 'container_type', NEW.container_type
        ),
        'Proxmox container ' || NEW.vmid || ' configuration updated'
    );
END;

-- ============================================================================
-- COMMIT TRANSACTION
-- ============================================================================

COMMIT;

-- ============================================================================
-- POST-MIGRATION VERIFICATION QUERIES
-- ============================================================================

-- Verify row counts
SELECT 'hosts' as table_name, COUNT(*) as row_count FROM hosts
UNION ALL SELECT 'proxmox_containers', COUNT(*) FROM proxmox_containers
UNION ALL SELECT 'docker_containers', COUNT(*) FROM docker_containers
UNION ALL SELECT 'services', COUNT(*) FROM services
UNION ALL SELECT 'docker_container_volumes', COUNT(*) FROM docker_container_volumes;

-- Verify proxmox_containers has data from both old tables
SELECT container_type, COUNT(*) as count FROM proxmox_containers GROUP BY container_type;

-- Verify indexes created
SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name;

-- Verify triggers created
SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'tr_%' ORDER BY name;
