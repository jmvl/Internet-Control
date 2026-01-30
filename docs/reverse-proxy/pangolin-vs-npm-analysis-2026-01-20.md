# Pangolin vs Nginx Proxy Manager: Comparative Analysis and Deployment Guide

**Date**: January 20, 2026
**Document Version**: 1.0
**Author**: Infrastructure Analysis

## Executive Summary

This document provides a comprehensive analysis of **Pangolin** as an alternative to **Nginx Proxy Manager (NPM)** for the internet-control infrastructure, specifically addressing the Docker-in-LXC networking instability encountered during the NPM migration to pve2 PCT 121.

**Key Finding**: Pangolin is **fundamentally different** from NPM. While NPM is a traditional HTTP/HTTPS reverse proxy, Pangolin is a **tunneled reverse proxy** using WireGuard for secure connections. These solutions serve different use cases and can actually complement each other rather than replace one another.

### Recommendation Summary

| Deployment Option | Suitability | Rationale |
|-------------------|-------------|-----------|
| **Replace NPM with Pangolin** | Not Recommended | Pangolin lacks traditional reverse proxy features (custom locations, advanced routing, TCP/UDP proxy) |
| **Pangolin + NPM (Complementary)** | Recommended | Use Pangolin for remote access tunneling, NPM for local HTTP/SSL termination |
| **Migrate NPM to VM** | Recommended | Solves Docker-in-LXC networking issues without feature loss |

---

## Table of Contents

