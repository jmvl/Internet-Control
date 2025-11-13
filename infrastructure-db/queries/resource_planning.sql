-- Resource Planning Queries
-- Use these queries for capacity planning, resource allocation, and optimization

-- =============================================================================
-- HOST RESOURCE UTILIZATION
-- =============================================================================

-- Query: Show resource utilization across all active hosts
SELECT
    hostname,
    host_type,
    management_ip,
    cpu_cores,
    total_ram_mb,
    used_ram_mb,
    (total_ram_mb - COALESCE(used_ram_mb, 0)) as available_ram_mb,
    ROUND((COALESCE(used_ram_mb, 0) * 100.0) / NULLIF(total_ram_mb, 0), 2) as ram_utilization_pct,
    criticality,
    status,
    CASE
        WHEN (COALESCE(used_ram_mb, 0) * 100.0) / NULLIF(total_ram_mb, 0) > 90 THEN '🔴 Critical'
        WHEN (COALESCE(used_ram_mb, 0) * 100.0) / NULLIF(total_ram_mb, 0) > 75 THEN '🟡 Warning'
        ELSE '🟢 Healthy'
    END as health_status
FROM hosts
WHERE status = 'active' AND total_ram_mb IS NOT NULL
ORDER BY ram_utilization_pct DESC;

-- =============================================================================
-- FIND HOSTS WITH AVAILABLE CAPACITY
-- =============================================================================

-- Query: Find hosts with available resources for new workloads
-- Filters for hosts with <60% RAM usage and active status
SELECT
    hostname,
    host_type,
    management_ip,
    cpu_cores,
    total_ram_mb,
    used_ram_mb,
    (total_ram_mb - COALESCE(used_ram_mb, 0)) as available_ram_mb,
    ROUND((COALESCE(used_ram_mb, 0) * 100.0) / NULLIF(total_ram_mb, 0), 2) as ram_utilization_pct,
    -- Calculate how much RAM can be safely allocated (leaving 10% buffer)
    ROUND((total_ram_mb * 0.9) - COALESCE(used_ram_mb, 0), 0) as safe_allocation_mb,
    purpose
FROM hosts
WHERE status = 'active'
  AND total_ram_mb IS NOT NULL
  AND (COALESCE(used_ram_mb, 0) * 100.0) / total_ram_mb < 60  -- Less than 60% used
ORDER BY available_ram_mb DESC;

-- =============================================================================
-- RESOURCE ALLOCATION BY TYPE
-- =============================================================================

-- Query: Aggregate resource allocation by host type
SELECT
    host_type,
    COUNT(*) as host_count,
    SUM(cpu_cores) as total_cpu_cores,
    SUM(total_ram_mb) as total_ram_mb,
    SUM(COALESCE(used_ram_mb, 0)) as used_ram_mb,
    SUM(total_ram_mb - COALESCE(used_ram_mb, 0)) as available_ram_mb,
    ROUND(AVG((COALESCE(used_ram_mb, 0) * 100.0) / NULLIF(total_ram_mb, 0)), 2) as avg_ram_utilization_pct,
    ROUND((SUM(COALESCE(used_ram_mb, 0)) * 100.0) / NULLIF(SUM(total_ram_mb), 0), 2) as total_ram_utilization_pct
FROM hosts
WHERE status = 'active' AND total_ram_mb IS NOT NULL
GROUP BY host_type
ORDER BY total_ram_mb DESC;

-- =============================================================================
-- CONTAINER RESOURCE INVENTORY
-- =============================================================================

-- Query: List Docker containers with their resource allocations
SELECT
    dc.container_name,
    h.hostname as docker_host,
    h.management_ip as host_ip,
    dc.image,
    dc.status,
    dc.health_status,
    dc.cpu_limit,
    dc.memory_limit_mb,
    dc.restart_policy,
    -- Calculate percentage of host RAM if limit is set
    CASE
        WHEN dc.memory_limit_mb IS NOT NULL AND h.total_ram_mb IS NOT NULL
        THEN ROUND((dc.memory_limit_mb * 100.0) / h.total_ram_mb, 2)
        ELSE NULL
    END as pct_of_host_ram
