# Pi-hole DNS Server Installation & Configuration

**Last Updated**: 2025-12-10
**Location**: Docker container on CT 111 (docker-debian) @ pve2
**IP Address**: 192.168.1.5 (via macvlan network)
**Status**: Production - Critical infrastructure

## Overview

Pi-hole is the primary DNS server for the entire home network, providing:
- DNS resolution for all LAN clients
- Ad blocking and tracking protection
- DNS query logging and statistics
- Custom DNS entries for local services

## Architecture

```
                     Internet
                         |
                         v
                   ┌─────────────┐
                   │  OPNsense   │
                   │ 192.168.1.3 │
                   │  (Gateway)  │
                   └──────┬──────┘
                          │
            DNS Server: 192.168.1.5
                          │
                          v
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox VE (pve2)                        │
│                      192.168.1.10                           │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           LXC Container 111 (docker-debian)           │  │
│  │                   192.168.1.20                         │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────────┐ │  │
│  │  │         Docker: pihole/pihole:latest             │ │  │
│  │  │                                                   │ │  │
│  │  │  Network: pihole_macvlan                         │ │  │
│  │  │  IP: 192.168.1.5                                 │ │  │
│  │  │                                                   │ │  │
│  │  │  Ports (via macvlan):                            │ │  │
│  │  │   - 53/tcp (DNS)                                 │ │  │
│  │  │   - 53/udp (DNS)                                 │ │  │
│  │  │   - 80/tcp (Web Admin)                           │ │  │
│  │  └──────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Installation Details

### Host Configuration

**Proxmox LXC Container (CT 111)**:
- Name: docker-debian
- IP: 192.168.1.20
- Features: nesting=1
- AppArmor: unconfined (required for Pi-hole sysctl access)

**LXC Config** (`/etc/pve/lxc/111.conf`):
```
features: nesting=1
lxc.apparmor.profile: unconfined
lxc.cap.drop:
```

### Docker Network

**Macvlan Network** (allows container to have its own IP on LAN):
```bash
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.3 \
  -o parent=eth0 \
  pihole_macvlan
```

### Container Configuration

**Docker Run Command**:
```bash
docker run -d \
  --name pihole \
  --hostname pihole \
  --network pihole_macvlan \
  --ip 192.168.1.5 \
  --privileged \
  --restart=unless-stopped \
  -e TZ="Europe/Brussels" \
  -e WEBPASSWORD="your_admin_password" \
  -e PIHOLE_DNS_="1.1.1.1;8.8.8.8" \
  -e DNSMASQ_LISTENING="all" \
  -v /data/compose/19/etc-pihole:/etc/pihole \
  -v /data/compose/19/etc-dnsmasq.d:/etc/dnsmasq.d \
  pihole/pihole:latest
```

**Environment Variables**:
| Variable | Value | Description |
|----------|-------|-------------|
| TZ | Europe/Brussels | Timezone |
| WEBPASSWORD | [redacted] | Admin panel password |
| PIHOLE_DNS_ | 1.1.1.1;8.8.8.8 | Upstream DNS servers |
| DNSMASQ_LISTENING | all | Listen on all interfaces |

**Volume Mounts**:
| Container Path | Host Path | Purpose |
|----------------|-----------|---------|
| /etc/pihole | /data/compose/19/etc-pihole | Pi-hole config & databases |
| /etc/dnsmasq.d | /data/compose/19/etc-dnsmasq.d | Dnsmasq custom config |

## Network Configuration

### OPNsense DNS Settings

OPNsense (192.168.1.3) is configured to use Pi-hole as DNS:
- System → Settings → General → DNS Servers: `192.168.1.5`
- DHCP Server distributes 192.168.1.5 as DNS to all clients

### Macvlan Considerations

Since Pi-hole uses macvlan networking:
- Container has its own MAC address on the LAN
- Container IP (192.168.1.5) is directly accessible from LAN
- **Important**: Host (192.168.1.20) cannot directly communicate with container (192.168.1.5) due to macvlan isolation
- Workaround: Create a macvlan interface on host if needed

## Management

### Web Admin Panel
- URL: http://192.168.1.5/admin
- Password: Set via WEBPASSWORD environment variable

### SSH Access
```bash
# Access LXC container
ssh root@192.168.1.10
pct exec 111 -- bash

