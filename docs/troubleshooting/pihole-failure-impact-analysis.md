# Pi-hole Failure Impact Analysis

**Generated:** 2025-10-17
**Host:** pihole (192.168.1.5)
**Role:** Layer 3 DNS Filtering & Ad Blocking
**Criticality:** CRITICAL

---

## Executive Summary

If Pi-hole (192.168.1.5) goes down, **DNS resolution will fail for the entire network** unless clients have fallback DNS configured. This is a **CRITICAL** failure that impacts all internet connectivity.

### Severity: 🔴 CRITICAL

**Impact Classification:**
- **Immediate Impact:** DNS resolution failure network-wide
- **Affected Services:** ALL network clients
- **Fallback Available:** YES (OPNsense has secondary DNS)
- **Recovery Time:** Minutes (manual intervention required)
- **Business Continuity:** DISRUPTED

---

## Network Position

Pi-hole sits at **Layer 3** of the three-tier traffic control system:

```
Internet
    ↓
[Layer 1] OpenWrt (192.168.1.2) ✅ Still operational
    ↓
[Layer 2] OPNsense (192.168.1.3) ✅ Still operational
    ↓
[Layer 3] Pi-hole (192.168.1.5) ❌ DOWN
    ↓
Internal Network ⚠️ DNS BROKEN
```

---

## Direct Impact

### Primary Service Failure

**Pi-hole DNS (192.168.1.5)**
- **Service Type:** DNS Server
- **Criticality:** CRITICAL
- **Purpose:** DNS filtering and ad blocking
- **Status if down:** ❌ DNS queries fail

**Pi-hole Admin Interface**
- **Service Type:** Web UI
- **Criticality:** HIGH
- **Endpoint:** http://192.168.1.5/admin
- **Status if down:** ❌ No management interface

---

## Cascading Failures

### Services with Hard Dependencies on Pi-hole

Based on the infrastructure database, the following services have **HARD** dependencies on Pi-hole DNS:

#### 1. OPNsense DHCP (192.168.1.3)
- **Criticality:** CRITICAL
- **Dependency Type:** HARD
- **Impact:** DHCP clients won't get Pi-hole as their DNS server
- **Mitigation:** OPNsense can still provide DHCP with fallback DNS

#### 2. Seafile File Server (192.168.1.25)
- **Criticality:** HIGH
- **Dependency Type:** HARD
- **Impact:** May not resolve external domains or internal names
- **Mitigation:** Manual DNS configuration or hosts file

---

## Network-Wide Impact

### What Breaks