FROM docker_containers dc
JOIN hosts h ON dc.docker_host_id = h.id
WHERE dc.status IN ('running', 'restarting')
ORDER BY h.hostname, dc.memory_limit_mb DESC NULLS LAST;

-- =============================================================================
-- STORAGE CAPACITY OVERVIEW
-- =============================================================================

-- Query: Storage device capacity and utilization
SELECT
    h.hostname,
    sd.device_name,
    sd.device_type,
    sd.model,
    sd.capacity_gb,
    sd.used_gb,
    sd.available_gb,
    ROUND((COALESCE(sd.used_gb, 0) * 100.0) / NULLIF(sd.capacity_gb, 0), 2) as utilization_pct,
    sd.filesystem_type,
    sd.mount_point,
    sd.smart_status,
    sd.purpose,
    CASE
        WHEN (COALESCE(sd.used_gb, 0) * 100.0) / NULLIF(sd.capacity_gb, 0) > 90 THEN '🔴 Critical'
        WHEN (COALESCE(sd.used_gb, 0) * 100.0) / NULLIF(sd.capacity_gb, 0) > 80 THEN '🟡 Warning'
        ELSE '🟢 Healthy'
    END as storage_status
FROM storage_devices sd
JOIN hosts h ON sd.host_id = h.id
WHERE sd.capacity_gb IS NOT NULL
ORDER BY utilization_pct DESC;

-- =============================================================================
-- STORAGE AGGREGATION BY HOST
-- =============================================================================

-- Query: Total storage capacity per host
SELECT
    h.hostname,
    h.management_ip,
    COUNT(sd.id) as device_count,
    SUM(sd.capacity_gb) as total_capacity_gb,
    SUM(COALESCE(sd.used_gb, 0)) as total_used_gb,
    SUM(COALESCE(sd.available_gb, 0)) as total_available_gb,
    ROUND((SUM(COALESCE(sd.used_gb, 0)) * 100.0) / NULLIF(SUM(sd.capacity_gb), 0), 2) as avg_utilization_pct,
    -- Identify storage types present
    GROUP_CONCAT(DISTINCT sd.device_type, ', ') as storage_types
FROM hosts h
JOIN storage_devices sd ON sd.host_id = h.id
WHERE sd.capacity_gb IS NOT NULL
GROUP BY h.id
ORDER BY total_capacity_gb DESC;

-- =============================================================================
-- VM/CONTAINER DENSITY
-- =============================================================================

-- Query: Show VM/container density per physical host
SELECT
    parent.hostname as physical_host,
    parent.management_ip,
    parent.cpu_cores as host_cpu_cores,
    parent.total_ram_mb as host_ram_mb,
    COUNT(DISTINCT child.id) as vm_container_count,
    SUM(COALESCE(child.cpu_cores, 0)) as allocated_cpu_cores,
    SUM(COALESCE(child.total_ram_mb, 0)) as allocated_ram_mb,
    -- CPU overcommit ratio
    ROUND(SUM(COALESCE(child.cpu_cores, 0)) * 1.0 / NULLIF(parent.cpu_cores, 0), 2) as cpu_overcommit_ratio,
    -- RAM overcommit ratio
    ROUND(SUM(COALESCE(child.total_ram_mb, 0)) * 1.0 / NULLIF(parent.total_ram_mb, 0), 2) as ram_overcommit_ratio,
    -- Breakdown by type
    SUM(CASE WHEN child.host_type = 'vm' THEN 1 ELSE 0 END) as vm_count,
    SUM(CASE WHEN child.host_type = 'lxc' THEN 1 ELSE 0 END) as lxc_count
FROM hosts parent
LEFT JOIN hosts child ON child.parent_host_id = parent.id
WHERE parent.host_type = 'physical'
GROUP BY parent.id
ORDER BY vm_container_count DESC;

-- =============================================================================
-- DOCKER VOLUME USAGE
-- =============================================================================

-- Query: Docker volume inventory with size tracking
SELECT
    h.hostname as docker_host,
    dv.volume_name,
    dv.driver,
    dv.mount_point,
    dv.size_mb,
    ROUND(dv.size_mb / 1024.0, 2) as size_gb,
    -- Count containers using this volume
    COUNT(DISTINCT dcv.container_id) as container_count,
    GROUP_CONCAT(DISTINCT dc.container_name, ', ') as used_by_containers,
    dv.labels
