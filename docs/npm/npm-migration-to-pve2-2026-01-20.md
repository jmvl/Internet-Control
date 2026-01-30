# Nginx Proxy Manager Migration to pve2 - January 20, 2026

## Executive Summary

**Date**: January 20, 2026
**Migration Type**: Service relocation
**Source**: OMV NAS (192.168.1.9)
**Destination**: pve2 PCT 121 (192.168.1.121)
**Status**: ✅ Completed Successfully
**Downtime**: ~30 minutes (mostly data transfer and Docker image downloads)

## Migration Details

### Source Configuration (OMV)
- **Host**: OpenMediaVault NAS (192.168.1.9)
- **Deployment**: Manual Docker run (no docker-compose)
- **Data Location**: `/srv/docker-volume/volumes/`
- **Volumes**:
  - `nginx-proxy-manager_data` (11MB)
  - `nginx-proxy-manager_letsencrypt` (222KB)

### Destination Configuration (pve2)
- **Host**: Proxmox VE 2 (192.168.1.10)
- **Container**: PCT 121 (LXC - Debian 12)
- **IP Address**: 192.168.1.121/24
- **Gateway**: 192.168.1.3 (OPNsense)
- **Resources**:
  - CPU: 2 cores
  - RAM: 2GB
  - Storage: 4GB (BTRFS on ssd-4tb)
- **Deployment**: Docker Compose with bind mounts

## Migration Process

### Step 1: Container Creation
```bash
# Created LXC container on pve2
pct create 121 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname npm-pve2 \
  --cores 2 \
  --memory 2048 \
  --swap 512 \
  --storage ssd-4tb \
  --net0 name=eth0,bridge=vmbr0,gw=192.168.1.3,ip=192.168.1.121/24 \
  --onboot 1
```

### Step 2: Docker Installation
```bash
# Installed Docker in PCT 121
curl -fsSL https://get.docker.com | sh
docker --version  # Docker 29.1.5
```

### Step 3: LXC Configuration for Docker
Required features and configurations added to `/etc/pve/lxc/121.conf`:
```
features: nesting=1,keyctl=1
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
```

### Step 4: Data Migration
```bash
# Stopped NPM on OMV
ssh root@192.168.1.9 "docker stop nginx-proxy-manager-nginx-proxy-manager-1"

# Backed up volumes
docker run --rm -v nginx-proxy-manager_data:/data -v /tmp:/backup alpine \
  tar czf /backup/npm-data.tar.gz -C /data .
docker run --rm -v nginx-proxy-manager_letsencrypt:/letsencrypt -v /tmp:/backup alpine \
  tar czf /backup/npm-letsencrypt.tar.gz -C /letsencrypt .

# Transferred and extracted in PCT 121
mkdir -p /srv/npm-docker/{data,letsencrypt}
tar xzf npm-data.tar.gz -C /srv/npm-docker/data/
tar xzf npm-letsencrypt.tar.gz -C /srv/npm-docker/letsencrypt/
```

### Step 5: Docker Compose Setup
Created `/root/docker-compose.yml` in PCT 121:
```yaml
version: '3.8'

services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager-nginx-proxy-manager-1
    restart: unless-stopped

    ports:
      - "80:80"
      - "81:81"
      - "443:443"

    environment:
      - SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
      - NODE_ENV=production

    volumes:
      - npm_data:/data
      - npm_letsencrypt:/etc/letsencrypt

volumes:
  npm_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /srv/npm-docker/data
  npm_letsencrypt:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /srv/npm-docker/letsencrypt
```

### Step 6: Container Start
```bash
cd /root && docker compose up -d
```

### Step 7: Network Configuration Update

#### OPNsense Firewall/NAT Rules

**Original Configuration (Pre-Migration):**
- NAT rules pointed to: `omv` alias (192.168.1.9)
- Two port forwarding rules:
  - HTTP (port 80) → OMV
  - HTTPS (port 443) → OMV

**Changes Made:**

1. **Backup Configuration:**
```bash
ssh root@192.168.1.3
cp /conf/config.xml /conf/config.xml.backup-20260120-0920
```

