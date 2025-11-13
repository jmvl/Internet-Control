-- Infrastructure Database Seed Data
-- Populated from infrastructure documentation as of 2025-10-17
-- This file contains the initial state of the infrastructure

-- =============================================================================
-- PHYSICAL HOSTS
-- =============================================================================

-- Proxmox Host (pve2)
INSERT INTO hosts (hostname, host_type, management_ip, status, cpu_cores, total_ram_mb, purpose, criticality, notes)
VALUES ('pve2', 'physical', '192.168.1.10', 'active', NULL, NULL, 'Proxmox virtualization host', 'critical', 'Main virtualization platform with dual NIC setup');

-- OpenWrt Router
INSERT INTO hosts (hostname, host_type, management_ip, status, purpose, criticality, notes)
VALUES ('openwrt', 'physical', '192.168.1.2', 'active', 'Wireless access point and gateway', 'critical', '4-radio setup with SQM traffic control');

-- Pi-hole DNS Server
INSERT INTO hosts (hostname, host_type, management_ip, status, purpose, criticality, notes)
VALUES ('pihole', 'physical', '192.168.1.5', 'active', 'DNS filtering and ad blocking', 'critical', 'Primary DNS server for network');

-- OpenMediaVault Storage Server
INSERT INTO hosts (hostname, host_type, management_ip, status, purpose, criticality, notes)
VALUES ('omv', 'physical', '192.168.1.9', 'active', 'Network attached storage and file server', 'critical', '6-disk BTRFS RAID + MergerFS pool, Docker host');

-- OPNsense VM
INSERT INTO hosts (hostname, host_type, management_ip, status, cpu_cores, total_ram_mb, used_ram_mb, parent_host_id, vmid, purpose, criticality, notes)
VALUES ('opnsense', 'vm', '192.168.1.3', 'active', 6, 3686, NULL, (SELECT id FROM hosts WHERE hostname = 'pve2'), 133, 'Firewall, DHCP, traffic shaper', 'critical', 'Dual NIC VM with WAN/LAN isolation');

-- LXC Containers on Proxmox
INSERT INTO hosts (hostname, host_type, management_ip, status, cpu_cores, total_ram_mb, parent_host_id, vmid, purpose, criticality, notes) VALUES
('ConfluenceDocker20220712', 'lxc', '192.168.1.21', 'active', 10, 10137, (SELECT id FROM hosts WHERE hostname = 'pve2'), 100, 'Confluence Wiki', 'high', 'Team documentation platform'),
('docker-debian-old', 'lxc', '192.168.1.20', 'stopped', NULL, NULL, (SELECT id FROM hosts WHERE hostname = 'pve2'), 101, 'Docker Host (deprecated)', 'low', 'IP conflict with PCT 111, decommissioned'),
('jira.accelior.com', 'lxc', '192.168.1.22', 'active', 6, 6144, (SELECT id FROM hosts WHERE hostname = 'pve2'), 102, 'JIRA Issue Tracking', 'high', 'Project management platform'),
('files.accelior.com', 'lxc', '192.168.1.25', 'active', 6, 2048, (SELECT id FROM hosts WHERE hostname = 'pve2'), 103, 'Seafile File Server', 'high', 'Cloud file storage and sync'),
('wanderwish', 'lxc', '192.168.1.29', 'active', 12, 4096, (SELECT id FROM hosts WHERE hostname = 'pve2'), 109, 'Web Application', 'medium', 'Custom web application'),
('ansible-mgmt', 'lxc', '192.168.1.26', 'active', 1, 1024, (SELECT id FROM hosts WHERE hostname = 'pve2'), 110, 'Ansible Automation', 'medium', 'Infrastructure automation and configuration management'),
('docker-debian', 'lxc', '192.168.1.20', 'active', 12, 10240, (SELECT id FROM hosts WHERE hostname = 'pve2'), 111, 'Docker Host (active)', 'critical', 'Primary Docker host for Supabase stack'),
('mail.vega-messenger.com', 'lxc', '192.168.1.30', 'active', 8, 8192, (SELECT id FROM hosts WHERE hostname = 'pve2'), 130, 'Mail Server', 'high', 'Email services'),
('gitlab.accelior.com', 'lxc', '192.168.1.35', 'stopped', 8, 6144, (SELECT id FROM hosts WHERE hostname = 'pve2'), 501, 'GitLab CE Server', 'medium', 'Git repository and CI/CD'),
('CT502', 'lxc', '192.168.1.33', 'active', NULL, NULL, (SELECT id FROM hosts WHERE hostname = 'pve2'), 502, 'General Purpose', 'low', 'Utility container'),
('gitlab-bulk', 'lxc', NULL, 'stopped', NULL, NULL, (SELECT id FROM hosts WHERE hostname = 'pve2'), 505, 'GitLab Bulk Operations', 'low', 'Uses DHCP');

