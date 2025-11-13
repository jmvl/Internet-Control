-- Network Topology Queries
-- Use these queries to understand network layout, IP allocations, and routing

-- =============================================================================
-- COMPLETE NETWORK TOPOLOGY
-- =============================================================================

-- Query: Show complete network topology with all IP allocations
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
    h.status,
    ni.interface_name,
    ni.interface_type,
    ni.mac_address
FROM networks n
LEFT JOIN ip_addresses ip ON ip.network_id = n.id
LEFT JOIN hosts h ON ip.host_id = h.id
LEFT JOIN network_interfaces ni ON ip.interface_id = ni.id
ORDER BY n.vlan_id, CAST(SUBSTR(ip.ip_address, INSTR(ip.ip_address, '.') + 1) AS INTEGER);

-- =============================================================================
-- IP ADDRESS INVENTORY
-- =============================================================================

-- Query: List all IP addresses with their current assignments
SELECT
    ip.ip_address,
    ip.allocation_type,
    h.hostname,
    h.host_type,
    h.status,
    CASE
        WHEN h.status = 'active' THEN '🟢'
        WHEN h.status = 'stopped' THEN '🔴'
        WHEN h.status = 'maintenance' THEN '🟡'
        ELSE '⚪'
    END as status_indicator,
    ip.purpose,
    n.network_name,
    n.cidr
FROM ip_addresses ip
JOIN networks n ON ip.network_id = n.id
LEFT JOIN hosts h ON ip.host_id = h.id
ORDER BY
    CAST(SUBSTR(ip.ip_address, 1, INSTR(ip.ip_address, '.') - 1) AS INTEGER),
    CAST(SUBSTR(SUBSTR(ip.ip_address, INSTR(ip.ip_address, '.') + 1), 1,
         INSTR(SUBSTR(ip.ip_address, INSTR(ip.ip_address, '.') + 1), '.') - 1) AS INTEGER),
    CAST(SUBSTR(SUBSTR(SUBSTR(ip.ip_address, INSTR(ip.ip_address, '.') + 1),
         INSTR(SUBSTR(ip.ip_address, INSTR(ip.ip_address, '.') + 1), '.') + 1), 1,
         INSTR(SUBSTR(SUBSTR(ip.ip_address, INSTR(ip.ip_address, '.') + 1),
         INSTR(SUBSTR(ip.ip_address, INSTR(ip.ip_address, '.') + 1), '.') + 1), '.') - 1) AS INTEGER),
    CAST(SUBSTR(ip.ip_address, LENGTH(ip.ip_address) - INSTR(REVERSE(ip.ip_address), '.') + 2) AS INTEGER);

-- =============================================================================
-- AVAILABLE IP ADDRESSES
-- =============================================================================

-- Query: Find available IP addresses in a subnet
-- Note: This is a simplified version. For production, you'd want to generate all possible IPs
WITH assigned_ips AS (
    SELECT ip_address
    FROM ip_addresses
    WHERE network_id = (SELECT id FROM networks WHERE cidr = '192.168.1.0/24')
)
SELECT
    '192.168.1.' || seq as available_ip
FROM (
    -- Generate sequence of possible host IDs (10-254)
    WITH RECURSIVE cnt(x) AS (
        SELECT 10
        UNION ALL
        SELECT x+1 FROM cnt WHERE x < 254
    )
    SELECT x as seq FROM cnt
) hosts
WHERE '192.168.1.' || seq NOT IN (SELECT ip_address FROM assigned_ips)
ORDER BY CAST(seq AS INTEGER)
LIMIT 20;  -- Show first 20 available IPs

-- =============================================================================
-- NETWORK INTERFACE INVENTORY
-- =============================================================================

-- Query: List all network interfaces with their configuration
SELECT
    h.hostname,
    h.host_type,
    ni.interface_name,
    ni.interface_type,
    ni.mac_address,
    ni.link_status,
    ni.speed_mbps,
    ip.ip_address,
    n.cidr as network,
    ni.bridge_name,
    ni.description
FROM network_interfaces ni
JOIN hosts h ON ni.host_id = h.id
LEFT JOIN ip_addresses ip ON ip.interface_id = ni.id
LEFT JOIN networks n ON ip.network_id = n.id
ORDER BY h.hostname, ni.interface_name;

-- =============================================================================
-- BRIDGE CONFIGURATION
-- =============================================================================

-- Query: Show bridge configuration with member interfaces
SELECT
    h.hostname as bridge_host,
    ni.interface_name as bridge_name,
    ni.bridge_ports,
    COUNT(DISTINCT ni_member.id) as member_count,
    GROUP_CONCAT(DISTINCT ni_member.interface_name, ', ') as members
FROM network_interfaces ni
JOIN hosts h ON ni.host_id = h.id
LEFT JOIN network_interfaces ni_member ON ni_member.bridge_name = ni.interface_name AND ni_member.host_id = h.id
WHERE ni.interface_type = 'bridge'
GROUP BY ni.id
ORDER BY h.hostname, ni.interface_name;

-- =============================================================================
-- ROUTING TABLE
-- =============================================================================

-- Query: Show complete routing table
SELECT
    src_net.network_name as source_network,
    src_net.cidr as source_cidr,
    nr.destination_network,
    nr.gateway_ip,
    gw_host.hostname as gateway_hostname,
    nr.route_type,
    nr.metric,
    nr.interface_name,
    nr.description