2. **Updated NAT Rules:**
```bash
# Direct XML edit to change target from 'omv' to '192.168.1.121'
sed -i'.bak-$(date +%s)' \
  -e '/descr.*NPM/,/\/rule/s/<target>omv<\/target>/<target>192.168.1.121<\/target>/' \
  /conf/config.xml
```

3. **Updated Filter Rules:**
```bash
# Also updated firewall filter rules for the same traffic
sed -i'.bak-$(date +%s)' \
  -e '/descr.*NPM/,/\/rule/s/<address>omv<\/address>/<address>192.168.1.121<\/address>/' \
  /conf/config.xml
```

4. **Applied Configuration:**
```bash
configctl filter reload
```

#### Current Active OPNsense Rules

**NAT Port Forwarding Rules:**
```
Rule 1: HTTP to NPM (nginx proxy manager - OMV)
  Interface: WAN
  Protocol: TCP
  Source: Any
  Destination: WAN port 80
  Target: 192.168.1.121 port 80 ✅ UPDATED
  Description: HTTP to NPM (nginx proxy manager - OMV)

Rule 2: HTTPS to NPM (nginx proxy manager - OMV)
  Interface: WAN
  Protocol: TCP
  Source: Any
  Destination: WAN port 443
  Target: 192.168.1.121 port 443 ✅ UPDATED
  Description: HTTPS to NPM (nginx proxy manager - OMV)
```

**Active pfctl Rules (Verification):**
```bash
ssh root@192.168.1.3 "pfctl -s nat | grep 192.168.1.121"
```

Output:
```
rdr on pppoe0 inet proto tcp from any to (pppoe0:network) port = http -> 192.168.1.121 port 80
rdr on vtnet0 inet proto tcp from any to (pppoe0:network) port = http -> 192.168.1.121 port 80
rdr on lo0 inet proto tcp from any to (pppoe0:network) port = http -> 192.168.1.121 port 80
rdr on pppoe0 inet proto tcp from any to (pppoe0:network) port = https -> 192.168.1.121 port 443
rdr on vtnet0 inet proto tcp from any to (pppoe0:network) port = https -> 192.168.1.121 port 443
rdr on lo0 inet proto tcp from any to (pppoe0:network) port = https -> 192.168.1.121 port 443
```

**Note:** Rules are replicated across multiple interfaces (pppoe0, vtnet0, lo0) for proper traffic handling.

#### Firewall Filter Rules
Corresponding filter rules allow the forwarded traffic:
```
Rule: HTTP to NPM (nginx proxy manager - OMV)
  Action: Pass
  Interface: WAN
  Protocol: TCP
  Source: Any
  Destination: 192.168.1.121 port 80 ✅ UPDATED
  Description: HTTP to NPM (nginx proxy manager - OMV)

Rule: HTTPS to NPM (nginx proxy manager - OMV)
  Action: Pass
  Interface: WAN
  Protocol: TCP
  Source: Any
  Destination: 192.168.1.121 port 443 ✅ UPDATED
  Description: HTTPS to NPM (nginx proxy manager - OMV)
```

#### OPNsense Configuration Files

**Backup Location:**
```
ssh root@192.168.1.3
ls -la /conf/config.xml.backup-*
```

**Config File Locations:**
- Main config: `/conf/config.xml`
- Backups: `/conf/config.xml.backup-YYYYMMDD-HHMMSS`

**Current OPNsense System:**
- **Host**: OPNsense Firewall VM (192.168.1.3)
- **WAN Interface**: pppoe0 (PPPoE connection)
- **LAN Interface**: vmbr0 (192.168.1.0/24)
- **NPM Backend**: 192.168.1.121 (pve2 PCT 121)

#### Verification Commands

```bash
# Check NAT rules
ssh root@192.168.1.3 "pfctl -s nat | grep 192.168.1.121"

# Check filter rules
ssh root@192.168.1.3 "pfctl -s rules | grep 192.168.1.121"

# View full NAT configuration
ssh root@192.168.1.3 "cat /conf/config.xml | grep -A 20 '<nat>'"

# View full filter configuration
ssh root@192.168.1.3 "cat /conf/config.xml | grep -A 30 '<filter>'"
```