-- Docker hosts as distinct entities
INSERT INTO hosts (hostname, host_type, management_ip, status, purpose, criticality, notes) VALUES
('docker-host-pct111', 'docker_host', '192.168.1.20', 'active', 'Supabase and n8n platform', 'critical', 'LXC container PCT 111 running Docker'),
('docker-host-omv', 'docker_host', '192.168.1.9', 'active', 'Media and monitoring services', 'high', 'OMV server running Docker containers');

-- =============================================================================
-- NETWORK INTERFACES
-- =============================================================================

-- Proxmox Host NICs
INSERT INTO network_interfaces (host_id, interface_name, interface_type, mac_address, pci_slot, driver, speed_mbps, link_status, description) VALUES
((SELECT id FROM hosts WHERE hostname = 'pve2'), 'enp1s0', 'physical', NULL, '01:00.0', 'RTL8125', 2500, 'up', 'Realtek RTL8125 2.5GbE LAN NIC'),
((SELECT id FROM hosts WHERE hostname = 'pve2'), 'enp2s0f0', 'physical', NULL, '02:00.0', 'RTL8111', 1000, 'up', 'Realtek RTL8111 1GbE WAN NIC'),
((SELECT id FROM hosts WHERE hostname = 'pve2'), 'wlp3s0', 'wifi', NULL, '03:00.0', NULL, NULL, 'up', 'WiFi interface for backup/management');

-- Proxmox Bridges
INSERT INTO network_interfaces (host_id, interface_name, interface_type, bridge_ports, link_status, description) VALUES
((SELECT id FROM hosts WHERE hostname = 'pve2'), 'vmbr0', 'bridge', '["enp1s0"]', 'up', 'LAN Bridge for internal network'),
((SELECT id FROM hosts WHERE hostname = 'pve2'), 'vmbr1', 'bridge', '["enp2s0f0"]', 'up', 'WAN Bridge for internet connection');

-- OPNsense VM interfaces
INSERT INTO network_interfaces (host_id, interface_name, interface_type, link_status, description) VALUES
((SELECT id FROM hosts WHERE hostname = 'opnsense'), 'net0', 'virtual', 'up', 'LAN interface (tap133i0 → vmbr0)'),
((SELECT id FROM hosts WHERE hostname = 'opnsense'), 'net1', 'virtual', 'up', 'WAN interface (tap133i1 → vmbr1)');

-- OpenWrt wireless radios
INSERT INTO network_interfaces (host_id, interface_name, interface_type, link_status, description) VALUES
((SELECT id FROM hosts WHERE hostname = 'openwrt'), 'radio0', 'wifi', 'up', '2.4GHz HE20 Ch9 - Primary network (Znutar)'),
((SELECT id FROM hosts WHERE hostname = 'openwrt'), 'radio1', 'wifi', 'down', '5GHz HE80 Ch36 - High-speed network (Znutar_2)'),
((SELECT id FROM hosts WHERE hostname = 'openwrt'), 'radio2', 'wifi', 'down', '2.4GHz HE20 Ch1 - Default/fallback (OpenWrt)'),
((SELECT id FROM hosts WHERE hostname = 'openwrt'), 'radio3', 'wifi', 'down', '5GHz HE80 Ch36 - Default/fallback (OpenWrt)');

-- =============================================================================
-- STORAGE DEVICES (OMV)
-- =============================================================================

-- System drive
INSERT INTO storage_devices (host_id, device_name, device_type, model, capacity_gb, filesystem_type, mount_point, purpose, notes) VALUES
((SELECT id FROM hosts WHERE hostname = 'omv'), '/dev/sda', 'disk', 'CT240BX500SSD1', 240, 'ext4', '/', 'System drive (SSD)', 'Boot and OS installation');

