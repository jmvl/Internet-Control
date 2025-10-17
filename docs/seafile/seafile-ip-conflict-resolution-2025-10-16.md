# Seafile IP Conflict Resolution - October 16, 2025

## Executive Summary

**Incident Type**: IP Address Conflict
**Date**: October 16, 2025
**Duration**: ~2 hours investigation
**Impact**: Seafile web interface inaccessible via Nginx Proxy Manager (502 Bad Gateway)
**Status**: ✅ **RESOLVED** - IP conflict identified and fixed

## Root Cause: IP Address Conflict

### The Problem
Two Proxmox containers were assigned the **same IP address (192.168.1.25)**:
- **PCT 103**: Seafile (files.accelior.com)
- **PCT [Ansible]**: Ansible automation server

This created a network conflict where:
- Connections to 192.168.1.25 were unpredictable (routing to either container)
- SSH worked (both containers had SSH on port 22)
- Docker ports (8090, 8091, 8092) failed because only Seafile had Docker
- Different hosts got different results depending on ARP cache

## Symptoms

### What We Observed
1. **502 Bad Gateway** when accessing https://files.accelior.com
2. **Nginx Proxy Manager (192.168.1.9) could NOT connect** to Seafile ports (8090, 8091, 8092)
3. **SSH connections worked** from NPM to 192.168.1.25
4. **Other hosts could connect** to Seafile successfully
5. **Port changes did NOT fix** the issue (tried 8090 → 8091 → 8092)
6. **Container reboots did NOT fix** the issue

### Misleading Clues
- Port 22 (SSH) worked, suggesting network connectivity was fine
- Only Docker-exposed ports failed, suggesting Docker networking issue
- Issue survived reboots and Docker restarts
- iptables rules showed correct configuration
- No firewall blocking rules found in OPNsense

## Investigation Timeline

### Initial Diagnosis (Incorrect)
Based on previous incidents ([seafile-port-connectivity-issue-2025-10-07.md](seafile-port-connectivity-issue-2025-10-07.md)), suspected:
- Recurring port-specific connectivity failure
- Stale NAT/connection tracking state
- OPNsense firewall blocking

### Diagnostic Steps Taken
1. ✅ Verified Seafile containers running and healthy
2. ✅ Tested direct HTTP access (worked from some hosts, failed from others)
3. ✅ Changed ports multiple times (8090 → 8091 → 8092)
4. ✅ Rebooted PCT 103 container
5. ✅ Restarted Docker daemon
6. ✅ Checked iptables rules (all correct)
7. ✅ Tested OPNsense firewall rules (no blocking)
8. ✅ Added explicit iptables ACCEPT rule (no effect)
9. ✅ Discovered port 22 worked but Docker ports didn't

### The Breakthrough
Testing revealed:
```bash
# From OMV (192.168.1.9):
Port 22 (SSH):    ✅ WORKS
Port 8092 (HTTP): ❌ FAILS (Connection refused)
Port 80:          ❌ FAILS (Connection refused)
Port 443:         ❌ FAILS (Connection refused)
Port 3306:        ❌ FAILS (Connection refused)

# All Docker-exposed ports failed, but SSH worked
```

This pattern indicated **two different systems** responding on the same IP:
- One with only SSH (Ansible PCT)
- One with SSH + Docker services (Seafile PCT)

## Resolution

### How It Was Fixed
1. Identified the IP conflict between Ansible PCT and Seafile PCT
2. Changed one container's IP address to eliminate conflict
3. Updated network configuration
4. Services immediately became accessible

### Verification
After fixing the IP conflict:
```bash
# All services now accessible from all hosts
curl http://192.168.1.25:8092    # ✅ HTTP 302
curl https://files.accelior.com  # ✅ HTTP 302 (via NPM)
```

## Why Previous Attempts Failed

### Port Changes (8090 → 8091 → 8092)
- **Why it didn't work**: The IP conflict meant connections were routing to the wrong container
- **Why SSH worked**: Both containers had SSH, so connections succeeded regardless of routing

### Container/Docker Restarts
- **Why it didn't work**: Both containers restarted with the same conflicting IP
- **The conflict persisted** across all restarts

### iptables Rules
- **Why adding rules didn't work**: Rules were correct, but traffic was routing to the wrong container
- **DOCKER-USER chain showed 0 packets**: Because packets went to Ansible PCT instead

