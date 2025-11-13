#!/usr/bin/env python3
"""
Master Infrastructure Synchronization Script
Orchestrates discovery from all sources: Proxmox, Docker hosts, network devices
"""

import os
import sys
import logging
import time
from datetime import datetime
from dotenv import load_dotenv
from rich.console import Console
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn

from db_utils import InfrastructureDB
from discover_proxmox import ProxmoxDiscovery
from discover_docker import DockerDiscovery

console = Console()
logger = logging.getLogger(__name__)


class InfrastructureSync:
    """Master synchronization orchestrator"""

    def __init__(self, config: dict):
        self.config = config
        self.db = InfrastructureDB(config['db_path'])
        self.results = {
            'proxmox': {'status': 'pending', 'error': None},
            'docker': {'status': 'pending', 'error': None, 'hosts': []},
            'network': {'status': 'pending', 'error': None},
        }

    def sync_proxmox(self):
        """Synchronize Proxmox infrastructure"""
        try:
            console.print("[bold blue]Discovering Proxmox infrastructure...[/bold blue]")

            discovery = ProxmoxDiscovery(
                self.db,
                self.config['proxmox_host'],
                self.config['proxmox_user'],
                self.config['proxmox_password'],
                self.config['proxmox_verify_ssl']
            )

            discovery.sync_proxmox_infrastructure()

            self.results['proxmox']['status'] = 'success'
            console.print("[bold green]✓ Proxmox discovery completed[/bold green]")

        except Exception as e:
            self.results['proxmox']['status'] = 'failed'
            self.results['proxmox']['error'] = str(e)
            logger.error(f"Proxmox discovery failed: {e}")
            console.print(f"[bold red]✗ Proxmox discovery failed: {e}[/bold red]")

    def sync_docker_hosts(self):
        """Synchronize all Docker hosts"""
        try:
            console.print("[bold blue]Discovering Docker hosts...[/bold blue]")

            discovery = DockerDiscovery(self.db)
            docker_hosts = self.config['docker_hosts']

            for host_spec in docker_hosts:
                if not host_spec.strip():
                    continue

                # Parse host specification
                if '@' in host_spec:
                    username, host = host_spec.split('@')
                else:
                    username = 'root'
                    host = host_spec

                try:
                    console.print(f"  → Discovering {host}...")
                    discovery.sync_docker_host(
                        host,
                        username,
                        self.config.get('ssh_key_path')
                    )
                    self.results['docker']['hosts'].append({
                        'host': host,
                        'status': 'success'
                    })
                    console.print(f"  [green]✓ {host} completed[/green]")

                except Exception as e:
                    self.results['docker']['hosts'].append({
                        'host': host,
                        'status': 'failed',
                        'error': str(e)
                    })
                    logger.error(f"Docker discovery failed for {host}: {e}")
                    console.print(f"  [red]✗ {host} failed: {e}[/red]")

            self.results['docker']['status'] = 'success'
            console.print("[bold green]✓ Docker discovery completed[/bold green]")

        except Exception as e:
            self.results['docker']['status'] = 'failed'
            self.results['docker']['error'] = str(e)
            logger.error(f"Docker discovery failed: {e}")
            console.print(f"[bold red]✗ Docker discovery failed: {e}[/bold red]")

    def sync_network(self):
        """Synchronize network topology (placeholder for future implementation)"""
        try:
            console.print("[bold blue]Discovering network topology...[/bold blue]")

            # TODO: Implement network discovery
            # - Query OPNsense API for firewall rules
            # - Parse ARP tables for IP/MAC mappings
            # - Discover routing tables
            # - Inventory VLANs and network segments

            self.results['network']['status'] = 'skipped'
            console.print("[yellow]⚠ Network discovery not yet implemented[/yellow]")

        except Exception as e:
            self.results['network']['status'] = 'failed'
            self.results['network']['error'] = str(e)
            logger.error(f"Network discovery failed: {e}")
            console.print(f"[bold red]✗ Network discovery failed: {e}[/bold red]")

    def run_full_sync(self):
        """Execute complete infrastructure synchronization"""
        start_time = datetime.now()
        console.print(f"\n[bold]Infrastructure Discovery - {start_time.strftime('%Y-%m-%d %H:%M:%S')}[/bold]\n")

        # Run all discovery tasks
        self.sync_proxmox()
        self.sync_docker_hosts()
        self.sync_network()

        # Print summary
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()

        console.print(f"\n[bold]Discovery Summary (completed in {duration:.1f}s)[/bold]")

        table = Table(show_header=True, header_style="bold magenta")
        table.add_column("Component", style="cyan")
        table.add_column("Status", justify="center")
        table.add_column("Details")

        # Proxmox status
        px_status = self.results['proxmox']['status']
        px_color = 'green' if px_status == 'success' else 'red'
        table.add_row(
            "Proxmox",
            f"[{px_color}]{px_status}[/{px_color}]",
            self.results['proxmox'].get('error', '')
        )

        # Docker status
        docker_status = self.results['docker']['status']
        docker_color = 'green' if docker_status == 'success' else 'red'
        docker_hosts_success = len([h for h in self.results['docker']['hosts'] if h['status'] == 'success'])
        docker_hosts_total = len(self.results['docker']['hosts'])
        table.add_row(
            "Docker Hosts",
            f"[{docker_color}]{docker_status}[/{docker_color}]",
            f"{docker_hosts_success}/{docker_hosts_total} hosts discovered"
        )

        # Network status
        net_status = self.results['network']['status']
        net_color = 'yellow' if net_status == 'skipped' else 'green' if net_status == 'success' else 'red'
        table.add_row(
            "Network",
            f"[{net_color}]{net_status}[/{net_color}]",
            self.results['network'].get('error', '')
        )

        console.print(table)

        # Print infrastructure stats
        self.print_infrastructure_stats()

    def print_infrastructure_stats(self):
        """Print current infrastructure statistics"""
        console.print("\n[bold]Infrastructure Statistics[/bold]")

        stats_table = Table(show_header=True, header_style="bold cyan")
        stats_table.add_column("Resource Type")
        stats_table.add_column("Count", justify="right")

        # Query database for stats
        host_count = self.db.execute_query("SELECT COUNT(*) as cnt FROM hosts WHERE status = 'active'")[0]['cnt']
        vm_count = self.db.execute_query("SELECT COUNT(*) as cnt FROM hosts WHERE host_type = 'vm'")[0]['cnt']
        lxc_count = self.db.execute_query("SELECT COUNT(*) as cnt FROM hosts WHERE host_type = 'lxc'")[0]['cnt']
        container_count = self.db.execute_query("SELECT COUNT(*) as cnt FROM docker_containers")[0]['cnt']
        service_count = self.db.execute_query("SELECT COUNT(*) as cnt FROM services")[0]['cnt']

        stats_table.add_row("Active Hosts", str(host_count))
        stats_table.add_row("Virtual Machines", str(vm_count))
        stats_table.add_row("LXC Containers", str(lxc_count))
        stats_table.add_row("Docker Containers", str(container_count))
        stats_table.add_row("Services", str(service_count))

        console.print(stats_table)


