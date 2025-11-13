#!/usr/bin/env python3
"""
Quick test script to populate Docker network information
Simplified version without change tracking to avoid database locks
"""

import json
import logging
import paramiko
import sqlite3
from typing import List, Dict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def discover_docker_networks(host: str, username: str = 'root', key_path: str = '~/.ssh/id_rsa') -> List[Dict]:
    """Discover Docker networks on a host via SSH"""
    import os
    key_path = os.path.expanduser(key_path)

    # Connect via SSH
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(host, username=username, key_filename=key_path)
    logger.info(f"Connected to {host}")

    # Get network list
    stdin, stdout, stderr = client.exec_command("docker network ls --format '{{json .}}'")
    output = stdout.read().decode()

    networks = []
    for line in output.strip().split('\n'):
        if not line:
            continue

        network_info = json.loads(line)
        network_name = network_info['Name']

        # Get detailed inspect data
        stdin, stdout, stderr = client.exec_command(f"docker network inspect {network_name}")
        inspect_output = stdout.read().decode()
        inspect_data = json.loads(inspect_output)[0]

        # Extract IPAM config
        ipam = inspect_data.get('IPAM', {})
        config = ipam.get('Config', [{}])[0] if ipam.get('Config') else {}

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

    client.close()
    logger.info(f"Discovered {len(networks)} networks on {host}")
    return networks


def populate_networks(db_path: str, host_ip: str, networks: List[Dict]):
    """Populate Docker networks in database"""
    conn = sqlite3.connect(db_path, timeout=30.0)
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA busy_timeout = 30000")

    cursor = conn.cursor()

    # Get docker host ID
    cursor.execute("SELECT id FROM hosts WHERE management_ip = ?", (host_ip,))
    result = cursor.fetchone()
    if not result:
        logger.error(f"Host {host_ip} not found in database")
        conn.close()
        return

    docker_host_id = result[0]

    # Insert/update networks
    for network in networks:
        network['docker_host_id'] = docker_host_id

        # Check if exists
        cursor.execute(
            "SELECT id FROM docker_networks WHERE docker_host_id = ? AND network_name = ?",
            (docker_host_id, network['network_name'])
        )
        existing = cursor.fetchone()

        if existing:
            # Update
            cursor.execute("""
                UPDATE docker_networks SET
                    network_id = ?, driver = ?, subnet = ?, gateway = ?,
                    internal = ?, attachable = ?, labels = ?
                WHERE docker_host_id = ? AND network_name = ?
            """, (
                network['network_id'], network['driver'], network['subnet'], network['gateway'],
                network['internal'], network['attachable'], network['labels'],
                docker_host_id, network['network_name']
            ))
            logger.info(f"Updated network: {network['network_name']}")
        else:
            # Insert
            cursor.execute("""
                INSERT INTO docker_networks
                (docker_host_id, network_name, network_id, driver, subnet, gateway, internal, attachable, labels)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                docker_host_id, network['network_name'], network['network_id'],
                network['driver'], network['subnet'], network['gateway'],
                network['internal'], network['attachable'], network['labels']
            ))
            logger.info(f"Inserted network: {network['network_name']}")

    conn.commit()
    conn.close()
    logger.info(f"Successfully populated {len(networks)} networks for {host_ip}")


if __name__ == '__main__':
    db_path = '../infrastructure.db'
    docker_hosts = ['192.168.1.20', '192.168.1.9']

    for host_ip in docker_hosts:
        try:
            logger.info(f"\n=== Discovering Docker networks on {host_ip} ===")
            networks = discover_docker_networks(host_ip)

            # Print discovered networks
            print(f"\nDiscovered networks on {host_ip}:")
            for net in networks:
                print(f"  - {net['network_name']} ({net['driver']}): {net['subnet'] or 'N/A'} (gateway: {net['gateway'] or 'N/A'})")

            # Populate database
            populate_networks(db_path, host_ip, networks)

        except Exception as e:
            logger.error(f"Failed to discover {host_ip}: {e}", exc_info=True)

    logger.info("\n=== Docker network discovery complete ===")
