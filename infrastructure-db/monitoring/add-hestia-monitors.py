#!/usr/bin/env python3
"""
Add Comprehensive HestiaCP Monitoring to Uptime Kuma

This script adds detailed monitoring for HestiaCP mail server (192.168.1.30)
covering control panel, webmail, and mail services.

Usage:
    python add-hestia-monitors.py
"""

import sys
from pathlib import Path
from uptime_kuma_api import UptimeKumaApi, MonitorType


def load_credentials_from_file(creds_file='.uptime-kuma-credentials'):
    """Load credentials from config file"""
    script_dir = Path(__file__).parent
    creds_path = script_dir / creds_file

    if not creds_path.exists():
        print(f"❌ Credentials file not found: {creds_path}")
        print("💡 Create .uptime-kuma-credentials file with:")
        print("   UPTIME_KUMA_URL=http://192.168.1.9:3010")
        print("   UPTIME_KUMA_USERNAME=admin")
        print("   UPTIME_KUMA_PASSWORD=yourpassword")
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


def add_hestia_monitors(api):
    """Add comprehensive HestiaCP monitoring"""

    monitors_created = []

    print("\n" + "="*70)
    print("📧 Adding HestiaCP Mail Server Monitors (192.168.1.30)")
    print("="*70 + "\n")

    # 1. HestiaCP Control Panel (Port 8083)
    print("Creating monitor: HestiaCP Control Panel...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🟠 HestiaCP Control Panel",
            url="https://192.168.1.30:8083",
            interval=300,  # 5 minutes
            maxretries=2,
            ignoreTls=True,
            description="HestiaCP admin interface - manages mail, web, and DNS services"
        )
        monitors_created.append(("HestiaCP Control Panel", result))
        print(f"  ✅ Created: Monitor ID {result.get('monitorID', 'N/A')}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 2. Webmail Interface (Apache on port 8443)
    print("Creating monitor: HestiaCP Webmail (Apache)...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🟠 HestiaCP Webmail",
            url="https://192.168.1.30:8443",
            interval=300,  # 5 minutes
            maxretries=2,
            ignoreTls=True,
            description="Roundcube webmail interface via Apache"
        )
        monitors_created.append(("HestiaCP Webmail", result))
        print(f"  ✅ Created: Monitor ID {result.get('monitorID', 'N/A')}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 3. SMTP Service (Port 25 - Already exists as ID 26, but we'll add a more detailed one)
    print("Creating monitor: HestiaCP SMTP Extended...")
    try:
        result = api.add_monitor(
            type=MonitorType.PORT,
            name="📧 HestiaCP SMTP (Exim4)",
            hostname="192.168.1.30",
            port=25,
            interval=300,  # 5 minutes
            maxretries=2,
            description="Exim4 SMTP server - outbound mail via EDP.net relay"
        )
        monitors_created.append(("HestiaCP SMTP", result))
        print(f"  ✅ Created: Monitor ID {result.get('monitorID', 'N/A')}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 4. IMAP Service (Port 993 - Secure IMAP)
    print("Creating monitor: HestiaCP IMAP...")
    try:
        result = api.add_monitor(
            type=MonitorType.PORT,
            name="📧 HestiaCP IMAP (Dovecot)",
            hostname="192.168.1.30",
            port=993,
            interval=300,  # 5 minutes
            maxretries=2,
            description="Dovecot IMAP SSL service - mail retrieval"
        )
        monitors_created.append(("HestiaCP IMAP", result))
        print(f"  ✅ Created: Monitor ID {result.get('monitorID', 'N/A')}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 5. POP3 Service (Port 995 - Secure POP3)
    print("Creating monitor: HestiaCP POP3...")
    try:
        result = api.add_monitor(
            type=MonitorType.PORT,
            name="📧 HestiaCP POP3 (Dovecot)",
            hostname="192.168.1.30",
            port=995,
            interval=600,  # 10 minutes
            maxretries=2,
            description="Dovecot POP3 SSL service - alternative mail retrieval"
        )
        monitors_created.append(("HestiaCP POP3", result))
        print(f"  ✅ Created: Monitor ID {result.get('monitorID', 'N/A')}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 6. Submission Port (Port 587 - Authenticated SMTP)
    print("Creating monitor: HestiaCP Submission...")
    try:
        result = api.add_monitor(
            type=MonitorType.PORT,
            name="📧 HestiaCP Submission",
            hostname="192.168.1.30",
            port=587,
            interval=300,  # 5 minutes
            maxretries=2,
            description="SMTP Submission port - authenticated mail sending"
        )
        monitors_created.append(("HestiaCP Submission", result))
        print(f"  ✅ Created: Monitor ID {result.get('monitorID', 'N/A')}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 7. Mail Domain Access (External domain check)
    print("Creating monitor: Mail Domain (mail.accelior.com)...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="🌐 mail.accelior.com",
            url="https://mail.accelior.com",
            interval=300,  # 5 minutes
            maxretries=2,
            description="External access to HestiaCP webmail via Nginx Proxy Manager"
        )
        monitors_created.append(("mail.accelior.com", result))
        print(f"  ✅ Created: Monitor ID {result.get('monitorID', 'N/A')}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    # 8. Radicale CalDAV/CardDAV (Port 5232 inside container)
    print("Creating monitor: Radicale CalDAV/CardDAV...")
    try:
        result = api.add_monitor(
            type=MonitorType.HTTP,
            name="📅 Radicale CalDAV",
            url="https://mail.accelior.com/radicale/.web/",
            interval=600,  # 10 minutes
            maxretries=2,
            description="Radicale calendar and contacts service"
        )
        monitors_created.append(("Radicale", result))
        print(f"  ✅ Created: Monitor ID {result.get('monitorID', 'N/A')}")
    except Exception as e:
        print(f"  ❌ Error: {e}")

    print("\n" + "="*70)
    print(f"✅ Total HestiaCP Monitors Created: {len(monitors_created)}")
    print("="*70 + "\n")

    return monitors_created


def main():
    # Load credentials
    creds = load_credentials_from_file()

    if not creds.get('UPTIME_KUMA_URL'):
        print("❌ Error: UPTIME_KUMA_URL not found in credentials file")
        sys.exit(1)

    if not creds.get('UPTIME_KUMA_USERNAME') or not creds.get('UPTIME_KUMA_PASSWORD'):
        print("❌ Error: UPTIME_KUMA_USERNAME and UPTIME_KUMA_PASSWORD required")
        sys.exit(1)

    print(f"\n{'='*70}")
    print(f"  HestiaCP Monitoring Setup for Uptime Kuma")
    print(f"{'='*70}")
    print(f"\nConnecting to: {creds['UPTIME_KUMA_URL']}")

    # Connect to Uptime Kuma
    api = UptimeKumaApi(creds['UPTIME_KUMA_URL'])

    try:
        # Login
        print(f"Authenticating as: {creds['UPTIME_KUMA_USERNAME']}")
        api.login(username=creds['UPTIME_KUMA_USERNAME'], password=creds['UPTIME_KUMA_PASSWORD'])
        print("✅ Connected successfully!\n")

        # Get existing monitors
        existing = api.get_monitors()
        print(f"Found {len(existing)} existing monitors\n")

        # Add HestiaCP monitors
        monitors = add_hestia_monitors(api)

        print(f"\n{'='*70}")
        print(f"  HestiaCP Monitoring Setup Complete!")
        print(f"{'='*70}")
        print(f"\n📊 Summary:")
        print(f"   Control Panel:      1 monitor  (HTTPS port 8083)")
        print(f"   Webmail Interface:  1 monitor  (HTTPS port 8443)")
        print(f"   Mail Services:      4 monitors (SMTP, IMAP, POP3, Submission)")
        print(f"   External Access:    1 monitor  (mail.accelior.com)")
        print(f"   CalDAV/CardDAV:     1 monitor  (Radicale)")
        print(f"\nAccess your dashboard: {creds['UPTIME_KUMA_URL']}/dashboard")
        print()

    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        api.disconnect()


if __name__ == "__main__":
    main()
