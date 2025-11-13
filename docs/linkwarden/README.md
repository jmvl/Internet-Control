# Linkwarden Documentation

**Deployment Date**: October 19, 2025
**Status**: Active and Healthy
**Access URL**: https://link.acmea.tech (after DNS/NPM configuration)

## Quick Links

- [Installation Guide](./installation-guide.md) - Complete installation and configuration documentation
- [Quick Setup](./quick-setup.md) - Manual DNS and NPM configuration steps

## Service Overview

**Linkwarden** is a self-hosted, collaborative bookmark manager that allows you to:
- Save and organize bookmarks with tags and collections
- Full-text search across all saved links
- Automatic webpage archiving and screenshots
- Collaborative bookmark sharing with teams
- Browser extensions for easy saving
- Public/private bookmark collections

## Deployment Information

### Infrastructure Details
- **Container**: CT 111 (docker-debian) on Proxmox host pve2
- **IP Address**: 192.168.1.20
- **Internal Port**: 3002
- **Installation Path**: `/opt/linkwarden`

### Stack Components
1. **Linkwarden** (ghcr.io/linkwarden/linkwarden:latest)
   - Main web application
   - Port: 3002:3000
   - Health: Monitored

2. **PostgreSQL 16 Alpine**
   - Database backend
   - Port: 5432 (internal)
   - Data: Persisted to `./pgdata`

3. **MeiliSearch v1.12.8**
   - Full-text search engine
   - Port: 7700 (internal)
   - Index: Persisted to `./meili_data`

### Network Configuration
- **Internal Access**: http://192.168.1.20:3002
- **External Access**: https://link.acmea.tech (via NPM on 192.168.1.9)
- **Reverse Proxy**: Nginx Proxy Manager on OMV

## Current Status

```bash
# Check service status
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose ps"
```

Expected output:
```
NAME                       STATUS
linkwarden-linkwarden-1    Up (healthy)
linkwarden-meilisearch-1   Up
linkwarden-postgres-1      Up
```

## Next Steps for Public Access

To enable public access via https://link.acmea.tech:

1. **Configure Cloudflare DNS** (see [Quick Setup](./quick-setup.md#step-1-cloudflare-dns-configuration))
   - Create CNAME: `link` → `base.acmea.tech`

2. **Configure Nginx Proxy Manager** (see [Quick Setup](./quick-setup.md#step-2-nginx-proxy-manager-configuration))
   - Add proxy host for link.acmea.tech
   - Forward to 192.168.1.20:3002
   - Enable SSL with Let's Encrypt

3. **Test Access**
   - Visit https://link.acmea.tech
   - Create admin account
   - Install browser extension

## Management Commands

### Service Management
```bash
# View logs
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose logs -f"

# Restart all services
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose restart"

# Stop services
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose down"

# Start services
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose up -d"
```

### Updates
```bash
# Update to latest version
ssh root@192.168.1.20 "cd /opt/linkwarden && docker compose pull && docker compose up -d"
```

### Backups
```bash
# Backup all data
ssh root@192.168.1.20 "cd /opt/linkwarden && tar -czf linkwarden-backup-$(date +%Y%m%d).tar.gz pgdata/ data/ meili_data/ .env docker-compose.yml"
```

## Database Information

Linkwarden has been registered in the infrastructure database:

- **Service ID**: 60
- **Service Name**: Linkwarden
- **Service Type**: web
- **Port**: 3002
- **Status**: healthy
- **Criticality**: medium

Three containers registered:
1. `linkwarden-linkwarden-1` - Main application
2. `linkwarden-postgres-1` - Database
3. `linkwarden-meilisearch-1` - Search engine

## Resources

- **Official Website**: https://linkwarden.app
- **Documentation**: https://docs.linkwarden.app
- **GitHub**: https://github.com/linkwarden/linkwarden
- **Docker Image**: https://ghcr.io/linkwarden/linkwarden

## Support

For issues or questions:
1. Check the [installation guide](./installation-guide.md#troubleshooting) troubleshooting section
2. Review container logs
3. Consult official documentation
4. Check GitHub issues

---

**Last Updated**: 2025-10-19
**Maintained By**: Infrastructure Team
