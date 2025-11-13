#!/usr/bin/env python3
"""
Docker Infrastructure Discovery
Connects to Docker hosts via SSH and inventories containers, volumes, and networks
"""

import json
import logging
import paramiko
from typing import Dict, List, Optional
from db_utils import InfrastructureDB

logger = logging.getLogger(__name__)


class DockerDiscovery:
    """Discover Docker infrastructure via SSH"""

    def __init__(self, db: InfrastructureDB):
        self.db = db

    def connect_ssh(self, host: str, username: str = 'root',
                   key_path: Optional[str] = None,
                   password: Optional[str] = None) -> paramiko.SSHClient:
        """Establish SSH connection to Docker host"""
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        try:
            if key_path:
                client.connect(host, username=username, key_filename=key_path)
            elif password:
                client.connect(host, username=username, password=password)
            else:
                client.connect(host, username=username)

            logger.info(f"Connected to {host} via SSH")
            return client
        except Exception as e:
            logger.error(f"Failed to connect to {host}: {e}")
            raise

    def execute_command(self, client: paramiko.SSHClient, command: str) -> str:
        """Execute command on remote host and return output"""
        stdin, stdout, stderr = client.exec_command(command)
        exit_status = stdout.channel.recv_exit_status()

        if exit_status != 0:
            error = stderr.read().decode()
            raise RuntimeError(f"Command failed with exit code {exit_status}: {error}")

        return stdout.read().decode()

    def discover_containers(self, host: str, username: str = 'root',
                           key_path: Optional[str] = None) -> List[Dict]:
        """Discover all Docker containers on a host"""
        client = self.connect_ssh(host, username, key_path)

        try:
            # Get container list with detailed info
            cmd = """docker ps -a --format '{{json .}}' """
            output = self.execute_command(client, cmd)

            containers = []
            for line in output.strip().split('\n'):
                if not line:
                    continue

                container_info = json.loads(line)

                # Get detailed inspect data
                container_id = container_info['ID']
                inspect_cmd = f"docker inspect {container_id}"
                inspect_output = self.execute_command(client, inspect_cmd)
                inspect_data = json.loads(inspect_output)[0]

                # Extract container details
                container = {
                    'container_id': container_id[:12],
                    'container_name': inspect_data['Name'].lstrip('/'),
                    'image': inspect_data['Config']['Image'].split(':')[0],
                    'image_tag': inspect_data['Config']['Image'].split(':')[1] if ':' in inspect_data['Config']['Image'] else 'latest',
                    'status': 'running' if inspect_data['State']['Running'] else 'exited',
                    'restart_policy': inspect_data['HostConfig']['RestartPolicy']['Name'],
                    'network_mode': inspect_data['HostConfig']['NetworkMode'],
                    'networks': json.dumps(list(inspect_data['NetworkSettings']['Networks'].keys())),
                    'ports': json.dumps(self._extract_ports(inspect_data)),
                    'environment_vars': json.dumps(inspect_data['Config']['Env']),
                    'cpu_limit': None,  # Would need to parse HostConfig.CpuQuota
                    'memory_limit_mb': inspect_data['HostConfig']['Memory'] // 1024 // 1024 if inspect_data['HostConfig']['Memory'] else None,
                    'health_status': self._get_health_status(inspect_data),
                    'labels': json.dumps(inspect_data['Config']['Labels']),
                    'command': ' '.join(inspect_data['Config']['Cmd']) if inspect_data['Config']['Cmd'] else None,
                }

                containers.append(container)

            logger.info(f"Discovered {len(containers)} containers on {host}")
            return containers

        finally:
            client.close()

    def _extract_ports(self, inspect_data: Dict) -> List[str]:
        """Extract port mappings from inspect data"""
        ports = []
        port_bindings = inspect_data.get('HostConfig', {}).get('PortBindings', {})

        for container_port, host_bindings in port_bindings.items():
            if host_bindings:
                for binding in host_bindings:
                    host_port = binding.get('HostPort', '')
                    if host_port:
                        ports.append(f"{host_port}:{container_port}")

        return ports

    def _get_health_status(self, inspect_data: Dict) -> str:
        """Determine container health status"""
        if 'Health' in inspect_data['State']:
            health = inspect_data['State']['Health']
            return health['Status']
        return 'none'

    def discover_volumes(self, host: str, username: str = 'root',
                        key_path: Optional[str] = None) -> List[Dict]:
        """Discover Docker volumes on a host"""
        client = self.connect_ssh(host, username, key_path)

        try:
            cmd = "docker volume ls --format '{{json .}}'"
            output = self.execute_command(client, cmd)

            volumes = []
            for line in output.strip().split('\n'):
                if not line:
                    continue

                volume_info = json.loads(line)

                # Get detailed inspect data
                volume_name = volume_info['Name']
                inspect_cmd = f"docker volume inspect {volume_name}"
                inspect_output = self.execute_command(client, inspect_cmd)
                inspect_data = json.loads(inspect_output)[0]

                volume = {
                    'volume_name': volume_name,
                    'driver': inspect_data['Driver'],
                    'mount_point': inspect_data['Mountpoint'],
                    'options': json.dumps(inspect_data.get('Options', {})),
                    'labels': json.dumps(inspect_data.get('Labels', {})),
                }

                volumes.append(volume)

            logger.info(f"Discovered {len(volumes)} volumes on {host}")
            return volumes

        finally:
            client.close()

    def discover_networks(self, host: str, username: str = 'root',
                         key_path: Optional[str] = None) -> List[Dict]:
        """Discover Docker networks on a host"""
        client = self.connect_ssh(host, username, key_path)

        try:
            cmd = "docker network ls --format '{{json .}}'"
            output = self.execute_command(client, cmd)

            networks = []
            for line in output.strip().split('\n'):
                if not line:
                    continue

                network_info = json.loads(line)

                # Get detailed inspect data
                network_name = network_info['Name']
                inspect_cmd = f"docker network inspect {network_name}"
                inspect_output = self.execute_command(client, inspect_cmd)
                inspect_data = json.loads(inspect_output)[0]

                # Extract IPAM config
                ipam = inspect_data.get('IPAM', {})
                config = ipam.get('Config', [{}])[0]

                network = {
                    'network_name': network_name,
                    'network_id': inspect_data['Id'][:12],
                    'driver': inspect_data['Driver'],
                    'subnet': config.get('Subnet'),
                    'gateway': config.get('Gateway'),
                    'internal': inspect_data.get('Internal', False),
                    'attachable': inspect_data.get('Attachable', False),
                    'labels': json.dumps(inspect_data.get('Labels', {})),
                }

                networks.append(network)

            logger.info(f"Discovered {len(networks)} networks on {host}")
            return networks

        finally:
            client.close()

    def sync_docker_host(self, host_ip: str, username: str = 'root',
                        key_path: Optional[str] = None):
        """Synchronize all Docker data for a host to database"""
        logger.info(f"Starting Docker discovery for {host_ip}")

        # Get or create host record
        host = self.db.get_host_by_ip(host_ip)
        if not host:
            logger.error(f"Host {host_ip} not found in database")
            return

        docker_host_id = host['id']

        # Discover containers
        containers = self.discover_containers(host_ip, username, key_path)
        for container in containers:
            container['docker_host_id'] = docker_host_id
            self.db.upsert_docker_container(container, changed_by='discovery')

        # Discover volumes
        volumes = self.discover_volumes(host_ip, username, key_path)
        for volume in volumes:
            volume['docker_host_id'] = docker_host_id
            self.db.upsert_docker_volume(volume, changed_by='discovery')

        # Discover networks
        networks = self.discover_networks(host_ip, username, key_path)
        for network in networks:
            network['docker_host_id'] = docker_host_id
            self.db.upsert_docker_network(network, changed_by='discovery')

        logger.info(f"Completed Docker discovery for {host_ip}")


def main():
    """Main entry point for Docker discovery"""
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
    docker_hosts = os.getenv('DOCKER_HOSTS', '').split(',')
    ssh_key_path = os.path.expanduser(os.getenv('SSH_KEY_PATH', '~/.ssh/id_rsa'))

    # Initialize database
    db = InfrastructureDB(db_path)
    discovery = DockerDiscovery(db)

    # Discover each Docker host
    for host_spec in docker_hosts:
        if not host_spec.strip():
            continue

        # Parse host specification (user@host or just host)
        if '@' in host_spec:
            username, host = host_spec.split('@')
        else:
            username = 'root'
            host = host_spec

        try:
            discovery.sync_docker_host(host, username, ssh_key_path)
        except Exception as e:
            logger.error(f"Failed to discover {host}: {e}")
            continue


if __name__ == '__main__':
    main()
