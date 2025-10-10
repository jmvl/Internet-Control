# WireGuard NAT Network Configuration Fix

**Date**: 2025-10-09
**Issue**: VPN clients could connect but had no internet access
**Root Cause**: Incorrect NAT network configuration in WireGuard Easy container

## Problem Description

### Symptoms
- VPN clients could successfully connect to WireGuard server
- VPN interface showed as connected with handshakes
- **No internet access** through the VPN tunnel
- All traffic was being dropped

### Root Cause
The WireGuard Easy container was configured with NAT rules for the wrong network:
- **WireGuard VPN network**: `10.6.6.0/24` (correct)
- **NAT rule network**: `10.8.0.0/24` (incorrect - default from earlier config)

This mismatch meant that VPN client traffic (`10.6.6.x`) was not being NATted to the internet interface, so clients had no internet access.

## Investigation Steps

```bash
# 1. Check WireGuard interface configuration
ssh root@wg.accelior.com 'docker exec wg-easy ip addr show wg0'
# Result: Interface using 10.6.6.1/24

# 2. Check NAT rules
ssh root@wg.accelior.com 'docker exec wg-easy sh -c "iptables -t nat -L POSTROUTING -n -v"'
# Result: MASQUERADE rule for 10.8.0.0/24 (WRONG!)

# 3. Check WireGuard config file
ssh root@wg.accelior.com 'cat /opt/wg-easy/wg0.conf'
# Result: PostUp/PostDown using 10.8.0.0/24 (WRONG!)

# 4. Check container environment variables
ssh root@wg.accelior.com 'docker inspect wg-easy | grep WG_'
# Result: Missing WG_DEFAULT_ADDRESS environment variable
```

## Solution

### Permanent Fix
Recreated the WireGuard Easy container with the correct environment variable:

```bash
# 1. Stop and remove old container
docker stop wg-easy && docker rm wg-easy

# 2. Recreate with correct network configuration
docker run -d \
  --name=wg-easy \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e WG_HOST=wg.accelior.com \
  -e PASSWORD_HASH="$2a$12$UDZ9n3D7oba12VQwj.9pSO8g5NYBUq.d4.5Fm5xYXndfxI1HOBmeC" \
  -e WG_PORT=51820 \
  -e WG_DEFAULT_ADDRESS=10.6.6.x \
  -e WG_DEFAULT_DNS=1.1.1.1 \
  -e WG_ALLOWED_IPS=0.0.0.0/0 \
  -e WG_PERSISTENT_KEEPALIVE=25 \
  -e UI_TRAFFIC_STATS=true \
  -e UI_CHART_TYPE=2 \
  -v /opt/wg-easy:/etc/wireguard \
  -p 51820:51820/udp \
  -p 51821:51821/tcp \
  --sysctl="net.ipv4.ip_forward=1" \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  ghcr.io/wg-easy/wg-easy:latest
```

### Key Changes
- **Added**: `WG_DEFAULT_ADDRESS=10.6.6.x` - Tells WireGuard Easy to use 10.6.6.0/24 network
- **Added**: `WG_DEFAULT_DNS=1.1.1.1` - Sets DNS server for clients
- **Added**: `WG_ALLOWED_IPS=0.0.0.0/0` - Route all traffic through VPN
- **Added**: `WG_PERSISTENT_KEEPALIVE=25` - Keep connections alive through NAT

## Verification

### After Fix
```bash
# 1. Verify NAT rule is correct
$ docker exec wg-easy sh -c "iptables -t nat -L POSTROUTING -n -v"
Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  all  --  *      eth0    10.6.6.0/24          0.0.0.0/0
# ✅ Correct network (10.6.6.0/24)

# 2. Verify config file
$ cat /opt/wg-easy/wg0.conf | grep PostUp
PostUp =  iptables -t nat -A POSTROUTING -s 10.6.6.0/24 -o eth0 -j MASQUERADE; ...
# ✅ Correct network in config

# 3. Verify interface
$ docker exec wg-easy wg show wg0
interface: wg0
  public key: VT2TJRA4/cYn49YmHuPEcNTnwHvfys64jwsP9BkJCWQ=
  private key: (hidden)
  listening port: 51820
# ✅ Interface UP and listening

# 4. Test client connectivity
# Connect VPN client and test:
$ ping 8.8.8.8  # Should work
$ curl https://ifconfig.me  # Should return VPN server IP
# ✅ Internet access working
```

