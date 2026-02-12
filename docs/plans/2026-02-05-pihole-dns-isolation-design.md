# Pi-hole DNS Isolation Design

**Date**: 2026-02-05
**Author**: Claude Code
**Status**: Approved for Implementation

## Executive Summary

Migrate Pi-hole DNS from Docker container (CT 111) to dedicated LXC container (CT 112) to eliminate single point of failure. When the Docker host reboots, DNS remains available, preventing network-wide outages.

## Problem Statement

### Current Architecture Issue

```
CT 111: docker-debian (192.168.1.20)
└── Docker Daemon
    ├── Pi-hole DNS (192.168.1.5) ← CRITICAL INFRASTRUCTURE
    ├── n8n, Supabase, databases
    └── 40+ application containers
```

**Impact**: When CT 111 reboots (as occurred on 2026-02-05 ~10:48 CET):
- All 44 containers stop simultaneously
- Pi-hole DNS goes down → entire network loses DNS resolution
- ~8 minutes of downtime while containers restart
- Network appears "down" because DNS fails

### Root Cause

Critical infrastructure (DNS) is bundled with application services in a monolithic Docker host. When the host fails, everything fails together.

## Proposed Solution

### New Architecture

```
┌──────────────────────────┐    ┌─────────────────────────────────┐
│ NEW CT 112: pihole-dns   │    │ CT 111: docker-debian (192.168.1.20)│
│ (192.168.1.5)            │    │ ┌───────────────────────────────┐ │
│ ┌────────────────────┐   │    │ │ Docker Daemon                 │ │
│ │ Pi-hole Native     │   │    │ │ ├── n8n, Supabase, databases  │ │
│ │ (No Docker)        │   │    │ │ └── 40+ application containers│ │
│ │ - Independent DNS  │   │    │ └───────────────────────────────┘ │
│ │ - Auto-restart     │   │    │         ↑ App failure = DNS OK    │
│ └────────────────────┘   │    └─────────────────────────────────┘
│     ↑ DNS isolated        │
└──────────────────────────┘
```

### Key Improvements

| Aspect | Before | After |
|--------|--------|-------|
| DNS Isolation | Shared with apps | Dedicated LXC |
| Docker Dependency | Required | None (native install) |
| Failure Domain | 44 containers affected | Only apps affected |
| Recovery Time | ~8 minutes (all containers) | ~30 seconds (systemd) |
| Resource Usage | Shared (12 cores) | Dedicated (1 core) |

## Implementation Plan

### Phase 1: Container Creation

**Create LXC Container CT 112 on pve2:**
```bash
pct create 112 local:vztmpl/debian-12-standard_12.5-1_amd64.tar.zst \
  --hostname pihole-dns \
  --cores 1 \
  --memory 512 \
  --swap 512 \
  --storage ssd-4tb:8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.5/24,gw=192.168.1.3 \
  --onboot 1 \
  --startup 1 \
  --unprivileged 0
```

**Configuration:**
- Hostname: `pihole-dns`
- IP Address: `192.168.1.5` (migrated from Docker)
- Resources: 1 CPU core, 512MB RAM, 8GB disk
- Purpose: Dedicated DNS server only
- Auto-start: Enabled (Proxmox boot order)

### Phase 2: Pi-hole Installation

Install Pi-hole natively (no Docker) inside CT 112:
```bash
pct exec 112 -- bash -c "$(curl -sSL https://install.pi-hole.net)"
```

**Configuration:**
- Upstream DNS: 1.1.1.1, 8.8.8.8
- Interface: eth0
- IPv4: Yes
- IPv6: No
- Web admin: Yes (port 80)

### Phase 3: Configuration Migration

| Configuration | Source | Destination | Method |
|---------------|--------|-------------|--------|
| Whitelist | Docker Pi-hole | New LXC Pi-hole | Export/import |
| Blocklists | StevenBlack + custom | Re-subscribe | Gravity update |
| Local DNS | Custom records | Manual recreation | Via web UI |

**Whitelist Export/Import:**
```bash
# From Docker Pi-hole
docker exec pihole pihole -w -l > /tmp/whitelist.txt

# Import to new Pi-hole
while read domain; do
  pihole -w "$domain"
done < /tmp/whitelist.txt
```

### Phase 4: Parallel Cutover Timeline

```
T-0    T+2h     T+24h    T+48h    T+72h        Final
│      │        │        │        │            │
▼      ▼        ▼        ▼        ▼            ▼
NEW    TEST     SWITCH   MONITOR  DEPRECATE    CLEANUP
LXC    BOTH     DHCP     STABLE   DOCKER      OLD CONTAINER
```

| Time | Action | Validation |
|------|--------|------------|
| T-0 | Create CT 112, install Pi-hole | Container starts, web UI accessible |
| T+2h | Migrate whitelist, configure blocklists | Test queries to 192.168.1.5 resolve |
| T+24h | Update OPNsense DHCP → primary DNS: 192.168.1.5 | Clients get new DNS via DHCP |
| T+48h | Monitor DNS queries, verify no blocks | Query logs show normal traffic |
| T+72h | Stop Docker Pi-hole container | DNS still works |
| T+96h | Remove Docker Pi-hole container | Cleanup complete |

### Phase 5: Rollback Plan

If issues occur, rollback is instant:
```bash
# Revert OPNsense DHCP to Docker Pi-hole
# Take Proxmox snapshot before DHCP switch
pct snapshot 112 pre-cutover --description "Before DHCP switch"
```

## Success Criteria

- [ ] CT 112 created and running Pi-hole natively
- [ ] Whitelist migrated (z.ai domains included)
- [ ] Blocklists configured and gravity updated
- [ ] OPNsense DHCP pointing to new Pi-hole
- [ ] DNS queries resolving correctly
- [ ] Docker Pi-hole container stopped
- [ ] DNS remains functional during Docker host reboot

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Configuration migration incomplete | Medium | Medium | Parallel testing before cutover |
| DNS resolution breaks | Low | High | Instant rollback via OPNsense |
| IP address conflict | Low | High | Stop Docker Pi-hole first |
| Performance degradation | Low | Low | Dedicated resources (1 core) |

## Post-Implementation

1. Update infrastructure database with new host configuration
2. Update documentation (`/docs/infrastructure.md`)
3. Monitor DNS resolution for 1 week
4. Document lessons learned

## References

- Infrastructure documentation: `/docs/infrastructure.md`
- Infrastructure database: `/infrastructure-db/infrastructure.db`
- Incident that triggered this: Docker host reboot 2026-02-05 ~10:48 CET
