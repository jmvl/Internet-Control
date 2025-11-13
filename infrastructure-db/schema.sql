-- Infrastructure Database Schema
-- SQLite database for comprehensive infrastructure management
-- Version: 1.0
-- Last Updated: 2025-10-17

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- =============================================================================
-- DOMAIN 1: PHYSICAL INFRASTRUCTURE
-- =============================================================================

-- Hosts: Physical servers, VMs, containers
CREATE TABLE hosts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT NOT NULL,
    host_type TEXT NOT NULL CHECK(host_type IN ('physical', 'vm', 'lxc', 'docker_host')),
    management_ip TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active', 'stopped', 'maintenance', 'decommissioned')),

    -- Resource specifications
    cpu_cores INTEGER,
    total_ram_mb INTEGER,
    used_ram_mb INTEGER,

    -- For VMs/Containers
    parent_host_id INTEGER REFERENCES hosts(id) ON DELETE SET NULL,
    vmid INTEGER, -- Proxmox VMID or container ID

    -- Metadata
    purpose TEXT,
    criticality TEXT CHECK(criticality IN ('critical', 'high', 'medium', 'low')),
    notes TEXT,

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(hostname)
);

CREATE INDEX idx_hosts_type ON hosts(host_type);
CREATE INDEX idx_hosts_status ON hosts(status);
CREATE INDEX idx_hosts_parent ON hosts(parent_host_id);
CREATE INDEX idx_hosts_management_ip ON hosts(management_ip);

-- Network Interfaces: NICs, bridges, VLAN interfaces
CREATE TABLE network_interfaces (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    interface_name TEXT NOT NULL,
    interface_type TEXT NOT NULL CHECK(interface_type IN ('physical', 'bridge', 'vlan', 'virtual', 'wifi')),

    -- Hardware details
    mac_address TEXT,
    pci_slot TEXT,
    driver TEXT,
    speed_mbps INTEGER,

    -- Bridge configuration
    bridge_name TEXT, -- For interfaces part of a bridge
    bridge_ports TEXT, -- JSON array of bridge member interfaces

    -- VLAN configuration
    vlan_id INTEGER,
    parent_interface_id INTEGER REFERENCES network_interfaces(id) ON DELETE SET NULL,

    -- Status
    link_status TEXT CHECK(link_status IN ('up', 'down', 'unknown')),

    -- Metadata
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(host_id, interface_name)
);

CREATE INDEX idx_netif_host ON network_interfaces(host_id);
CREATE INDEX idx_netif_type ON network_interfaces(interface_type);
CREATE INDEX idx_netif_mac ON network_interfaces(mac_address);

-- Storage Devices: Physical disks, RAID arrays, filesystems
CREATE TABLE storage_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL, -- /dev/sda, /dev/sdb, etc.
    device_type TEXT NOT NULL CHECK(device_type IN ('disk', 'raid', 'lvm', 'zfs', 'btrfs', 'mergerfs')),

    -- Physical disk details
    model TEXT,
    serial_number TEXT,
    capacity_gb INTEGER,

    -- Filesystem details
    filesystem_type TEXT,
    mount_point TEXT,
    used_gb INTEGER,
    available_gb INTEGER,

    -- RAID configuration
    raid_level TEXT, -- raid0, raid1, raid5, etc.
    raid_members TEXT, -- JSON array of member devices

    -- Health monitoring
    smart_status TEXT CHECK(smart_status IN ('passed', 'failed', 'unknown')),
    health_status TEXT,

    -- Metadata
    purpose TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(host_id, device_name)
);

CREATE INDEX idx_storage_host ON storage_devices(host_id);
CREATE INDEX idx_storage_type ON storage_devices(device_type);
CREATE INDEX idx_storage_mount ON storage_devices(mount_point);

-- =============================================================================
-- DOMAIN 2: NETWORK INFRASTRUCTURE
-- =============================================================================

-- Networks: Subnets, VLANs, network segments
CREATE TABLE networks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    network_name TEXT NOT NULL,
    cidr TEXT NOT NULL, -- e.g., 192.168.1.0/24
    vlan_id INTEGER,

    -- Network configuration
    gateway TEXT,
    dns_servers TEXT, -- JSON array of DNS servers
    dhcp_enabled BOOLEAN DEFAULT 0,
    dhcp_range_start TEXT,
    dhcp_range_end TEXT,

    -- Metadata
    purpose TEXT,
    security_zone TEXT CHECK(security_zone IN ('public', 'dmz', 'management', 'private', 'isolated')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(cidr)
);

