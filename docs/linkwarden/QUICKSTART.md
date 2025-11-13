# Linkwarden Quick Start

## ✅ Deployment Complete

**Status**: Infrastructure deployed and configured
**Waiting on**: Cloudflare DNS record creation

## 🚀 Complete These 2 Steps to Go Live

### Step 1: Add Cloudflare DNS Record (2 minutes)

1. Go to https://dash.cloudflare.com
2. Select domain: `acmea.tech`
3. Go to **DNS** → **Records**
4. Click **Add record**
5. Configure:
   ```
   Type:    CNAME
   Name:    link
   Target:  base.acmea.tech
   Proxy:   🟠 Proxied (ENABLED)
   TTL:     Auto
   ```
6. Click **Save**

### Step 2: Enable SSL in NPM (3 minutes)

1. Open http://192.168.1.9:81
2. Go to **Proxy Hosts**
3. Find `link.acmea.tech` (should be at the top)
4. Click **⋮** → **Edit**
5. Go to **SSL** tab
6. Configure:
   ```
   SSL Certificate: Request a new SSL Certificate
   ☑ Force SSL
   ☑ HTTP/2 Support
   ☑ HSTS Enabled
   ```
7. Click **Save**

## ✅ You're Done!

Visit https://link.acmea.tech and create your admin account.

## 📍 Access Points

- **Public**: https://link.acmea.tech (after DNS/SSL)
- **Internal**: http://192.168.1.20:3002
- **NPM Admin**: http://192.168.1.9:81

## 🛠️ Management Commands

```bash
# Check status
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose ps"

# View logs
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose logs -f"

# Restart
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose restart"
```

## 📊 Infrastructure Details

- **Container**: CT 111 (docker-debian) on pve2
- **IP**: 192.168.1.20
- **Port**: 3002
- **Database**: Service ID 60
- **NPM Proxy**: ID 40

## 🆘 Troubleshooting

**DNS not resolving?**
```bash
nslookup link.acmea.tech
```
Wait 2-5 minutes after creating the record.

**SSL certificate fails?**
- Ensure DNS is resolving first
- Verify ports 80/443 are accessible
- Check NPM logs: `docker logs nginx-proxy-manager-nginx-proxy-manager-1`

**502 Bad Gateway?**
```bash
# Verify Linkwarden is running
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose ps"

# Should show all containers as "Up (healthy)"
```

## 📚 Full Documentation

See `docs/linkwarden/` for:
- Complete installation guide
- Detailed troubleshooting
- Advanced configuration
- Backup procedures

---

**Deployed**: 2025-10-19
**Ready for**: DNS configuration