-- RAID mirror members
INSERT INTO storage_devices (host_id, device_name, device_type, model, capacity_gb, filesystem_type, raid_level, purpose, notes) VALUES
((SELECT id FROM hosts WHERE hostname = 'omv'), '/dev/sdb', 'disk', 'WDC WD40EZRX-00SPEB0', 4000, 'btrfs', 'raid1', 'RAID mirror member 1', 'Critical data redundancy'),
((SELECT id FROM hosts WHERE hostname = 'omv'), '/dev/sde', 'disk', 'ST4000NE001-2MA101', 4000, 'btrfs', 'raid1', 'RAID mirror member 2', 'Critical data redundancy');

-- RAID array (logical)
INSERT INTO storage_devices (host_id, device_name, device_type, filesystem_type, mount_point, capacity_gb, used_gb, available_gb, raid_level, raid_members, purpose) VALUES
((SELECT id FROM hosts WHERE hostname = 'omv'), '/srv/raid', 'raid', 'btrfs', '/srv/raid', 3700, 1850, 1850, 'raid1', '["sdb", "sde"]', 'BTRFS RAID1 mirror for critical data');

-- MergerFS pool members
INSERT INTO storage_devices (host_id, device_name, device_type, model, capacity_gb, filesystem_type, purpose) VALUES
((SELECT id FROM hosts WHERE hostname = 'omv'), '/dev/sdc', 'disk', 'WDC WD30EZRX-00MMMB0', 3000, 'btrfs', 'MergerFS pool member'),
((SELECT id FROM hosts WHERE hostname = 'omv'), '/dev/sdd', 'disk', 'WDC WD20EVDS-63T3B0', 2000, 'btrfs', 'MergerFS pool member'),
((SELECT id FROM hosts WHERE hostname = 'omv'), '/dev/sdf', 'disk', 'WDC WD140EMFZ-11A0WA0', 14000, 'btrfs', 'MergerFS pool member (primary capacity)');

-- MergerFS pool (logical)
INSERT INTO storage_devices (host_id, device_name, device_type, filesystem_type, mount_point, capacity_gb, used_gb, available_gb, raid_members, purpose) VALUES
((SELECT id FROM hosts WHERE hostname = 'omv'), '/srv/mergerfs/MergerFS/', 'mergerfs', 'fuse', '/srv/mergerfs/MergerFS/', 18000, 14400, 3600, '["sdc", "sdd", "sdf"]', 'Unified storage pool');

-- =============================================================================
-- NETWORKS AND SUBNETS
-- =============================================================================

-- Primary LAN
INSERT INTO networks (network_name, cidr, vlan_id, gateway, dns_servers, dhcp_enabled, dhcp_range_start, dhcp_range_end, purpose, security_zone) VALUES
('LAN_Primary', '192.168.1.0/24', NULL, '192.168.1.3', '["192.168.1.5", "1.1.1.1"]', 1, '192.168.1.10', '192.168.1.200', 'Primary internal network', 'private');

-- =============================================================================
-- IP ADDRESS ALLOCATIONS
-- =============================================================================

-- Static IP assignments
INSERT INTO ip_addresses (ip_address, network_id, host_id, allocation_type, hostname, purpose) VALUES
('192.168.1.2', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'openwrt'), 'static', 'openwrt', 'Wireless AP and gateway'),
('192.168.1.3', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'opnsense'), 'static', 'opnsense', 'Firewall and DHCP server'),
('192.168.1.5', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'pihole'), 'static', 'pihole', 'DNS filtering server'),
('192.168.1.9', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'omv'), 'static', 'omv', 'NAS and storage server'),
('192.168.1.10', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'pve2'), 'static', 'pve2', 'Proxmox host management'),
('192.168.1.20', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'docker-debian'), 'static', 'docker-debian', 'Docker host (active)'),
('192.168.1.21', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'ConfluenceDocker20220712'), 'static', 'confluence', 'Confluence Wiki'),
('192.168.1.22', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'jira.accelior.com'), 'static', 'jira', 'JIRA Issue Tracking'),
('192.168.1.25', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'files.accelior.com'), 'static', 'seafile', 'Seafile File Server'),
('192.168.1.26', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'ansible-mgmt'), 'static', 'ansible', 'Ansible management'),
('192.168.1.29', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'wanderwish'), 'static', 'wanderwish', 'Web application'),
('192.168.1.30', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'mail.vega-messenger.com'), 'static', 'mail', 'Mail server'),
('192.168.1.33', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'CT502'), 'static', 'ct502', 'General purpose CT'),
('192.168.1.35', (SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), (SELECT id FROM hosts WHERE hostname = 'gitlab.accelior.com'), 'static', 'gitlab', 'GitLab server');