def load_config() -> dict:
    """Load configuration from environment"""
    load_dotenv()

    config = {
        'db_path': os.getenv('DB_PATH', '../infrastructure.db'),
        'proxmox_host': os.getenv('PROXMOX_HOST', '192.168.1.10'),
        'proxmox_user': os.getenv('PROXMOX_USER', 'root@pam'),
        'proxmox_password': os.getenv('PROXMOX_PASSWORD'),
        'proxmox_verify_ssl': os.getenv('PROXMOX_VERIFY_SSL', 'false').lower() == 'true',
        'docker_hosts': [h.strip() for h in os.getenv('DOCKER_HOSTS', '').split(',') if h.strip()],
        'ssh_key_path': os.path.expanduser(os.getenv('SSH_KEY_PATH', '~/.ssh/id_rsa')),
        'log_level': os.getenv('LOG_LEVEL', 'INFO'),
    }

    return config


def main():
    """Main entry point"""
    config = load_config()

    # Setup logging
    logging.basicConfig(
        level=getattr(logging, config['log_level']),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler('infrastructure_discovery.log'),
            logging.StreamHandler()
        ]
    )

    # Validate configuration
    if not config['proxmox_password']:
        console.print("[bold red]Error: PROXMOX_PASSWORD not set in environment[/bold red]")
        sys.exit(1)

    if not config['docker_hosts']:
        console.print("[yellow]Warning: No Docker hosts configured[/yellow]")

    # Run synchronization
    sync = InfrastructureSync(config)
    sync.run_full_sync()


if __name__ == '__main__':
    main()
