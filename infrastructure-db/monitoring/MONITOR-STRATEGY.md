# Uptime Kuma Comprehensive Monitoring Strategy

**Created:** 2025-10-17
**Total Monitors:** 21
**Coverage:** Complete infrastructure across 6 criticality tiers
**Alert Integration:** Discord, Email, SMS (configurable)

---

## 📊 Executive Summary

This monitoring strategy provides **complete visibility** across the entire infrastructure with **tiered alerting** based on service criticality and impact.

### Monitor Distribution

| Tier | Priority | Check Interval | Count | Purpose |
|------|----------|----------------|-------|---------|
| 🔴 Tier 1 | CRITICAL | 60 seconds | 3 | Single points of failure |
| 🟡 Tier 2 | HIGH | 120 seconds | 2 | Container platforms |
| 🟠 Tier 3 | MEDIUM | 300 seconds | 5 | Core services |
| ⚠️  Tier 4 | HEALTH | 300 seconds | 2 | Resource monitoring |
| 🟢 Tier 5 | LOW | 600 seconds | 5 | Collaboration tools |
| 📊 Tier 6 | META | 300-600 seconds | 4 | System monitoring |

**Total Monitoring Points:** 21
**Total Services Covered:** 50+ (including container dependencies)

---

## 🔴 TIER 1: CRITICAL INFRASTRUCTURE (60-second checks)

### Why 60-Second Intervals?
These are **single points of failure** that bring down the entire network. Fast detection (1 minute) enables immediate response before cascading failures occur.

### 1. Pi-hole DNS (192.168.1.5:53)
**Monitor Type:** DNS Query
**Check:** `dig @192.168.1.5 google.com`
**Criticality:** CRITICAL

**Why Critical:**
- Single point of failure for network DNS
- ALL 50 services depend on DNS resolution
- Network-wide internet failure if down

**Impact if Down:**
- ❌ DNS resolution fails for all 31 Docker containers
- ❌ No external API access (all domains fail)
- ❌ Email server cannot resolve MX records
- ❌ GitLab CI/CD pipelines fail
- ❌ Web browsing stops for all clients

**Alert:** Immediate (Discord + Email + SMS)
**Documented Failure:** `/docs/troubleshooting/pihole-failure-impact-analysis.md`

---

### 2. OPNsense Firewall (https://192.168.1.3:8443)
**Monitor Type:** HTTP(S)
**Check:** HTTPS health endpoint
**Criticality:** CRITICAL

**Why Critical:**
- Network gateway and firewall
- DHCP server for entire LAN
- Traffic shaping for QoS
- Layer 2 of three-tier traffic control

**Impact if Down:**
- ❌ No internet access (gateway failure)
- ❌ DHCP assignments stop
- ❌ New devices cannot join network
- ❌ Traffic shaping disabled
- ⚠️  Internal network continues (static IPs)

**Alert:** Immediate (Discord + Email + SMS)

---

### 3. Proxmox pve2 Host (https://192.168.1.10:8006)
**Monitor Type:** HTTP(S)
**Check:** Web UI availability
**Criticality:** CRITICAL

**Why Critical:**
- Hosts ALL virtual infrastructure
- 11 LXC containers depend on it
- 1 VM (OPNsense) depends on it
- Dual-NIC hardware isolation

**Impact if Down:**
- ❌ ALL 11 LXC containers offline
  - Confluence, JIRA, GitLab
  - Seafile, Mail Server
  - pct111 (27 Docker containers)
- ❌ OPNsense VM offline (network failure)
- ❌ Complete infrastructure outage

**Alert:** Immediate (Discord + Email + SMS)

---

## 🟡 TIER 2: CRITICAL DOCKER HOSTS (120-second checks)

### Why 120-Second Intervals?
Docker hosts are critical platforms but have more resilience than network infrastructure. 2-minute checks balance detection speed with load.

### 4. Docker Host pct111 (192.168.1.20)
**Monitor Type:** PING
**Check:** ICMP ping response
**Criticality:** HIGH

**Why Important:**
- Hosts 27 Docker containers
- Primary development platform
- Supabase full stack (9 containers)
- n8n automation platform

**Impact if Down:**
- ❌ Supabase database offline
- ❌ Supabase Studio (dev UI) unavailable
- ❌ n8n workflows stop
- ❌ 27 containers affected
  - Development APIs fail
  - Portainer management down
  - Netdata monitoring down

**Alert:** High Priority (Discord + Email within 5 min)

---