-- =============================================================================
-- NETWORK ROUTES
-- =============================================================================

-- Default route via OPNsense
INSERT INTO network_routes (source_network_id, destination_network, gateway_ip, gateway_host_id, route_type, description) VALUES
((SELECT id FROM networks WHERE cidr = '192.168.1.0/24'), 'default', '192.168.1.3', (SELECT id FROM hosts WHERE hostname = 'opnsense'), 'default', 'Default gateway to internet');

-- =============================================================================
-- DOCKER CONTAINERS (PCT 111 - docker-debian)
-- =============================================================================

-- Supabase Stack
INSERT INTO docker_containers (docker_host_id, container_id, container_name, image, image_tag, status, health_status, restart_policy, network_mode) VALUES
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'postgres-db', 'supabase-db', 'supabase/postgres', '15.8.1.147', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'studio', 'supabase-studio', 'supabase/studio', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'auth', 'supabase-auth', 'supabase/gotrue', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'storage', 'supabase-storage', 'supabase/storage-api', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'rest', 'supabase-rest', 'postgrest/postgrest', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'realtime', 'supabase-realtime', 'supabase/realtime', 'latest', 'running', 'unhealthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'kong', 'supabase-kong', 'kong', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'meta', 'supabase-meta', 'supabase/postgres-meta', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'edge-fn', 'supabase-edge-functions', 'supabase/edge-runtime', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'logflare', 'supabase-analytics', 'supabase/logflare', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'pooler', 'supabase-pooler', 'supabase/supavisor', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'vector', 'supabase-vector', 'timberio/vector', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'imgproxy', 'supabase-imgproxy', 'darthsim/imgproxy', 'latest', 'running', 'healthy', 'unless-stopped', 'bridge');

-- Development & Automation
INSERT INTO docker_containers (docker_host_id, container_id, container_name, image, status, health_status, restart_policy, ports) VALUES
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'n8n', 'n8n', 'n8nio/n8n', 'running', 'healthy', 'unless-stopped', '["5678:5678"]'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'gotenberg', 'gotenberg', 'gotenberg/gotenberg', 'running', 'healthy', 'unless-stopped', NULL);

-- Container Management
INSERT INTO docker_containers (docker_host_id, container_id, container_name, image, status, ports) VALUES
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'portainer', 'portainer', 'portainer/portainer-ce', 'running', '["8000:8000", "9443:9443"]'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-pct111'), 'portainer-agent', 'portainer-agent', 'portainer/agent', 'running', '["9001:9001"]');

-- =============================================================================
-- DOCKER CONTAINERS (OMV)
-- =============================================================================

-- Content Management & Library
INSERT INTO docker_containers (docker_host_id, container_id, container_name, image, status, ports) VALUES
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'calibre', 'calibre', 'linuxserver/calibre', 'running', '["8082:8082", "8083:8083"]'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'wallabag', 'wallabag', 'wallabag/wallabag', 'running', '["8880:80"]'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'wallabag-redis', 'wallabag-redis', 'redis', 'running', NULL),
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'wallabag-db', 'wallabag-mariadb', 'mariadb', 'running', NULL);

UPDATE docker_containers SET health_status = 'healthy' WHERE container_name = 'wallabag-redis';
UPDATE docker_containers SET health_status = 'unhealthy' WHERE container_name = 'wallabag-mariadb';

-- Photo & Media Management (Immich Stack)
INSERT INTO docker_containers (docker_host_id, container_id, container_name, image, status, health_status, ports) VALUES
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'immich-server', 'immich-server', 'ghcr.io/immich-app/immich-server', 'running', 'healthy', '["2283:3001"]'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'immich-postgres', 'immich-postgres', 'tensorchord/pgvecto-rs', 'running', 'healthy', NULL),
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'immich-ml', 'immich-machine-learning', 'ghcr.io/immich-app/immich-machine-learning', 'running', 'healthy', NULL),
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'immich-redis', 'immich-redis', 'redis', 'running', 'healthy', NULL);

-- Network & Proxy Management
INSERT INTO docker_containers (docker_host_id, container_id, container_name, image, status, ports) VALUES
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'npm', 'nginx-proxy-manager', 'jc21/nginx-proxy-manager', 'running', '["80:80", "81:81", "443:443"]');

