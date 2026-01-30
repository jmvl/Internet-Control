#!/usr/bin/env python3
"""
Infrastructure API
Flask API serving infrastructure data from SQLite database
"""

import os
import sqlite3
import json
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from pathlib import Path

app = Flask(__name__, static_folder='static')
CORS(app)  # Enable CORS for all routes

# Database path
DB_PATH = os.path.join(os.path.dirname(__file__), '..', 'infrastructure.db')

def get_db_connection():
    """Create a database connection with row factory"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def row_to_dict(row):
    """Convert sqlite3.Row to dict"""
    return dict(row) if row else None

@app.route('/')
def index():
    """Serve the static HTML page"""
    return send_from_directory('static', 'index.html')

@app.route('/api/hosts')
def get_hosts():
    """Get all hosts with LXC/VM information"""
    conn = get_db_connection()

    # Get hosts with their proxmox container details
    query = """
        SELECT
            h.id,
            h.hostname,
            h.host_type,
            h.management_ip,
            h.status,
            h.cpu_cores,
            h.total_ram_mb,
            h.vmid,
            h.criticality,
            h.purpose,
            pc.container_type,
            pc.vm_type,
            pc.os_type,
            pc.os_template,
            pc.unprivileged,
            pc.auto_start,
            ph.hostname as parent_hostname
        FROM hosts h
        LEFT JOIN proxmox_containers pc ON h.id = pc.host_id
        LEFT JOIN hosts ph ON h.parent_host_id = ph.id
        WHERE h.host_type IN ('lxc', 'vm', 'physical')
        ORDER BY h.vmid, h.hostname
    """

    cursor = conn.execute(query)
    hosts = [row_to_dict(row) for row in cursor.fetchall()]
    conn.close()

    return jsonify(hosts)

@app.route('/api/containers')
def get_containers():
    """Get all Docker containers with host information"""
    conn = get_db_connection()

    query = """
        SELECT
            dc.id,
            dc.container_name,
            dc.image,
            dc.image_tag,
            dc.status,
            dc.health_status,
            dc.ports,
            dc.networks,
            h.hostname as docker_host,
            h.management_ip as host_ip,
            h.id as docker_host_id
        FROM docker_containers dc
        JOIN hosts h ON dc.docker_host_id = h.id
        ORDER BY h.hostname, dc.container_name
    """

    cursor = conn.execute(query)
    containers = [row_to_dict(row) for row in cursor.fetchall()]
    conn.close()

    return jsonify(containers)

@app.route('/api/containers/<int:host_id>')
def get_containers_by_host(host_id):
    """Get Docker containers for a specific host"""
    conn = get_db_connection()

    query = """
        SELECT
            dc.id,
            dc.container_name,
            dc.image,
            dc.image_tag,
            dc.status,
            dc.health_status,
            dc.ports,
            dc.networks
        FROM docker_containers dc
        WHERE dc.docker_host_id = ?
        ORDER BY dc.container_name
    """

    cursor = conn.execute(query, (host_id,))
    containers = [row_to_dict(row) for row in cursor.fetchall()]
    conn.close()

    return jsonify(containers)

@app.route('/api/stats')
def get_stats():
    """Get infrastructure summary statistics"""
    conn = get_db_connection()

    stats = {}

    # Host counts by type
    stats['hosts'] = {
        'total': conn.execute("SELECT COUNT(*) FROM hosts").fetchone()[0],
        'physical': conn.execute("SELECT COUNT(*) FROM hosts WHERE host_type = 'physical'").fetchone()[0],
        'lxc': conn.execute("SELECT COUNT(*) FROM hosts WHERE host_type = 'lxc' AND status = 'active'").fetchone()[0],
        'vm': conn.execute("SELECT COUNT(*) FROM hosts WHERE host_type = 'vm' AND status = 'active'").fetchone()[0],
    }

    # Docker counts
    stats['docker'] = {
        'containers': conn.execute("SELECT COUNT(*) FROM docker_containers").fetchone()[0],
        'running': conn.execute("SELECT COUNT(*) FROM docker_containers WHERE status = 'running'").fetchone()[0],
        'healthy': conn.execute("SELECT COUNT(*) FROM docker_containers WHERE health_status = 'healthy'").fetchone()[0],
        'networks': conn.execute("SELECT COUNT(*) FROM docker_networks").fetchone()[0],
    }

    # Service counts
    stats['services'] = {
        'total': conn.execute("SELECT COUNT(*) FROM services").fetchone()[0],
        'running': conn.execute("SELECT COUNT(*) FROM services WHERE status = 'running' OR status = 'healthy'").fetchone()[0],
    }

    # Proxmox counts
    stats['proxmox'] = {
        'containers': conn.execute("SELECT COUNT(*) FROM proxmox_containers").fetchone()[0],
        'lxc': conn.execute("SELECT COUNT(*) FROM proxmox_containers WHERE container_type = 'lxc'").fetchone()[0],
        'vm': conn.execute("SELECT COUNT(*) FROM proxmox_containers WHERE container_type = 'vm'").fetchone()[0],
    }

    conn.close()

    return jsonify(stats)

@app.route('/api/topology')
def get_topology():
    """Get network topology information"""
    conn = get_db_connection()

    query = """
        SELECT
            n.network_name,
            n.cidr,
            n.vlan_id,
            n.gateway,
            n.security_zone,
            h.hostname,
            h.host_type,
            ni.interface_name,
            ip.ip_address
        FROM networks n
        LEFT JOIN ip_addresses ip ON ip.network_id = n.id
        LEFT JOIN hosts h ON ip.host_id = h.id
        LEFT JOIN network_interfaces ni ON ip.interface_id = ni.id
        ORDER BY n.vlan_id, ip.ip_address
    """

    cursor = conn.execute(query)
    topology = [row_to_dict(row) for row in cursor.fetchall()]
    conn.close()

    return jsonify(topology)

@app.route('/api/host/<hostname>')
def get_host_detail(hostname):
    """Get detailed information about a specific host"""
    conn = get_db_connection()

    # Get host info
    host = conn.execute(
        "SELECT * FROM hosts WHERE hostname = ?",
        (hostname,)
    ).fetchone()

    if not host:
        conn.close()
        return jsonify({'error': 'Host not found'}), 404

    host_data = row_to_dict(host)

    # Get Docker containers for this host
    if host_data['host_type'] == 'docker_host' or host_data.get('container_id'):
        cursor = conn.execute(
            """SELECT * FROM docker_containers
               WHERE docker_host_id = ?
               ORDER BY container_name""",
            (host_data['id'],)
        )
        host_data['docker_containers'] = [row_to_dict(row) for row in cursor.fetchall()]

    # Get services for this host
    cursor = conn.execute(
        """SELECT * FROM services
           WHERE host_id = ?
           ORDER BY service_name""",
        (host_data['id'],)
    )
    host_data['services'] = [row_to_dict(row) for row in cursor.fetchall()]

    # Get proxmox container info if applicable
    if host_data['host_type'] in ('lxc', 'vm'):
        cursor = conn.execute(
            """SELECT * FROM proxmox_containers
               WHERE host_id = ?""",
            (host_data['id'],)
        )
        pc = cursor.fetchone()
        if pc:
            host_data['proxmox'] = row_to_dict(pc)

    conn.close()

    return jsonify(host_data)

@app.route('/api/health')
def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        conn.execute("SELECT 1")
        conn.close()
        return jsonify({'status': 'healthy', 'database': 'connected'})
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

@app.route('/api/refresh', methods=['POST'])
def refresh_data():
    """Trigger infrastructure database refresh from PVE2"""
    import subprocess
    import os

    script_path = os.path.join(os.path.dirname(__file__), '..', 'scrape_pve2.sh')

    if not os.path.exists(script_path):
        return jsonify({'error': 'Scraper script not found'}), 404

    try:
        # Run the scraper script
        result = subprocess.run(
            ['bash', script_path],
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )

        if result.returncode == 0:
            return jsonify({
                'status': 'success',
                'message': 'Infrastructure database updated successfully',
                'stdout': result.stdout
            })
        else:
            return jsonify({
                'status': 'error',
                'message': 'Scraper script failed',
                'stderr': result.stderr,
                'stdout': result.stdout
            }), 500

    except subprocess.TimeoutExpired:
        return jsonify({'status': 'error', 'message': 'Refresh timed out after 5 minutes'}), 504
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.errorhandler(404)
def not_found(e):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def server_error(e):
    return jsonify({'error': 'Internal server error', 'message': str(e)}), 500

if __name__ == '__main__':
    # Create static directory if it doesn't exist
    static_dir = Path(__file__).parent / 'static'
    static_dir.mkdir(exist_ok=True)

    # Run app
    app.run(host='0.0.0.0', port=5000, debug=False)