# Docker commands
docker logs pihole
docker exec -it pihole bash
```

### Common Commands
```bash
# Check status
docker ps | grep pihole

# View logs
docker logs -f pihole

# Restart container
docker restart pihole

# Update Pi-hole
docker pull pihole/pihole:latest
docker stop pihole && docker rm pihole
# Then run docker run command above

# Check DNS resolution
dig @192.168.1.5 google.com
```

## Troubleshooting

### Container Won't Start - Sysctl Permission Denied

**Error**:
```
OCI runtime create failed: runc create failed: unable to start container process:
error during container init: open sysctl net.ipv4.ip_unprivileged_port_start file:
reopen fd 8: permission denied
```

**Cause**: LXC container AppArmor profile blocking sysctl access

**Solution**:
```bash
# On Proxmox host (pve2)
ssh root@192.168.1.10

# Add to LXC config
cat >> /etc/pve/lxc/111.conf << 'EOF'
lxc.apparmor.profile: unconfined
lxc.cap.drop:
EOF

# Restart LXC container
pct stop 111 && pct start 111

# Start Pi-hole
pct exec 111 -- docker start pihole
```

### No Internet on Network

**Symptoms**: Devices cannot browse internet, but can ping IPs

**Cause**: Pi-hole is down, DNS resolution failing

**Quick Fix** (temporary):
1. Set DNS manually on device to 8.8.8.8
2. Restart Pi-hole container

**Diagnosis**:
```bash
# Test Pi-hole reachability
ping 192.168.1.5

# Test DNS
dig @192.168.1.5 google.com

# Check container status
ssh root@192.168.1.10 "pct exec 111 -- docker ps -a | grep pihole"
```

### Container Exited

**Check logs**:
```bash
ssh root@192.168.1.10 "pct exec 111 -- docker logs pihole --tail 50"
```

**Common causes**:
- Sysctl permission issues (see above)
- Port 53 already in use
- Volume mount issues

### DNS Not Resolving

1. Check Pi-hole is running: `docker ps | grep pihole`
2. Check Pi-hole can reach upstream: `docker exec pihole dig @1.1.1.1 google.com`
3. Check Pi-hole logs: `docker logs pihole`
4. Verify macvlan network: `docker network inspect pihole_macvlan`

## Backup & Recovery

### Backup Pi-hole Config
```bash
# On CT 111
tar -czf /tmp/pihole-backup-$(date +%Y%m%d).tar.gz \
  /data/compose/19/etc-pihole \
  /data/compose/19/etc-dnsmasq.d
```

### Restore Pi-hole
```bash
# Stop container
docker stop pihole

# Restore config
tar -xzf pihole-backup-YYYYMMDD.tar.gz -C /

# Start container
docker start pihole
```

## Monitoring

### Uptime Kuma
Pi-hole is monitored via Uptime Kuma at 192.168.1.9:3010
- DNS check on 192.168.1.5:53
- HTTP check on http://192.168.1.5/admin

### Health Check
Container has built-in health check that verifies DNS functionality

## Security Considerations

1. **Web Admin Password**: Change default password immediately
2. **Network Isolation**: Pi-hole only accessible from LAN (via macvlan)
3. **Upstream DNS**: Using Cloudflare (1.1.1.1) and Google (8.8.8.8) for privacy
4. **Logging**: DNS query logs stored locally, review retention settings

## Maintenance History

### 2025-12-10 - Container Crash Recovery
- **Issue**: Pi-hole container crashed with sysctl permission error
- **Cause**: LXC AppArmor profile blocking container init
- **Fix**: Added `lxc.apparmor.profile: unconfined` to CT 111 config
- **Duration**: ~30 minutes network outage

## Related Documentation

- Infrastructure Database: `/infrastructure-db/infrastructure.db`
- OPNsense Configuration: `/docs/OPNsense/`
- Network Architecture: `/docs/infrastructure.md`

## References

- [Pi-hole Docker GitHub](https://github.com/pi-hole/docker-pi-hole)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Docker Macvlan Networking](https://docs.docker.com/network/macvlan/)
