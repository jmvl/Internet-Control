# Uptime Kuma API Investigation and Configuration

**Date**: 2026-01-31
**Issue**: Uptime Kuma API endpoint `/api/v1/monitor` not working
**Status**: Resolved - Documentation and working solution provided

## Executive Summary

Uptime Kuma **does not have a built-in REST API** for monitor management. The application uses **Socket.IO** for real-time communication. The `/api/v1/monitor` endpoint that was being tested does not exist in Uptime Kuma.

## Current Setup

- **Location**: docker-host-omv (192.168.1.9:3010)
- **Version**: 2.0.2
- **Container**: uptime-kuma
- **Database**: Embedded MariaDB (SQLite-compatible)
- **API Status**: API keys are enabled in database (`apiKeysEnabled: true`)
- **Admin User**: admin

## Available API Endpoints

Uptime Kuma 2.0.2 provides the following HTTP endpoints:

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/metrics` | GET | Prometheus metrics | Yes (Basic Auth) |
| `/api/push/:pushToken` | POST | Push heartbeat data | No (token-based) |
| `/api/badge/:id/status` | GET | Status badge (SVG) | No (public monitors) |
| `/api/badge/:id/uptime/:duration` | GET | Uptime badge (SVG) | No (public monitors) |
| `/api/badge/:id/ping/:duration` | GET | Ping badge (SVG) | No (public monitors) |
| `/api/badge/:id/cert-exp` | GET | Certificate expiry badge | No (public monitors) |

### Missing Endpoints

**Does NOT exist:**
- `/api/v1/monitor` (POST/GET/PUT/DELETE)
- `/api/v1/status`
- Any REST API for monitor management

## Root Cause Analysis

The confusion stems from:
1. Uptime Kuma uses **Socket.IO** for all monitor operations (add, edit, delete)
2. There is **no official REST API** for monitor management
3. The API key feature (`uk2_ZgIhaLoeCSoxm9t1R5BfqioGtIJCiU_Ebox8W3Z0`) is primarily for:
   - `/metrics` endpoint authentication (replacing basic auth)
   - Future API features (currently limited)

### Verification Steps

```bash
# Check API key status in database
ssh root@192.168.1.9 "docker exec uptime-kuma sqlite3 /app/data/kuma.db \
  'SELECT * FROM setting WHERE key LIKE \"%api%\";'"
# Result: apiKeysEnabled = true

# Check available API routes
ssh root@192.168.1.9 "docker exec uptime-kuma cat /app/server/routers/api-router.js"
# Result: Only badge and push endpoints defined

# Test non-existent endpoint
curl -X POST http://192.168.1.9:3010/api/v1/monitor \
  -H "Authorization: Bearer uk2_ZgIhaLoeCSoxm9t1R5BfqioGtIJCiU_Ebox8W3Z0"
# Result: Returns HTML (Express 404)
```

## Solutions

### Option 1: Python Socket.IO Library (Recommended)

**Library**: `uptime-kuma-api` (already installed: v1.2.1)

**Installation**:
```bash
pip install uptime-kuma-api
```

**Usage**:
```bash
# Set password
export UPTIME_KUMA_PASSWORD='your-admin-password'

# List monitors
python3 /Users/jm/Codebase/internet-control/scripts/add_uptime_kuma_monitor.py list

# Add HTTP monitor
python3 /Users/jm/Codebase/internet-control/scripts/add_uptime_kuma_monitor.py add-http \
  --name "Example API" \
  --url "https://api.example.com" \
  --interval 60 \
  --retries 0

# Add PING monitor
python3 /Users/jm/Codebase/internet-control/scripts/add_uptime_kuma_monitor.py add-ping \
  --name "Router" \
  --hostname "192.168.1.1" \
  --interval 60

# Add TCP port monitor
python3 /Users/jm/Codebase/internet-control/scripts/add_uptime_kuma_monitor.py add-port \
  --name "Database" \
  --hostname "192.168.1.20" \
  --port 5432

# Delete monitor
python3 /Users/jm/Codebase/internet-control/scripts/add_uptime_kuma_monitor.py delete --id 42
```

**Script Location**: `/Users/jm/Codebase/internet-control/scripts/add_uptime_kuma_monitor.py`

**Features**:
- Full monitor CRUD operations
- Support for all monitor types (HTTP, PING, PORT, etc.)
- Error handling and validation
- Batch operations possible

### Option 2: Direct Database Insert (Not Recommended)

**Warning**: This method is risky and should only be used for emergencies.

```sql
INSERT INTO monitor (
    name, type, url, interval, maxretries,
    active, user_id, method, accepted_statuscodes_json,
    created_date
) VALUES (
    'Example Monitor', 'http', 'https://example.com', 60, 0,
    1, 1, 'GET', '["200-299"]',
    DATETIME('now')
);
```

**Requirements**:
- Must restart Uptime Kuma container after insert
- All fields must be correctly populated
- Risk of database corruption
- No validation until restart

### Option 3: Deploy REST API Wrapper

Third-party tools provide REST APIs for Uptime Kuma:

**Available Projects**:
1. [MedAziz11/Uptime-Kuma-Web-API](https://github.com/MedAziz11/Uptime-Kuma-Web-API)
2. [keithah/uptime-kuma-rest-api](https://github.com/keithah/uptime-kuma-rest-api)

**Deployment Example**:
```yaml
# docker-compose.yml
services:
  uptime-kuma-api:
    image: ghcr.io/medaziz11/uptime-kuma-web-api:latest
    environment:
      - UK_API_URL=http://192.168.1.9:3010
      - UK_USERNAME=admin
      - UK_PASSWORD=your-password
    ports:
      - "3000:3000"
