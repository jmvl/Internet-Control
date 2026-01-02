# Pi-hole Container Crash - Sysctl Permission Denied

**Date**: 2025-12-10
**Severity**: Critical (network-wide DNS outage)
**Duration**: ~1 hour
**Status**: Resolved

## Symptoms

- No internet connectivity from WiFi devices
- DNS resolution failing network-wide
- Pi-hole container (192.168.1.5) unreachable

## Investigation

### Initial Diagnosis
```bash
# Infrastructure checks
ping 192.168.1.3   # OPNsense: OK
ping 192.168.1.2   # OpenWrt: OK
ping 192.168.1.5   # Pi-hole: UNREACHABLE
ping 8.8.8.8       # Internet: OK
```

**Finding**: Pi-hole DNS server was down, causing all DNS-dependent traffic to fail.

### Container Status
```bash
ssh root@192.168.1.10 "pct exec 111 -- docker ps -a | grep pihole"
# Output: pihole  Exited (126) About an hour ago
```

### Error on Restart Attempt
```bash
docker start pihole
# Error: OCI runtime create failed: runc create failed: unable to start
# container process: error during container init: open sysctl
# net.ipv4.ip_unprivileged_port_start file: reopen fd 8: permission denied
```

## Root Cause

The LXC container (CT 111 - docker-debian) running Docker had AppArmor restrictions that prevented the Pi-hole container from modifying sysctl parameters during initialization.

Pi-hole requires sysctl access for:
- `net.ipv4.ip_unprivileged_port_start` - Binding to port 53 (privileged port)
- `net.ipv4.ping_group_range` - ICMP functionality

The container had been running previously, but after some system event (possibly Proxmox/LXC update), the AppArmor profile became more restrictive.

## Resolution

### Step 1: Update LXC Container Configuration
```bash
ssh root@192.168.1.10

# Add AppArmor unconfined profile to LXC config
cat >> /etc/pve/lxc/111.conf << 'EOF'
lxc.apparmor.profile: unconfined
lxc.cap.drop:
EOF
```

### Step 2: Restart LXC Container
```bash
pct stop 111 && pct start 111
```

### Step 3: Start Pi-hole Container
```bash
pct exec 111 -- docker start pihole
```

### Step 4: Verify DNS Resolution
```bash
ping 192.168.1.5           # Pi-hole reachable
dig @192.168.1.5 google.com # DNS working
```

## Prevention

1. **LXC Config Change**: Added permanent AppArmor unconfined profile
2. **Documentation**: Created `/docs/pihole/pihole-installation.md` with troubleshooting steps
3. **Database Update**: Updated infrastructure DB with correct container info
4. **Recommendation**: Consider adding fallback DNS (8.8.8.8) to OPNsense

## OPNsense DNS Configuration Issue

OPNsense had only Pi-hole configured as DNS with no fallback:
```xml
<dnsserver>192.168.1.5</dnsserver>
```

**Recommendation**: Add secondary DNS server in OPNsense:
- System → Settings → General
- Add: `8.8.8.8` or `1.1.1.1` as secondary DNS

This ensures network continues to function if Pi-hole goes down.

## Files Modified

| File | Change |
|------|--------|
| `/etc/pve/lxc/111.conf` | Added `lxc.apparmor.profile: unconfined` |
| Infrastructure DB | Updated pihole container_id and status |

## Related Documentation

- Pi-hole Installation: `/docs/pihole/pihole-installation.md`
- Infrastructure Database: `/infrastructure-db/infrastructure.db`
