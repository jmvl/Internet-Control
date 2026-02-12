# Pi-hole DNS Isolation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate Pi-hole DNS from Docker container to dedicated LXC container to eliminate single point of failure and prevent network-wide outages during Docker host reboots.

**Architecture:** Create new Proxmox LXC container (CT 112) with native Pi-hole installation (no Docker). Migrate configuration (whitelist, blocklists) via parallel cutover. Update OPNsense DHCP to point to new Pi-hole. Decommission Docker Pi-hole after validation.

**Tech Stack:** Proxmox VE, LXC containers, Pi-hole (native install), OPNsense firewall, SQLite infrastructure database

---

## Prerequisites

**Access Required:**
- SSH to pve2 (192.168.1.10) - Proxmox host
- SSH to CT 111 (192.168.1.20) - Current Docker host
- OPNsense web UI (https://192.168.1.3) - DHCP configuration

**Templates/Downloads:**
- Debian 12 LXC template: `local:vztmpl/debian-12-standard_12.5-1_amd64.tar.zst`

**Documentation References:**
- Infrastructure docs: `/docs/infrastructure.md`
- Design doc: `/docs/plans/2026-02-05-pihole-dns-isolation-design.md`
- Infrastructure DB: `/infrastructure-db/infrastructure.db`

---

## Task 1: Verify Prerequisites and Current State

**Files:**
- Reference: `/docs/infrastructure.md`
- Query: `sqlite3 /infrastructure-db/infrastructure.db`

**Step 1: Verify Proxmox host connectivity**

```bash
# From local machine
ssh root@192.168.1.10 "pveversion"
```

Expected: `pve-manager/8.x.x`

**Step 2: Check available LXC template**

```bash
ssh root@192.168.1.10 "pveam available | grep debian-12-standard"
```

Expected: Debian 12 template listed

If not downloaded:
```bash
ssh root@192.168.1.10 "pveam download local debian-12-standard_12.5-1_amd64.tar.zst"
```

**Step 3: Verify IP address 192.168.1.5 is available**

```bash
ssh root@192.168.1.10 "ping -c 1 192.168.1.5"
```

Expected: Pi-hole Docker container responds (will be migrated)

**Step 4: Check current Pi-hole whitelist size**

```bash
ssh root@192.168.1.20 "docker exec pihole pihole -w -l | wc -l"
```

Expected: Number of whitelisted domains (for validation later)

**Step 5: No commit (read-only verification)**

Document current state:
```
- Proxmox version: [version]
- Template available: yes/no
- 192.168.1.5 currently: Docker Pi-hole
- Whitelist count: [number]
```

---

## Task 2: Create LXC Container CT 112

**Files:**
- Create: Proxmox CT 112 container on pve2
- Modify: None (new container)

**Step 1: Create the LXC container**

```bash
ssh root@192.168.1.10 "pct create 112 local:vztmpl/debian-12-standard_12.5-1_amd64.tar.zst \
  --hostname pihole-dns \
  --cores 1 \
  --memory 512 \
  --swap 512 \
  --storage ssd-4tb:8 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.5/24,gw=192.168.1.3 \
  --onboot 1 \
  --startup 1 \
  --unprivileged 0 \
  --rootfs ssd-4tb:8"
```

Expected: `CT 112 created successfully`

**Step 2: Verify container was created**

```bash
ssh root@192.168.1.10 "pct config 112"
```

Expected: Shows hostname, cores, memory, network config

**Step 3: Start the container**

```bash
ssh root@192.168.1.10 "pct start 112"
```

Expected: No error

**Step 4: Verify container is running**

```bash
ssh root@192.168.1.10 "pct status 112"
```

Expected: `Status: running`

**Step 5: Test network connectivity from container**

```bash
ssh root@192.168.1.10 "pct exec 112 -- ping -c 2 192.168.1.3"
```

Expected: Ping to OPNsense gateway succeeds

**Step 6: Commit (infrastructure change)**

```bash
# Update infrastructure database
sqlite3 /infrastructure-db/infrastructure.db <<EOF
INSERT INTO hosts (hostname, host_type, management_ip, status, cpu_cores, total_ram_mb, parent_host_id, vmid, purpose, criticality)
VALUES ('pihole-dns', 'lxc', '192.168.1.5', 'active', 1, 512, 1, 112, 'Dedicated DNS server', 'critical');
EOF

git add infrastructure-db/infrastructure.db
git commit -m "feat: add CT 112 pihole-dns LXC container"
```

---

## Task 3: Install Pi-hole Natively in CT 112

**Files:**
- Modify: CT 112 container filesystem (install Pi-hole)
- Create: Pi-hole configuration

**Step 1: Update container packages**

```bash
ssh root@192.168.1.10 "pct exec 112 -- bash -c 'apt update && apt upgrade -y'"
```

Expected: Packages updated, no errors

**Step 2: Install curl for Pi-hole installer**

```bash
ssh root@192.168.1.10 "pct exec 112 -- apt install -y curl"
```

Expected: curl installed

**Step 3: Run Pi-hole installer (non-interactive)**

Create install script on pve2:
```bash
ssh root@192.168.1.10 "cat > /tmp/pihole-install.sh <<'EOFSCRIPT'
#!/bin/bash
# Non-interactive Pi-hole installation
export PIHOLE_SKIP_INSTALL=true

# Download installer
curl -sSL https://install.pi-hole.net -o /tmp/pihole-install.sh

# Run with environment variables for non-interactive install
export PIHOLE_INTERFACE=eth0
export PIHOLE_DNS_1=1.1.1.1
export PIHOLE_DNS_2=8.8.8.8
export PIHOLE_IPV4=true
export PIHOLE_IPV6=false

bash /tmp/pihole-install.sh --unattended
EOFSCRIPT"

chmod +x /tmp/pihole-install.sh
```

Expected: Script created

**Step 4: Execute installation**

```bash
ssh root@192.168.1.10 "pct exec 112 -- bash /tmp/pihole-install.sh"
```

Expected: Pi-hole installs, may take 2-3 minutes

**Step 5: Verify Pi-hole is running**

```bash
ssh root@192.168.1.10 "pct exec 112 -- systemctl status pihole-FTL"
```

Expected: Service is active (running)

**Step 6: Get Pi-hole admin password**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -a -p"
```

Expected: Displays admin password

**Step 7: Test DNS resolution from container**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -a -i"
```

Expected: Shows admin interface URL (http://192.168.1.5/admin)

**Step 8: Commit**

```bash
# Update infrastructure database - add Pi-hole service
sqlite3 /infrastructure-db/infrastructure.db <<EOF
INSERT INTO services (service_name, service_type, host_id, protocol, port, endpoint_url, health_check_url, status, criticality, description)
VALUES ('Pi-hole DNS (LXC)', 'dns', (SELECT id FROM hosts WHERE hostname='pihole-dns'), 'UDP', 53, 'http://192.168.1.5/admin', 'http://192.168.1.5/admin/api.php', 'healthy', 'critical', 'Native Pi-hole installation in LXC container');
EOF

git add infrastructure-db/infrastructure.db
git commit -m "feat: install Pi-hole natively in CT 112"
```

---

## Task 4: Export Whitelist from Docker Pi-hole

**Files:**
- Read: Docker Pi-hole whitelist
- Create: `/tmp/whitelist.txt` on local machine

**Step 1: Export whitelist from Docker Pi-hole**

```bash
ssh root@192.168.1.20 "docker exec pihole pihole -w -l" > /tmp/whitelist.txt
```

Expected: File created with whitelist entries

**Step 2: Verify whitelist was exported**

```bash
wc -l /tmp/whitelist.txt
head -5 /tmp/whitelist.txt
```

Expected: Shows domain list, including z.ai entries

**Step 3: Create import script**

```bash
cat > /tmp/import-whitelist.sh <<'EOF'
#!/bin/bash
# Import whitelist to new Pi-hole
while read -r domain; do
  # Skip empty lines and comments
  [[ -z "$domain" || "$domain" =~ ^# ]] && continue
  echo "Adding: $domain"
  ssh root@192.168.1.10 "pct exec 112 -- pihole -w $domain"
done < /tmp/whitelist.txt
EOF

chmod +x /tmp/import-whitelist.sh
```

Expected: Script created

**Step 4: No commit (preparation for next task)**

---

## Task 5: Import Whitelist to New Pi-hole

**Files:**
- Read: `/tmp/whitelist.txt`
- Modify: CT 112 Pi-hole configuration

**Step 1: Execute whitelist import**

```bash
/tmp/import-whitelist.sh
```

Expected: Domains added one by one

**Step 2: Verify whitelist was imported**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -w -l | grep -i 'z.ai'"
```

Expected: z.ai, chat.z.ai, api.z.ai in whitelist

**Step 3: Verify whitelist count matches**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -w -l | wc -l"
```

Expected: Count matches or exceeds Docker Pi-hole

**Step 4: Test DNS resolution for whitelisted domain**

```bash
ssh root@192.168.1.10 "pct exec 112 -- dig @127.0.0.1 chat.z.ai +short"
```

Expected: Returns IP address (not blocked)

**Step 5: Commit**

```bash
git add /tmp/whitelist.txt /tmp/import-whitelist.sh
git commit -m "feat: migrate Pi-hole whitelist to CT 112"
```

---

## Task 6: Configure Blocklists on New Pi-hole

**Files:**
- Modify: CT 112 Pi-hole blocklist configuration

**Step 1: Get StevenBlack blocklist URL**

```bash
# From Docker Pi-hole config
ssh root@192.168.1.20 "docker exec pihole pihole -a -l" | grep -i stevenblack
```

Expected: `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`

**Step 2: Add StevenBlack blocklist to new Pi-hole**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -a adlist.add 'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts'"
```

Expected: Blocklist added

**Step 3: Verify blocklist was added**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -a adlist.list"
```

Expected: StevenBlack list shown

**Step 4: Update gravity (refresh blocklists)**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -g"
```

Expected: Gravity updates, may take 1-2 minutes

**Step 5: Verify gravity updated**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -a -t"
```

Expected: Shows gravity database info with recent timestamp

**Step 6: Commit**

```bash
git add infrastructure-db/infrastructure.db
git commit -m "feat: configure blocklists on CT 112 Pi-hole"
```

---

## Task 7: Test DNS Resolution on New Pi-hole

**Files:**
- Test: CT 112 DNS functionality

**Step 1: Test basic DNS resolution**

```bash
ssh root@192.168.1.10 "pct exec 112 -- dig @127.0.0.1 google.com +short"
```

Expected: Returns Google IP addresses

**Step 2: Test whitelisted domain resolution**

```bash
ssh root@192.168.1.10 "pct exec 112 -- dig @127.0.0.1 chat.z.ai +short"
```

Expected: Returns chat.z.ai IP address (not blocked)

**Step 3: Test blocked domain resolution**

```bash
ssh root@192.168.1.10 "pct exec 112 -- dig @127.0.0.1 doubleclick.net +short"
```

Expected: Returns 0.0.0.0 or NXDOMAIN (blocked)

**Step 4: Test from external client**

```bash
# From local machine
dig @192.168.1.5 google.com +short
```

Expected: Returns Google IP addresses

**Step 5: Verify query logging is working**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -a -q"
```

Expected: Shows recent queries

**Step 6: No commit (testing only)**

Document test results:
```
- Basic DNS: PASS/FAIL
- Whitelisted domain: PASS/FAIL
- Blocked domain: PASS/FAIL
- External query: PASS/FAIL
- Query logging: PASS/FAIL
```

---

## Task 8: Create Pre-Cutover Snapshot

**Files:**
- Create: Proxmox snapshot of CT 112

**Step 1: Create snapshot before DHCP cutover**

```bash
ssh root@192.168.1.10 "pct snapshot 112 pre-cutover --description 'Before DHCP switch - working Pi-hole config'"
```

Expected: Snapshot created

**Step 2: Verify snapshot exists**

```bash
ssh root@192.168.1.10 "pct snapshot 112 list"
```

Expected: `pre-cutover` snapshot listed

**Step 3: No commit (preparation for rollback)**

---

## Task 9: Update OPNsense DHCP Configuration

**Files:**
- Modify: OPNsense DHCP configuration via web UI or API

**Step 1: Access OPNsense web UI**

Navigate to: https://192.168.1.3

Login with OPNsense credentials

**Step 2: Navigate to DHCP settings**

Go to: Services → DHCPv4 → LAN

**Step 3: Update DNS servers**

Current configuration:
- Primary DNS: 192.168.1.5 (Docker Pi-hole)
- Secondary DNS: 1.1.1.1

New configuration:
- Primary DNS: 192.168.1.5 (New LXC Pi-hole - same IP!)
- Secondary DNS: 1.1.1.1

Note: IP address is the same, so no change needed if CT 112 uses 192.168.1.5

**Step 4: Stop Docker Pi-hole container to test**

```bash
ssh root@192.168.1.20 "docker stop pihole"
```

Expected: Docker Pi-hole stops

**Step 5: Test DNS resolution from client**

```bash
# From local machine (after DHCP lease renewal or manual DNS test)
dig @192.168.1.5 google.com +short
```

Expected: Returns Google IPs (from new Pi-hole)

**Step 6: Verify query logs on new Pi-hole**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -a -q"
```

Expected: Shows recent queries from your client IP

**Step 7: Commit**

```bash
# Update infrastructure database - stop Docker Pi-hole
sqlite3 /infrastructure-db/infrastructure.db <<EOF
UPDATE docker_containers SET status = 'stopped', updated_at = CURRENT_TIMESTAMP
WHERE container_name = 'pihole' AND docker_host_id = 17;

UPDATE services SET status = 'degraded', updated_at = CURRENT_TIMESTAMP
WHERE service_name LIKE 'Pi-hole%' AND host_id IN (SELECT id FROM hosts WHERE hostname LIKE '%docker%');
EOF

git add infrastructure-db/infrastructure.db
git commit -m "feat: switch to LXC Pi-hole, stop Docker Pi-hole"
```

---

## Task 10: Monitor DNS Stability (24-48 hours)

**Files:**
- Monitor: DNS query logs and resolution

**Step 1: Check query logs periodically**

```bash
ssh root@192.168.1.10 "pct exec 112 -- pihole -a -q | tail -20"
```

Expected: Shows ongoing queries from network clients

**Step 2: Monitor Pi-hole FTL service status**

```bash
ssh root@192.168.1.10 "pct exec 112 -- systemctl status pihole-FTL"
```

Expected: Service remains active and running

**Step 3: Test various domains**

```bash
# Test whitelisted
dig @192.168.1.5 chat.z.ai +short

# Test normal domains
dig @192.168.1.5 google.com +short
dig @192.168.1.5 github.com +short

# Test blocked domains
dig @192.168.1.5 doubleclick.net +short
```

Expected: Correct responses for all

**Step 4: Check for any error logs**

```bash
ssh root@192.168.1.10 "pct exec 112 -- journalctl -u pihole-FTL -n 50 --no-pager"
```

Expected: No critical errors

**Step 5: Document monitoring results**

Create monitoring log at `/docs/pihole/2026-02-05-dns-migration-monitoring.md`:
```markdown
# DNS Migration Monitoring Log

## T+24 Hours (2026-02-06)

- Query count: [from pihole -a -q]
- Blocked count: [from pihole -a -q]
- Service status: active
- Issues found: [none or list]

## T+48 Hours (2026-02-07)

[Update with latest status]
```

**Step 6: No commit (monitoring phase)**

---

## Task 11: Final Cleanup

**Files:**
- Delete: Docker Pi-hole container
- Update: Infrastructure documentation

**Step 1: Verify no clients using Docker Pi-hole**

```bash
ssh root@192.168.1.20 "docker logs pihole 2>&1 | tail -50"
```

Expected: No recent query activity (or container already stopped)

**Step 2: Remove Docker Pi-hole container**

```bash
ssh root@192.168.1.20 "docker rm pihole"
```

Expected: Container removed

**Step 3: Remove Pi-hole image (optional)**

```bash
ssh root@192.168.1.20 "docker rmi pihole/pihole:latest"
```

Expected: Image removed (frees space)

**Step 4: Update infrastructure documentation**

```bash
# Update /docs/infrastructure.md
# Change Pi-hole section from "Docker container" to "LXC container"
```

**Step 5: Update infrastructure database**

```bash
sqlite3 /infrastructure-db/infrastructure.db <<EOF
-- Remove old Docker Pi-hole service
DELETE FROM services WHERE service_name LIKE 'Pi-hole%' AND host_id IN (SELECT id FROM hosts WHERE hostname LIKE '%docker%');

-- Remove Docker Pi-hole container
DELETE FROM docker_containers WHERE container_name = 'pihole' AND docker_host_id = 17;
EOF

git add docs/infrastructure.md infrastructure-db/infrastructure.db
git commit -m "feat: complete Pi-hole migration to LXC, remove Docker container"
```

**Step 6: Create migration completion document**

Create `/docs/pihole/pihole-lxc-migration-complete-2026-02-05.md`:
```markdown
# Pi-hole LXC Migration Complete

**Date:** 2026-02-05
**Status:** Complete

## Summary

Pi-hole DNS migrated from Docker container (CT 111) to dedicated LXC container (CT 112).

## Benefits

- DNS no longer depends on Docker daemon
- ~30 second restart vs 8 minutes
- Isolated failure domain
- Survives Docker host reboots

## Configuration

- Container: CT 112 (pihole-dns)
- IP: 192.168.1.5
- Resources: 1 core, 512MB RAM
- Blocklists: StevenBlack hosts
- Whitelist: Migrated from Docker (including z.ai)

## Validation

- [ ] DNS resolving correctly
- [ ] Whitelist migrated
- [ ] Blocklists active
- [ ] Docker Pi-hole removed
- [ ] Documentation updated
```

---

## Success Criteria

After completing all tasks, verify:

- [ ] CT 112 running Pi-hole natively (no Docker)
- [ ] DNS queries resolving to 192.168.1.5 correctly
- [ ] Whitelist includes z.ai domains
- [ ] Blocklists active (StevenBlack)
- [ ] Docker Pi-hole container removed
- [ ] Infrastructure database updated
- [ ] Documentation updated
- [ ] 24-48 hour monitoring shows stability

---

## Rollback Procedure

If issues occur at any point:

**Immediate rollback (if new Pi-hole not working):**
```bash
# Start Docker Pi-hole
ssh root@192.168.1.20 "docker start pihole"

# DNS should work immediately
```

**Snapshot rollback (if new container misconfigured):**
```bash
# Restore pre-cutover snapshot
ssh root@192.168.1.10 "pct snapshot 112 rollback pre-cutover"
```

**Database rollback:**
```bash
# Restore infrastructure database
git checkout HEAD~1 infrastructure-db/infrastructure.db
```

---

## References

- Design document: `/docs/plans/2026-02-05-pihole-dns-isolation-design.md`
- Infrastructure documentation: `/docs/infrastructure.md`
- Infrastructure database: `/infrastructure-db/infrastructure.db`
- Pi-hole documentation: https://docs.pi-hole.net/