## Lessons Learned

### Key Insights
1. **IP conflicts can be extremely misleading** - some services work while others don't
2. **ARP caching complicates diagnosis** - different hosts may see different containers
3. **Port-specific failures suggest multiple hosts** on the same IP
4. **Previous incident patterns** (port changes fixing issues) were coincidental, not causative

### Diagnostic Checklist for Future IP Conflicts
When experiencing mysterious connectivity issues:

1. ✅ **Check for duplicate IPs across all containers/VMs**:
   ```bash
   # On Proxmox host
   for i in $(pct list | awk 'NR>1 {print $1}'); do
     echo -n "PCT $i: "
     pct config $i | grep "ip=" | cut -d, -f3
   done
   ```

2. ✅ **Test multiple ports** (not just one service):
   - If SSH works but other ports don't → likely IP conflict
   - If some hosts work but others don't → likely ARP cache differences

3. ✅ **Check ARP tables** on multiple hosts:
   ```bash
   arp -n | grep <IP>
   ```

4. ✅ **Scan for duplicate MACs**:
   ```bash
   nmap -sn 192.168.1.0/24
   ```

### Prevention
- **Document all IP assignments** in centralized location
- **Use DHCP reservations** where possible to prevent conflicts
- **Implement IP conflict detection** monitoring
- **Maintain IP address inventory** for static assignments

## Technical Details

### Environment
- **Proxmox Host**: pve2
- **Seafile PCT**: 103 (intended IP: 192.168.1.25)
- **Ansible PCT**: [ID unknown] (conflicting IP: 192.168.1.25)
- **NPM Host**: 192.168.1.9 (OMV)
- **Gateway**: 192.168.1.3 (OPNsense)

### Network Topology
```
[Internet] → [OPNsense 192.168.1.3] → [LAN 192.168.1.0/24]
                                          ├─ OMV/NPM: 192.168.1.9
                                          ├─ Seafile PCT 103: 192.168.1.25 ⚠️
                                          └─ Ansible PCT: 192.168.1.25 ⚠️ CONFLICT
```

### Configuration Files Changed
- Ansible PCT network configuration (IP address changed)
- No Seafile changes required

## Related Documentation

### Previous Incidents (Different Root Causes)
- [seafile-crash-resolution-2025-09-27.md](seafile-crash-resolution-2025-09-27.md) - MariaDB startup timing
- [seafile-network-fix-2025-09-27.md](seafile-network-fix-2025-09-27.md) - Port 50080 → 8080 change
- [seafile-port-connectivity-issue-2025-10-07.md](seafile-port-connectivity-issue-2025-10-07.md) - Port 8080 → 8090 change

**Note**: The October 7 incident may have also been an IP conflict that was temporarily resolved by rebooting, only to recur later.

### General Documentation
- [seafile-infrastructure.md](seafile-infrastructure.md) - Infrastructure overview
- [troubleshooting-guide.md](troubleshooting-guide.md) - General troubleshooting

## Recommendations

### Immediate Actions
- ✅ Document all PCT IP addresses in infrastructure documentation
- ✅ Verify no other IP conflicts exist across Proxmox environment
- ✅ Update Seafile troubleshooting guide with IP conflict detection

### Long-term Improvements
1. **Implement IP Address Management (IPAM)**:
   - Use phpIPAM, NetBox, or similar tool
   - Document all static IP assignments
   - Track IP allocation centrally

2. **Automated Conflict Detection**:
   - Monitor for duplicate IPs using arpwatch
   - Alert on ARP table anomalies
   - Regular network scans for conflicts

3. **Network Documentation**:
   - Maintain `/docs/network-topology.md` with all IP assignments
   - Update when adding new containers/VMs
   - Include in onboarding documentation

4. **Configuration Management**:
   - Use Infrastructure as Code (Terraform, Ansible) for container provisioning
   - Validate IP uniqueness before deployment
   - Centralized configuration repository

---

**Investigation completed**: October 16, 2025
**Resolution time**: ~2 hours (including extensive troubleshooting)
**Service status**: Fully operational
**Root cause**: IP address conflict between Seafile PCT 103 and Ansible PCT
**Solution**: Changed conflicting container's IP address
**Lesson**: Always check for IP conflicts when experiencing mysterious port-specific failures

*Documented by: Claude Code Assistant*
*Incident classification: IP address conflict (Layer 3 networking issue)*