FROM network_routes nr
LEFT JOIN networks src_net ON nr.source_network_id = src_net.id
LEFT JOIN hosts gw_host ON nr.gateway_host_id = gw_host.id
ORDER BY nr.metric, src_net.network_name, nr.destination_network;

-- =============================================================================
-- NETWORK PATH TRACING
-- =============================================================================

-- Query: Trace network path from source to destination
-- This is a simplified example - adjust based on your actual routing configuration
WITH RECURSIVE path AS (
    -- Start from LAN network
    SELECT
        n.network_name,
        n.cidr,
        nr.gateway_ip,
        nr.destination_network,
        h.hostname as gateway_host,
        1 as hop_count,
        n.network_name as path
    FROM networks n
    JOIN network_routes nr ON nr.source_network_id = n.id
    LEFT JOIN hosts h ON nr.gateway_host_id = h.id
    WHERE n.cidr = '192.168.1.0/24'

    UNION ALL

    -- Follow routes recursively
    SELECT
        next_net.network_name,
        next_net.cidr,
        next_route.gateway_ip,
        next_route.destination_network,
        next_host.hostname,
        p.hop_count + 1,
        p.path || ' → ' || COALESCE(next_net.network_name, next_route.destination_network)
    FROM path p
    LEFT JOIN networks next_net ON p.destination_network = next_net.cidr
    LEFT JOIN network_routes next_route ON next_route.source_network_id = next_net.id
    LEFT JOIN hosts next_host ON next_route.gateway_host_id = next_host.id
    WHERE p.hop_count < 10 AND next_route.id IS NOT NULL
)
SELECT
    hop_count,
    network_name,
    cidr,
    gateway_ip,
    gateway_host,
    destination_network,
    path
FROM path
ORDER BY hop_count;

-- =============================================================================
-- VLAN INVENTORY
-- =============================================================================

-- Query: List all VLANs with their configuration
SELECT
    n.vlan_id,
    n.network_name,
    n.cidr,
    n.gateway,
    n.security_zone,
    n.purpose,
    COUNT(DISTINCT ip.id) as assigned_ips,
    COUNT(DISTINCT h.id) as connected_hosts,
    GROUP_CONCAT(DISTINCT h.hostname, ', ') as hosts
FROM networks n
LEFT JOIN ip_addresses ip ON ip.network_id = n.id
LEFT JOIN hosts h ON ip.host_id = h.id
WHERE n.vlan_id IS NOT NULL
GROUP BY n.id
ORDER BY n.vlan_id;

-- =============================================================================
-- MAC ADDRESS TABLE
-- =============================================================================

-- Query: MAC address to IP/hostname mapping
SELECT
    ni.mac_address,
    h.hostname,
    h.host_type,
    ip.ip_address,
    ni.interface_name,
    ni.interface_type,
    h.status
FROM network_interfaces ni
JOIN hosts h ON ni.host_id = h.id
LEFT JOIN ip_addresses ip ON ip.interface_id = ni.id
WHERE ni.mac_address IS NOT NULL
ORDER BY ni.mac_address;

-- =============================================================================
-- DHCP RANGE UTILIZATION
-- =============================================================================

-- Query: Show DHCP pool utilization
SELECT
    n.network_name,
    n.cidr,
    n.dhcp_range_start,
    n.dhcp_range_end,
    COUNT(ip.id) as assigned_dhcp_ips,
    -- Calculate pool size (simplified - assumes contiguous range)
    CAST(SUBSTR(n.dhcp_range_end, LENGTH(n.dhcp_range_end) - INSTR(REVERSE(n.dhcp_range_end), '.') + 2) AS INTEGER) -
    CAST(SUBSTR(n.dhcp_range_start, LENGTH(n.dhcp_range_start) - INSTR(REVERSE(n.dhcp_range_start), '.') + 2) AS INTEGER) + 1 as pool_size,
    ROUND(
        (COUNT(ip.id) * 100.0) /
        (CAST(SUBSTR(n.dhcp_range_end, LENGTH(n.dhcp_range_end) - INSTR(REVERSE(n.dhcp_range_end), '.') + 2) AS INTEGER) -
         CAST(SUBSTR(n.dhcp_range_start, LENGTH(n.dhcp_range_start) - INSTR(REVERSE(n.dhcp_range_start), '.') + 2) AS INTEGER) + 1),
        2
    ) as utilization_pct
FROM networks n
LEFT JOIN ip_addresses ip ON ip.network_id = n.id AND ip.allocation_type = 'dhcp'
WHERE n.dhcp_enabled = 1
GROUP BY n.id;

-- =============================================================================
-- NETWORK CONNECTIVITY MAP
-- =============================================================================

-- Query: Show which hosts can communicate with each other (same network)
SELECT DISTINCT
    h1.hostname as host1,
    h1.management_ip as ip1,
    h2.hostname as host2,
    h2.management_ip as ip2,
    n.network_name,
    n.cidr,
    n.security_zone
FROM ip_addresses ip1
JOIN ip_addresses ip2 ON ip1.network_id = ip2.network_id AND ip1.id < ip2.id
JOIN networks n ON ip1.network_id = n.id
LEFT JOIN hosts h1 ON ip1.host_id = h1.id
LEFT JOIN hosts h2 ON ip2.host_id = h2.id
WHERE h1.status = 'active' AND h2.status = 'active'
ORDER BY n.network_name, h1.hostname, h2.hostname;
