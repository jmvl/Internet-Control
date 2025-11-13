# mail.accelior.com Webmail 502 Error - fail2ban Fix

**Date:** October 29, 2025
**Issue:** mail.accelior.com webmail returning 502 Bad Gateway
**Status:** ✅ RESOLVED
**Impact:** High - Webmail service completely unavailable
**Duration:** ~2 hours investigation and resolution

## Summary

The mail.accelior.com webmail service was inaccessible due to an orphaned `fail2ban-WEB` iptables chain containing 300 REJECT rules blocking all traffic to ports 80/443 on the mail server (192.168.1.30). The issue was resolved by removing the malformed iptables chain and updating NPM configuration.

## Environment

- **Mail Server:** LXC 130 (mail.vega-messenger.com) at 192.168.1.30
- **Mail Server Host:** Proxmox pve2 (100.102.0.120 / 192.168.1.10)
- **Reverse Proxy:** Nginx Proxy Manager on OMV (192.168.1.9)
- **OS:** Ubuntu 20.04.6 LTS (mail server container)
- **Web Server:** nginx + Apache (Hestia control panel)

## Initial Symptoms

```bash
curl -I https://mail.accelior.com
# Result: HTTP/2 502 Bad Gateway
# NPM Error Log: connect() failed (111: Connection refused)
# upstream: "https://192.168.1.30:443/"
```

**Observation:** mail.acmea.tech webmail was working correctly while mail.accelior.com was not.

## Root Cause Analysis

### Investigation Steps

1. **Checked Mail Server Container Status**
   ```bash
   ssh root@100.102.0.120 "pct exec 130 -- systemctl status nginx apache2"
   # Result: Both services running
   ```

2. **Verified Port Configuration**
   ```bash
   ssh root@100.102.0.120 "pct exec 130 -- ss -tlnp | grep -E ':(80|443|8080|8443)'"
   ```
   Found:
   - nginx: `0.0.0.0:80`, `0.0.0.0:443`
   - Apache: `192.168.1.30:8080`, `192.168.1.30:8443`

3. **Tested Backend Connectivity**
   ```bash
   curl -I -k https://192.168.1.30:443 -H 'Host: mail.accelior.com'
   # Result: Connection refused from outside container

   # But from host:
   curl -I http://192.168.1.30 -H 'Host: mail.accelior.com'
   # Result: HTTP/1.1 200 OK
   ```

4. **Discovered the Critical Difference**
   - **mail.accelior.com NPM config:** Forward to `192.168.1.30:443` (nginx)
   - **mail.acmea.tech NPM config:** Forward to `192.168.1.30:8443` (Apache)

5. **Identified iptables Blocking**
   ```bash
   ssh root@100.102.0.120 "pct exec 130 -- iptables -L INPUT -n -v"
   ```
   Found suspicious `fail2ban-WEB` chain:
   ```
   Chain INPUT (policy DROP)
   fail2ban-WEB  tcp  --  *  *  0.0.0.0/0  0.0.0.0/0  multiport dports 80,443
   ```

6. **Examined fail2ban-WEB Chain**
   ```bash
   ssh root@100.102.0.120 "pct exec 130 -- iptables -L fail2ban-WEB -n"
   ```
   Result: **300 REJECT rules** all blocking `0.0.0.0/0` (ALL traffic)
   ```
   Chain fail2ban-WEB (1 references)
   REJECT  all  --  0.0.0.0/0  0.0.0.0/0  reject-with icmp-port-unreachable
   REJECT  all  --  0.0.0.0/0  0.0.0.0/0  reject-with icmp-port-unreachable
   [... 298 more identical rules]
   ```

7. **Verified fail2ban Status**
   ```bash
   ssh root@100.102.0.120 "pct exec 130 -- fail2ban-client status"
   ```
   Result: No `fail2ban-WEB` jail active (orphaned chain from old config)

### Root Cause

**Orphaned fail2ban-WEB iptables chain** containing 300 REJECT rules blocking all traffic to ports 80/443. This was a leftover from a previous fail2ban configuration that was never properly cleaned up. The chain was:
- Not managed by any active fail2ban jail
- Blocking ALL traffic (0.0.0.0/0) instead of specific IPs
- Preventing NPM from reaching nginx on port 443

## Solution Implemented

### Fix 1: Update NPM Configuration (Immediate Workaround)

Connected via SSH chain: MacBook → pve2 → OMV

