# Uptime Kuma Monitoring Setup

**Access:** http://192.168.1.9:3010
**Purpose:** Centralized monitoring with alerts for critical infrastructure
**Status:** ✅ Running (confirmed 2025-10-17)

---

## Quick Setup

### 1. Access Uptime Kuma

Open: **http://192.168.1.9:3010**

If first time, create admin account.

---

### 2. Add These Critical Monitors

#### 🔴 Priority 1: Network Infrastructure (Check every 60 seconds)

**Pi-hole DNS** - MOST CRITICAL (single point of failure)
- Monitor Type: **DNS**
- Hostname: `192.168.1.5`
- DNS Resolver: `192.168.1.5`
- Test Hostname: `google.com`
- Port: `53`
- Heartbeat: `60 seconds`
- Retries: `3`
- ✅ Enable all notifications

**OPNsense Firewall**
- Monitor Type: **HTTP(s)**
- URL: `https://192.168.1.3`
- Accept Unauthorized SSL: ✅
- Heartbeat: `60 seconds`
- ✅ Enable all notifications

**Proxmox Host**
- Monitor Type: **HTTP(s)**
- URL: `https://192.168.1.10:8006`
- Accept Unauthorized SSL: ✅
- Heartbeat: `120 seconds`
- ✅ Enable all notifications

#### 🟡 Priority 2: Application Services (Check every 300 seconds)

**Supabase Studio**
- Monitor Type: **HTTP**
- URL: `http://192.168.1.20:3000`
- Heartbeat: `300 seconds`

**n8n Automation**
- Monitor Type: **HTTP**
- URL: `http://192.168.1.20:5678`
- Heartbeat: `300 seconds`

**Immich Photos**
- Monitor Type: **HTTP**
- URL: `http://192.168.1.9:2283`
- Heartbeat: `300 seconds`

---

### 3. Configure Notifications

**Settings → Notifications → Add New**

#### Recommended: Discord
1. Create webhook in Discord server
2. Select: **Discord**
3. Paste webhook URL
4. Test notification
5. Apply to all critical monitors

#### Alternative: Email, Telegram, Slack
See Uptime Kuma documentation for setup

---

### 4. Optional: Create Status Page

**Settings → Status Pages → Add**
- Name: "Infrastructure Status"
- Select monitors to display
- Public URL: `http://192.168.1.9:3010/status/infra-status`

---

## That's It!

Uptime Kuma will now:
- ✅ Monitor all critical services
- ✅ Send alerts on failures
- ✅ Track uptime statistics
- ✅ Provide visual dashboard

No additional scripts needed - everything in one place!

---

## Monitor Summary

| What | Type | URL/IP | Why Critical |
|------|------|--------|--------------|
| Pi-hole DNS | DNS | 192.168.1.5:53 | Network-wide DNS failure if down |
| OPNsense | HTTPS | 192.168.1.3 | No internet if down |
| Proxmox | HTTPS | 192.168.1.10:8006 | All VMs/LXC down if host fails |
| Supabase | HTTP | 192.168.1.20:3000 | Dev platform down |
| n8n | HTTP | 192.168.1.20:5678 | Automation stops |
| Immich | HTTP | 192.168.1.9:2283 | Photo service down |

---

**Created:** 2025-10-17
**Next Step:** Configure monitors in web UI