### 5. Docker Host OMV (192.168.1.9)
**Monitor Type:** PING
**Check:** ICMP ping response
**Criticality:** HIGH

**Why Important:**
- Hosts 14 Docker containers
- 21.7TB storage server
- Immich photo platform
- Media & monitoring services

**Current Issues:**
- ⚠️  **CRITICAL:** Swap at 99.99% utilization
- ⚠️  RAM: Only 7.4GB with 15+ containers
- ⚠️  Needs immediate intervention

**Impact if Down:**
- ❌ Immich photos unavailable
- ❌ File storage inaccessible
- ❌ Uptime Kuma monitoring down
- ❌ Nginx Proxy Manager offline
- ❌ 14 containers affected

**Alert:** High Priority (Discord + Email within 5 min)
**Related:** `/docs/troubleshooting/swap-memory-high-utilization-2025-10-17.md`

---

## 🟠 TIER 3: CORE SERVICES (300-second checks)

### Why 300-Second Intervals?
Application services have redundancy and graceful degradation. 5-minute checks provide adequate coverage without excessive load.

### 6. Supabase Kong Gateway (http://192.168.1.20:8000)
**Monitor Type:** HTTP
**Check:** HTTP health endpoint
**Criticality:** MEDIUM

**Why Important:**
- API gateway for all Supabase services
- Routes requests to Auth, Storage, REST APIs
- Critical for development workflows

**Impact if Down:**
- ❌ All Supabase API calls fail
- ❌ Authentication unavailable
- ⚠️  Database still accessible locally

---

### 7. Supabase PostgreSQL (192.168.1.20:5432)
**Monitor Type:** TCP Port
**Check:** Port 5432 connectivity
**Criticality:** MEDIUM

**Why Important:**
- Primary database for development
- Powers all Supabase-dependent apps
- Data persistence layer

---

### 8. n8n Automation (http://192.168.1.20:5678)
**Monitor Type:** HTTP
**Check:** Web UI availability
**Criticality:** MEDIUM

**Why Important:**
- Workflow automation platform
- Integration hub for services
- Background job processing

**Impact if Down:**
- ❌ Automated workflows stop
- ❌ API integrations pause
- ⚠️  Manual operations continue

---

### 9. Immich Photos (http://192.168.1.9:2283)
**Monitor Type:** HTTP
**Check:** Web UI availability
**Criticality:** MEDIUM

**Why Important:**
- AI-powered photo management
- Machine learning features
- Family photo backup

**Impact if Down:**
- ❌ Photo uploads unavailable
- ❌ ML features offline
- ⚠️  Existing photos remain on disk

---

### 10. Nginx Proxy Manager (https://192.168.1.9:81)
**Monitor Type:** HTTP(S)
**Check:** Admin UI availability
**Criticality:** MEDIUM

**Why Important:**
- Reverse proxy for external access
- SSL certificate management
- Entry point for public services

**Impact if Down:**
- ❌ External service access broken
- ❌ Cannot manage proxy rules
- ⚠️  Internal services continue

---

## ⚠️  TIER 4: RESOURCE & HEALTH MONITORING (300-second checks)

### 11. Netdata Monitoring (https://netdata.acmea.tech)
**Monitor Type:** HTTP(S)
**Check:** Dashboard availability
**Criticality:** MEDIUM

**Why Important:**
- Meta-monitoring system
- Real-time resource metrics
- Currently alerting on swap issues

**Current Status:**
- 🔴 **CRITICAL ALERT:** OMV swap at 99.99%
- 🟡 **WARNING:** pve2 swap at 94%

**Impact if Down:**
- ❌ No real-time metrics
- ❌ Resource alerts stop
- ⚠️  Systems continue operating

---

### 12. Supabase Realtime (http://192.168.1.20:4000)
**Monitor Type:** HTTP
**Check:** WebSocket endpoint
**Criticality:** MEDIUM

**Current Status:** ⚠️  **KNOWN UNHEALTHY**

**Why Monitor:**
- Track known issue
- Alert if status changes
- Prepare for fix deployment

**Impact:**
- ❌ Real-time subscriptions unavailable
- ⚠️  REST APIs continue working

---

## 🟢 TIER 5: COLLABORATION SERVICES (600-second checks)

### Why 600-Second Intervals?
Collaboration tools have natural human response times. 10-minute checks are sufficient for business applications.

### 13. Confluence Wiki (http://192.168.1.21)
**Monitor Type:** HTTP
**Impact:** Team documentation unavailable

### 14. JIRA (http://192.168.1.22)
**Monitor Type:** HTTP
**Impact:** Issue tracking unavailable