CREATE INDEX idx_networks_vlan ON networks(vlan_id);
CREATE INDEX idx_networks_zone ON networks(security_zone);

-- IP Addresses: IP address allocations
CREATE TABLE ip_addresses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip_address TEXT NOT NULL,
    network_id INTEGER NOT NULL REFERENCES networks(id) ON DELETE CASCADE,
    interface_id INTEGER REFERENCES network_interfaces(id) ON DELETE SET NULL,
    host_id INTEGER REFERENCES hosts(id) ON DELETE SET NULL,

    -- Allocation type
    allocation_type TEXT NOT NULL CHECK(allocation_type IN ('static', 'dhcp', 'reserved')),

    -- Metadata
    hostname TEXT,
    purpose TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(ip_address)
);

CREATE INDEX idx_ip_network ON ip_addresses(network_id);
CREATE INDEX idx_ip_interface ON ip_addresses(interface_id);
CREATE INDEX idx_ip_host ON ip_addresses(host_id);
CREATE INDEX idx_ip_address ON ip_addresses(ip_address);

-- Network Routes: Routing tables and gateway relationships
CREATE TABLE network_routes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_network_id INTEGER REFERENCES networks(id) ON DELETE CASCADE,
    destination_network TEXT NOT NULL, -- CIDR or 'default'
    gateway_ip TEXT NOT NULL,
    gateway_host_id INTEGER REFERENCES hosts(id) ON DELETE SET NULL,

    -- Route metrics
    metric INTEGER DEFAULT 0,
    route_type TEXT CHECK(route_type IN ('static', 'dynamic', 'default')),

    -- Metadata
    interface_name TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_routes_source ON network_routes(source_network_id);
CREATE INDEX idx_routes_gateway_host ON network_routes(gateway_host_id);

-- Firewall Rules: OPNsense/iptables rules inventory
CREATE TABLE firewall_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    firewall_host_id INTEGER NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    rule_number INTEGER,

    -- Rule configuration
    action TEXT NOT NULL CHECK(action IN ('allow', 'deny', 'reject', 'nat')),
    direction TEXT NOT NULL CHECK(direction IN ('in', 'out', 'forward')),
    protocol TEXT CHECK(protocol IN ('tcp', 'udp', 'icmp', 'any')),

    -- Source/Destination
    source_network TEXT,
    source_port TEXT,
    destination_network TEXT,
    destination_port TEXT,

    -- Schedule
    schedule_name TEXT,
    schedule_enabled BOOLEAN DEFAULT 1,

    -- Status
    enabled BOOLEAN DEFAULT 1,

    -- Metadata
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_fw_host ON firewall_rules(firewall_host_id);
CREATE INDEX idx_fw_action ON firewall_rules(action);
CREATE INDEX idx_fw_enabled ON firewall_rules(enabled);

-- =============================================================================
-- DOMAIN 3: VIRTUALIZATION LAYER
-- =============================================================================

-- Virtual Machines: Proxmox VMs
CREATE TABLE virtual_machines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL UNIQUE REFERENCES hosts(id) ON DELETE CASCADE,
    proxmox_host_id INTEGER NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    vmid INTEGER NOT NULL,

    -- VM Configuration
    vm_type TEXT CHECK(vm_type IN ('qemu', 'kvm')),
    os_type TEXT,

    -- Network configuration
    network_interfaces TEXT, -- JSON array of network configs

    -- Storage
    boot_disk TEXT,
    additional_disks TEXT, -- JSON array

    -- Metadata
    auto_start BOOLEAN DEFAULT 0,
    template BOOLEAN DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(proxmox_host_id, vmid)
);

CREATE INDEX idx_vm_proxmox_host ON virtual_machines(proxmox_host_id);

-- LXC Containers: Proxmox containers
CREATE TABLE lxc_containers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    host_id INTEGER NOT NULL UNIQUE REFERENCES hosts(id) ON DELETE CASCADE,
    proxmox_host_id INTEGER NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    vmid INTEGER NOT NULL,

    -- Container Configuration
    os_template TEXT,
    unprivileged BOOLEAN DEFAULT 1,

    -- Storage
    rootfs_storage TEXT,
    rootfs_size_gb INTEGER,
    mount_points TEXT, -- JSON array of bind mounts

    -- Network configuration
    network_config TEXT, -- JSON

    -- Features
    nesting BOOLEAN DEFAULT 0,
    keyctl BOOLEAN DEFAULT 0,

    -- Metadata
    auto_start BOOLEAN DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(proxmox_host_id, vmid)
);

