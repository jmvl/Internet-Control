#!/usr/bin/env python3
"""
Uptime Kuma Monitor Management Script

This script uses the uptime-kuma-api library to add monitors to Uptime Kuma.
Uptime Kuma doesn't have a built-in REST API - it uses Socket.IO for communication.

Requirements:
    pip install uptime-kuma-api

Usage:
    python3 add_uptime_kuma_monitor.py

Environment Variables:
    UPTIME_KUMA_URL: Uptime Kuma URL (default: http://192.168.1.9:3010)
    UPTIME_KUMA_USERNAME: Admin username (default: admin)
    UPTIME_KUMA_PASSWORD: Admin password (REQUIRED)
"""

import os
import sys
from uptime_kuma_api import UptimeKumaApi, MonitorType, NotificationType

# Configuration
UPTIME_KUMA_URL = os.getenv('UPTIME_KUMA_URL', 'http://192.168.1.9:3010')
UPTIME_KUMA_USERNAME = os.getenv('UPTIME_KUMA_USERNAME', 'admin')
UPTIME_KUMA_PASSWORD = os.getenv('UPTIME_KUMA_PASSWORD')

if not UPTIME_KUMA_PASSWORD:
    print("ERROR: UPTIME_KUMA_PASSWORD environment variable is required")
    print("Usage: UPTIME_KUMA_PASSWORD='your-password' python3 add_uptime_kuma_monitor.py")
    sys.exit(1)


def add_http_monitor(name, url, interval=60, max_retries=0):
    """
    Add an HTTP/HTTPS monitor to Uptime Kuma.

    Args:
        name: Monitor name
        url: URL to monitor (e.g., https://example.com)
        interval: Check interval in seconds (default: 60)
        max_retries: Number of retries before marking as down (default: 0)

    Returns:
        Monitor object if successful, None otherwise
    """
    api = UptimeKumaApi(UPTIME_KUMA_URL)

    try:
        print(f"Connecting to Uptime Kuma at {UPTIME_KUMA_URL}...")
        api.login(UPTIME_KUMA_USERNAME, UPTIME_KUMA_PASSWORD)
        print("✓ Login successful")

        print(f"Adding HTTP monitor: {name} -> {url}")
        monitor = api.add_monitor(
            type=MonitorType.HTTP,
            name=name,
            url=url,
            interval=interval,
            maxretries=max_retries,
            method="GET",
            accepted_statuscodes=["200-299"],
        )

        print(f"✓ Monitor added successfully with ID: {monitor.id}")
        return monitor

    except Exception as e:
        print(f"✗ Error adding monitor: {e}")
        return None

    finally:
        api.disconnect()


def add_ping_monitor(name, hostname, interval=60, max_retries=0):
    """
    Add a ping (ICMP) monitor to Uptime Kuma.

    Args:
        name: Monitor name
        hostname: Hostname or IP to ping
        interval: Check interval in seconds (default: 60)
        max_retries: Number of retries before marking as down (default: 0)

    Returns:
        Monitor object if successful, None otherwise
    """
    api = UptimeKumaApi(UPTIME_KUMA_URL)

    try:
        print(f"Connecting to Uptime Kuma at {UPTIME_KUMA_URL}...")
        api.login(UPTIME_KUMA_USERNAME, UPTIME_KUMA_PASSWORD)
        print("✓ Login successful")

        print(f"Adding PING monitor: {name} -> {hostname}")
        monitor = api.add_monitor(
            type=MonitorType.PING,
            name=name,
            hostname=hostname,
            interval=interval,
            maxretries=max_retries,
            packet_size=56,
            ping_count=1,
        )

        print(f"✓ Monitor added successfully with ID: {monitor.id}")
        return monitor

    except Exception as e:
        print(f"✗ Error adding monitor: {e}")
        return None

    finally:
        api.disconnect()


def add_port_monitor(name, hostname, port, interval=60, max_retries=0):
    """
    Add a TCP port monitor to Uptime Kuma.

    Args:
        name: Monitor name
        hostname: Hostname or IP to check
        port: TCP port number
        interval: Check interval in seconds (default: 60)
        max_retries: Number of retries before marking as down (default: 0)

    Returns:
        Monitor object if successful, None otherwise
    """
    api = UptimeKumaApi(UPTIME_KUMA_URL)

    try:
        print(f"Connecting to Uptime Kuma at {UPTIME_KUMA_URL}...")
        api.login(UPTIME_KUMA_USERNAME, UPTIME_KUMA_PASSWORD)
        print("✓ Login successful")

        print(f"Adding PORT monitor: {name} -> {hostname}:{port}")
        monitor = api.add_monitor(
            type=MonitorType.PORT,
            name=name,
            hostname=hostname,
            port=port,
            interval=interval,
            maxretries=max_retries,
        )

        print(f"✓ Monitor added successfully with ID: {monitor.id}")
        return monitor

    except Exception as e:
        print(f"✗ Error adding monitor: {e}")
        return None

    finally:
        api.disconnect()