```bash
# Backup original config
ssh root@100.102.0.120 "ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  cp /data/nginx/proxy_host/18.conf /data/nginx/proxy_host/18.conf.backup'"

# Change port from 443 to 8443
ssh root@100.102.0.120 "ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  sed -i \"s/set \\\$port 443;/set \\\$port           8443;/g\" /data/nginx/proxy_host/18.conf'"

# Reload NPM
ssh root@100.102.0.120 "ssh root@192.168.1.9 'docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  nginx -t && nginx -s reload'"
```

**Result:** ✅ mail.accelior.com immediately accessible via port 8443 (Apache backend)

### Fix 2: Remove Orphaned fail2ban-WEB Chain (Permanent Solution)

```bash
# Remove INPUT rule referencing fail2ban-WEB
ssh root@100.102.0.120 "pct exec 130 -- iptables -D INPUT 2"

# Flush all rules in fail2ban-WEB chain
ssh root@100.102.0.120 "pct exec 130 -- iptables -F fail2ban-WEB"

# Delete the chain
ssh root@100.102.0.120 "pct exec 130 -- iptables -X fail2ban-WEB"

# Save iptables rules permanently
ssh root@100.102.0.120 "pct exec 130 -- bash -c 'mkdir -p /etc/iptables && \
  iptables-save > /etc/iptables/rules.v4'"
```

**Verification:**
```bash
# Confirmed fail2ban-WEB not in saved rules
grep -c 'fail2ban-WEB' /etc/iptables/rules.v4
# Result: 0

# Tested port 443 access
curl -I -k https://192.168.1.30:443 -H 'Host: mail.accelior.com'
# Result: HTTP/1.1 200 OK
```

## Post-Fix Status

### NPM Configuration
- **mail.accelior.com:** Forwards to `192.168.1.30:8443` (Apache HTTPS)
- **mail.acmea.tech:** Forwards to `192.168.1.30:8443` (Apache HTTPS)
- Both bypass nginx port 443 entirely
- Both now use the same reliable backend

### Firewall Status
- **fail2ban-WEB chain:** Removed permanently
- **Active fail2ban jails:**
  - dovecot, dovecot-iptables
  - exim, exim-iptables
  - hestia-iptables
  - phpmyadmin-auth
  - recidive
  - ssh-iptables
  - vsftpd-iptables
- **Port 443:** Now accessible (no longer blocked)
- **Port 8443:** Accessible (always was via firewall ACCEPT rule)

### Service Status
```bash
# Final verification
curl -I https://mail.accelior.com
HTTP/2 200 OK
server: openresty
content-type: text/html; charset=UTF-8
set-cookie: roundcube_sessid=...

# Roundcube loading correctly
curl -sL https://mail.accelior.com | grep -i roundcube
<title>Roundcube Webmail :: Welcome to Roundcube Webmail</title>
```

## Additional Issue: Tailscale Connectivity

During troubleshooting, Tailscale service crashed on the troubleshooting workstation, causing temporary loss of connectivity to infrastructure servers.

**Symptoms:**
```bash
/Applications/Tailscale.app/Contents/MacOS/Tailscale status
# Result: Tailscale is stopped.
```

**Resolution:**
```bash
killall Tailscale IPNExtension
open /Applications/Tailscale.app
```

**Note:** This was unrelated to the webmail issue. User initially thought mail.accelior.com was "blocked again" but it was actually Tailscale connectivity loss.

## Lessons Learned

1. **Port 8443 vs 443:** Apache on port 8443 bypasses fail2ban-WEB chain, nginx on port 443 did not
2. **Orphaned iptables chains:** Always clean up iptables chains when disabling fail2ban jails
3. **Hestia firewall management:** Container uses `hestia-iptables.service` for rule persistence
4. **NPM configuration:** Both mail domains now use same backend (8443) for consistency

## Prevention

### Monitor for Similar Issues
```bash
# Check for orphaned fail2ban chains
iptables -L -n | grep fail2ban

# Verify fail2ban jails match iptables chains
fail2ban-client status | grep "Jail list"
```

### Regular Maintenance
- Review iptables rules quarterly
- Clean up orphaned chains when disabling fail2ban jails
- Document all firewall rule changes

## Related Documentation

- NPM Configuration: `/etc/nginx/proxy_host/18.conf` on NPM container
- Mail Server Firewall: `/etc/iptables/rules.v4` in LXC 130
- Hestia Config: `/usr/local/hestia/` in LXC 130
- fail2ban Config: `/etc/fail2ban/` in LXC 130

## Files Modified

1. **NPM Proxy Host Config**
   - File: `/data/nginx/proxy_host/18.conf` (in nginx-proxy-manager container)
   - Change: `set $port 443;` → `set $port 8443;`
   - Backup: `/data/nginx/proxy_host/18.conf.backup`

2. **LXC 130 iptables**
   - Removed: fail2ban-WEB chain and INPUT reference
   - Saved: `/etc/iptables/rules.v4`