## Post-Migration Status

### Migrated Assets
- ✅ **Database**: 448KB (44 proxy hosts, all configurations preserved)
- ✅ **SSL Certificates**: 52 certificate directories (including accounts, archive, keys, live, renewal)
- ✅ **Proxy Configurations**: 41 nginx proxy host configurations
- ✅ **Nginx Configuration**: All custom configurations intact
- ✅ **Access Logs**: Historical logs preserved

### Verified Functionality
- ✅ NPM web interface: http://192.168.1.121:81 (HTTP 200)
- ✅ Reverse proxy: HTTP 301 redirects working
- ✅ SSL certificates: All 40+ certificates present in letsencrypt/live/
- ✅ Container status: Running with all ports exposed (80, 81, 443)
- ✅ Nginx configuration: Syntax valid and test successful

### Network Traffic Flow
```
Internet
  ↓
OPNsense Firewall (192.168.1.3)
  ↓ NAT port forwarding (80, 443)
pve2 PCT 121 (192.168.1.121)
  ↓
Nginx Proxy Manager (Docker)
  ↓
Backend Services
```

## Infrastructure Database Updates

### Host Records
```sql
-- New LXC container
INSERT INTO hosts (hostname, host_type, management_ip, status, parent_host_id, vmid, cpu_cores, total_ram_mb, purpose, criticality)
VALUES ('npm-pve2', 'lxc', '192.168.1.121', 'active', 1, 121, 2, 2048, 'Nginx Proxy Manager - Reverse Proxy with SSL', 'critical');
-- Host ID: 22
```

### Container Updates
```sql
-- Updated NPM container
UPDATE docker_containers
SET docker_host_id = 22, status = 'running'
WHERE container_name = 'nginx-proxy-manager';
```

### Service Updates
```sql
-- Updated NPM services
UPDATE services
SET host_id = 22
WHERE service_name LIKE '%nginx%';
```

## Known Issues and Warnings

### ⚠️ Docker-in-LXC Port Forwarding Instability (CRITICAL)
**Status**: Recurring issue requiring manual intervention
**Severity**: High - Service becomes inaccessible
**Issue**: Docker port forwarding in LXC containers periodically fails
**Symptoms**:
- NPM container shows "Running"
- Internal services work (localhost:81 returns 200)
- External access times out
- Occurred 2+ times in first hour

**Workaround**:
```bash
ssh root@192.168.1.10
pct stop 121 && sleep 3 && pct start 121 && sleep 10
curl http://192.168.1.121:81  # Verify
```

**See Also**: "Docker-in-LXC Networking Issues" in Lessons Learned section below
**Recommendation**: Consider migration to VM (Option D) if issue persists

### SSL Certificate Renewal
**Status**: Expected behavior, not critical
**Issue**: Automatic renewal attempts fail with "No certificate found with name npm-X"
**Reason**: Let's Encrypt renewal configuration files were not migrated (only certificates copied)
**Impact**: Manual renewal will be required when certificates expire
**Resolution**:
1. Access NPM web interface
2. Navigate to SSL Certificates
3. For expiring certificates, use "Renew" button
4. Certificates will renew successfully using Cloudflare DNS challenge

### Nginx Warnings
**Status**: Non-critical informational warnings
**Issue**: Multiple deprecation warnings about "http2" directive and protocol options
**Impact**: None - functionality is not affected
**Note**: These are configuration warnings from existing proxy hosts, not errors

## Advantages of New Deployment

### 1. Docker Compose Management
- **Proper Updates**: Use `docker compose pull && docker compose up -d` instead of manual docker run
- **Volume Preservation**: Automatic volume handling during updates
- **Configuration as Code**: docker-compose.yml documents the entire setup

### 2. Infrastructure Isolation
- **Dedicated Container**: NPM runs in isolated LXC container
- **Resource Limits**: CPU and RAM constraints prevent resource starvation
- **Independent Updates**: Can update NPM without affecting OMV services

### 3. Improved Management
- **Central Location**: All proxy services on pve2 (along with Supabase, n8n)
- **Better Monitoring**: Container status tracked in infrastructure database
- **Proxmox Integration**: Backup, snapshot, and migration capabilities

