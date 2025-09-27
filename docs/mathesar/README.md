# Mathesar Documentation

Mathesar is a web-based interface for PostgreSQL databases that provides a spreadsheet-like UI for database management.

## Documentation Index

### 📋 Quick Start
- [**Quick Reference**](quick-reference.md) - Essential commands and access information

### 🔧 Technical Documentation
- [**Installation Guide**](installation.md) - Complete installation and configuration process

## Current Status

- **Status**: ✅ **Working**
- **Access URL**: http://192.168.1.20:8080
- **Installation Date**: September 17, 2025
- **Location**: Docker VM (192.168.1.20)

## Key Information

### Access Details
- **URL**: http://192.168.1.20:8080
- **Method**: Direct service access (bypassing Caddy proxy)
- **Setup Required**: Admin user creation on first access

### Known Issues
- **Caddy HTTPS Redirect**: Automatic redirect to port 443 causes external access issues
- **Current Workaround**: Direct service access on port 8080 (working)

### Container Stack
- `mathesar_service`: Main application (healthy)
- `mathesar_db`: PostgreSQL database (healthy)
- `caddy-reverse-proxy`: Web server (bypassed due to HTTPS issues)

## Quick Commands

```bash
# Access the service
ssh root@192.168.1.20
cd /root/mathesar-project
docker compose run --rm -p 8080:8000 service bash -c "python manage.py runserver 0.0.0.0:8000"

# Then browse to: http://192.168.1.20:8080
```

## Related Documentation

- [Docker Containers Overview](../docker-containers-overview.md)
- [Infrastructure Overview](../infrastructure.md)
- [Supabase Documentation](../Supabase/) (alternative database interface)