-- File Synchronization
INSERT INTO docker_containers (docker_host_id, container_id, container_name, image, status, ports) VALUES
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'syncthing', 'syncthing', 'syncthing/syncthing', 'running', '["8384:8384", "22000:22000", "21027:21027/udp"]');

-- Monitoring & Management
INSERT INTO docker_containers (docker_host_id, container_id, container_name, image, image_tag, status, health_status, ports) VALUES
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'uptime-kuma', 'uptime-kuma', 'louislam/uptime-kuma', '1', 'running', 'healthy', '["3010:3001"]'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'portainer-omv', 'portainer', 'portainer/portainer-ce', NULL, 'running', NULL, '["8000:8000", "9443:9443"]'),
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'portainer-agent-omv', 'portainer-agent', 'portainer/agent', NULL, 'running', NULL, '["9001:9001"]');

-- Custom Applications
INSERT INTO docker_containers (docker_host_id, container_id, container_name, image, status, ports) VALUES
((SELECT id FROM hosts WHERE hostname = 'docker-host-omv'), 'wedding-share', 'wedding-share', 'custom/wedding-share', 'running', '["8080:80"]');

-- =============================================================================
-- SERVICES
-- =============================================================================

-- Infrastructure Services
INSERT INTO services (service_name, service_type, host_id, protocol, port, endpoint_url, health_check_url, status, criticality, description) VALUES
('OpenWrt Web UI', 'web', (SELECT id FROM hosts WHERE hostname = 'openwrt'), 'http', 80, 'http://192.168.1.2', 'http://192.168.1.2', 'healthy', 'high', 'LuCI web interface'),
('OPNsense Web UI', 'web', (SELECT id FROM hosts WHERE hostname = 'opnsense'), 'https', 443, 'https://192.168.1.3', 'https://192.168.1.3', 'healthy', 'critical', 'Firewall management interface'),
('OPNsense DHCP', 'dhcp', (SELECT id FROM hosts WHERE hostname = 'opnsense'), 'udp', 67, NULL, NULL, 'healthy', 'critical', 'Network DHCP server'),
('Pi-hole DNS', 'dns', (SELECT id FROM hosts WHERE hostname = 'pihole'), 'udp', 53, NULL, NULL, 'healthy', 'critical', 'DNS filtering and resolution'),
('Pi-hole Admin', 'web', (SELECT id FROM hosts WHERE hostname = 'pihole'), 'http', 80, 'http://192.168.1.5/admin', 'http://192.168.1.5/admin', 'healthy', 'high', 'Pi-hole admin interface'),
('Proxmox Web UI', 'web', (SELECT id FROM hosts WHERE hostname = 'pve2'), 'https', 8006, 'https://192.168.1.10:8006', 'https://192.168.1.10:8006', 'healthy', 'critical', 'Proxmox VE management'),
('OMV Web UI', 'web', (SELECT id FROM hosts WHERE hostname = 'omv'), 'http', 80, 'http://192.168.1.9', 'http://192.168.1.9', 'healthy', 'high', 'OpenMediaVault admin panel'),
('OMV Samba', 'storage', (SELECT id FROM hosts WHERE hostname = 'omv'), 'smb', 445, '\\\\192.168.1.9\\Pool', NULL, 'healthy', 'high', 'Network file sharing');

-- Application Services (LXC)
INSERT INTO services (service_name, service_type, host_id, protocol, port, endpoint_url, status, criticality, description) VALUES
('Confluence', 'web', (SELECT id FROM hosts WHERE hostname = 'ConfluenceDocker20220712'), 'https', 443, 'https://confluence.accelior.com', 'healthy', 'high', 'Team documentation wiki'),
('JIRA', 'web', (SELECT id FROM hosts WHERE hostname = 'jira.accelior.com'), 'https', 443, 'https://jira.accelior.com', 'healthy', 'high', 'Project management and issue tracking'),
('Seafile', 'web', (SELECT id FROM hosts WHERE hostname = 'files.accelior.com'), 'https', 443, 'https://files.accelior.com', 'healthy', 'high', 'Cloud file storage and sync'),
('Mail Server', 'other', (SELECT id FROM hosts WHERE hostname = 'mail.vega-messenger.com'), 'smtp', 25, 'mail.vega-messenger.com', 'healthy', 'high', 'Email services');