1. [Architecture Comparison](#architecture-comparison)
2. [Feature Comparison Matrix](#feature-comparison-matrix)
3. [Docker-in-LXC Compatibility Analysis](#docker-in-lxc-compatibility-analysis)
4. [Deployment Options for Proxmox](#deployment-options-for-proxmox)
5. [Step-by-Step Deployment Guides](#step-by-step-deployment-guides)
6. [Cost-Benefit Analysis](#cost-benefit-analysis)

---

## Architecture Comparison

### Nginx Proxy Manager (Traditional Reverse Proxy)

```
Internet → OPNsense (80/443) → NPM Container → Backend Services
              ↓                    ↓
         NAT Rules           SSL Termination
                             Access Lists
                             Custom Routing
```

**Characteristics**:
- **Protocol**: HTTP/HTTPS
- **SSL/TLS**: Let's Encrypt automation with ACME
- **Access Control**: Basic auth, IP allowlists
- **Routing**: Host-based, path-based, custom locations
- **Port Requirements**: 80 (HTTP), 443 (HTTPS), 81 (Management UI)

### Pangolin (Tunneled Reverse Proxy)

```
Remote Client → Pangolin Dashboard (Authentication)
                     ↓
             WireGuard Tunnel (Gerbil :51820/udp)
                     ↓
              Newt Client (Site Connector)
                     ↓
              Backend Services (Local Network)
```

**Characteristics**:
- **Protocol**: WireGuard tunnels with HTTP/HTTPS inside
- **SSL/TLS**: Built-in Let's Encrypt via Traefik
- **Access Control**: Identity-aware (SSO, OIDC, PIN, Geolocation, IP, Temporary links)
- **Routing**: Tunnel-based routing to sites
- **Port Requirements**: 80/443 (Dashboard), 51820/udp (WireGuard)

**Critical Difference**: Pangolin does NOT require open ports on your firewall for backend services. Traffic flows through encrypted tunnels.

---

## Feature Comparison Matrix

| Feature | Nginx Proxy Manager | Pangolin | Notes |
|---------|-------------------|----------|-------|
| **Primary Purpose** | HTTP/HTTPS Reverse Proxy | Tunneled Reverse Proxy | Different architectural approaches |
| **SSL/TLS Automation** | Let's Encrypt (ACME) | Let's Encrypt (Traefik) | Both support automated SSL |
| **Authentication** | Basic Auth, Access Lists | SSO, OIDC, PIN, Password, Geo, IP | Pangolin has superior auth |
| **Custom Routing** | Custom Locations, Path Rewrites | Host-based routing only | NPM more flexible for complex routing |
| **TCP/UDP Proxy** | Yes (Stream functionality) | Raw TCP/UDP via tunnels | Different implementations |
| **WebSocket Support** | Yes | Yes (via Traefik) | Both support WebSockets |
| **Access Control** | IP allowlists, Basic Auth | Identity-aware, context-aware | Pangolin significantly more advanced |
| **No-Open-Ports** | No (requires 80/443) | Yes (tunneling) | Pangolin's key advantage |
| **CGNAT Compatible** | No | Yes | Pangolin works behind CGNAT |
| **Zero-Trust Security** | Limited | Built-in | Pangolin designed for zero-trust |
| **Dashboard UI** | Yes (Port 81) | Yes (Default subdomain) | Both have web UIs |
| **Migration Complexity** | Baseline | High | Different paradigms |
| **Docker-Based** | Yes | Yes | Both containerized |
| **WireGuard Built-in** | No | Yes | Pangolin includes WireGuard |

---

## Docker-in-LXC Compatibility Analysis

### Critical Finding: Pangolin Has WORSE Docker-in-LXC Compatibility

Based on the official Docker Compose configuration from [Pangolin Docs](https://docs.pangolin.net/self-host/manual/docker-compose):

```yaml
gerbil:
  image: fosrl/gerbil:latest
  cap_add:
    - NET_ADMIN    # Requires network administration capabilities
    - SYS_MODULE   # Requires kernel module loading
  ports:
    - 51820:51820/udp  # WireGuard port
```

**Compatibility Issues**:

| Requirement | LXC Support | Impact |
|-------------|-------------|--------|
| `NET_ADMIN` capability | Partial | May work with LXC features enabled |
| `SYS_MODULE` capability | **Not Supported** | Kernel modules cannot be loaded in LXC containers |
| WireGuard kernel module | **Not Supported** | LXC containers share the host kernel; module loading is restricted |
| `network_mode: service:gerbil` | **Problematic** | Advanced Docker networking mode known to fail in Docker-in-LXC |

**Assessment**: Pangolin would experience **more severe** Docker-in-LXC issues than NPM due to:

1. **WireGuard dependency**: Requires kernel module (`SYS_MODULE` capability unavailable in LXC)
2. **Advanced networking**: Uses `network_mode: service:gerbil` which is more complex than NPM's port bindings
3. **CAP_SYS_MODULE**: Not available in LXC containers by design

**Reference**: The NPM migration documentation (`/docs/npm/npm-migration-to-pve2-2026-01-20.md`) already documented Docker-in-LXC port forwarding failures. Pangolin would suffer from these PLUS the WireGuard kernel module limitation.

---

## Deployment Options for Proxmox

### Option 1: Replace NPM with Pangolin (NOT RECOMMENDED)

**Pros**:
- Eliminates NPM entirely
- Advanced identity-aware access control
- No open ports needed (except Pangolin dashboard)

**Cons**:
- **Feature Loss**:
  - No custom location routing (e.g., `/api/` → different backend)
  - No advanced Nginx directives
  - Limited to host-based routing
- **Migration Complexity**: All 41 proxy hosts would need complete reconfiguration
- **Backend Access**: Services on the same network as NPM would need Newt client installed
- **SSL Certificates**: Cannot reuse existing NPM certificates
- **Learning Curve**: New paradigm (tunneling vs traditional proxy)

**Verdict**: Not recommended for production use where existing NPM configuration works well.

### Option 2: Pangolin + NPM (COMPLEMENTARY - RECOMMENDED)

**Architecture**:
```
Internet → Pangolin (Tunnel/Identity) → NPM (HTTP/SSL) → Backend Services
                                      ↓
                                 Local Network Services
```

**Use Case Distribution**:
- **Pangolin**: Remote access from outside networks, mobile users, temporary access links
- **NPM**: Local network services, complex routing, custom Nginx configurations

**Pros**:
- Best of both worlds
- Gradual migration possible
- NPM handles complex routing
- Pangolin handles remote access and identity

**Cons**:
- Two systems to maintain
- Increased complexity
- Higher resource usage

**Verdict**: Recommended for users needing both remote tunneling and advanced reverse proxy features.

### Option 3: Migrate NPM to VM (RECOMMENDED FOR STABILITY)

**Reference**: See `/docs/npm/npm-migration-to-pve2-2026-01-20.md` - "Alternative Deployment Options Research" section (lines 552-853).

**Key Actions**:
1. Create Proxmox VM with dedicated Docker environment
2. Migrate NPM data and configuration
3. Eliminates Docker-in-LXC networking issues

**Pros**:
- Solves the root cause of current issues
- No feature loss
- Isolated environment
- Full Docker networking capabilities

**Cons**:
- Higher resource usage than LXC
- Requires VM setup (documented in migration guide)

**Verdict**: Best option for resolving Docker-in-LXC instability without feature loss.

### Option 4: Pangolin in VM (NEW DEPLOYMENT)

**Deployment**:
- Create dedicated VM for Pangolin
- Use Docker Compose configuration from official docs
- Configure WireGuard tunnel endpoint

**Pros**:
- Full kernel module support (WireGuard)
- No Docker-in-LXC limitations
- Isolated environment

**Cons**:
- Additional infrastructure to maintain
- Higher resource usage
- Does not replace NPM feature set

**Verdict**: Only recommended if remote tunneling and zero-trust access are required.

---

## Step-by-Step Deployment Guides

### Guide A: Migrate NPM to VM (Solves Current Issues)

**Reference**: `/docs/npm/npm-migration-to-pve2-2026-01-20.md` lines 552-853

**Quick Summary**:
1. Create VM on pve2 with Debian 12 template
2. Install Docker and Docker Compose
3. Copy NPM data volumes from PCT 121
4. Update OPNsense firewall/NAT rules to point to VM IP
5. Test all 41 proxy hosts

**Resource Requirements**:
- 2 vCPU
- 2GB RAM
- 20GB disk

### Guide B: Deploy Pangolin in VM (New Remote Access)

**Prerequisites**:
- Domain name with A record pointing to pve2 public IP
- VM with Docker installed (recommended: separate from NPM)

**Steps**:

1. **Create VM on pve2**:
   ```bash
   qm create 122 \
     --name pangolin \
     --memory 2048 \
     --cores 2 \
     --net0 virtio,bridge=vmbr0 \
     --ostype l26 \
     --scsihw virtio-scsi-pci
   ```

2. **Prepare Directory Structure** (on the VM):
   ```bash
   mkdir -p /opt/pangolin/config/{db,letsencrypt,logs,traefik}
   cd /opt/pangolin
   ```

3. **Create docker-compose.yml**:
   ```yaml
   services:
     pangolin:
       image: fosrl/pangolin:latest
       container_name: pangolin
       restart: unless-stopped
       volumes:
         - ./config:/app/config
       healthcheck:
         test: ["CMD", "curl", "-f", "http://localhost:3001/api/v1/"]
         interval: "3s"
         timeout: "3s"
         retries: 15

     gerbil:
       image: fosrl/gerbil:latest
       container_name: gerbil
       restart: unless-stopped
       depends_on:
         pangolin:
           condition: service_healthy
       command:
         - --reachableAt=http://gerbil:3004
         - --generateAndSaveKeyTo=/var/config/key
         - --remoteConfig=http://pangolin:3001/api/v1/
       volumes:
         - ./config/:/var/config
       cap_add:
         - NET_ADMIN
         - SYS_MODULE
       ports:
         - 51820:51820/udp
         - 21820:21820/udp
         - 443:443
         - 80:80

     traefik:
       image: traefik:v3.4.0
       container_name: traefik
       restart: unless-stopped
       network_mode: service:gerbil
       depends_on:
         pangolin:
           condition: service_healthy
       command:
         - --configFile=/etc/traefik/traefik_config.yml
       volumes:
         - ./config/traefik:/etc/traefik:ro
         - ./config/letsencrypt:/letsencrypt
         - ./config/traefik/logs:/var/log/traefik

   networks:
     default:
       driver: bridge
       name: pangolin
   ```

4. **Configure Traefik** (`config/traefik/traefik_config.yml`):
   ```yaml
   api:
     insecure: true
     dashboard: true

   providers:
     http:
       endpoint: "http://pangolin:3001/api/v1/traefik-config"
       pollInterval: "5s"
     file:
       filename: "/etc/traefik/dynamic_config.yml"

   experimental:
     plugins:
       badger:
         moduleName: "github.com/fosrl/badger"
         version: "v1.2.0"

   log:
     level: "INFO"

   certificatesResolvers:
     letsencrypt:
       acme:
         httpChallenge:
           entryPoint: web
         email: your-email@example.com  # REPLACE
         storage: "/letsencrypt/acme.json"
         caServer: "https://acme-v02.api.letsencrypt.org/directory"

   entryPoints:
     web:
       address: ":80"
     websecure:
       address: ":443"
       http:
         tls:
           certResolver: "letsencrypt"
   ```

5. **Configure OPNsense Firewall**:
   - Allow UDP 51820 from WAN to Pangolin VM IP
   - Allow TCP 80/443 to Pangolin VM IP

6. **Start Pangolin**:
   ```bash
   docker compose up -d
   ```

7. **Access Dashboard**: Navigate to `https://pangolin.home.accelior.com` (or your configured domain)

### Guide C: Deploy Pangolin + NPM (Complementary Architecture)

**Architecture**:
- PCT 121: NPM (existing)
- New VM: Pangolin
- OPNsense: Port forwarding for both

**Configuration**:
- NPM: Handles local network services on ports 80/443/81
- Pangolin: Handles remote tunnel access on different ports or separate IP

**Resource Requirements**: Combined 4 vCPU, 4GB RAM

---

## Cost-Benefit Analysis

### Migrating NPM to VM vs Deploying Pangolin

| Factor | NPM to VM | Deploy Pangolin | Combined |
|--------|-----------|-----------------|----------|
| **Implementation Effort** | Medium (6-8 hours) | High (12-16 hours) | High (20+ hours) |
| **Learning Curve** | Low (same software) | High (new paradigm) | Very High |
| **Feature Loss** | None | Partial (NPM features) | None |
| **New Capabilities** | Stability | Remote tunneling, zero-trust | Both |
| **Resource Usage** | +1 VM | +1 VM | +1 VM |
| **Maintenance** | Same as current | New software to learn | Two systems |
| **Problem Solved** | Docker-in-LXC issues | Remote access needs | Both |
| **Risk Level** | Low | Medium | Medium |

### Recommendation Priority

1. **Short Term** (Immediate): Migrate NPM to VM to resolve Docker-in-LXC instability
2. **Medium Term** (If remote access needed): Deploy Pangolin in separate VM
3. **Long Term**: Evaluate if NPM features can be replaced by Pangolin (unlikely given complexity)

---

## Conclusion

### Key Takeaways

1. **Pangolin ≠ NPM Replacement**: These are fundamentally different tools serving different use cases
2. **Docker-in-LXC Issues**: Pangolin has WORSE LXC compatibility than NPM due to WireGuard kernel requirements
3. **Best Path Forward**: Migrate NPM to VM for stability, evaluate Pangolin for remote access separately

### Final Recommendation

**For your current infrastructure**:

1. **Immediate Action**: Follow the VM migration guide in `/docs/npm/npm-migration-to-pve2-2026-01-20.md` to move NPM from PCT 121 to a VM. This solves the port forwarding instability.

2. **Evaluate Pangolin**: If you need remote access from outside your network without opening ports, deploy Pangolin in a separate VM. Use it for:
   - Remote administration while traveling
   - Temporary access links for guests
   - Zero-trust access control for sensitive services

3. **Don't Replace NPM**: The 41 proxy hosts you have configured rely on NPM features that Pangolin doesn't support (custom routing, advanced Nginx directives, etc.).

### Next Steps

- [ ] Decide: Migrate NPM to VM first, or evaluate Pangolin needs?
- [ ] If migrating to VM: Follow guide in `/docs/npm/npm-migration-to-pve2-2026-01-20.md`
- [ ] If deploying Pangolin: Follow Guide B in this document
- [ ] Update infrastructure database after any changes

---

## References

### Documentation Sources
1. [Pangolin Official Docs - Docker Compose](https://docs.pangolin.net/self-host/manual/docker-compose)
2. [Pangolin GitHub Repository](https://github.com/fosrl/pangolin)
3. [PiMyLifeUp - Pangolin Tutorial](https://pimylifeup.com/pangolin-linux/)
4. [NPM Migration Documentation](/Users/jm/Codebase/internet-control/docs/npm/npm-migration-to-pve2-2026-01-20.md)

### Key Technical Specifications
- **Pangolin Stack**: Pangolin + Gerbil (WireGuard) + Traefik
- **Port Requirements**: 80 (HTTP), 443 (HTTPS), 51820/udp (WireGuard)
- **Required Capabilities**: NET_ADMIN, SYS_MODULE (not available in LXC)
- **Database**: SQLite for configuration
- **SSL**: Let's Encrypt via Traefik ACME

---

*Document End*