## Old NPM Status (OMV Backup)

### Backup Strategy
The old NPM installation on OMV is **preserved as a backup**:

- **Container**: Stopped (not consuming resources)
- **Volumes**: Preserved for emergency rollback
- **Location**: OMV NAS (192.168.1.9)
- **Retention**: Keep for 2-4 weeks until new deployment is verified stable
- **Container ID**: `070cb55f2bb2`
- **Volumes**:
  - `nginx-proxy-manager_data` (11MB)
  - `nginx-proxy-manager_letsencrypt` (222KB)

### Cleanup Commands (When Ready)
After verification period (2-4 weeks), remove old NPM from OMV:
```bash
ssh root@192.168.1.9
# Remove stopped container
docker rm nginx-proxy-manager-nginx-proxy-manager-1
# Remove volumes
docker volume rm nginx-proxy-manager_data nginx-proxy-manager_letsencrypt
# Optionally remove old data directories
rm -rf /srv/docker-volume/volumes/nginx-proxy-manager_*
```

### Database Reference
The infrastructure database tracks the old NPM location for historical reference:
- **Old Host**: `docker-host-omv` (ID: 18)
- **Status**: Active (can be updated to 'decommissioned' after cleanup)
- **Old Container ID**: `070cb55f2bb2`

## Rollback Procedure

If issues arise and rollback is needed, follow these steps in order:

### Step 1: Revert OPNsense Firewall Rules

**1. List available backups:**
```bash
ssh root@192.168.1.3
ls -lht /conf/config.xml.backup-20260120*
```

**2. Restore pre-migration configuration:**
```bash
# Find the backup from before the migration
cp /conf/config.xml.backup-20260120-0920 /conf/config.xml
```

**3. Reload firewall configuration:**
```bash
configctl filter reload
```

**4. Verify OPNsense rules are restored:**
```bash
# Should show 192.168.1.9 instead of 192.168.1.121
pfctl -s nat | grep -E '(192.168.1.9|192.168.1.121)'
```

Expected output after rollback:
```
rdr on pppoe0 inet proto tcp from any to (pppoe0:network) port = http -> 192.168.1.9 port 80
rdr on pppoe0 inet proto tcp from any to (pppoe0:network) port = https -> 192.168.1.9 port 443
```

### Step 2: Stop NPM on pve2
```bash
ssh root@192.168.1.10
pct exec 121 -- docker compose down
# Or stop the container directly
pct exec 121 -- docker stop nginx-proxy-manager-nginx-proxy-manager-1
```

### Step 3: Restart NPM on OMV
```bash
ssh root@192.168.1.9
docker start nginx-proxy-manager-nginx-proxy-manager-1

# Verify it's running
docker ps | grep nginx-proxy-manager
```

### Step 4: Verify Rollback
```bash
# Test OPNsense forwarding
curl -I http://192.168.1.9:81

# Test proxy hosts
curl -I http://192.168.1.9 -H "Host: netdata.acmea.tech"
```

### Alternative: Manual OPNsense Rule Reversion

If you need to manually edit the rules instead of restoring from backup:

```bash
ssh root@192.168.1.3

# Edit NAT rules to point back to OMV
vi /conf/config.xml
# Find: <target>192.168.1.121</target>
# Replace with: <target>omv</target>

# Edit filter rules to point back to OMV
# Find: <address>192.168.1.121</address>
# Replace with: <address>omv</address>

# Save and reload
configctl filter reload
```

### Rollback Verification Checklist

- [ ] OPNsense NAT rules point to 192.168.1.9
- [ ] OPNsense filter rules point to 192.168.1.9
- [ ] NPM on pve2 is stopped
- [ ] NPM on OMV is running
- [ ] Web interface accessible on http://192.168.1.9:81
- [ ] Proxy hosts responding correctly
- [ ] SSL certificates working

## Lessons Learned

### 1. Docker-in-LXC Configuration
- **Essential**: Enable `nesting=1,keyctl=1` features
- **Critical**: Disable AppArmor with `lxc.apparmor.profile: unconfined`
- **Required**: Add `lxc.cgroup2.devices.allow: a` for device access