CREATE INDEX idx_lxc_proxmox_host ON lxc_containers(proxmox_host_id);

-- Docker Containers: Container instances with detailed config
CREATE TABLE docker_containers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    docker_host_id INTEGER NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    container_id TEXT NOT NULL, -- Docker container ID (short)
    container_name TEXT NOT NULL,

    -- Image configuration
    image TEXT NOT NULL,
    image_tag TEXT,

    -- Runtime configuration
    status TEXT CHECK(status IN ('running', 'stopped', 'paused', 'restarting', 'exited')),
    restart_policy TEXT,

    -- Network configuration
    network_mode TEXT,
    networks TEXT, -- JSON array of connected networks
    ports TEXT, -- JSON array of port mappings

    -- Environment
    environment_vars TEXT, -- JSON object

    -- Resource limits
    cpu_limit REAL,
    memory_limit_mb INTEGER,

    -- Health
    health_status TEXT CHECK(health_status IN ('healthy', 'unhealthy', 'starting', 'none')),

    -- Metadata
    labels TEXT, -- JSON object
    command TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(docker_host_id, container_name)
);

CREATE INDEX idx_docker_host ON docker_containers(docker_host_id);
CREATE INDEX idx_docker_status ON docker_containers(status);
CREATE INDEX idx_docker_health ON docker_containers(health_status);

-- Docker Volumes: Persistent volume mappings
CREATE TABLE docker_volumes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    docker_host_id INTEGER NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    volume_name TEXT NOT NULL,
    driver TEXT DEFAULT 'local',

    -- Volume configuration
    mount_point TEXT,
    options TEXT, -- JSON object

    -- Usage tracking
    size_mb INTEGER,

    -- Metadata
    labels TEXT, -- JSON object
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(docker_host_id, volume_name)
);

CREATE INDEX idx_volume_host ON docker_volumes(docker_host_id);

-- Docker Container-Volume mappings
CREATE TABLE docker_container_volumes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    container_id INTEGER NOT NULL REFERENCES docker_containers(id) ON DELETE CASCADE,
    volume_id INTEGER REFERENCES docker_volumes(id) ON DELETE SET NULL,

    -- Mount configuration
    container_path TEXT NOT NULL,
    host_path TEXT, -- For bind mounts
    read_only BOOLEAN DEFAULT 0,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(container_id, container_path)
);

CREATE INDEX idx_container_volume_container ON docker_container_volumes(container_id);
CREATE INDEX idx_container_volume_volume ON docker_container_volumes(volume_id);

-- Docker Networks: Docker bridge/overlay networks
CREATE TABLE docker_networks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    docker_host_id INTEGER NOT NULL REFERENCES hosts(id) ON DELETE CASCADE,
    network_name TEXT NOT NULL,
    network_id TEXT, -- Docker network ID

    -- Network configuration
    driver TEXT CHECK(driver IN ('bridge', 'host', 'overlay', 'macvlan', 'none')),
    subnet TEXT,
    gateway TEXT,

    -- Network options
    internal BOOLEAN DEFAULT 0,
    attachable BOOLEAN DEFAULT 0,

    -- Metadata
    labels TEXT, -- JSON object
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(docker_host_id, network_name)
);

CREATE INDEX idx_docker_net_host ON docker_networks(docker_host_id);

-- =============================================================================
-- DOMAIN 4: APPLICATION SERVICES
-- =============================================================================

-- Services: Application services
CREATE TABLE services (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    service_name TEXT NOT NULL,
    service_type TEXT NOT NULL CHECK(service_type IN (
        'web', 'api', 'database', 'cache', 'queue', 'dns', 'dhcp',
        'firewall', 'proxy', 'monitoring', 'backup', 'storage', 'other'
    )),

    -- Hosting
    host_id INTEGER REFERENCES hosts(id) ON DELETE SET NULL,
    container_id INTEGER REFERENCES docker_containers(id) ON DELETE SET NULL,

    -- Network access
    protocol TEXT,
    port INTEGER,
    endpoint_url TEXT,

    -- Health monitoring
    health_check_url TEXT,
    health_check_interval INTEGER DEFAULT 60,
    status TEXT CHECK(status IN ('healthy', 'degraded', 'down', 'unknown')),

    -- Metadata
    version TEXT,
    criticality TEXT CHECK(criticality IN ('critical', 'high', 'medium', 'low')),
    description TEXT,
    documentation_url TEXT,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_services_host ON services(host_id);
CREATE INDEX idx_services_container ON services(container_id);
CREATE INDEX idx_services_type ON services(service_type);
CREATE INDEX idx_services_status ON services(status);

-- Service Dependencies: Service-to-service dependency graph
CREATE TABLE service_dependencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dependent_service_id INTEGER NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    dependency_service_id INTEGER NOT NULL REFERENCES services(id) ON DELETE CASCADE,

    -- Dependency characteristics
    dependency_type TEXT CHECK(dependency_type IN ('hard', 'soft', 'optional')),

    -- Metadata
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(dependent_service_id, dependency_service_id),
    CHECK(dependent_service_id != dependency_service_id)
);

