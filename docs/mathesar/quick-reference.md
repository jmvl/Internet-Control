# Mathesar Quick Reference

## Essential Commands

### Access Mathesar
```bash
# Current working method
ssh root@192.168.1.20
cd /root/mathesar-project
docker compose run --rm -p 8080:8000 service bash -c "python manage.py runserver 0.0.0.0:8000"

# Then browse to: http://192.168.1.20:8080
```

### Service Management
```bash
# Check container status
docker ps | grep mathesar

# View logs
docker logs mathesar_service
docker logs mathesar_db

# Database access
docker exec -it mathesar_db psql -U mathesar -d mathesar_django
```

### Troubleshooting
```bash
# Test connectivity
curl -I http://192.168.1.20:8080

# Check port usage
netstat -tlpn | grep :8080

# Verify database health
docker exec mathesar_db pg_isready -d mathesar_django -U mathesar
```

## Access Information

- **URL**: http://192.168.1.20:8080
- **Status**: ✅ Working (direct service access)
- **Setup Required**: Yes (admin user creation on first access)

## Known Issues

1. **Caddy HTTPS Redirect**: Automatic redirect to port 443 (not accessible externally)
2. **Solution**: Using direct service access on port 8080
3. **Future Fix**: Resolve Caddy configuration for proper HTTP access

## File Locations

- **Project**: `/root/mathesar-project/`
- **Data**: `/root/mathesar-project/msar/pgdata/`
- **Config**: `/root/mathesar-project/.env`
- **Documentation**: `/docs/mathesar/`