FROM docker_volumes dv
JOIN hosts h ON dv.docker_host_id = h.id
LEFT JOIN docker_container_volumes dcv ON dcv.volume_id = dv.id
LEFT JOIN docker_containers dc ON dcv.container_id = dc.id
GROUP BY dv.id
ORDER BY dv.size_mb DESC NULLS LAST;

-- =============================================================================
-- RESOURCE TREND ANALYSIS (HISTORICAL)
-- =============================================================================

-- Query: Resource utilization changes over time
-- Shows hosts that have increased RAM usage in the last 30 days
SELECT
    h.hostname,
    h.host_type,
    h.used_ram_mb as current_ram_mb,
    h.total_ram_mb,
    ROUND((h.used_ram_mb * 100.0) / NULLIF(h.total_ram_mb, 0), 2) as current_utilization_pct,
    -- Extract previous RAM usage from change log
    CAST(json_extract(ic.old_values, '$.used_ram_mb') AS INTEGER) as previous_ram_mb,
    h.used_ram_mb - CAST(json_extract(ic.old_values, '$.used_ram_mb') AS INTEGER) as ram_change_mb,
    DATE(ic.change_timestamp) as last_update_date
FROM hosts h
JOIN infrastructure_changes ic ON ic.entity_type = 'host' AND ic.entity_id = h.id
WHERE ic.change_type = 'update'
  AND json_extract(ic.old_values, '$.used_ram_mb') IS NOT NULL
  AND ic.change_timestamp >= datetime('now', '-30 days')
ORDER BY ram_change_mb DESC
LIMIT 20;

-- =============================================================================
-- RESOURCE ALLOCATION RECOMMENDATIONS
-- =============================================================================

-- Query: Identify overprovisioned hosts (low utilization) and underprovisioned (high utilization)
WITH resource_analysis AS (
    SELECT
        hostname,
        host_type,
        management_ip,
        total_ram_mb,
        used_ram_mb,
        ROUND((COALESCE(used_ram_mb, 0) * 100.0) / NULLIF(total_ram_mb, 0), 2) as utilization_pct,
        CASE
            WHEN (COALESCE(used_ram_mb, 0) * 100.0) / NULLIF(total_ram_mb, 0) > 85 THEN 'Underprovisioned'
            WHEN (COALESCE(used_ram_mb, 0) * 100.0) / NULLIF(total_ram_mb, 0) < 30 THEN 'Overprovisioned'
            ELSE 'Optimal'
        END as provisioning_status,
        CASE
            WHEN (COALESCE(used_ram_mb, 0) * 100.0) / NULLIF(total_ram_mb, 0) > 85
                THEN 'Consider adding RAM or migrating workloads'
            WHEN (COALESCE(used_ram_mb, 0) * 100.0) / NULLIF(total_ram_mb, 0) < 30
                THEN 'Consider reducing allocation or adding workloads'
            ELSE 'No action needed'
        END as recommendation
    FROM hosts
    WHERE status = 'active' AND total_ram_mb IS NOT NULL
)
SELECT *
FROM resource_analysis
WHERE provisioning_status != 'Optimal'
ORDER BY utilization_pct DESC;

-- =============================================================================
-- COST PROJECTION (THEORETICAL)
-- =============================================================================

-- Query: Calculate theoretical cloud costs if infrastructure was in AWS/GCP
-- This is a rough estimate based on resource allocations
SELECT
    h.hostname,
    h.host_type,
    h.cpu_cores,
    h.total_ram_mb,
    -- Rough AWS t3.medium equivalent pricing (adjust multiplier as needed)
    ROUND(h.cpu_cores * 0.0416 * 730, 2) as estimated_monthly_cost_usd,
    ROUND(h.cpu_cores * 0.0416 * 730 * 12, 2) as estimated_annual_cost_usd,
    purpose,
    criticality
FROM hosts
WHERE host_type IN ('vm', 'lxc', 'physical')
  AND status = 'active'
  AND cpu_cores IS NOT NULL
ORDER BY estimated_monthly_cost_usd DESC;
