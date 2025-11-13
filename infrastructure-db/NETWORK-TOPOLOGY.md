# Infrastructure Network Topology

**Generated:** 2025-10-17
**Source:** Infrastructure Database (automated discovery)

## Overview

Complete network topology including physical hosts, Docker container networks, and service mappings discovered from live infrastructure.

---

## Main Network: 192.168.1.0/24

### Physical Infrastructure
| Hostname | IP Address | Type | Purpose |
|----------|------------|------|---------|
| openwrt | 192.168.1.2 | Physical | Wireless AP & Gateway |
| opnsense | 192.168.1.3 | VM | Firewall, DHCP, Traffic Shaper |
| pihole | 192.168.1.5 | Physical | DNS Filtering & Ad Blocking |
| omv | 192.168.1.9 | Physical | Network Attached Storage |
| pve2 | 192.168.1.10 | Physical | Proxmox Virtualization Host |

### Docker Hosts
| Hostname | IP Address | Type | Purpose |
|----------|------------|------|---------|
| docker-debian (pct111) | 192.168.1.20 | LXC | Primary Docker Host (Supabase, n8n) |
| omv | 192.168.1.9 | Physical | Secondary Docker Host (Immich, Media) |

### Service Containers (LXC)
| Hostname | IP Address | Purpose |
|----------|------------|---------|
| ConfluenceDocker20220712 | 192.168.1.21 | Confluence Wiki |
| jira.accelior.com | 192.168.1.22 | JIRA Issue Tracking |
| files.accelior.com | 192.168.1.25 | Seafile File Server |
| ansible-mgmt | 192.168.1.26 | Ansible Automation |
| wanderwish | 192.168.1.29 | Web Application |
| mail.vega-messenger.com | 192.168.1.30 | Mail Server |
| CT502 | 192.168.1.33 | General Purpose |
| gitlab.accelior.com | 192.168.1.35 | GitLab CE Server |

---

## Docker Networks: 192.168.1.20 (Primary Docker Host)

### Bridge Networks (Internal Container Communication)
| Network Name | Subnet | Gateway | Purpose |
|--------------|--------|---------|---------|
| bridge (default) | 172.17.0.0/16 | 172.17.0.1 | Default Docker bridge |
| **supabase_default** | **172.18.0.0/16** | **172.18.0.1** | **Supabase Stack** |
| n8n_default | 172.19.0.0/16 | 172.19.0.1 | n8n Automation |
| portainer_agent_default | 172.20.0.0/16 | 172.20.0.1 | Portainer Management |
| bluecherry_net | 172.21.0.0/16 | 172.21.0.1 | Bluecherry DVR |
| couchdb_couchdb_network | 172.22.0.0/16 | 172.22.0.1 | CouchDB Database |
| perplexica_perplexica-network | 172.23.0.0/16 | 172.23.0.1 | Perplexica AI Search |
| casino-brussels-db_casino-network | 172.24.0.0/16 | 172.24.0.1 | Casino Brussels DB |
| netdata_monitoring | 172.25.0.0/16 | 172.25.0.1 | Netdata Monitoring |
| shinobidocker_default | 172.26.0.0/16 | 172.26.0.1 | Shinobi NVR |

### Macvlan Network (Physical Network Integration)
| Network Name | Subnet | Gateway | Purpose |
|--------------|--------|---------|---------|
| **pihole_macvlan** | **192.168.1.0/24** | **192.168.1.3** | **Pi-hole container with physical IP** |

**Note:** The pihole_macvlan network allows containers to get IPs directly on the main 192.168.1.0/24 network, appearing as physical devices.

---

## Docker Networks: 192.168.1.9 (Secondary Docker Host - OMV)

### Bridge Networks (Internal Container Communication)
| Network Name | Subnet | Gateway | Purpose |
|--------------|--------|---------|---------|
| bridge (default) | 172.17.0.0/16 | 172.17.0.1 | Default Docker bridge |
| **immich_default** | **172.18.0.0/16** | **172.18.0.1** | **Immich Photo Stack** |
| nginx-proxy-manager_default | 172.19.0.0/16 | 172.19.0.1 | Nginx Proxy Manager |
| syncthing_default | 172.20.0.0/16 | 172.20.0.1 | Syncthing Sync |
| uptime-kuma_default | 172.21.0.0/16 | 172.21.0.1 | Uptime Kuma Monitoring |
| wallabag_default | 172.22.0.0/16 | 172.22.0.1 | Wallabag Read-it-later |
| calibre_default | 172.23.0.0/16 | 172.23.0.1 | Calibre E-books |
| 32_default | 172.24.0.0/16 | 172.24.0.1 | Unknown service |