### 15. GitLab (http://192.168.1.35)
**Monitor Type:** HTTP
**Impact:** Git + CI/CD unavailable

### 16. Seafile (http://192.168.1.25)
**Monitor Type:** HTTP
**Impact:** File sharing unavailable

### 17. Mail Server (192.168.1.30:25)
**Monitor Type:** TCP Port (SMTP)
**Impact:** Email delivery broken

---

## 📊 TIER 6: META-MONITORING (300-600 seconds)

### 18. Uptime Kuma Self-Check (http://192.168.1.9:3010)
**Monitor Type:** HTTP
**Why:** Ensure monitoring system itself is operational

### 19. Portainer (https://192.168.1.20:9443)
**Monitor Type:** HTTP(S)
**Why:** Docker management UI availability

### 20. Calibre E-books (http://192.168.1.9:8082)
**Monitor Type:** HTTP
**Why:** Library management availability

### 21. Syncthing (http://192.168.1.9:8384)
**Monitor Type:** HTTP
**Why:** File synchronization service

---

## 🚨 ALERT ESCALATION POLICY

### Immediate Response (< 5 minutes)
**Triggers:** Tier 1 failures
**Channels:** Discord + Email + SMS
**Who:** On-call engineer

**Monitors:**
- Pi-hole DNS
- OPNsense Firewall
- Proxmox pve2

---

### High Priority (< 30 minutes)
**Triggers:** Tier 2 failures
**Channels:** Discord + Email
**Who:** DevOps team

**Monitors:**
- Docker Host pct111
- Docker Host OMV

---

### Medium Priority (< 2 hours)
**Triggers:** Tier 3 failures
**Channels:** Discord notification
**Who:** Development team

**Monitors:**
- Supabase stack
- n8n, Immich, Nginx PM

---

### Low Priority (< 24 hours)
**Triggers:** Tier 4-6 failures
**Channels:** Discord summary
**Who:** Operations team

**Monitors:**
- Collaboration tools
- Meta-monitoring
- Resource alerts

---

## 📈 MONITORING METRICS

### Coverage Statistics

| Category | Total Services | Monitored | Coverage % |
|----------|----------------|-----------|------------|
| Critical Infrastructure | 3 | 3 | 100% |
| Docker Platforms | 2 | 2 | 100% |
| Core Services | 10 | 5 | 50% |
| Collaboration | 5 | 5 | 100% |
| Meta-Monitoring | 4 | 4 | 100% |
| **TOTAL** | **24** | **21** | **87.5%** |

### Check Frequency Analysis

- **Every Minute:** 3 monitors (Critical infrastructure)
- **Every 2 Minutes:** 2 monitors (Docker hosts)
- **Every 5 Minutes:** 12 monitors (Services + Health)
- **Every 10 Minutes:** 4 monitors (Collaboration + Meta)

**Total Checks Per Hour:**
- Tier 1: 180 checks/hour
- Tier 2: 60 checks/hour
- Tier 3-4: 144 checks/hour
- Tier 5-6: 54 checks/hour
- **Total:** 438 checks/hour

---

## 🔧 NEXT STEPS

### Immediate (This Week)
1. ✅ Deploy all 21 monitors via automated script
2. ⏳ Configure Discord webhook for alerts
3. ⏳ Test alert notifications for each tier
4. ⏳ Address OMV swap memory crisis (99.99%)

### Short-Term (This Month)
1. ⏳ Add custom script monitors for swap/disk
2. ⏳ Implement SSL certificate expiration monitoring
3. ⏳ Add backup status monitoring
4. ⏳ Create runbook for each alert type

### Long-Term (This Quarter)
1. ⏳ Deploy secondary Pi-hole for redundancy
2. ⏳ Implement auto-remediation scripts
3. ⏳ Build Grafana dashboard integration
4. ⏳ Add performance trend analysis

---

## 📚 RELATED DOCUMENTATION

- **Setup Script:** `/infrastructure-db/monitoring/setup-uptime-kuma.py`
- **Credentials:** `/infrastructure-db/monitoring/.uptime-kuma-credentials`
- **Pi-hole Analysis:** `/docs/troubleshooting/pihole-failure-impact-analysis.md`
- **Swap Crisis:** `/docs/troubleshooting/swap-memory-high-utilization-2025-10-17.md`
- **Infrastructure Overview:** `/infrastructure-db/INFRASTRUCTURE-OVERVIEW.md`

---

**Status:** Ready for deployment
**Last Updated:** 2025-10-17
**Maintained By:** Infrastructure Team