❌ **DNS Resolution Fails:**
- All clients configured with Pi-hole as primary DNS (192.168.1.5) will fail to resolve domain names
- Web browsing stops (domains can't be resolved)
- Email clients can't connect (unless using IP addresses)
- App APIs fail (can't resolve api.example.com)

❌ **No Ad Blocking:**
- Even if fallback DNS works, ad blocking is lost
- Tracking protection disabled
- Malware domain blocking disabled

❌ **Loss of DNS-based Metrics:**
- No query logging
- No statistics on blocked domains
- No visibility into DNS traffic

### What Still Works

✅ **Internal Network Communication:**
- Hosts with static IPs can still communicate via IP
- Local services accessible by IP (e.g., http://192.168.1.9:2283)

✅ **Firewall & DHCP:**
- OPNsense continues to provide firewall protection
- DHCP still assigns IP addresses (with fallback DNS)

✅ **Internet Access (if fallback DNS configured):**
- Clients with secondary DNS configured (e.g., 1.1.1.1, 8.8.8.8) will failover
- OPNsense can provide fallback DNS to DHCP clients

---

## Affected Infrastructure

### By Category

| Category | Total | Affected | Still Functional |
|----------|-------|----------|------------------|
| **Physical Hosts** | 4 | 4 (DNS loss) | 4 (local IPs) |
| **LXC Containers** | 10 | 10 (DNS loss) | 10 (local IPs) |
| **Docker Containers** | 31 | 31 (DNS loss) | 31 (local IPs) |
| **Services** | 50 | 50 (DNS loss) | ~20 (IP-only) |

### Critical Services Most Affected

Services that rely heavily on external DNS lookups:

1. **Supabase Stack** (192.168.1.20)
   - External API calls will fail
   - Authentication providers may be unreachable
   - Edge functions can't resolve external URLs

2. **n8n Automation** (192.168.1.20:5678)
   - Workflows calling external APIs will fail
   - Webhook endpoints may be unreachable

3. **Immich Photos** (192.168.1.9:2283)
   - External ML model downloads fail
   - Reverse geocoding fails (location lookups)

4. **Email Server** (192.168.1.30)
   - Cannot resolve MX records
   - Email delivery completely broken
   - Incoming mail fails

5. **GitLab** (192.168.1.35)
   - Cannot clone from external repos
   - CI/CD pipelines fail (can't download dependencies)
   - Container registry pulls fail

---

## Mitigation Strategies

### Immediate Actions (Recovery)

**Option 1: Restore Pi-hole Service**
```bash
# SSH to Pi-hole host
ssh admin@192.168.1.5

# Check Pi-hole service status
sudo systemctl status pihole-FTL

# Restart Pi-hole if crashed
sudo systemctl restart pihole-FTL

# Or reboot host
sudo reboot
```

**Option 2: Emergency DNS Fallback**
```bash
# On OPNsense: Configure fallback DNS
# System → Settings → General → DNS Servers
# Add: 1.1.1.1, 8.8.8.8 as fallback

# Update DHCP to provide fallback DNS
# Services → DHCPv4 → LAN
# DNS Servers: 192.168.1.5, 1.1.1.1, 8.8.8.8
```

**Option 3: Emergency Client Configuration**
```bash
# Manually set DNS on critical systems
# Linux:
echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf

# Windows:
# Network Settings → Adapter → Properties → TCP/IPv4
# DNS: 1.1.1.1, 8.8.8.8
```

### Preventive Measures

**1. Configure DNS Fallback in OPNsense**
- **Primary DNS:** 192.168.1.5 (Pi-hole)
- **Secondary DNS:** 1.1.1.1 (Cloudflare)
- **Tertiary DNS:** 8.8.8.8 (Google)

This ensures automatic failover if Pi-hole is unreachable.

**2. Implement Pi-hole High Availability**
```bash
# Option A: Secondary Pi-hole instance
# Install Pi-hole on another host (e.g., 192.168.1.6)
# Sync gravity database between instances
# Configure DHCP with both: 192.168.1.5, 192.168.1.6

# Option B: Pi-hole in Docker with restart policy
# Move Pi-hole to Docker with "restart: unless-stopped"
# Ensures automatic recovery from crashes
```

**3. Monitoring & Alerting**
```bash
# Monitor Pi-hole availability
# Use Uptime Kuma (192.168.1.9:3010) to monitor:
# - HTTP: http://192.168.1.5/admin
# - DNS: dig @192.168.1.5 google.com

# Set up alerts via:
# - Email
# - Discord/Slack webhook
# - SMS (if critical)
```

**4. Health Check in Infrastructure DB**
```bash
# Add automated health check
cd /Users/jm/Codebase/internet-control/infrastructure-db

# Create health check script
cat > check_pihole.sh << 'SCRIPT'
#!/bin/bash
PIHOLE_IP="192.168.1.5"
if dig @$PIHOLE_IP google.com +time=2 +tries=1 > /dev/null 2>&1; then
    echo "Pi-hole DNS: HEALTHY"
    sqlite3 infrastructure.db "INSERT INTO health_checks (service_id, status, response_time_ms) VALUES ((SELECT id FROM services WHERE service_name = 'Pi-hole DNS'), 'healthy', 50);"
else
    echo "Pi-hole DNS: DOWN"
    sqlite3 infrastructure.db "INSERT INTO health_checks (service_id, status, error_message) VALUES ((SELECT id FROM services WHERE service_name = 'Pi-hole DNS'), 'unhealthy', 'DNS query timeout');"
    # Send alert here
fi
SCRIPT

chmod +x check_pihole.sh

# Add to crontab (check every minute)
# */1 * * * * /path/to/check_pihole.sh
```

---

## Recovery Procedures

### Standard Recovery (5-10 minutes)

1. **Verify failure:**
   ```bash
   # Test DNS from any client
   nslookup google.com 192.168.1.5
   # If timeout: Pi-hole is down
   ```

2. **Check Pi-hole host status:**
   ```bash
   ping 192.168.1.5
   # If unreachable: Host is down (hardware issue)
   # If reachable: Service issue
   ```

3. **If host is reachable (service issue):**
   ```bash
   ssh admin@192.168.1.5
   sudo systemctl status pihole-FTL
   sudo systemctl restart pihole-FTL

   # Check logs
   sudo tail -f /var/log/pihole/pihole-FTL.log
   ```

4. **If host is unreachable (hardware issue):**
   - Check physical host power/network
   - Check Proxmox if it's a VM
   - Consider emergency fallback DNS

5. **Verify recovery:**
   ```bash
   # Test DNS resolution
   nslookup google.com 192.168.1.5

   # Check Pi-hole admin
   curl http://192.168.1.5/admin

   # Verify ad blocking
   nslookup ads.google.com 192.168.1.5
   # Should return 0.0.0.0 if blocking works
   ```

### Emergency Bypass (1-2 minutes)

If Pi-hole cannot be recovered quickly:

1. **Update OPNsense DHCP:**
   - Login to OPNsense: https://192.168.1.3
   - Services → DHCPv4 → LAN
   - Change DNS from `192.168.1.5` to `1.1.1.1`
   - Save & Apply

2. **Force DHCP renewal on clients:**
   ```bash
   # Linux/Mac
   sudo dhclient -r && sudo dhclient

   # Windows
   ipconfig /release
   ipconfig /renew
   ```

3. **Update critical servers manually:**
   ```bash
   # Supabase host (192.168.1.20)
   ssh root@192.168.1.20
   echo "nameserver 1.1.1.1" > /etc/resolv.conf

   # OMV host (192.168.1.9)
   ssh root@192.168.1.9
   echo "nameserver 1.1.1.1" > /etc/resolv.conf
   ```

---

## Testing Recovery

### Simulate Pi-hole Failure

```bash
# CAUTION: This will break DNS network-wide

# Option 1: Stop Pi-hole service
ssh admin@192.168.1.5
sudo systemctl stop pihole-FTL

# Option 2: Block Pi-hole traffic (safer - can quickly undo)
# On OPNsense, create temporary firewall rule:
# Block: Source=Any, Dest=192.168.1.5, Port=53

# Test impact
nslookup google.com 192.168.1.5  # Should fail

# Verify fallback works (if configured)
nslookup google.com  # Should use secondary DNS

# Restore
ssh admin@192.168.1.5
sudo systemctl start pihole-FTL
```

---

## Lessons Learned

### Current Vulnerabilities

❌ **Single Point of Failure:** Only one Pi-hole instance
❌ **No Automatic Failover:** Requires manual intervention
❌ **Limited Monitoring:** No automated health checks
❌ **No Redundancy:** DNS completely fails if Pi-hole is down

### Recommended Architecture

✅ **Dual Pi-hole Setup:**
```
Primary Pi-hole: 192.168.1.5
Secondary Pi-hole: 192.168.1.6 (NEW)
DHCP provides both in order
```

✅ **OPNsense as Tertiary DNS:**
```
OPNsense configured with external DNS (1.1.1.1)
Acts as last resort DNS server
```

✅ **Automated Monitoring:**
```
Uptime Kuma monitoring both Pi-hole instances
Alert on failure via Discord/Email
Health checks stored in infrastructure DB
```

---

## Related Documentation

- **Main Infrastructure:** `/docs/infrastructure.md`
- **Network Topology:** `/infrastructure-db/NETWORK-TOPOLOGY.md`
- **Quick Recovery:** `/QUICK-START.md`
- **OPNsense Config:** `/docs/OPNsense/README.md`

---

## Summary

**If Pi-hole (192.168.1.5) fails:**

| Impact | Severity | Workaround |
|--------|----------|------------|
| DNS resolution fails network-wide | 🔴 CRITICAL | Configure fallback DNS in OPNsense |
| No ad blocking | 🟡 MEDIUM | Acceptable during outage |
| 50 services lose DNS | 🔴 CRITICAL | Services using IPs still work |
| Email server breaks | 🔴 CRITICAL | No workaround without DNS |
| External API calls fail | 🔴 CRITICAL | Apps using IPs unaffected |

**Recommended Actions:**
1. ✅ Configure OPNsense DHCP with fallback DNS (1.1.1.1, 8.8.8.8)
2. ⏳ Deploy secondary Pi-hole instance
3. ⏳ Implement automated monitoring
4. ⏳ Test failover procedures quarterly

**Current Status:** SINGLE POINT OF FAILURE - HIGH RISK

---

**Last Updated:** 2025-10-17
**Reviewed By:** Infrastructure Database Analysis
**Next Review:** After implementing redundancy
