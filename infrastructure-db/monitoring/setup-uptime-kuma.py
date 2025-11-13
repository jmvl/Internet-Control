#!/usr/bin/env python3
"""
Uptime Kuma Automated Setup
Automatically configure critical infrastructure monitors via API

Usage:
    # Using credentials file (recommended):
    python setup-uptime-kuma.py

    # Using command line arguments:
    python setup-uptime-kuma.py --url http://192.168.1.9:3010 --username admin --password yourpassword
    python setup-uptime-kuma.py --url http://192.168.1.9:3010 --token YOUR_API_TOKEN

    # With Telegram notifications:
    python setup-uptime-kuma.py --telegram-bot-token YOUR_BOT_TOKEN --telegram-chat-id YOUR_CHAT_ID
"""

import argparse
import sys
import os
from pathlib import Path
from uptime_kuma_api import UptimeKumaApi, MonitorType, NotificationType


def load_credentials_from_file(creds_file='.uptime-kuma-credentials'):
    """Load credentials from config file"""
    script_dir = Path(__file__).parent
    creds_path = script_dir / creds_file

    if not creds_path.exists():
        return {}

    creds = {}
    with open(creds_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                key, value = line.split('=', 1)
                creds[key.strip()] = value.strip()

    return creds

def create_monitors(api):
    """Create all 25 comprehensive infrastructure monitors across 6 tiers"""

    monitors_created = []

    # ========================================
    # TIER 1: CRITICAL INFRASTRUCTURE (60s)
    # ========================================
    print("\n" + "="*60)
    print("🔴 TIER 1: CRITICAL INFRASTRUCTURE (60-second checks)")
    print("="*60 + "\n")

    # 1. Pi-hole DNS (MOST CRITICAL)
    print("Creating monitor: Pi-hole DNS...")
    try:
        result = api.add_monitor(
            type=MonitorType.DNS,
            name="🔴 Pi-hole DNS",
            hostname="192.168.1.5",
            dns_resolve_server="192.168.1.5",
            dns_resolve_type="A",
            port=53,
            interval=60,  # Check every 60 seconds
            maxretries=3,
            description="Critical DNS server - single point of failure"
        )
        monitors_created.append(("Pi-hole DNS", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 2. OPNsense Firewall
    print("Creating monitor: OPNsense Firewall...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🔴 OPNsense Firewall",
            url="https://192.168.1.3:8443",
            interval=60,
            maxretries=3,
            ignoreTls=True,
            description="Network firewall and gateway"
        )
        monitors_created.append(("OPNsense Firewall", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 3. Proxmox Virtualization Host
    print("Creating monitor: Proxmox Host...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🔴 Proxmox pve2",
            url="https://192.168.1.10:8006",
            interval=120,
            maxretries=3,
            ignoreTls=True,
            description="Virtualization host - all VMs/LXC depend on this"
        )
        monitors_created.append(("Proxmox pve2", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 4. Docker Host - pct111 (Supabase)
    print("Creating monitor: Docker Host pct111...")
    try:
        result = api.add_monitor(
            type=MonitorType.PING,
            name="🟡 Docker Host pct111",
            hostname="192.168.1.20",
            interval=120,
            maxretries=3,
            description="Primary Docker host - Supabase + n8n"
        )
        monitors_created.append(("Docker Host pct111", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 5. Docker Host - OMV (Storage)
    print("Creating monitor: OMV Storage & Docker Host...")
    try:
        result = api.add_monitor(
            type=MonitorType.PING,
            name="🟡 OMV Storage",
            hostname="192.168.1.9",
            interval=120,
            maxretries=3,
            description="Storage server + Docker host - Immich & media services"
        )
        monitors_created.append(("OMV Storage", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # ========================================
    # TIER 2: CRITICAL DOCKER HOSTS (120s)
    # ========================================
    print("\n" + "="*60)
    print("🟡 TIER 2: CRITICAL DOCKER HOSTS (120-second checks)")
    print("="*60 + "\n")

    # 4. Docker Host - pct111 (Already created above)
    # 5. Docker Host - OMV (Already created above)

    # ========================================
    # TIER 3: CORE SERVICES (300s)
    # ========================================
    print("\n" + "="*60)
    print("🟠 TIER 3: CORE SERVICES (300-second checks)")
    print("="*60 + "\n")

    # 6. Supabase Kong Gateway (moved to position 6)
    print("Creating monitor: Supabase Kong Gateway...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🟠 Supabase Kong Gateway",
            url="http://192.168.1.20:8000",
            interval=300,
            maxretries=2,
            description="Supabase API gateway - critical for all API access"
        )
        monitors_created.append(("Supabase Kong Gateway", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 7. Supabase PostgreSQL
    print("Creating monitor: Supabase PostgreSQL...")
    try:
        result = api.add_monitor(
            type=MonitorType.PORT,
            name="🟠 Supabase PostgreSQL",
            hostname="192.168.1.20",
            port=5432,
            interval=300,
            maxretries=2,
            description="Primary PostgreSQL database for Supabase"
        )
        monitors_created.append(("Supabase PostgreSQL", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 8. n8n Automation (using domain name via Nginx Proxy Manager)
    print("Creating monitor: n8n Automation...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🟠 n8n Automation",
            url="https://n8n.accelior.com",
            interval=300,
            maxretries=2,
            description="Workflow automation platform"
        )
        monitors_created.append(("n8n Automation", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 9. Immich Photos
    print("Creating monitor: Immich Photos...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🟠 Immich Photos",
            url="http://192.168.1.9:2283",
            interval=300,
            maxretries=2,
            description="AI-powered photo management service"
        )
        monitors_created.append(("Immich Photos", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 10. Nginx Proxy Manager
    print("Creating monitor: Nginx Proxy Manager...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🟠 Nginx Proxy Manager",
            url="https://192.168.1.9:81",
            interval=300,
            maxretries=2,
            ignoreTls=True,
            description="Reverse proxy for external service access"
        )
        monitors_created.append(("Nginx Proxy Manager", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # ========================================
    # TIER 4: RESOURCE & HEALTH MONITORING (300s)
    # ========================================
    print("\n" + "="*60)
    print("⚠️  TIER 4: RESOURCE & HEALTH MONITORING (300-second checks)")
    print("="*60 + "\n")

    # 11. Netdata Monitoring System (using domain name via Nginx Proxy Manager)
    print("Creating monitor: Netdata Monitoring...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="⚠️  Netdata Monitoring",
            url="https://netdata.acmea.tech",
            interval=300,
            maxretries=2,
            description="Meta-monitoring system (currently alerting on swap issues)"
        )
        monitors_created.append(("Netdata Monitoring", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 12. Supabase Realtime (Known Unhealthy)
    print("Creating monitor: Supabase Realtime (Known Issue)...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="⚠️  Supabase Realtime",
            url="http://192.168.1.20:4000",  # Realtime service port
            interval=300,
            maxretries=2,
            description="WebSocket service - KNOWN UNHEALTHY, needs investigation"
        )
        monitors_created.append(("Supabase Realtime", result))
        print(f"  ⚠️  Created (Known unhealthy): {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # ========================================
    # TIER 5: COLLABORATION SERVICES (600s)
    # ========================================
    print("\n" + "="*60)
    print("🟢 TIER 5: COLLABORATION SERVICES (600-second checks)")
    print("="*60 + "\n")

    # 13. Confluence Wiki (using domain name via Nginx Proxy Manager)
    print("Creating monitor: Confluence Wiki...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🟢 Confluence Wiki",
            url="https://confluence.accelior.com",
            interval=600,
            maxretries=2,
            description="Team documentation and collaboration platform"
        )
        monitors_created.append(("Confluence", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 14. JIRA Issue Tracking (using domain name via Nginx Proxy Manager)
    print("Creating monitor: JIRA...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🟢 JIRA",
            url="https://jira.accelior.com",
            interval=600,
            maxretries=2,
            description="Issue tracking and project management"
        )
        monitors_created.append(("JIRA", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 15. GitLab (using domain name via Nginx Proxy Manager)
    print("Creating monitor: GitLab...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🟢 GitLab",
            url="https://gitlab.accelior.com",
            interval=600,
            maxretries=2,
            description="Git repository and CI/CD platform"
        )
        monitors_created.append(("GitLab", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 16. Seafile File Server (using domain name via Nginx Proxy Manager)
    print("Creating monitor: Seafile...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🟢 Seafile",
            url="https://files.accelior.com",
            interval=600,
            maxretries=2,
            description="Team file sharing and collaboration"
        )
        monitors_created.append(("Seafile", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 17. Mail Server
    print("Creating monitor: Mail Server...")
    try:
        result = api.add_monitor(
            type=MonitorType.PORT,
            name="🟢 Mail Server (SMTP)",
            hostname="192.168.1.30",
            port=25,
            interval=600,
            maxretries=2,
            description="Email delivery system"
        )
        monitors_created.append(("Mail Server", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # ========================================
    # TIER 6: META-MONITORING (300s)
    # ========================================
    print("\n" + "="*60)
    print("📊 TIER 6: META-MONITORING (300-second checks)")
    print("="*60 + "\n")

    # 18. Uptime Kuma Self-Check
    print("Creating monitor: Uptime Kuma Self-Monitor...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="📊 Uptime Kuma (Self)",
            url="http://192.168.1.9:3010",
            interval=300,
            maxretries=2,
            description="Monitoring the monitoring system itself"
        )
        monitors_created.append(("Uptime Kuma Self-Check", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 19. Portainer (pct111)
    print("Creating monitor: Portainer (pct111)...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="📊 Portainer (pct111)",
            url="https://192.168.1.20:9443",
            interval=300,
            maxretries=2,
            ignoreTls=True,
            description="Docker container management UI"
        )
        monitors_created.append(("Portainer pct111", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 20. Calibre E-books (using domain name via Nginx Proxy Manager)
    print("Creating monitor: Calibre...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="📚 Calibre E-books",
            url="https://books.acmea.tech",
            interval=600,
            maxretries=2,
            description="E-book library management"
        )
        monitors_created.append(("Calibre", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 21. Syncthing
    print("Creating monitor: Syncthing...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="📊 Syncthing",
            url="http://192.168.1.9:8384",
            interval=600,
            maxretries=2,
            description="File synchronization service"
        )
        monitors_created.append(("Syncthing", result))
        print(f"  ✅ Created: {result}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    print("\n" + "="*60)
    print(f"✅ Total Monitors Created: {len(monitors_created)}")
    print("="*60)

    return monitors_created


def setup_telegram_notification(api, bot_token, chat_id):
    """Set up Telegram notification channel"""
    print("\n=== Setting up Telegram Notifications ===\n")

    try:
        result = api.add_notification(
            name="Telegram Alerts",
            type=NotificationType.TELEGRAM,
            isDefault=True,  # Apply to all monitors by default
            applyExisting=True,  # Apply to existing monitors
            telegramBotToken=bot_token,
            telegramChatID=chat_id
        )
        print(f"✅ Telegram notification configured: {result}")
        return result
    except Exception as e:
        print(f"❌ Error setting up Telegram: {e}")
        return None


def main():
    # Load credentials from file
    creds = load_credentials_from_file()

    parser = argparse.ArgumentParser(
        description="Automatically configure Uptime Kuma monitors for infrastructure",
        epilog="If no arguments provided, will try to load from .uptime-kuma-credentials file"
    )
    parser.add_argument(
        "--url",
        default=creds.get('UPTIME_KUMA_URL'),
        help="Uptime Kuma URL (e.g., http://192.168.1.9:3010)"
    )
    parser.add_argument(
        "--username",
        default=creds.get('UPTIME_KUMA_USERNAME'),
        help="Admin username"
    )
    parser.add_argument(
        "--password",
        default=creds.get('UPTIME_KUMA_PASSWORD'),
        help="Admin password"
    )
    parser.add_argument(
        "--token",
        default=creds.get('UPTIME_KUMA_API_TOKEN'),
        help="API token (alternative to username/password)"
    )
    parser.add_argument(
        "--telegram-bot-token",
        default=creds.get('TELEGRAM_BOT_TOKEN'),
        help="Telegram bot token for notifications (optional)"
    )
    parser.add_argument(
        "--telegram-chat-id",
        default=creds.get('TELEGRAM_CHAT_ID'),
        help="Telegram chat ID for notifications (optional)"
    )

    args = parser.parse_args()

    # Validate we have URL
    if not args.url:
        print("❌ Error: Must provide --url or set UPTIME_KUMA_URL in .uptime-kuma-credentials")
        sys.exit(1)

    # Validate authentication
    if not args.token and (not args.username or not args.password):
        print("❌ Error: Must provide either --token OR both --username and --password")
        print("💡 Tip: Create .uptime-kuma-credentials file with your credentials")
        sys.exit(1)

    print(f"\n{'='*60}")
    print(f"  Uptime Kuma Automated Setup")
    print(f"{'='*60}")
    print(f"\nConnecting to: {args.url}")

    # Connect to Uptime Kuma
    api = UptimeKumaApi(args.url)

    try:
        # Login
        if args.token:
            print("Authenticating with token...")
            api.login_by_token(args.token)
        else:
            print(f"Authenticating as: {args.username}")
            api.login(username=args.username, password=args.password)

        print("✅ Connected successfully!\n")

        # Get existing monitors
        existing = api.get_monitors()
        print(f"Found {len(existing)} existing monitors")

        # Create monitors
        monitors = create_monitors(api)

        print(f"\n{'='*60}")
        print(f"  Monitor Creation Summary")
        print(f"{'='*60}")
        print(f"\n✅ Total Monitors Created: {len(monitors)}")
        print(f"\n📊 Monitor Distribution:")
        print(f"   🔴 Tier 1 (Critical - 60s):  3 monitors")
        print(f"   🟡 Tier 2 (Docker - 120s):   2 monitors")
        print(f"   🟠 Tier 3 (Services - 300s): 5 monitors")
        print(f"   ⚠️  Tier 4 (Health - 300s):   2 monitors")
        print(f"   🟢 Tier 5 (Collab - 600s):   5 monitors")
        print(f"   📊 Tier 6 (Meta - 300-600s): 4 monitors")

        # Set up Telegram notifications if bot token and chat ID provided
        if args.telegram_bot_token and args.telegram_chat_id:
            setup_telegram_notification(api, args.telegram_bot_token, args.telegram_chat_id)
        else:
            print("\n💡 Tip: Add Telegram notifications:")
            print("   Add TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID to .uptime-kuma-credentials")
            print("   Or use: --telegram-bot-token TOKEN --telegram-chat-id CHAT_ID")

        print(f"\n{'='*60}")
        print(f"  Setup Complete!")
        print(f"{'='*60}")
        print(f"\nAccess your dashboard: {args.url}/dashboard")
        print("\nNext steps:")
        print("  1. Review monitors in web UI")
        print("  2. Configure notification channels (Settings → Notifications)")
        print("  3. Test alerts by pausing a monitor")
        print()

    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)
    finally:
        api.disconnect()


if __name__ == "__main__":
    main()
