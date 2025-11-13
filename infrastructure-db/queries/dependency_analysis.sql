-- Dependency Analysis Queries
-- Use these queries to understand service dependencies and impact analysis

-- =============================================================================
-- IMPACT ANALYSIS
-- =============================================================================

-- Query: What services are affected if a specific host goes down?
-- Replace ? with host_id or use WHERE hostname = 'hostname'
--
-- Example: What breaks if OMV (192.168.1.9) fails?
WITH affected_services AS (
    -- Direct services on the host
    SELECT
        s.id,
        s.service_name,
        s.service_type,
        s.criticality,
        'direct' as impact_type,
        s.status as current_status
    FROM services s
    WHERE s.host_id = (SELECT id FROM hosts WHERE management_ip = '192.168.1.9')

    UNION

    -- Services that depend on services on this host
    SELECT DISTINCT
        dependent.id,
        dependent.service_name,
        dependent.service_type,
        dependent.criticality,
        'indirect' as impact_type,
        dependent.status as current_status
    FROM services dependency_svc
    JOIN service_dependencies sd ON dependency_svc.id = sd.dependency_service_id
    JOIN services dependent ON sd.dependent_service_id = dependent.id
    WHERE dependency_svc.host_id = (SELECT id FROM hosts WHERE management_ip = '192.168.1.9')
)
SELECT
    service_name,
    service_type,
    criticality,
    impact_type,
    current_status,
    CASE criticality
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
    END as priority_order
FROM affected_services
ORDER BY priority_order, impact_type;

-- =============================================================================
-- DEPENDENCY TREE VISUALIZATION
-- =============================================================================

-- Query: Show complete dependency tree for a service
-- Shows all services that the given service depends on (recursively)
--
-- Example: What does Supabase Studio depend on?
WITH RECURSIVE dependency_tree AS (
    -- Base case: the service itself
    SELECT
        s.id,
        s.service_name,
        s.service_type,
        h.hostname,
        0 as depth,
        s.service_name as path
    FROM services s
    LEFT JOIN hosts h ON s.host_id = h.id
    WHERE s.service_name = 'Supabase Studio'

    UNION ALL

    -- Recursive case: dependencies of dependencies
    SELECT
        dep_svc.id,
        dep_svc.service_name,
        dep_svc.service_type,
        h.hostname,
        dt.depth + 1,
        dt.path || ' → ' || dep_svc.service_name
    FROM dependency_tree dt
    JOIN service_dependencies sd ON dt.id = sd.dependent_service_id
    JOIN services dep_svc ON sd.dependency_service_id = dep_svc.id
    LEFT JOIN hosts h ON dep_svc.host_id = h.id
    WHERE dt.depth < 10  -- Prevent infinite loops
)
SELECT
    SUBSTR('                              ', 1, depth * 2) || service_name as dependency_hierarchy,
    service_type,
    hostname,
    depth
FROM dependency_tree
ORDER BY depth, service_name;

-- =============================================================================
-- REVERSE DEPENDENCY TREE
-- =============================================================================

-- Query: Show what depends on a given service
-- Shows all services that would be affected if this service fails
--
-- Example: What depends on PostgreSQL?
WITH RECURSIVE dependent_tree AS (
    -- Base case: the service itself
    SELECT
        s.id,
        s.service_name,
        s.service_type,
        s.criticality,
        h.hostname,
        0 as depth,
        s.service_name as path
    FROM services s
    LEFT JOIN hosts h ON s.host_id = h.id
    WHERE s.service_name = 'PostgreSQL'

    UNION ALL

    -- Recursive case: things that depend on this
    SELECT
        dependent.id,
        dependent.service_name,
        dependent.service_type,
        dependent.criticality,
        h.hostname,
        dt.depth + 1,
        dt.path || ' ← ' || dependent.service_name
    FROM dependent_tree dt
    JOIN service_dependencies sd ON dt.id = sd.dependency_service_id
    JOIN services dependent ON sd.dependent_service_id = dependent.id
    LEFT JOIN hosts h ON dependent.host_id = h.id
    WHERE dt.depth < 10
)
SELECT
    SUBSTR('                              ', 1, depth * 2) || service_name as dependent_hierarchy,
    service_type,
    criticality,
    hostname,
    depth