-- Docker Services (Supabase Stack)
INSERT INTO services (service_name, service_type, container_id, protocol, port, endpoint_url, status, criticality, description) VALUES
('Supabase Studio', 'web', (SELECT id FROM docker_containers WHERE container_name = 'supabase-studio'), 'http', 3000, 'http://192.168.1.20:3000', 'healthy', 'high', 'Database admin dashboard'),
('Supabase Auth API', 'api', (SELECT id FROM docker_containers WHERE container_name = 'supabase-auth'), 'http', 9999, 'http://192.168.1.20:9999', 'healthy', 'critical', 'Authentication API'),
('Supabase REST API', 'api', (SELECT id FROM docker_containers WHERE container_name = 'supabase-rest'), 'http', 3000, 'http://192.168.1.20:3000', 'healthy', 'critical', 'Auto-generated REST API'),
('Supabase Storage API', 'api', (SELECT id FROM docker_containers WHERE container_name = 'supabase-storage'), 'http', 5000, 'http://192.168.1.20:5000', 'healthy', 'high', 'File storage API'),
('Supabase Kong Gateway', 'proxy', (SELECT id FROM docker_containers WHERE container_name = 'supabase-kong'), 'http', 8000, 'http://192.168.1.20:8000', 'healthy', 'critical', 'API gateway'),
('PostgreSQL', 'database', (SELECT id FROM docker_containers WHERE container_name = 'supabase-db'), 'tcp', 5432, NULL, 'healthy', 'critical', 'Primary database'),
('n8n Automation', 'web', (SELECT id FROM docker_containers WHERE container_name = 'n8n'), 'http', 5678, 'http://192.168.1.20:5678', 'healthy', 'medium', 'Workflow automation'),
('Portainer', 'web', (SELECT id FROM docker_containers WHERE container_name = 'portainer'), 'https', 9443, 'https://192.168.1.20:9443', 'healthy', 'medium', 'Container management');

-- Docker Services (OMV Stack)
INSERT INTO services (service_name, service_type, container_id, protocol, port, endpoint_url, status, criticality, description) VALUES
('Immich Photos', 'web', (SELECT id FROM docker_containers WHERE container_name = 'immich-server'), 'http', 2283, 'http://192.168.1.9:2283', 'healthy', 'medium', 'AI-powered photo management'),
('Nginx Proxy Manager', 'proxy', (SELECT id FROM docker_containers WHERE container_name = 'nginx-proxy-manager'), 'https', 443, 'https://192.168.1.9:81', 'healthy', 'high', 'Reverse proxy and SSL'),
('Uptime Kuma', 'monitoring', (SELECT id FROM docker_containers WHERE container_name = 'uptime-kuma'), 'http', 3010, 'http://192.168.1.9:3010', 'healthy', 'medium', 'Service monitoring'),
('Calibre', 'web', (SELECT id FROM docker_containers WHERE container_name = 'calibre'), 'http', 8082, 'http://192.168.1.9:8082', 'healthy', 'low', 'E-book management'),
('Syncthing', 'storage', (SELECT id FROM docker_containers WHERE container_name = 'syncthing'), 'http', 8384, 'http://192.168.1.9:8384', 'healthy', 'medium', 'File synchronization');

-- =============================================================================
-- SERVICE DEPENDENCIES
-- =============================================================================

-- OPNsense dependencies
INSERT INTO service_dependencies (dependent_service_id, dependency_service_id, dependency_type, description) VALUES
((SELECT id FROM services WHERE service_name = 'OPNsense DHCP'), (SELECT id FROM services WHERE service_name = 'Pi-hole DNS'), 'hard', 'DHCP assigns Pi-hole as DNS server');

-- Supabase internal dependencies
INSERT INTO service_dependencies (dependent_service_id, dependency_service_id, dependency_type, description) VALUES
((SELECT id FROM services WHERE service_name = 'Supabase Studio'), (SELECT id FROM services WHERE service_name = 'PostgreSQL'), 'hard', 'Studio requires database access'),
((SELECT id FROM services WHERE service_name = 'Supabase Auth API'), (SELECT id FROM services WHERE service_name = 'PostgreSQL'), 'hard', 'Auth stores data in PostgreSQL'),
((SELECT id FROM services WHERE service_name = 'Supabase REST API'), (SELECT id FROM services WHERE service_name = 'PostgreSQL'), 'hard', 'PostgREST connects to database'),
((SELECT id FROM services WHERE service_name = 'Supabase Storage API'), (SELECT id FROM services WHERE service_name = 'PostgreSQL'), 'hard', 'Storage metadata in database'),
((SELECT id FROM services WHERE service_name = 'Supabase Kong Gateway'), (SELECT id FROM services WHERE service_name = 'Supabase Auth API'), 'hard', 'Kong routes auth requests'),
((SELECT id FROM services WHERE service_name = 'Supabase Kong Gateway'), (SELECT id FROM services WHERE service_name = 'Supabase REST API'), 'hard', 'Kong routes REST requests'),
((SELECT id FROM services WHERE service_name = 'Supabase Kong Gateway'), (SELECT id FROM services WHERE service_name = 'Supabase Storage API'), 'hard', 'Kong routes storage requests');

