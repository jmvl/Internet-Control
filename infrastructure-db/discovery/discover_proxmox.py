#!/usr/bin/env python3
"""
Proxmox Infrastructure Discovery
Connects to Proxmox API and inventories VMs, containers, and resource allocation
"""

import json
import logging
from typing import Dict, List
from proxmoxer import ProxmoxAPI
from db_utils import InfrastructureDB

logger = logging.getLogger(__name__)


class ProxmoxDiscovery:
    """Discover Proxmox VMs and containers via API"""

    def __init__(self, db: InfrastructureDB, host: str, user: str, password: str, verify_ssl: bool = False):
        self.db = db
        self.host = host
        self.proxmox = ProxmoxAPI(host, user=user, password=password, verify_ssl=verify_ssl)
        logger.info(f"Connected to Proxmox at {host}")

    def discover_nodes(self) -> List[Dict]:
        """Discover Proxmox cluster nodes"""
        nodes = []
        for node in self.proxmox.nodes.get():
            node_data = {
                'hostname': node['node'],
                'host_type': 'physical',
                'management_ip': node.get('ip'),
                'status': 'active' if node['status'] == 'online' else 'stopped',
                'cpu_cores': node.get('maxcpu'),
                'total_ram_mb': node.get('maxmem', 0) // 1024 // 1024,
                'used_ram_mb': node.get('mem', 0) // 1024 // 1024,
                'purpose': 'Proxmox virtualization host',
                'criticality': 'critical',
            }
            nodes.append(node_data)

        logger.info(f"Discovered {len(nodes)} Proxmox nodes")
        return nodes

    def discover_vms(self, node_name: str) -> List[Dict]:
        """Discover VMs on a Proxmox node"""
        vms = []
        node = self.proxmox.nodes(node_name)

        for vm in node.qemu.get():
            # Get detailed config
            vmid = vm['vmid']
            config = node.qemu(vmid).config.get()
            status = node.qemu(vmid).status.current.get()

            vm_data = {
                'vmid': vmid,
                'name': vm['name'],
                'status': vm['status'],
                'cpu_cores': config.get('cores', 0) * config.get('sockets', 1),
                'total_ram_mb': config.get('memory', 0),
                'vm_type': vm.get('type', 'qemu'),
                'os_type': config.get('ostype'),
                'network_interfaces': json.dumps(self._extract_vm_networks(config)),
                'boot_disk': config.get('bootdisk'),
                'auto_start': config.get('onboot', 0) == 1,
            }

            vms.append(vm_data)

        logger.info(f"Discovered {len(vms)} VMs on node {node_name}")
        return vms

    def _extract_vm_networks(self, config: Dict) -> List[Dict]:
        """Extract network configuration from VM config"""
        networks = []
        for key, value in config.items():
            if key.startswith('net'):
                # Parse network config (format: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0)
                parts = value.split(',')
                net_config = {'interface': key}

                for part in parts:
                    if '=' in part:
                        k, v = part.split('=', 1)
                        net_config[k] = v

                networks.append(net_config)

        return networks

    def discover_containers(self, node_name: str) -> List[Dict]:
        """Discover LXC containers on a Proxmox node"""
        containers = []
        node = self.proxmox.nodes(node_name)

        for ct in node.lxc.get():
            # Get detailed config
            vmid = ct['vmid']
            config = node.lxc(vmid).config.get()
            status = node.lxc(vmid).status.current.get()

            ct_data = {
                'vmid': vmid,
                'name': ct['name'],
                'status': ct['status'],
                'cpu_cores': config.get('cores', 1),
                'total_ram_mb': config.get('memory', 0),
                'os_template': config.get('ostype'),
                'unprivileged': config.get('unprivileged', 1) == 1,
                'rootfs_storage': config.get('rootfs', '').split(',')[0].split(':')[0] if config.get('rootfs') else None,
                'network_config': json.dumps(self._extract_container_networks(config)),
                'nesting': config.get('features', {}).get('nesting', 0) == 1 if isinstance(config.get('features'), dict) else False,
                'auto_start': config.get('onboot', 0) == 1,
            }

            # Extract management IP from network config
            if 'net0' in config:
                # Format: name=eth0,bridge=vmbr0,ip=192.168.1.20/24,gw=192.168.1.3
                net_parts = config['net0'].split(',')
                for part in net_parts:
                    if part.startswith('ip='):
                        ip = part.split('=')[1].split('/')[0]
                        ct_data['management_ip'] = ip
                        break

            containers.append(ct_data)

        logger.info(f"Discovered {len(containers)} containers on node {node_name}")
        return containers

    def _extract_container_networks(self, config: Dict) -> List[Dict]:
        """Extract network configuration from container config"""
        networks = []
        for key, value in config.items():
            if key.startswith('net'):
                parts = value.split(',')
                net_config = {'interface': key}

                for part in parts:
                    if '=' in part:
                        k, v = part.split('=', 1)
                        net_config[k] = v

                networks.append(net_config)

        return networks

    def sync_proxmox_infrastructure(self):
        """Synchronize all Proxmox infrastructure to database"""
        logger.info("Starting Proxmox infrastructure discovery")

        # Discover and sync nodes
        nodes = self.discover_nodes()
        for node_data in nodes:
            host_id = self.db.upsert_host(node_data, changed_by='proxmox_discovery')
            node_name = node_data['hostname']

            # Discover VMs on this node
            vms = self.discover_vms(node_name)
            for vm_data in vms:
                # Create host record for VM
                vm_host_data = {
                    'hostname': vm_data['name'],
                    'host_type': 'vm',
                    'status': vm_data['status'],
                    'cpu_cores': vm_data['cpu_cores'],
                    'total_ram_mb': vm_data['total_ram_mb'],
                    'parent_host_id': host_id,
                    'vmid': vm_data['vmid'],
                    'criticality': 'high',  # Default, can be updated manually
                }

                vm_host_id = self.db.upsert_host(vm_host_data, changed_by='proxmox_discovery')

                # Create VM-specific record
                vm_record = {
                    'host_id': vm_host_id,
                    'proxmox_host_id': host_id,
                    'vmid': vm_data['vmid'],
                    'vm_type': vm_data.get('vm_type'),
                    'os_type': vm_data.get('os_type'),
                    'network_interfaces': vm_data.get('network_interfaces'),
                    'boot_disk': vm_data.get('boot_disk'),
                    'auto_start': vm_data.get('auto_start'),
                }

                # Upsert VM record (implement in db_utils if needed)
                # self.db.upsert_virtual_machine(vm_record)

            # Discover containers on this node
            containers = self.discover_containers(node_name)
            for ct_data in containers:
                # Create host record for container
                ct_host_data = {
                    'hostname': ct_data['name'],
                    'host_type': 'lxc',
                    'management_ip': ct_data.get('management_ip'),
                    'status': ct_data['status'],
                    'cpu_cores': ct_data['cpu_cores'],
                    'total_ram_mb': ct_data['total_ram_mb'],
                    'parent_host_id': host_id,
                    'vmid': ct_data['vmid'],
                    'criticality': 'medium',  # Default
                }

                ct_host_id = self.db.upsert_host(ct_host_data, changed_by='proxmox_discovery')

                # Create LXC-specific record
                lxc_record = {
                    'host_id': ct_host_id,
                    'proxmox_host_id': host_id,
                    'vmid': ct_data['vmid'],
                    'os_template': ct_data.get('os_template'),
                    'unprivileged': ct_data.get('unprivileged'),
                    'rootfs_storage': ct_data.get('rootfs_storage'),
                    'network_config': ct_data.get('network_config'),
                    'nesting': ct_data.get('nesting'),
                    'auto_start': ct_data.get('auto_start'),
                }

                # Upsert LXC record (implement in db_utils if needed)
                # self.db.upsert_lxc_container(lxc_record)

        logger.info("Completed Proxmox infrastructure discovery")


def main():
    """Main entry point for Proxmox discovery"""
    import os
    from dotenv import load_dotenv

    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    # Load environment
    load_dotenv()

    db_path = os.getenv('DB_PATH', '../infrastructure.db')
    proxmox_host = os.getenv('PROXMOX_HOST', '192.168.1.10')
    proxmox_user = os.getenv('PROXMOX_USER', 'root@pam')
    proxmox_password = os.getenv('PROXMOX_PASSWORD')
    verify_ssl = os.getenv('PROXMOX_VERIFY_SSL', 'false').lower() == 'true'

    if not proxmox_password:
        logger.error("PROXMOX_PASSWORD not set in environment")
        return

    # Initialize database
    db = InfrastructureDB(db_path)

    # Run discovery
    discovery = ProxmoxDiscovery(db, proxmox_host, proxmox_user, proxmox_password, verify_ssl)
    discovery.sync_proxmox_infrastructure()


if __name__ == '__main__':
    main()