## Commands Reference

### Quick Diagnostics
```bash
# Check NPM logs for a domain
ssh root@192.168.1.9 "docker exec nginx-proxy-manager-nginx-proxy-manager-1 \
  tail -50 /data/logs/proxy-host-18_error.log"

# Check mail server firewall
ssh root@100.102.0.120 "pct exec 130 -- iptables -L INPUT -n -v | head -20"

# Test backend connectivity
ssh root@100.102.0.120 "pct exec 130 -- curl -I http://192.168.1.30:8080"

# Check fail2ban status
ssh root@100.102.0.120 "pct exec 130 -- fail2ban-client status"
```

### Restart Services
```bash
# Reload NPM nginx
ssh root@192.168.1.9 "docker exec nginx-proxy-manager-nginx-proxy-manager-1 nginx -s reload"

# Restart mail server nginx
ssh root@100.102.0.120 "pct exec 130 -- systemctl restart nginx"

# Restart Tailscale
killall Tailscale IPNExtension
open /Applications/Tailscale.app
```

## Success Metrics

- ✅ mail.accelior.com responding with HTTP 200
- ✅ Roundcube webmail login page loading
- ✅ Valid SSL certificate (Let's Encrypt)
- ✅ No 502 errors in NPM logs
- ✅ Port 443 accessible (fail2ban removed)
- ✅ Configuration persistent across reboots

---

**Resolved by:** Claude Code AI Assistant
**Approved by:** System Administrator
**Follow-up:** Monitor for 48 hours to ensure stability

## Infrastructure Database Update

Added Tailscale VPN configuration to the infrastructure database (`infrastructure-db/infrastructure.db`):

### Tailscale Network Configuration

```sql
-- Network entry
INSERT INTO networks (network_name, cidr, purpose, security_zone, notes)
VALUES ('tailscale', '100.64.0.0/10', 'VPN mesh network for secure remote access', 'management', 
        'Tailscale WireGuard-based mesh VPN. Network: znutarr@. CGNAT range 100.64.0.0/10');

-- Added hosts
- macbookpro-jm (physical, development workstation)
- pve2 (already exists)
- omv (already exists)

-- Network interfaces (tailscale0)
- macbookpro-jm: tailscale0 (virtual)
- omv: tailscale0 (virtual)
- pve2: tailscale0 (virtual)

-- IP addresses
- 100.101.39.149 → macbookpro-jm
- 100.98.117.70 → openmediavault (omv)
- 100.102.0.120 → pve-home-asrock (pve2)
```

### Query Tailscale Configuration

```bash
# View Tailscale network summary
cd /Users/jm/Codebase/internet-control/infrastructure-db
sqlite3 infrastructure.db "
SELECT h.hostname, ni.interface_name, ip.ip_address, ip.hostname as tailscale_hostname
FROM hosts h
JOIN network_interfaces ni ON h.id = ni.host_id
JOIN ip_addresses ip ON ni.id = ip.interface_id
WHERE ni.interface_name = 'tailscale0'
ORDER BY h.hostname;"

# Expected output:
# macbookpro-jm|tailscale0|100.101.39.149|macbookpro-jm
# omv|tailscale0|100.98.117.70|openmediavault
# pve2|tailscale0|100.102.0.120|pve-home-asrock
```

### Tailscale Status During Troubleshooting

**Active Peers:**
- macbookpro-jm (100.101.39.149) - macOS - ✅ Online
- openmediavault (100.98.117.70) - Linux - ✅ Online
- pve-home-asrock (100.102.0.120) - Linux - ✅ Online

**Offline Peers (not added to database):**
- proxmox-backup-server-pbs (100.78.42.63) - Last seen: Oct 19
- proxmox-home-server (100.65.98.107) - Last seen: Oct 19
- samsung-sm-f946b (100.76.232.107) - Last seen: Jul 16
- samsung-sm-s911b (100.73.146.154) - Last seen: Sep 28

**Tailscale Network:**
- Tailnet: znutarr@
- Primary Relay: Dubai (dbi) - 17.2ms latency
- Health: No issues detected
- Version: 1.88.4

### Tailscale Restart Issue

Tailscale service crashed twice during this troubleshooting session. This appears to be an intermittent issue with the macOS Tailscale client, possibly related to the MagicSock ReceiveIPv4 issue encountered earlier.

**Restart procedure:**
```bash
killall Tailscale IPNExtension
open /Applications/Tailscale.app
# Wait 5-10 seconds for connection establishment
```

---

**Database Last Updated:** October 29, 2025
**Tailscale Configuration Version:** 1.88.4
