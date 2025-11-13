# Domain Name Mapping for Uptime Kuma Monitors

**Date:** 2025-10-17
**Purpose:** Document which services use domain names vs IP addresses in monitoring
**Managed By:** Nginx Proxy Manager

---

## Overview

Services exposed through Nginx Proxy Manager should be monitored using their **domain names** instead of internal IP addresses. This ensures:

1. **Correct endpoint monitoring** - Avoids confusion when multiple instances exist (e.g., GitLab A vs GitLab B during migration)
2. **DNS resolution testing** - Verifies that DNS and reverse proxy are working correctly
3. **End-to-end validation** - Tests the complete request path including SSL termination
4. **Migration resilience** - Domain names remain stable even when backend IPs change

---

## Domain Name Mappings

### accelior.com Domain (Primary Services)

| Service | Domain Name | Internal IP | Port | Protocol |
|---------|-------------|-------------|------|----------|
| **Confluence** | confluence.accelior.com | 192.168.1.21 | 8090 | HTTPS |
| **JIRA** | jira.accelior.com | 192.168.1.22 | 8080 | HTTPS |
| **GitLab** | gitlab.accelior.com | 192.168.1.35 | 80/443 | HTTPS |
| **Seafile** | files.accelior.com | 192.168.1.25 | 80 | HTTPS |
| **n8n** | n8n.accelior.com | 192.168.1.20 | 5678 | HTTPS |
| **Mail Server** | mail.accelior.com | 192.168.1.30 | 443 | HTTPS |

### acmea.tech Domain (Secondary Services)

| Service | Domain Name | Internal IP | Port | Protocol |
|---------|-------------|-------------|------|----------|
| **Netdata** | netdata.acmea.tech | 192.168.1.20 | 19999 | HTTPS |
| **Calibre** | books.acmea.tech | 192.168.1.9 | 8082 | HTTPS |
| **Wanderwish** | wanderwish.acmea.tech | External | - | HTTPS |

---

## Services Monitored by IP Address

These services are **not** proxied through Nginx Proxy Manager and should be monitored directly:

### Critical Infrastructure
- **Pi-hole DNS**: `192.168.1.5:53` (DNS query check)
- **OPNsense Firewall**: `192.168.1.3:8443` (Direct HTTPS)
- **Proxmox Host**: `192.168.1.10:8006` (Direct HTTPS)

### Docker Hosts
- **pct111**: `192.168.1.20` (PING check)
- **OMV Storage**: `192.168.1.9` (PING check)

### Internal Services (No Reverse Proxy)
- **Supabase PostgreSQL**: `192.168.1.20:5432` (TCP port check)
- **Supabase Realtime**: `192.168.1.20:4000` (HTTP, known unhealthy)
- **Immich Photos**: `192.168.1.9:2283` (HTTP, internal only)
- **Nginx Proxy Manager**: `192.168.1.9:81` (HTTPS, admin interface)
- **Mail Server SMTP**: `192.168.1.30:25` (TCP port check)
- **Uptime Kuma**: `192.168.1.9:3010` (HTTP, internal only)
- **Portainer**: `192.168.1.20:9443` (HTTPS, internal only)
- **Syncthing**: `192.168.1.9:8384` (HTTP, internal only)

---

## Monitoring Strategy Rationale

### Use Domain Names When:
✅ Service is exposed externally via Nginx Proxy Manager
✅ SSL termination happens at reverse proxy
✅ Service has a public-facing URL
✅ Multiple instances might exist (migration scenarios)

**Examples:**
- Confluence, JIRA, GitLab, Seafile, n8n, Mail
- Netdata, Calibre, Wanderwish

### Use IP Addresses When:
✅ Service is infrastructure-critical (DNS, Firewall, Proxmox)
✅ Service is internal-only with no reverse proxy
✅ Direct port checks are needed (PostgreSQL, SMTP)
✅ Admin interfaces not meant for external access

**Examples:**
- Pi-hole, OPNsense, Proxmox
- Supabase PostgreSQL, Immich, Portainer
- Nginx Proxy Manager admin UI

---

## Migration Example: GitLab A → GitLab B

**Problem:** During migration from old GitLab (192.168.1.35) to new GitLab instance:
- Two GitLab servers existed simultaneously
- IP-based monitoring would track the wrong instance
- Confusion about which server was "production"

**Solution:** Use domain name `gitlab.accelior.com`:
- Nginx Proxy Manager points to active instance
- Monitoring automatically follows DNS updates
- No Uptime Kuma configuration changes needed during cutover
- Clear separation between production (domain) and migration (IP)

---

## Setup Script Configuration

The `setup-uptime-kuma.py` script has been updated to use domain names for all proxied services:

```python
# ✅ CORRECT: Use domain name for proxied service
api.add_monitor(
    type=MonitorType.HTTP,
    name="🟢 GitLab",
    url="https://gitlab.accelior.com",  # Domain name
    ...
)

# ❌ WRONG: Don't use IP for proxied service
api.add_monitor(
    type=MonitorType.HTTP,
    name="🟢 GitLab",
    url="http://192.168.1.35",  # IP address - may be wrong instance!
    ...
)
```

---

## Nginx Proxy Manager Configuration

All domain names listed above are configured in Nginx Proxy Manager at:
- **Admin UI:** `https://192.168.1.9:81`
- **Proxy Hosts:** Settings → Proxy Hosts

Each proxy host entry includes:
- Domain name (e.g., `gitlab.accelior.com`)
- Target scheme (http/https)
- Forward hostname/IP (internal IP)
- Forward port (internal port)
- SSL certificate (Let's Encrypt or custom)

---

## DNS Configuration

**External DNS (Cloudflare or similar):**
- `*.accelior.com` → Public IP → Nginx Proxy Manager
- `*.acmea.tech` → Public IP → Nginx Proxy Manager

**Internal DNS (Pi-hole):**
- Local DNS records for internal resolution
- Custom DNS entries for `*.accelior.com` and `*.acmea.tech`
- Points to Nginx Proxy Manager: `192.168.1.9`

---

## Verification

To verify domain name resolution and proxying:

```bash
# Test external domain resolution
dig +short gitlab.accelior.com

# Test HTTPS endpoint (should return 200)
curl -I https://gitlab.accelior.com

# Verify SSL certificate
openssl s_client -connect gitlab.accelior.com:443 -servername gitlab.accelior.com
```

---

## Related Documentation

- **Setup Script:** `/infrastructure-db/monitoring/setup-uptime-kuma.py`
- **Monitoring Strategy:** `/infrastructure-db/monitoring/MONITOR-STRATEGY.md`
- **Nginx Proxy Manager:** Configured at `https://192.168.1.9:81`
- **Infrastructure Overview:** `/infrastructure-db/INFRASTRUCTURE-OVERVIEW.md`

---

**Created:** 2025-10-17
**Last Updated:** 2025-10-17
**Maintained By:** Infrastructure Team