FROM dependent_tree
ORDER BY depth, service_name;

-- =============================================================================
-- CRITICAL PATH ANALYSIS
-- =============================================================================

-- Query: Find single points of failure (services with critical dependents but no redundancy)
SELECT
    dependency_svc.service_name as critical_dependency,
    dependency_svc.service_type,
    h.hostname as running_on,
    dependency_svc.criticality,
    COUNT(DISTINCT sd.dependent_service_id) as dependent_count,
    GROUP_CONCAT(DISTINCT dependent.service_name, ', ') as dependent_services
FROM services dependency_svc
JOIN service_dependencies sd ON dependency_svc.id = sd.dependency_service_id
JOIN services dependent ON sd.dependent_service_id = dependent.id
LEFT JOIN hosts h ON dependency_svc.host_id = h.id
WHERE sd.dependency_type = 'hard'  -- Only hard dependencies
GROUP BY dependency_svc.id
HAVING dependent_count >= 3  -- Services with 3+ dependents
ORDER BY dependent_count DESC, dependency_svc.criticality;

-- =============================================================================
-- CONTAINER DEPENDENCY MAPPING
-- =============================================================================

-- Query: Show Docker container dependencies within a stack
-- Useful for understanding microservice relationships
SELECT
    dependent_container.container_name as dependent,
    dependency_container.container_name as depends_on,
    sd.dependency_type,
    dependent_svc.service_name as dependent_service,
    dependency_svc.service_name as dependency_service
FROM service_dependencies sd
JOIN services dependent_svc ON sd.dependent_service_id = dependent_svc.id
JOIN services dependency_svc ON sd.dependency_service_id = dependency_svc.id
JOIN docker_containers dependent_container ON dependent_svc.container_id = dependent_container.id
JOIN docker_containers dependency_container ON dependency_svc.container_id = dependency_container.id
WHERE dependent_container.docker_host_id = dependency_container.docker_host_id  -- Same host
ORDER BY dependent_container.container_name;

-- =============================================================================
-- HOST-LEVEL CASCADE ANALYSIS
-- =============================================================================

-- Query: If a physical host fails, what cascades?
-- Shows VMs, containers, and all services on them
SELECT
    parent.hostname as failed_host,
    child.hostname as affected_vm_or_container,
    child.host_type,
    s.service_name,
    s.service_type,
    s.criticality,
    COUNT(dependent.id) as services_depending_on_this
FROM hosts parent
JOIN hosts child ON child.parent_host_id = parent.id
LEFT JOIN services s ON s.host_id = child.id
LEFT JOIN service_dependencies sd ON s.id = sd.dependency_service_id
LEFT JOIN services dependent ON sd.dependent_service_id = dependent.id
WHERE parent.hostname = 'pve2'  -- Replace with target host
GROUP BY child.id, s.id
ORDER BY s.criticality, services_depending_on_this DESC;

-- =============================================================================
-- CROSS-HOST DEPENDENCIES
-- =============================================================================

-- Query: Find services that depend on services running on different hosts
-- Useful for identifying network dependencies and potential bottlenecks
SELECT
    dependent_svc.service_name as dependent_service,
    h1.hostname as dependent_host,
    h1.management_ip as dependent_ip,
    dependency_svc.service_name as dependency_service,
    h2.hostname as dependency_host,
    h2.management_ip as dependency_ip,
    sd.dependency_type
FROM service_dependencies sd
JOIN services dependent_svc ON sd.dependent_service_id = dependent_svc.id
JOIN services dependency_svc ON sd.dependency_service_id = dependency_svc.id
JOIN hosts h1 ON dependent_svc.host_id = h1.id
JOIN hosts h2 ON dependency_svc.host_id = h2.id
WHERE h1.id != h2.id  -- Different hosts
ORDER BY sd.dependency_type DESC, dependent_svc.service_name;
