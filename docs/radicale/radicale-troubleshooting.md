# Radicale Access Troubleshooting Guide

## Problem Summary
The Radicale CalDAV/CardDAV server is inaccessible because it's bound to localhost (127.0.0.1:5232) inside a Docker container on the Hestia server (192.168.1.30).

## Solution Overview

### 1. Fix Docker Binding
The current container binds to `127.0.0.1:5232`, making it accessible only from within the container host. The solution is to bind to the host's IP address.

**Quick Fix:**
```bash
# SSH into Hestia server
ssh root@192.168.1.30

# Stop and recreate container with proper binding
docker stop radicale
docker rm radicale
docker run -d \
  --name radicale \
  -p 192.168.1.30:5232:5232 \
  -v radicale-data:/data \
  --restart unless-stopped \
  tomsquest/docker-radicale
```

### 2. Configure Nginx Proxy Manager

1. Access Nginx Proxy Manager: http://192.168.1.9:81
2. Add new Proxy Host:
   - **Domain Names**: `radicale.vega-messenger.com`
   - **Scheme**: `http`
   - **Forward Hostname/IP**: `192.168.1.30`
   - **Forward Port**: `5232`
   - **Enable SSL**: Yes (Let's Encrypt)
   - **Force SSL**: Yes

3. Under "Advanced" tab, add:
```nginx
proxy_set_header Depth $http_depth;
proxy_set_header Destination $http_destination;
proxy_set_header Overwrite $http_overwrite;
proxy_set_header Prefer $http_prefer;
proxy_connect_timeout 90;
proxy_send_timeout 90;
proxy_read_timeout 90;
proxy_buffering off;
proxy_request_buffering off;
client_max_body_size 100M;
```

### 3. Complete Setup Script
Run the provided script on the Hestia server:
```bash
# Copy and run the fix script
scp fix-radicale-access.sh root@192.168.1.30:/tmp/
ssh root@192.168.1.30 'bash /tmp/fix-radicale-access.sh'
```

## Testing Access

### Local Test (from Hestia server):
```bash
curl http://192.168.1.30:5232/.web/
```

### Network Test (from another machine):
```bash
curl http://192.168.1.30:5232/.web/
```

### External Test (after proxy setup):
```bash
curl https://radicale.vega-messenger.com/.web/
```

## Client Configuration

### iOS/macOS:
- Server: `https://radicale.vega-messenger.com/`
- Username: Your Radicale username
- Password: Your Radicale password

### Android (DAVx5):
- Base URL: `https://radicale.vega-messenger.com/`
- Username & Password as configured

### Thunderbird:
- CalDAV: `https://radicale.vega-messenger.com/`
- CardDAV: `https://radicale.vega-messenger.com/`

## Common Issues

### Issue 1: Connection Refused
**Cause**: Docker still binding to localhost
**Fix**: Check docker port binding:
```bash
docker port radicale
# Should show: 5232/tcp -> 192.168.1.30:5232
```

### Issue 2: 502 Bad Gateway from Nginx
**Cause**: Firewall blocking connection
**Fix**: Allow connection from proxy:
```bash
ufw allow from 192.168.1.9 to any port 5232
```

### Issue 3: Authentication Failed
**Cause**: No users created
**Fix**: Create user:
```bash
docker exec -it radicale htpasswd -B /data/users username
```

### Issue 4: SSL Certificate Error
**Cause**: Let's Encrypt not configured
**Fix**: Enable SSL in Nginx Proxy Manager with Let's Encrypt

## Security Recommendations

1. **Bind to specific IP**: Use `192.168.1.30:5232` instead of `0.0.0.0:5232`
2. **Use HTTPS only**: Force SSL in Nginx Proxy Manager
3. **Strong passwords**: Use bcrypt encryption for htpasswd
4. **Firewall rules**: Only allow proxy server access to port 5232
5. **Regular backups**: Backup `/data` volume regularly

## Backup and Restore

### Backup:
```bash
docker exec radicale tar -czf - /data > radicale-backup-$(date +%Y%m%d).tar.gz
```

### Restore:
```bash
docker exec -i radicale tar -xzf - -C / < radicale-backup-20240101.tar.gz
```

## Monitoring

Check container health:
```bash
docker ps | grep radicale
docker logs radicale --tail 50
```

Monitor access logs:
```bash
docker logs radicale -f | grep -E "(GET|PUT|DELETE|PROPFIND)"
```