-- Docker host dependencies
INSERT INTO service_dependencies (dependent_service_id, dependency_service_id, dependency_type, description) VALUES
((SELECT id FROM services WHERE service_name = 'Supabase Studio'), (SELECT id FROM services WHERE service_name = 'Portainer'), 'soft', 'Portainer manages all containers'),
((SELECT id FROM services WHERE service_name = 'n8n Automation'), (SELECT id FROM services WHERE service_name = 'Supabase Auth API'), 'soft', 'n8n can integrate with Supabase');

-- Immich dependencies
INSERT INTO service_dependencies (dependent_service_id, dependency_service_id, dependency_type, description) VALUES
((SELECT id FROM services WHERE service_name = 'Immich Photos'), (SELECT id FROM services WHERE service_name = 'OMV Samba'), 'hard', 'Immich stores photos on NAS storage');

-- Monitoring dependencies
INSERT INTO service_dependencies (dependent_service_id, dependency_service_id, dependency_type, description) VALUES
((SELECT id FROM services WHERE service_name = 'Uptime Kuma'), (SELECT id FROM services WHERE service_name = 'n8n Automation'), 'soft', 'Monitors n8n service'),
((SELECT id FROM services WHERE service_name = 'Uptime Kuma'), (SELECT id FROM services WHERE service_name = 'Supabase Studio'), 'soft', 'Monitors Supabase services');

-- Network dependencies
INSERT INTO service_dependencies (dependent_service_id, dependency_service_id, dependency_type, description) VALUES
((SELECT id FROM services WHERE service_name = 'Confluence'), (SELECT id FROM services WHERE service_name = 'OPNsense DHCP'), 'hard', 'Requires network connectivity'),
((SELECT id FROM services WHERE service_name = 'JIRA'), (SELECT id FROM services WHERE service_name = 'OPNsense DHCP'), 'hard', 'Requires network connectivity'),
((SELECT id FROM services WHERE service_name = 'Seafile'), (SELECT id FROM services WHERE service_name = 'Pi-hole DNS'), 'hard', 'Requires DNS resolution');

-- =============================================================================
-- INITIAL HEALTH CHECKS
-- =============================================================================

-- Record initial health status for critical services
INSERT INTO health_checks (service_id, status, response_time_ms, check_source) VALUES
((SELECT id FROM services WHERE service_name = 'OPNsense Web UI'), 'healthy', 45, 'manual'),
((SELECT id FROM services WHERE service_name = 'Pi-hole Admin'), 'healthy', 32, 'manual'),
((SELECT id FROM services WHERE service_name = 'Supabase Studio'), 'healthy', 120, 'manual'),
((SELECT id FROM services WHERE service_name = 'PostgreSQL'), 'healthy', 8, 'manual'),
((SELECT id FROM services WHERE service_name = 'Immich Photos'), 'healthy', 95, 'manual');

-- =============================================================================
-- SEED DATA COMPLETE
-- =============================================================================

-- Verify data
SELECT 'Hosts loaded: ' || COUNT(*) FROM hosts;
SELECT 'Network interfaces loaded: ' || COUNT(*) FROM network_interfaces;
SELECT 'Storage devices loaded: ' || COUNT(*) FROM storage_devices;
SELECT 'Networks loaded: ' || COUNT(*) FROM networks;
SELECT 'IP addresses loaded: ' || COUNT(*) FROM ip_addresses;
SELECT 'Docker containers loaded: ' || COUNT(*) FROM docker_containers;
SELECT 'Services loaded: ' || COUNT(*) FROM services;
SELECT 'Service dependencies loaded: ' || COUNT(*) FROM service_dependencies;