CREATE INDEX idx_dep_dependent ON service_dependencies(dependent_service_id);
CREATE INDEX idx_dep_dependency ON service_dependencies(dependency_service_id);

-- =============================================================================
-- DOMAIN 5: OPERATIONS & VERSIONING
-- =============================================================================

-- Infrastructure Changes: Audit log for all changes (versioning)
CREATE TABLE infrastructure_changes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    change_type TEXT NOT NULL CHECK(change_type IN (
        'create', 'update', 'delete', 'start', 'stop', 'restart', 'migrate', 'backup', 'restore'
    )),
    entity_type TEXT NOT NULL,
    entity_id INTEGER NOT NULL,

    -- Change details
    changed_by TEXT, -- username or 'system'
    change_source TEXT CHECK(change_source IN ('manual', 'api', 'automation', 'discovery')),

    -- Change data
    old_values TEXT, -- JSON snapshot of previous state
    new_values TEXT, -- JSON snapshot of new state

    -- Metadata
    description TEXT,
    change_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_changes_entity ON infrastructure_changes(entity_type, entity_id);
CREATE INDEX idx_changes_timestamp ON infrastructure_changes(change_timestamp);
CREATE INDEX idx_changes_type ON infrastructure_changes(change_type);

-- Health Checks: Service health monitoring results
CREATE TABLE health_checks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    service_id INTEGER NOT NULL REFERENCES services(id) ON DELETE CASCADE,

    -- Health check result
    check_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT NOT NULL CHECK(status IN ('healthy', 'degraded', 'down', 'timeout')),
    response_time_ms INTEGER,

    -- Details
    status_code INTEGER,
    response_body TEXT,
    error_message TEXT,

    -- Metadata
    check_source TEXT DEFAULT 'automated'
);

CREATE INDEX idx_health_service ON health_checks(service_id);
CREATE INDEX idx_health_timestamp ON health_checks(check_timestamp);
CREATE INDEX idx_health_status ON health_checks(status);

-- =============================================================================
-- VIEWS FOR COMMON QUERIES
-- =============================================================================

-- View: Complete host inventory with resource utilization
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
    COUNT(DISTINCT s.id) as services_count
FROM hosts h
LEFT JOIN hosts ph ON h.parent_host_id = ph.id
LEFT JOIN hosts ch ON ch.parent_host_id = h.id
LEFT JOIN services s ON s.host_id = h.id
GROUP BY h.id;

-- View: Network topology with IP allocations
CREATE VIEW v_network_topology AS
SELECT
    n.network_name,
    n.cidr,
    n.vlan_id,
    n.gateway,
    n.security_zone,
    ip.ip_address,
    ip.allocation_type,
    h.hostname,
    h.host_type,
    ni.interface_name,
    ni.mac_address
FROM networks n
LEFT JOIN ip_addresses ip ON ip.network_id = n.id
LEFT JOIN hosts h ON ip.host_id = h.id
LEFT JOIN network_interfaces ni ON ip.interface_id = ni.id
ORDER BY n.vlan_id, ip.ip_address;

-- View: Service dependency tree with impact analysis
CREATE VIEW v_service_dependencies AS
SELECT
    s1.service_name as dependent_service,
    s1.service_type as dependent_type,
    h1.hostname as dependent_host,
    sd.dependency_type,
    s2.service_name as dependency_service,
    s2.service_type as dependency_type_target,
    h2.hostname as dependency_host,
    s2.criticality as dependency_criticality
FROM service_dependencies sd
JOIN services s1 ON sd.dependent_service_id = s1.id
JOIN services s2 ON sd.dependency_service_id = s2.id
LEFT JOIN hosts h1 ON s1.host_id = h1.id
LEFT JOIN hosts h2 ON s2.host_id = h2.id;

-- View: Docker container inventory with health status
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
LEFT JOIN docker_container_volumes dcv ON dcv.container_id = dc.id
LEFT JOIN services s ON s.container_id = dc.id
GROUP BY dc.id;