def list_monitors():
    """List all monitors in Uptime Kuma."""
    api = UptimeKumaApi(UPTIME_KUMA_URL)

    try:
        print(f"Connecting to Uptime Kuma at {UPTIME_KUMA_URL}...")
        api.login(UPTIME_KUMA_USERNAME, UPTIME_KUMA_PASSWORD)
        print("✓ Login successful")

        monitors = api.get_monitors()
        print(f"\nTotal monitors: {len(monitors)}\n")

        for monitor in monitors:
            status_icon = {
                0: "⚫ UNKNOWN",
                1: "🟢 UP",
                2: "🔴 DOWN",
                3: "🟡 PENDING",
            }.get(monitor.status, f"❓ ({monitor.status})")

            print(f"  [{monitor.id}] {monitor.name}")
            print(f"      Type: {monitor.type}")
            print(f"      Status: {status_icon}")
            print(f"      URL: {getattr(monitor, 'url', getattr(monitor, 'hostname', 'N/A'))}")
            print(f"      Interval: {monitor.interval}s")
            print()

    except Exception as e:
        print(f"✗ Error listing monitors: {e}")

    finally:
        api.disconnect()


def delete_monitor(monitor_id):
    """Delete a monitor by ID."""
    api = UptimeKumaApi(UPTIME_KUMA_URL)

    try:
        print(f"Connecting to Uptime Kuma at {UPTIME_KUMA_URL}...")
        api.login(UPTIME_KUMA_USERNAME, UPTIME_KUMA_PASSWORD)
        print("✓ Login successful")

        print(f"Deleting monitor ID: {monitor_id}")
        api.delete_monitor(monitor_id)
        print(f"✓ Monitor deleted successfully")

    except Exception as e:
        print(f"✗ Error deleting monitor: {e}")

    finally:
        api.disconnect()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Uptime Kuma Monitor Management")
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # List monitors
    subparsers.add_parser("list", help="List all monitors")

    # Add HTTP monitor
    http_parser = subparsers.add_parser("add-http", help="Add HTTP/HTTPS monitor")
    http_parser.add_argument("--name", required=True, help="Monitor name")
    http_parser.add_argument("--url", required=True, help="URL to monitor")
    http_parser.add_argument("--interval", type=int, default=60, help="Check interval (seconds)")
    http_parser.add_argument("--retries", type=int, default=0, help="Max retries")

    # Add PING monitor
    ping_parser = subparsers.add_parser("add-ping", help="Add PING monitor")
    ping_parser.add_argument("--name", required=True, help="Monitor name")
    ping_parser.add_argument("--hostname", required=True, help="Hostname to ping")
    ping_parser.add_argument("--interval", type=int, default=60, help="Check interval (seconds)")
    ping_parser.add_argument("--retries", type=int, default=0, help="Max retries")

    # Add PORT monitor
    port_parser = subparsers.add_parser("add-port", help="Add TCP port monitor")
    port_parser.add_argument("--name", required=True, help="Monitor name")
    port_parser.add_argument("--hostname", required=True, help="Hostname to check")
    port_parser.add_argument("--port", type=int, required=True, help="TCP port number")
    port_parser.add_argument("--interval", type=int, default=60, help="Check interval (seconds)")
    port_parser.add_argument("--retries", type=int, default=0, help="Max retries")

    # Delete monitor
    delete_parser = subparsers.add_parser("delete", help="Delete monitor")
    delete_parser.add_argument("--id", type=int, required=True, help="Monitor ID")

    args = parser.parse_args()

    if args.command == "list":
        list_monitors()
    elif args.command == "add-http":
        add_http_monitor(args.name, args.url, args.interval, args.retries)
    elif args.command == "add-ping":
        add_ping_monitor(args.name, args.hostname, args.interval, args.retries)
    elif args.command == "add-port":
        add_port_monitor(args.name, args.hostname, args.port, args.interval, args.retries)
    elif args.command == "delete":
        delete_monitor(args.id)
    else:
        parser.print_help()