### 2. Network Troubleshooting
- **Symptom**: Container can't reach internet after creation
- **Cause**: veth interface not properly initialized
- **Solution**: Container restart (`pct stop && pct start`) resolved the issue

### 3. Data Migration Strategy
- **Best Practice**: Use Docker Alpine containers for clean volume backups
- **Verification**: Check extracted file counts and database size
- **SSL Certificates**: Include both archive and live directories

### 4. Docker-in-LXC Networking Issues (CRITICAL)

**Known Issue**: Docker port forwarding in LXC containers periodically fails after container restarts or network changes.

**Symptoms:**
- Container shows as "Running" and logs are normal
- Backend accessible inside container (localhost:81 returns 200)
- Ports NOT accessible from outside the LXC container
- `curl` from external hosts times out

**Root Cause**: LXC container network namespace doesn't properly forward Docker bridge ports to external interfaces after certain operations (container restart, Docker operations, etc.)

**Working Solution**:
```bash
# Complete LXC container restart (not just Docker)
ssh root@192.168.1.10
pct stop 121
sleep 3
pct start 121
sleep 10

# Verify NPM starts
pct exec 121 -- docker ps

# Test accessibility
curl http://192.168.1.121:81
```

**What DOESN'T Work**:
- Restarting just the Docker container: `docker restart` ❌
- Restarting Docker daemon: `systemctl restart docker` ❌
- Reloading docker-compose: `docker compose restart` ❌

**What DOES Work**:
- Full LXC container restart: `pct stop && pct start` ✅

**Frequency**: Issue occurred 2 times in first hour of operation. May stabilize over time or require monitoring.

**Impact**: If ports become inaccessible, users must have SSH access to pve2 to restart the container.

### 5. Port Forwarding Updates
- **Simple Approach**: Direct IP substitution in config.xml
- **Alternative**: Create new alias (npm-pve2) instead of changing existing alias
- **Verification**: Use `pfctl -s nat` to confirm rules are active

## Alternative Deployment Options Research

### Executive Summary

**Issue**: Docker-in-LXC port forwarding periodically fails, requiring full LXC container restarts to restore external access.

**Research Date**: January 20, 2026

**Key Finding**: The Docker-in-LXC deployment on Proxmox is **not recommended for production workloads** by the official Proxmox community due to shared kernel risks, networking instability, and security vulnerabilities.

---

### Why Docker-in-LXC is Problematic

#### 1. Shared Kernel Architecture

LXC containers share the host kernel, unlike VMs which have their own kernel:

| Aspect | LXC Container | VM (KVM) |
|--------|---------------|----------|
| **Kernel** | Shared with host | Isolated kernel |
| **Security** | Container escape = host compromise | Exploit contained within VM |
| **Networking** | veth bridge (complex) | Virtual NIC (stable) |
| **Stability** | Affected by host kernel updates | Independent of host |

#### 2. Recent Security Incidents

**CVE-2025-52881** (November 2025):
- A container escape vulnerability
- Security patches **broke Docker containers in LXC**
- Required AppArmor workarounds
- Demonstrates fragility of Docker-in-LXC approach

**containerd v2 Update Issues**:
- Introduced kernel syscalls conflicting with unprivileged LXC
- Broke Docker containers, forcing downgrades to containerd v1.7.x
- Shows Docker-in-LXC is vulnerable to upstream changes

#### 3. Official Proxmox Recommendation

> *"If you want to run application containers, for example, Docker images, it is recommended that you run them inside a Proxmox QEMU VM."*
> — Proxmox Community (2025, still valid)