---

## Key Services by IP & Port

### 192.168.1.20 (docker-debian / pct111)
| Service | Port | Network | Status |
|---------|------|---------|--------|
| Supabase Studio | 3000 | supabase_default | Healthy |
| Supabase Kong Gateway | 8000 | supabase_default | Healthy |
| Supabase Auth API | 9999 | supabase_default | Healthy |
| Supabase Storage API | 5000 | supabase_default | Healthy |
| Supabase REST API | 3000 | supabase_default | Healthy |
| n8n Automation | 5678 | n8n_default | Healthy |
| Portainer | 9443 | portainer_agent_default | Healthy |

### 192.168.1.9 (OMV)
| Service | Port | Network | Status |
|---------|------|---------|--------|
| Immich Photos | 2283 | immich_default | Healthy |
| Nginx Proxy Manager | 81 | nginx-proxy-manager_default | Healthy |
| Uptime Kuma | 3010 | uptime-kuma_default | Healthy |
| Calibre | 8082 | calibre_default | Healthy |
| Syncthing | 8384 | syncthing_default | Healthy |

---

## Network Topology Diagram

```
Internet
    │
    ├─ OpenWrt (192.168.1.2) ────────────── Layer 1: Wireless QoS
    │       │
    │       └─ OPNsense (192.168.1.3) ──── Layer 2: Firewall & Traffic Shaping
    │               │
    │               └─ Pi-hole (192.168.1.5) ── Layer 3: DNS Filtering
    │                       │
    │                       └─ LAN (192.168.1.0/24)
    │                               │
    ├───────────────────────────────┼─ Physical Hosts
    │                               ├─ pve2 (192.168.1.10) - Proxmox
    │                               ├─ omv (192.168.1.9) - Storage + Docker
    │                               │
    ├───────────────────────────────┼─ LXC Containers
    │                               ├─ docker-debian (192.168.1.20) - Primary Docker
    │                               ├─ Confluence (192.168.1.21)
    │                               ├─ JIRA (192.168.1.22)
    │                               ├─ Seafile (192.168.1.25)
    │                               ├─ Ansible (192.168.1.26)
    │                               ├─ WanderWish (192.168.1.29)
    │                               ├─ Mail (192.168.1.30)
    │                               ├─ CT502 (192.168.1.33)
    │                               └─ GitLab (192.168.1.35)
    │
    └─ Docker Networks (Isolated)
            ├─ 192.168.1.20: 11 bridge networks (172.17-26.0.0/16)
            │   ├─ Supabase Stack (172.18.0.0/16)
            │   ├─ n8n (172.19.0.0/16)
            │   ├─ Portainer (172.20.0.0/16)
            │   └─ ... (8 more networks)
            │
            └─ 192.168.1.9: 8 bridge networks (172.17-24.0.0/16)
                ├─ Immich Stack (172.18.0.0/16)
                ├─ Nginx Proxy Manager (172.19.0.0/16)
                └─ ... (6 more networks)
```

---

## IP Address Space Summary

| Network Range | Usage | Count |
|---------------|-------|-------|
| 192.168.1.0/24 | Main LAN | 14 IPs allocated |
| 172.17.0.0/16 | Docker default bridge (both hosts) | 2 networks |
| 172.18.0.0/16 | Supabase (pct111), Immich (OMV) | 2 networks |
| 172.19-26.0.0/16 | Docker app networks | 17 networks |

**Total Networks Discovered:**
- 1 Physical LAN (192.168.1.0/24)
- 23 Docker bridge/macvlan networks
- 19 Docker networks with allocated subnets

---

## Discovery Notes

- **Data Source:** Live discovery via SSH to Docker hosts (192.168.1.20, 192.168.1.9)
- **Discovery Date:** 2025-10-17
- **Method:** `docker network inspect` via paramiko SSH client
- **Database:** SQLite infrastructure.db with automated change tracking

### Key Findings:
1. **Subnet Overlap:** Both hosts use 172.17.0.0/16 for default bridge (isolated, no conflict)
2. **Macvlan Network:** pihole_macvlan allows containers to join physical network
3. **Service Isolation:** Each Docker Compose stack gets its own bridge network
4. **Gateway Pattern:** All Docker bridge networks use .0.1 as gateway

---

## Next Steps

1. ✅ Docker network discovery complete
2. ⏳ Add container-to-network mappings
3. ⏳ Discover Docker volumes and mount points
4. ⏳ Map service dependencies across networks
5. ⏳ Implement network monitoring and alerting

---

**Maintained by:** Infrastructure Database System
**Last Updated:** 2025-10-17
**Automation:** Run `python discovery/test_docker_discovery.py` to refresh