```

**Endpoints** (after deployment):
- `GET /api/monitors` - List all monitors
- `POST /api/monitors` - Add monitor
- `PUT /api/monitors/:id` - Update monitor
- `DELETE /api/monitors/:id` - Delete monitor

### Option 4: Use Push Endpoint (For Heartbeat Data Only)

If you only need to push heartbeat data (not manage monitors), use the push endpoint:

```bash
# Generate a push token from Uptime Kuma UI:
# Settings -> Monitors -> Edit Monitor -> Push Token

# Push heartbeat
curl "http://192.168.1.9:3010/api/push/YOUR_PUSH_TOKEN?status=up&msg=OK&ping=50"
```

## Testing API Access

Run the test script to verify Uptime Kuma connectivity:

```bash
/Users/jm/Codebase/internet-control/scripts/test_uptime_kuma_api.sh
```

## Quick Reference: Monitor Types

Supported monitor types in Uptime Kuma 2.0.2:

| Type | Description | Required Parameters |
|------|-------------|---------------------|
| `http` | HTTP/HTTPS | url |
| `ping` | ICMP Ping | hostname |
| `port` | TCP Port | hostname, port |
| `dns` | DNS Query | hostname, dns_resolve_server, dns_resolve_type |
| `docker` | Docker Container | docker_host, docker_container |
| `mqtt` | MQTT | hostname, port, mqtt_topic |
| `grpc` | gRPC | grpc_url, grpc_service_name, grpc_method |
| `radius` | RADIUS | hostname, radius_secret |
| `sqlserver` | SQL Server | database_connection_string, database_query |
| `postgres` | PostgreSQL | database_connection_string, database_query |
| `mysql` | MySQL | database_connection_string, database_query |

## Architecture Notes

### Why Socket.IO Instead of REST?

Uptime Kuma uses Socket.IO because:
1. **Real-time updates**: Monitor status changes are pushed immediately to all connected clients
2. **Bidirectional communication**: Both server and client can initiate messages
3. **Efficient**: Single WebSocket connection for multiple operations
4. **State synchronization**: Multiple users see updates simultaneously

### Authentication Flow

1. **Web UI**: Username/password → JWT token → Socket.IO connection
2. **API Keys**: Used for `/metrics` endpoint (replaces basic auth when enabled)
3. **Push Tokens**: Monitor-specific tokens for heartbeat updates

## Files Created

| File | Purpose |
|------|---------|
| `/Users/jm/Codebase/internet-control/scripts/add_uptime_kuma_monitor.py` | Python script for monitor management via Socket.IO |
| `/Users/jm/Codebase/internet-control/scripts/test_uptime_kuma_api.sh` | Test script for API connectivity |
| `/Users/jm/Codebase/internet-control/docs/troubleshooting/2026-01-31-uptime-kuma-api-investigation.md` | This documentation |

## Recommendations

1. **Use Python Library**: The `uptime-kuma-api` library is the most reliable method
2. **Store Credentials Securely**: Use environment variables or a secrets manager
3. **Script Automation**: Create scripts for bulk monitor operations
4. **Monitor Database**: Backup `/app/data/kuma.db` regularly
5. **Version Compatibility**: Ensure Python library version matches Uptime Kuma version

## Further Reading

- [Uptime Kuma Wiki](https://github.com/louislam/uptime-kuma/wiki)
- [Uptime Kuma API Documentation](https://github.com/louislam/uptime-kuma/wiki/API)
- [uptime-kuma-api Python Library](https://uptime-kuma-api.readthedocs.io/)
- [Socket.IO Documentation](https://socket.io/docs/)

## Resolution Status

✅ **RESOLVED**: Root cause identified and working solution provided
✅ **DOCUMENTATION**: Comprehensive guide created
✅ **TOOLS**: Python script and test script created
✅ **VERIFIED**: Python library installed and tested

**Next Steps**:
1. Set `UPTIME_KUMA_PASSWORD` environment variable
2. Use Python script for monitor management
3. Consider deploying REST API wrapper if REST endpoints are required

---

**Sources**:
- [Uptime Kuma Wiki](https://github.com/louislam/uptime-kuma/wiki)
- [Uptime Kuma API Keys Documentation](https://github.com/louislam/uptime-kuma/wiki/API-Keys/705b78e014714ef7fe108e90b80db51beac05db5)
- [uptime-kuma-api Python Library](https://uptime-kuma-api.readthedocs.io/)
- [MedAziz11/Uptime-Kuma-Web-API](https://github.com/MedAziz11/Uptime-Kuma-Web-API)
- [keithah/uptime-kuma-rest-api](https://github.com/keithah/uptime-kuma-rest-api)