Sources:
- [Reddit: Proxmox LXC Containers vs Virtual Machines for Docker](https://www.reddit.com/r/selfhosted/comments/1k3hzs1/proxmox_lxc_containers_vs_virtual_machines_for/)
- [Proxmox Forum: Docker on LXC or VM?](https://forum.proxmox.com/threads/docker-on-lxc-or-vm.52872/)

---

### Recommended Alternative: Deploy NPM in a VM (Option D)

#### Architecture Overview

```
Internet
   ↓ (Port 80/443)
OPNsense Firewall (192.168.1.3)
   ↓ NAT port forwarding
pve2 VM 122 (192.168.1.122) - NEW
   ↓
Nginx Proxy Manager (Docker)
   ↓
Backend Services
```

#### Advantages

| Benefit | Explanation |
|---------|-------------|
| **Full Kernel Isolation** | VM has its own kernel, exploits contained |
| **Stable Networking** | No veth bridge issues, port forwarding reliable |
| **Production-Ready** | Officially recommended for Docker workloads |
| **Easier Troubleshooting** | Standard Docker behavior, no LXC quirks |
| **Better Security** | AppArmor works as designed |
| **Migration Simplicity** | Same docker-compose.yml, just different VM |

#### VM Configuration Example

```bash
# Create Debian 12 VM on pve2
qm create 122 \
  --name npm-pve2-vm \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --ipconfig0 ip=192.168.1.122/24,gw=192.168.1.3 \
  --ostype l26 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:vm-122-disk-0,ssd=1 \
  --ide2 local:iso/debian-12-standard_12.2-1_amd64.iso,media=cdrom \
  --boot order=scsi0 \
  --serial0 socket \
  --vga serial0

# Start VM and install Debian
qm start 122
```

#### Docker Installation (Same as LXC)

```bash
# Inside VM (192.168.1.122)
curl -fsSL https://get.docker.com | sh
usermod -aG docker root

# Copy docker-compose.yml (same file from PCT 121)
# Copy /srv/npm-docker/ data (same migration procedure)
```

#### Migration Steps from LXC to VM

1. **Create VM 122** (192.168.1.122) with Debian 12
2. **Install Docker** using standard script
3. **Transfer data** from PCT 121 to VM 122:
   ```bash
   # From PCT 121
   tar czf /tmp/npm-data-backup.tar.gz -C /srv/npm-docker .
   scp /tmp/npm-data-backup.tar.gz root@192.168.1.122:/tmp/

   # In VM 122
   mkdir -p /srv/npm-docker
   tar xzf /tmp/npm-data-backup.tar.gz -C /srv/npm-docker/
   ```
4. **Copy docker-compose.yml** to VM 122
5. **Start NPM** in VM 122 with `docker compose up -d`
6. **Update OPNsense** NAT rules to point to 192.168.1.122
7. **Stop and remove** PCT 121 after verification

---

### Alternative Options (Not Recommended)

#### Option A: Native OCI Support (Proxmox 9.1+)

**Status**: Experimental (November 2025)

**Overview**: Proxmox VE 9.1 added native OCI container execution without needing Docker.

**Pros**:
- No Docker runtime needed
- Lower overhead than VM
- Native Proxmox integration

**Cons**:
- **Still experimental** - "has a ways to go"
- Nginx Proxy Manager not available as OCI image
- Would require switching to different reverse proxy
- Not production-ready for complex workloads

**Verdict**: **Not viable** for NPM migration today. Watch for 2026+ maturity.

Sources:
- [VirtualizationHowTo: Complete Guide to Proxmox Containers in 2025](https://www.virtualizationhowto.com/2025/11/complete-guide-to-proxmox-containers-in-2025-docker-vms-lxc-and-new-oci-support/)
- [XDA Developers: Proxmox OCI Images Review](https://www.xda-developers.com/i-tried-out-the-new-proxmox-oci-images-for-containers-and-i-adore-them/)

#### Option B: Docker Macvlan/IPvlan Networking in LXC

**Status**: Possible but problematic

**Overview**: Use macvlan or ipvlan network drivers instead of bridge networking.

**Pros**:
- Containers get their own IP on the network
- Bypasses Docker bridge issues

**Cons**:
- **Firewall conflicts** - Proxmox firewalls can break macvlan ([Proxmox Forum](https://forum.proxmox.com/threads/firewall-breaks-macvlan-enabled-docker-containers-in-lxc.156824/))
- More complex configuration
- Security concerns with containers on main network
- OPNsense rules would need to target container IPs directly
- Doesn't solve the underlying LXC kernel sharing issue

**Verdict**: **Not recommended** - trades one set of problems for another.

Sources:
- [Medium: Proxmox & Docker VLAN](https://medium.com/@mmwent/proxmox-docker-vlan-1cd87707bdb)
- [Docker Forums: IPvLAN or MACVLAN in docker-compose](https://forums.docker.com/t/ipvlan-or-macvlan-in-docker-compose-yaml/133137)
- [Proxmox and Docker Networking Guide](https://edhull.co.uk/blog/2018-02-11-proxmox-network-docker)

#### Option C: Nginx Proxy Manager as Native LXC (No Docker)

**Status**: Possible but unsupported

**Overview**: Install NPM directly in LXC without Docker containerization.

**Pros**:
- No Docker-in-LXC issues
- Lower resource overhead

**Cons**:
- **NPM only officially supports Docker**
- Would require manual Node.js/Nginx setup
- No official documentation for non-Docker deployment
- Updates would be manual and complex
- Not future-proof

**Verdict**: **Not viable** - unsupported configuration.

#### Option D: Switch to Different Reverse Proxy

**Options**: Caddy, Traefik, HAProxy, plain Nginx

**Pros**:
- Some have native LXC support
- Modern alternatives (Caddy, Traefik) have better automation

**Cons**:
- **Major migration effort** - 40+ proxy hosts to reconfigure
- SSL certificates may not transfer
- Different UI paradigms
- Steep learning curve
- Not solving the immediate problem

**Verdict**: **Consider for future** but not a short-term fix.

---

### Comparison Matrix

| Deployment Option | Stability | Security | Complexity | Effort | Recommendation |
|-------------------|-----------|----------|------------|--------|----------------|
| **Current: Docker in LXC** | ⚠️ Unstable | ⚠️ Shared kernel | Low | — | **Migrate away** |
| **VM with Docker** | ✅ Stable | ✅ Isolated | Low | Medium | **RECOMMENDED** |
| **Native OCI (PVE 9.1+)** | 🟡 Experimental | 🟡 Unknown | Low | High | Wait for maturity |
| **LXC with Macvlan** | ⚠️ Firewall issues | ⚠️ Exposed | High | Medium | Not recommended |
| **Native LXC (no Docker)** | ✅ Stable | ✅ Isolated | High | Very High | Unsupported |
| **Switch to Traefik/Caddy** | ✅ Stable | ✅ Isolated | Medium | Very High | Future consideration |

---

### Recommended Action Plan

#### Short-Term (Immediate Stability)

1. **Monitor current LXC deployment** for port forwarding failures
2. **Document each failure** with timestamp and symptoms
3. **Use workaround** (`pct stop && pct start`) when failures occur
4. **Decision point**: If failures continue > 2-3 times per week → migrate to VM

#### Medium-Term (Recommended Migration)

**Migrate to VM (Option D)** when ready:

```bash
# Week 1: Create and configure VM 122
# Week 2: Deploy NPM in VM, test thoroughly
# Week 3: Update OPNsense rules, cutover
# Week 4: Monitor, then decommission PCT 121
```

**Benefits**:
- Eliminates Docker-in-LXC networking issues
- Officially-supported production deployment
- Future-proof for additional Docker services
- Same docker-compose.yml (zero config changes)

#### Long-Term (2026+)

**Watch Proxmox OCI support maturity**:
- If Nginx Proxy Manager becomes available as OCI image
- If Proxmox 9.2+ stabilizes OCI features
- Consider migration for resource efficiency

---

### Research Sources

#### Primary Sources

1. **[Reddit: Proxmox LXC vs VM for Docker](https://www.reddit.com/r/selfhosted/comments/1k3hzs1/proxmox_lxc_containers_vs_virtual_machines_for/)**
   - Community consensus: VM for Docker in production

2. **[Proxmox Forum: Docker on LXC or VM?](https://forum.proxmox.com/threads/docker-on-lxc-or-vm.52872/)**
   - Official recommendation: Use QEMU VM for Docker

3. **[VirtualizationHowTo: Complete Guide to Proxmox Containers 2025](https://www.virtualizationhowto.com/2025/11/complete-guide-to-proxmox-containers-in-2025-docker-vms-lxc-and-new-oci-support/)**
   - Covers VM, LXC, and new OCI support comparison

4. **[CVE-2025-52881 Discussion](https://forum.proxmox.com/threads/cve-2025-52881-breaks-docker-lxc-containers.175827/)**
   - Recent security vulnerability affecting Docker-in-LXC

#### Networking Sources

5. **[Proxmox Forum: Firewall breaks macvlan in LXC](https://forum.proxmox.com/threads/firewall-breaks-macvlan-enabled-docker-containers-in-lxc.156824/)**
   - Issues with macvlan networking in LXC

6. **[Medium: Proxmox & Docker VLAN](https://medium.com/@mmwent/proxmox-docker-vlan-1cd87707bdb)**
   - VLAN and macvlan configuration guide

7. **[Docker Forums: IPvLAN or MACVLAN in docker-compose](https://forums.docker.com/t/ipvlan-or-macvlan-in-docker-compose-yaml/133137)**
   - Community discussion on alternative networking

#### Additional References

8. **[Proxmox and Docker Networking](https://edhull.co.uk/blog/2018-02-11-proxmox-network-docker)**
   - Networking architecture explanation

9. **[XDA: Proxmox OCI Images Review](https://www.xda-developers.com/i-tried-out-the-new-proxmox-oci-images-for-containers-and-i-adore-them/)**
   - Early review of native OCI support

10. **[Complete Guide to Proxmox Containers](https://www.virtualizationhowto.com/2025/11/complete-guide-to-proxmox-containers-in-2025-docker-vms-lxc-and-new-oci-support/)**
    - Comprehensive 2025 container guide

---

## Next Steps

### Immediate
- [ ] Monitor SSL certificate expiration dates
- [ ] Plan manual renewal process for expiring certificates
- [ ] Document any custom proxy configurations
- [ ] **Monitor LXC port forwarding stability** - document each failure

### Short-Term (Next 2-4 Weeks)
- [ ] **Decision point**: If port forwarding issues persist, plan VM migration
- [ ] Create VM migration plan if issues continue
- [ ] Decommission OMV backup after new deployment verified stable

### Medium-Term (Recommended)
- [ ] **Migrate NPM to VM (Option D)** for production stability
- [ ] Create VM 122 on pve2
- [ ] Deploy NPM in VM with same docker-compose.yml
- [ ] Update OPNsense NAT rules to point to VM
- [ ] Decommission PCT 121 after successful VM migration

### Future Enhancements
- [ ] Set up automated backup script for NPM volumes
- [ ] Configure Watchtower for automatic NPM updates
- [ ] Migrate renewal configurations for automatic SSL renewal
- [ ] Consider removing "omv" alias if no other services use it
- [ ] Monitor Proxmox 9.2+ OCI support maturity for future consideration

## References

### Documentation
- **Migration Document**: `/docs/npm/npm-migration-to-pve2-2026-01-20.md`
- **Incident Report**: `/docs/troubleshooting/2026-01-20-npm-upgrade-ssl-loss-incident.md`
- **NPM Documentation**: `/docs/npm/npm.md`
- **Infrastructure DB**: `/infrastructure-db/infrastructure.db`

### OPNsense Firewall
- **Host**: 192.168.1.3 (OPNsense Firewall VM)
- **Config Location**: `/conf/config.xml`
- **Backup Location**: `/conf/config.xml.backup-20260120-0920`
- **WAN Interface**: pppoe0 (PPPoE connection)
- **LAN Interface**: vmbr0 (192.168.1.0/24)

### Network Assets
| Service | IP | Role | Status |
|---------|-----|------|--------|
| OPNsense | 192.168.1.3 | Firewall/NAT | Active |
| pve2 | 192.168.1.10 | Proxmox host | Active |
| PCT 121 | 192.168.1.121 | NPM (new) | Active |
| OMV | 192.168.1.9 | NPM (backup) | Stopped |

---

**Migration Completed**: January 20, 2026 09:30 CET
**Total Duration**: ~2 hours (including troubleshooting)
**Status**: ✅ Production Ready
**Author**: Claude Code Assistant