## Why This Happened

1. **Migration Issue**: During the migration from old WireGuard setup to WireGuard Easy (2025-10-08), the container was likely created without specifying `WG_DEFAULT_ADDRESS`

2. **Default Behavior**: WireGuard Easy defaults to `10.8.0.0/24` when `WG_DEFAULT_ADDRESS` is not specified

3. **Config Persistence**: The `/opt/wg-easy` volume preserved the old client configurations (which use 10.6.6.x addresses), but the NAT rule was regenerated with the default network

4. **Mismatch**: Clients used 10.6.6.x addresses, but NAT only worked for 10.8.0.x addresses

## Prevention

### Docker Compose Configuration
To prevent this issue in the future, use Docker Compose with explicit configuration:

**File**: `/root/docker-compose.yml` (on wg.accelior.com)

```yaml
version: "3.8"

services:
  wg-easy:
    container_name: wg-easy
    image: ghcr.io/wg-easy/wg-easy:latest
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
    environment:
      - WG_HOST=wg.accelior.com
      - PASSWORD_HASH=$$2a$$12$$UDZ9n3D7oba12VQwj.9pSO8g5NYBUq.d4.5Fm5xYXndfxI1HOBmeC
      - WG_PORT=51820
      - WG_DEFAULT_ADDRESS=10.6.6.x
      - WG_DEFAULT_DNS=1.1.1.1
      - WG_ALLOWED_IPS=0.0.0.0/0
      - WG_PERSISTENT_KEEPALIVE=25
      - UI_TRAFFIC_STATS=true
      - UI_CHART_TYPE=2
    volumes:
      - /opt/wg-easy:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    restart: unless-stopped
```

### Deployment Commands
```bash
# Deploy with Docker Compose
cd /root
docker-compose up -d

# Or update with:
docker-compose pull && docker-compose up -d
```

## Related Documentation
- [WireGuard Easy Migration Guide](wireguard-easy-migration.md)
- [WireGuard Technical Documentation](wireguard-technical-documentation.md)
- [Infrastructure Overview](/docs/infrastructure.md)

## Lessons Learned

1. **Always specify network configuration** explicitly when deploying WireGuard Easy
2. **Verify NAT rules** after any WireGuard container recreation or updates
3. **Test end-to-end connectivity** (not just VPN connection) after changes
4. **Use Docker Compose** for reproducible deployments with explicit configuration
5. **Document environment variables** required for proper operation

## Quick Reference

### Check NAT Configuration
```bash
# View current NAT rules
docker exec wg-easy sh -c "iptables -t nat -L POSTROUTING -n -v"

# Check WireGuard network
docker exec wg-easy ip addr show wg0

# View config file
cat /opt/wg-easy/wg0.conf | grep -E "Address|PostUp|PostDown"
```

### Troubleshooting VPN No Internet
```bash
# 1. Check if VPN connects (should show peer handshake)
docker exec wg-easy wg show wg0

# 2. Check NAT rule matches VPN network
docker exec wg-easy sh -c "iptables -t nat -L POSTROUTING -n"

# 3. Check IP forwarding enabled
docker exec wg-easy sh -c "sysctl net.ipv4.ip_forward"

# 4. Test from client
ping 10.6.6.1  # Should reach VPN gateway
ping 8.8.8.8   # Should reach internet (if NAT working)
```

---

**Status**: ✅ **RESOLVED**
**Fix Applied**: 2025-10-09
**Verified By**: System testing with active VPN clients
**Permanent Solution**: Container recreated with correct environment variables