-- View: Recent infrastructure changes (last 30 days)
CREATE VIEW v_recent_changes AS
SELECT
    ic.change_timestamp,
    ic.change_type,
    ic.entity_type,
    ic.entity_id,
    ic.changed_by,
    ic.change_source,
    ic.description
FROM infrastructure_changes ic
WHERE ic.change_timestamp >= datetime('now', '-30 days')
ORDER BY ic.change_timestamp DESC;

-- =============================================================================
-- TRIGGERS FOR AUTOMATIC VERSIONING
-- =============================================================================

-- Trigger: Log host changes
CREATE TRIGGER tr_hosts_update_version
AFTER UPDATE ON hosts
FOR EACH ROW
BEGIN
    INSERT INTO infrastructure_changes (
        change_type, entity_type, entity_id, changed_by, change_source,
        old_values, new_values, description
    )
    VALUES (
        'update', 'host', NEW.id, 'system', 'automation',
        json_object(
            'hostname', OLD.hostname, 'status', OLD.status,
            'cpu_cores', OLD.cpu_cores, 'total_ram_mb', OLD.total_ram_mb,
            'used_ram_mb', OLD.used_ram_mb
        ),
        json_object(
            'hostname', NEW.hostname, 'status', NEW.status,
            'cpu_cores', NEW.cpu_cores, 'total_ram_mb', NEW.total_ram_mb,
            'used_ram_mb', NEW.used_ram_mb
        ),
        'Host configuration updated'
    );

    UPDATE hosts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger: Log service status changes
CREATE TRIGGER tr_services_status_change
AFTER UPDATE OF status ON services
FOR EACH ROW
WHEN OLD.status != NEW.status
BEGIN
    INSERT INTO infrastructure_changes (
        change_type, entity_type, entity_id, changed_by, change_source,
        old_values, new_values, description
    )
    VALUES (
        'update', 'service', NEW.id, 'system', 'automation',
        json_object('status', OLD.status),
        json_object('status', NEW.status),
        'Service status changed from ' || OLD.status || ' to ' || NEW.status
    );
END;

-- Trigger: Log docker container changes
CREATE TRIGGER tr_docker_containers_update
AFTER UPDATE ON docker_containers
FOR EACH ROW
WHEN OLD.status != NEW.status OR OLD.health_status != NEW.health_status
BEGIN
    INSERT INTO infrastructure_changes (
        change_type, entity_type, entity_id, changed_by, change_source,
        old_values, new_values, description
    )
    VALUES (
        'update', 'docker_container', NEW.id, 'system', 'automation',
        json_object('status', OLD.status, 'health_status', OLD.health_status),
        json_object('status', NEW.status, 'health_status', NEW.health_status),
        'Container ' || NEW.container_name || ' state changed'
    );
END;

-- Trigger: Auto-update timestamps
CREATE TRIGGER tr_update_timestamp_hosts
AFTER UPDATE ON hosts
FOR EACH ROW
BEGIN
    UPDATE hosts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER tr_update_timestamp_services
AFTER UPDATE ON services
FOR EACH ROW
BEGIN
    UPDATE services SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER tr_update_timestamp_docker
AFTER UPDATE ON docker_containers
FOR EACH ROW
BEGIN
    UPDATE docker_containers SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- =============================================================================
-- UTILITY FUNCTIONS (via SQL)
-- =============================================================================

-- These queries can be saved as named queries in your application

-- Query: Find all services affected if a host goes down
-- Parameters: host_id
-- SELECT DISTINCT s.service_name, s.service_type, s.criticality
-- FROM services s
-- WHERE s.id IN (
--     SELECT sd.dependent_service_id
--     FROM service_dependencies sd
--     JOIN services dep_svc ON sd.dependency_service_id = dep_svc.id
--     WHERE dep_svc.host_id = ?
-- )
-- OR s.host_id = ?;

-- Query: Network path from source to destination
-- Requires recursive CTE (shown in documentation)

-- Query: Resource availability across all hosts
-- SELECT host_type,
--        COUNT(*) as total_hosts,
--        SUM(total_ram_mb) as total_ram_mb,
--        SUM(used_ram_mb) as used_ram_mb,
--        ROUND(AVG((used_ram_mb * 100.0) / total_ram_mb), 2) as avg_ram_utilization
-- FROM hosts
-- WHERE status = 'active'
-- GROUP BY host_type;

-- =============================================================================
-- END OF SCHEMA
-- =============================================================================
