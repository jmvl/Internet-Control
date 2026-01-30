#!/usr/bin/env python3
"""
Database utility functions for infrastructure discovery
Provides common database operations and change tracking
"""

import sqlite3
import json
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple
from contextlib import contextmanager

logger = logging.getLogger(__name__)


class InfrastructureDB:
    """SQLite database wrapper for infrastructure management"""

    def __init__(self, db_path: str):
        self.db_path = db_path
        self._ensure_database_exists()

    def _ensure_database_exists(self):
        """Ensure database file exists"""
        import os
        if not os.path.exists(self.db_path):
            raise FileNotFoundError(
                f"Database not found at {self.db_path}. "
                f"Please run schema.sql first to create the database."
            )

    @contextmanager
    def get_connection(self):
        """Context manager for database connections"""
        conn = sqlite3.connect(self.db_path, timeout=30.0)  # 30 second timeout
        conn.row_factory = sqlite3.Row  # Enable column access by name
        conn.execute("PRAGMA foreign_keys = ON")  # Enable foreign keys
        conn.execute("PRAGMA journal_mode = WAL")  # Enable WAL mode for better concurrency
        conn.execute("PRAGMA busy_timeout = 30000")  # 30 second busy timeout
        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"Database error: {e}")
            raise
        finally:
            conn.close()

    def execute_query(self, query: str, params: Optional[Tuple] = None) -> List[Dict]:
        """Execute a SELECT query and return results as list of dicts"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)

            columns = [desc[0] for desc in cursor.description] if cursor.description else []
            results = [dict(zip(columns, row)) for row in cursor.fetchall()]
            return results

    def execute_update(self, query: str, params: Optional[Tuple] = None) -> int:
        """Execute an INSERT/UPDATE/DELETE query and return affected rows"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            return cursor.rowcount

    def get_host_by_hostname(self, hostname: str) -> Optional[Dict]:
        """Get host record by hostname"""
        results = self.execute_query(
            "SELECT * FROM hosts WHERE hostname = ?",
            (hostname,)
        )
        return results[0] if results else None

    def get_host_by_ip(self, ip: str) -> Optional[Dict]:
        """Get host record by management IP"""
        results = self.execute_query(
            "SELECT * FROM hosts WHERE management_ip = ?",
            (ip,)
        )
        return results[0] if results else None

    def upsert_host(self, host_data: Dict, changed_by: str = 'system') -> int:
        """Insert or update host record with change tracking"""
        existing = self.get_host_by_hostname(host_data['hostname'])

        if existing:
            # Update existing host
            update_fields = []
            params = []
            for key, value in host_data.items():
                if key != 'hostname' and key in existing:
                    update_fields.append(f"{key} = ?")
                    params.append(value)

            if update_fields:
                query = f"UPDATE hosts SET {', '.join(update_fields)} WHERE hostname = ?"
                params.append(host_data['hostname'])
                self.execute_update(query, tuple(params))

                # Log change
                self.log_change(
                    change_type='update',
                    entity_type='host',
                    entity_id=existing['id'],
                    old_values=existing,
                    new_values=host_data,
                    changed_by=changed_by
                )

            return existing['id']
        else:
            # Insert new host
            columns = list(host_data.keys())
            placeholders = ','.join(['?' for _ in columns])
            query = f"INSERT INTO hosts ({','.join(columns)}) VALUES ({placeholders})"

            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, tuple(host_data.values()))
                host_id = cursor.lastrowid

                # Log creation
                self.log_change(
                    change_type='create',
                    entity_type='host',
                    entity_id=host_id,
                    old_values=None,
                    new_values=host_data,
                    changed_by=changed_by
                )

                return host_id

    def upsert_docker_container(self, container_data: Dict, changed_by: str = 'system') -> int:
        """Insert or update Docker container with change tracking"""
        # Check if container exists
        existing = self.execute_query(
            "SELECT * FROM docker_containers WHERE docker_host_id = ? AND container_name = ?",
            (container_data['docker_host_id'], container_data['container_name'])
        )
        existing = existing[0] if existing else None

        if existing:
            # Update
            update_fields = []
            params = []
            for key, value in container_data.items():
                if key not in ['docker_host_id', 'container_name']:
                    update_fields.append(f"{key} = ?")
                    params.append(value)

            if update_fields:
                query = f"""UPDATE docker_containers SET {', '.join(update_fields)}
                           WHERE docker_host_id = ? AND container_name = ?"""
                params.extend([container_data['docker_host_id'], container_data['container_name']])
                self.execute_update(query, tuple(params))

                # Log change if status or health changed
                if (existing['status'] != container_data.get('status') or
                    existing['health_status'] != container_data.get('health_status')):
                    self.log_change(
                        change_type='update',
                        entity_type='docker_container',
                        entity_id=existing['id'],
                        old_values=existing,
                        new_values=container_data,
                        changed_by=changed_by
                    )

            return existing['id']
        else:
            # Insert
            columns = list(container_data.keys())
            placeholders = ','.join(['?' for _ in columns])
            query = f"INSERT INTO docker_containers ({','.join(columns)}) VALUES ({placeholders})"

            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, tuple(container_data.values()))
                container_id = cursor.lastrowid

                self.log_change(
                    change_type='create',
                    entity_type='docker_container',
                    entity_id=container_id,
                    old_values=None,
                    new_values=container_data,
                    changed_by=changed_by
                )

                return container_id

    def upsert_docker_volume(self, volume_data: Dict, changed_by: str = 'system') -> int:
        """Insert or update Docker volume with change tracking"""
        # Check if volume exists
        existing = self.execute_query(
            "SELECT * FROM docker_volumes WHERE docker_host_id = ? AND volume_name = ?",
            (volume_data['docker_host_id'], volume_data['volume_name'])
        )
        existing = existing[0] if existing else None

        if existing:
            # Update
            update_fields = []
            params = []
            for key, value in volume_data.items():
                if key not in ['docker_host_id', 'volume_name']:
                    update_fields.append(f"{key} = ?")
                    params.append(value)

            if update_fields:
                query = f"""UPDATE docker_volumes SET {', '.join(update_fields)}
                           WHERE docker_host_id = ? AND volume_name = ?"""
                params.extend([volume_data['docker_host_id'], volume_data['volume_name']])
                self.execute_update(query, tuple(params))

            return existing['id']
        else:
            # Insert
            columns = list(volume_data.keys())
            placeholders = ','.join(['?' for _ in columns])
            query = f"INSERT INTO docker_volumes ({','.join(columns)}) VALUES ({placeholders})"

            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, tuple(volume_data.values()))
                volume_id = cursor.lastrowid

                self.log_change(
                    change_type='create',
                    entity_type='docker_volume',
                    entity_id=volume_id,
                    old_values=None,
                    new_values=volume_data,
                    changed_by=changed_by
                )

                return volume_id

    def upsert_docker_network(self, network_data: Dict, changed_by: str = 'system') -> int:
        """Insert or update Docker network with change tracking"""
        # Check if network exists
        existing = self.execute_query(
            "SELECT * FROM docker_networks WHERE docker_host_id = ? AND network_name = ?",
            (network_data['docker_host_id'], network_data['network_name'])
        )
        existing = existing[0] if existing else None

        if existing:
            # Update
            update_fields = []
            params = []
            for key, value in network_data.items():
                if key not in ['docker_host_id', 'network_name']:
                    update_fields.append(f"{key} = ?")
                    params.append(value)

            if update_fields:
                query = f"""UPDATE docker_networks SET {', '.join(update_fields)}
                           WHERE docker_host_id = ? AND network_name = ?"""
                params.extend([network_data['docker_host_id'], network_data['network_name']])
                self.execute_update(query, tuple(params))

            return existing['id']
        else:
            # Insert
            columns = list(network_data.keys())
            placeholders = ','.join(['?' for _ in columns])
            query = f"INSERT INTO docker_networks ({','.join(columns)}) VALUES ({placeholders})"

            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(query, tuple(network_data.values()))
                network_id = cursor.lastrowid

                self.log_change(
                    change_type='create',
                    entity_type='docker_network',
                    entity_id=network_id,
                    old_values=None,
                    new_values=network_data,
                    changed_by=changed_by
                )

                return network_id

    def log_change(self, change_type: str, entity_type: str, entity_id: int,
                   old_values: Optional[Dict], new_values: Dict,
                   changed_by: str = 'system', description: str = None):
        """Log infrastructure change to audit table"""
        try:
            query = """
                INSERT INTO infrastructure_changes
                (change_type, entity_type, entity_id, changed_by, change_source,
                 old_values, new_values, description)
                VALUES (?, ?, ?, ?, 'automation', ?, ?, ?)
            """

            self.execute_update(query, (
                change_type,
                entity_type,
                entity_id,
                changed_by,
                json.dumps(old_values) if old_values else None,
                json.dumps(new_values, default=str),
                description
            ))

            logger.info(f"Logged {change_type} for {entity_type}:{entity_id}")
        except Exception as e:
            logger.error(f"Failed to log change: {e}")

    def update_service_health(self, service_id: int, status: str,
                             response_time_ms: int = None,
                             error_message: str = None):
        """Record service health check result"""
        query = """
            INSERT INTO health_checks
            (service_id, status, response_time_ms, error_message)
            VALUES (?, ?, ?, ?)
        """
        self.execute_update(query, (service_id, status, response_time_ms, error_message))

        # Update service status if changed
        current_status = self.execute_query(
            "SELECT status FROM services WHERE id = ?",
            (service_id,)
        )
        if current_status and current_status[0]['status'] != status:
            self.execute_update(
                "UPDATE services SET status = ? WHERE id = ?",
                (status, service_id)
            )

    def get_services_for_host(self, host_id: int) -> List[Dict]:
        """Get all services running on a host"""
        return self.execute_query(
            "SELECT * FROM services WHERE host_id = ?",
            (host_id,)
        )

    def find_dependent_services(self, service_id: int) -> List[Dict]:
        """Find all services that depend on the given service"""
        query = """
            SELECT s.*, sd.dependency_type
            FROM services s
            JOIN service_dependencies sd ON s.id = sd.dependent_service_id
            WHERE sd.dependency_service_id = ?
        """
        return self.execute_query(query, (service_id,))

    def get_host_resource_utilization(self) -> List[Dict]:
        """Get resource utilization summary for all hosts"""
        return self.execute_query("""
            SELECT
                hostname,
                host_type,
                status,
                total_ram_mb,
                used_ram_mb,
                ROUND((used_ram_mb * 100.0) / NULLIF(total_ram_mb, 0), 2) as ram_utilization_pct,
                criticality
            FROM hosts
            WHERE status = 'active' AND total_ram_mb IS NOT NULL
            ORDER BY ram_utilization_pct DESC
        """)

    def get_container_inventory(self) -> List[Dict]:
        """Get complete Docker container inventory"""
        return self.execute_query("""
            SELECT
                dc.container_name,
                dc.image,
                dc.status,
                dc.health_status,
                h.hostname as docker_host,
                h.management_ip as host_ip
            FROM docker_containers dc
            JOIN hosts h ON dc.docker_host_id = h.id
            ORDER BY h.hostname, dc.container_name
        """)

    def upsert_proxmox_container(self, container_data: Dict, changed_by: str = 'proxmox_discovery') -> Optional[int]:
        """Insert or update Proxmox container (VM or LXC) with change tracking

        Args:
            container_data: Dictionary with container fields including:
                - host_id: Link to hosts table
                - proxmox_host_id: Link to Proxmox host
                - vmid: Proxmox VM/Container ID
                - container_type: 'vm' or 'lxc'
                - Plus type-specific fields (vm_type, os_type, os_template, etc.)
            changed_by: Identifier for who/what made the change

        Returns:
            int: The container record ID, or None if upsert failed
        """
        try:
            # Check if container exists (by vmid and proxmox_host)
            existing = self.execute_query(
                "SELECT * FROM proxmox_containers WHERE proxmox_host_id = ? AND vmid = ?",
                (container_data['proxmox_host_id'], container_data['vmid'])
            )
            existing = existing[0] if existing else None

            if existing:
                # Update existing container
                update_fields = []
                params = []
                for key, value in container_data.items():
                    if key not in ['proxmox_host_id', 'vmid'] and key in existing:
                        update_fields.append(f"{key} = ?")
                        params.append(value)

                if update_fields:
                    query = f"""UPDATE proxmox_containers SET {', '.join(update_fields)}
                               WHERE proxmox_host_id = ? AND vmid = ?"""
                    params.extend([container_data['proxmox_host_id'], container_data['vmid']])
                    self.execute_update(query, tuple(params))

                    # Log change
                    self.log_change(
                        change_type='update',
                        entity_type='proxmox_container',
                        entity_id=existing['id'],
                        old_values=existing,
                        new_values=container_data,
                        changed_by=changed_by,
                        description=f"Updated {container_data['container_type']} {container_data['vmid']}"
                    )

                return existing['id']
            else:
                # Insert new container
                columns = list(container_data.keys())
                placeholders = ','.join(['?' for _ in columns])
                query = f"INSERT INTO proxmox_containers ({','.join(columns)}) VALUES ({placeholders})"

                with self.get_connection() as conn:
                    cursor = conn.cursor()
                    cursor.execute(query, tuple(container_data.values()))
                    container_id = cursor.lastrowid

                self.log_change(
                    change_type='create',
                    entity_type='proxmox_container',
                    entity_id=container_id,
                    old_values=None,
                    new_values=container_data,
                    changed_by=changed_by,
                    description=f"Created {container_data['container_type']} {container_data['vmid']}"
                )

                return container_id

        except Exception as e:
            logger.error(f"Failed to upsert Proxmox container {container_data.get('vmid')}: {e}")
            return None

    def get_proxmox_containers_for_host(self, proxmox_host_id: int) -> List[Dict]:
        """Get all Proxmox containers (VMs and LXCs) on a given Proxmox host"""
        return self.execute_query("""
            SELECT
                pc.*,
                h.hostname,
                h.status as host_status
            FROM proxmox_containers pc
            JOIN hosts h ON pc.host_id = h.id
            WHERE pc.proxmox_host_id = ?
            ORDER BY pc.vmid
        """, (proxmox_host_id,))

    def get_network_topology(self) -> List[Dict]:
        """Get complete network topology"""
        return self.execute_query("""
            SELECT
                n.network_name,
                n.cidr,
                n.vlan_id,
                ip.ip_address,
                h.hostname,
                h.host_type,
                ni.interface_name
            FROM networks n
            LEFT JOIN ip_addresses ip ON ip.network_id = n.id
            LEFT JOIN hosts h ON ip.host_id = h.id
            LEFT JOIN network_interfaces ni ON ip.interface_id = ni.id
            ORDER BY n.vlan_id, ip.ip_address
        """)
