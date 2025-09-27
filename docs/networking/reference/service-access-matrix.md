# Service Access Matrix - VLAN Management Interface Isolation

## Overview

This document defines the complete service access control matrix for the VLAN-based management interface isolation implementation. It specifies which services are accessible from which VLANs and the specific ports/protocols allowed.

## Access Control Philosophy

### Security Principles
1. **Principle of Least Privilege**: Grant minimum necessary access
2. **Defense in Depth**: Multiple layers of access control
3. **Clear Separation**: Management vs. user service boundaries
4. **Operational Continuity**: Maintain essential service functionality

### Access Categories
- **ALLOW**: Full access permitted
- **RESTRICTED**: Limited access with specific port/protocol restrictions
- **DNS ONLY**: Only DNS queries (port 53) permitted
- **DENY**: No access permitted

## Master Service Access Matrix

| Service Category | Management VLAN (100) | User VLAN (10) | IoT VLAN (20) | Legacy VLAN (1) |
|------------------|----------------------|----------------|---------------|-----------------|
| **Network Services** |
| DNS Resolution (53/UDP) | ✅ ALLOW | ✅ ALLOW | ✅ ALLOW | ✅ ALLOW |
| DHCP Services (67-68/UDP) | ✅ ALLOW | ✅ ALLOW | ✅ ALLOW | ✅ ALLOW |
| Internet Gateway | ✅ ALLOW | ✅ ALLOW | 🔶 RESTRICTED | ✅ ALLOW |
| **Management Interfaces** |
| SSH Access (22/TCP) | ✅ ALLOW | ❌ DENY | ❌ DENY | ⚠️ TRANSITIONAL |
| OPNsense Admin (443/TCP) | ✅ ALLOW | ❌ DENY | ❌ DENY | ⚠️ TRANSITIONAL |
| Proxmox Admin (8006/TCP) | ✅ ALLOW | ❌ DENY | ❌ DENY | ⚠️ TRANSITIONAL |
| Pi-hole Admin (80/TCP) | ✅ ALLOW | ❌ DENY | ❌ DENY | ⚠️ TRANSITIONAL |
| OMV Admin (80/TCP) | ✅ ALLOW | ❌ DENY | ❌ DENY | ⚠️ TRANSITIONAL |
| **User Services** |
| File Shares (445,2049/TCP) | ✅ ALLOW | ✅ ALLOW | ❌ DENY | ✅ ALLOW |
| Immich Photos (2283/TCP) | ✅ ALLOW | ✅ ALLOW | ❌ DENY | ✅ ALLOW |
| n8n Automation (5678/TCP) | ✅ ALLOW | ✅ ALLOW | ❌ DENY | ✅ ALLOW |
| Supabase API (8000/TCP) | ✅ ALLOW | ✅ ALLOW | ❌ DENY | ✅ ALLOW |
| Confluence Wiki (8090/TCP) | ✅ ALLOW | ✅ ALLOW | ❌ DENY | ✅ ALLOW |
| JIRA Issues (8080/TCP) | ✅ ALLOW | ✅ ALLOW | ❌ DENY | ✅ ALLOW |
| **Infrastructure Services** |
| Database Direct (5432/TCP) | ✅ ALLOW | ❌ DENY | ❌ DENY | ⚠️ TRANSITIONAL |
| Monitoring (3010/TCP) | ✅ ALLOW | ❌ DENY | ❌ DENY | ⚠️ TRANSITIONAL |
| Container Mgmt (9443/TCP) | ✅ ALLOW | ❌ DENY | ❌ DENY | ⚠️ TRANSITIONAL |

## Detailed Service Breakdown

### Network Infrastructure Services

#### DNS Resolution (Pi-hole)
```yaml
Service: Pi-hole DNS Server
IP Address: 192.168.100.5
Primary Port: 53/UDP

Access Control:
  Management VLAN (100):
    - Port 53/UDP: ✅ DNS queries
    - Port 80/TCP: ✅ Admin interface
    - Port 22/TCP: ✅ SSH management

  User VLAN (10):
    - Port 53/UDP: ✅ DNS queries
    - Port 80/TCP: ❌ Admin interface blocked
    - Port 22/TCP: ❌ SSH blocked

  IoT VLAN (20):
    - Port 53/UDP: ✅ DNS queries (filtered)
    - Port 80/TCP: ❌ Admin interface blocked
    - Port 22/TCP: ❌ SSH blocked

Purpose: Central DNS resolution for all VLANs with management isolation
```

#### Gateway Services (OPNsense)
```yaml
Service: OPNsense Firewall/Gateway
Management IP: 192.168.100.3
VLAN Gateways: 192.168.{10,20,100}.1

Access Control:
  Management VLAN (100):
    - Port 443/TCP: ✅ Web admin interface
    - Port 22/TCP: ✅ SSH management
    - All ports: ✅ Full administrative access

  User VLAN (10):
    - Gateway routing: ✅ Internet access via 192.168.10.1
    - Port 443/TCP: ❌ Admin interface blocked
    - Port 22/TCP: ❌ SSH blocked

  IoT VLAN (20):
    - Gateway routing: 🔶 Limited internet access via 192.168.20.1
    - Port 443/TCP: ❌ Admin interface blocked
    - Port 22/TCP: ❌ SSH blocked

Traffic Shaping: Maintained across all VLANs per existing policies
```

### Management Interface Services

#### Proxmox Virtualization Platform
```yaml
Service: Proxmox Virtual Environment
IP Address: 192.168.100.10
Primary Port: 8006/TCP (HTTPS)

Access Control:
  Management VLAN (100):
    - Port 8006/TCP: ✅ Web management interface
    - Port 22/TCP: ✅ SSH root access
    - Port 5900-5999/TCP: ✅ VNC console access

  User VLAN (10):
    - All ports: ❌ Complete access blocked

  IoT VLAN (20):
    - All ports: ❌ Complete access blocked

Security Features:
  - Multi-factor authentication required
  - Certificate-based access preferred
  - Session timeout: 30 minutes
```

#### OpenMediaVault Storage Server
```yaml
Service: OpenMediaVault (OMV)
Management IP: 192.168.100.9
User Services IP: 192.168.10.9

Access Control:
  Management VLAN (100):
    - Port 80/TCP: ✅ OMV admin interface (192.168.100.9)
    - Port 22/TCP: ✅ SSH management
    - Port 9443/TCP: ✅ Portainer access

  User VLAN (10):
    - Port 445/TCP: ✅ SMB file shares (192.168.10.9)
    - Port 2049/TCP: ✅ NFS file shares (192.168.10.9)
    - Port 80/TCP: ❌ Admin interface blocked
    - Port 22/TCP: ❌ SSH blocked

  IoT VLAN (20):
    - All ports: ❌ No file share access

Dual-Homing: Management and user services on separate VLAN interfaces
```

### User Application Services

#### Photo Management (Immich)
```yaml
Service: Immich Photo Management
IP Address: 192.168.10.21
Primary Port: 2283/TCP

Access Control:
  Management VLAN (100):
    - Port 2283/TCP: ✅ Web interface
    - Port 22/TCP: ✅ SSH to container host

  User VLAN (10):
    - Port 2283/TCP: ✅ Web interface
    - Port 22/TCP: ❌ SSH blocked

  IoT VLAN (20):
    - All ports: ❌ No access (prevent data exposure)

Features: AI-powered photo recognition and management
User Access: http://192.168.10.21:2283
```

#### Workflow Automation (n8n)
```yaml
Service: n8n Workflow Automation
IP Address: 192.168.10.22
Primary Port: 5678/TCP

Access Control:
  Management VLAN (100):
    - Port 5678/TCP: ✅ Web interface
    - Administrative functions: ✅ Full access

  User VLAN (10):
    - Port 5678/TCP: ✅ Web interface
    - Workflow execution: ✅ User workflows
    - System admin: ❌ Limited administrative access

  IoT VLAN (20):
    - All ports: ❌ No access

Features: Workflow triggers, data processing, API integrations
User Access: http://192.168.10.22:5678
```

#### Backend Services (Supabase)
```yaml
Service: Supabase Backend Platform
IP Address: 192.168.10.20
Primary Ports: 8000/TCP (API), 3000/TCP (Studio)

Access Control:
  Management VLAN (100):
    - Port 8000/TCP: ✅ API Gateway
    - Port 3000/TCP: ✅ Supabase Studio
    - Port 5432/TCP: ✅ Direct PostgreSQL access
    - Port 22/TCP: ✅ SSH to container host

  User VLAN (10):
    - Port 8000/TCP: ✅ API Gateway (public endpoints)
    - Port 3000/TCP: 🔶 Studio access (auth required)
    - Port 5432/TCP: ❌ Direct database blocked
    - Port 22/TCP: ❌ SSH blocked

  IoT VLAN (20):
    - All ports: ❌ No backend access

Components: PostgreSQL, Auth, Storage, Edge Functions, Realtime
```

### Collaboration Services

#### Documentation (Confluence)
```yaml
Service: Confluence Wiki Platform
IP Address: 192.168.10.23
Primary Port: 8090/TCP

Access Control:
  Management VLAN (100):
    - Port 8090/TCP: ✅ Web interface
    - Administrative functions: ✅ Full admin access

  User VLAN (10):
    - Port 8090/TCP: ✅ Web interface
    - User functions: ✅ Create/edit content
    - System admin: ❌ Limited administrative access

  IoT VLAN (20):
    - All ports: ❌ No documentation access

Features: Team documentation, knowledge base, collaboration
User Access: http://192.168.10.23:8090
```

#### Issue Tracking (JIRA)
```yaml
Service: JIRA Issue Tracking
IP Address: 192.168.10.24
Primary Port: 8080/TCP

Access Control:
  Management VLAN (100):
    - Port 8080/TCP: ✅ Web interface
    - Administrative functions: ✅ Full admin access

  User VLAN (10):
    - Port 8080/TCP: ✅ Web interface
    - Project functions: ✅ Create/manage issues
    - System admin: ❌ Limited administrative access

  IoT VLAN (20):
    - All ports: ❌ No issue tracking access

Features: Project management, issue tracking, workflow automation
User Access: http://192.168.10.24:8080
```

### Infrastructure Monitoring Services

#### Service Monitoring (Uptime Kuma)
```yaml
Service: Uptime Kuma Monitoring
IP Address: 192.168.100.161  # Management VLAN only
Primary Port: 3010/TCP

Access Control:
  Management VLAN (100):
    - Port 3010/TCP: ✅ Web interface
    - Configuration: ✅ Full monitoring setup

  User VLAN (10):
    - All ports: ❌ No monitoring access

  IoT VLAN (20):
    - All ports: ❌ No monitoring access

Purpose: Infrastructure health monitoring and alerting
Admin Access: http://192.168.100.161:3010
```

#### Container Management (Portainer)
```yaml
Service: Portainer Container Management
IP Address: 192.168.100.9  # Via OMV host
Primary Port: 9443/TCP

Access Control:
  Management VLAN (100):
    - Port 9443/TCP: ✅ Web interface
    - Container control: ✅ Full container management

  User VLAN (10):
    - All ports: ❌ No container access

  IoT VLAN (20):
    - All ports: ❌ No container access

Purpose: Docker container lifecycle management
Admin Access: https://192.168.100.9:9443
```

## Firewall Rule Implementation

### OPNsense Firewall Rules by VLAN

#### Management VLAN (100) Rules
```yaml
Rule Priority: 1000 (Highest)

Rules:
  - Action: Pass
    Source: 192.168.100.0/24
    Destination: Any
    Ports: Any
    Description: "Allow full access from management VLAN"

  - Action: Log
    Source: 192.168.100.0/24
    Destination: Any
    Ports: 22,443,8006,5432
    Description: "Log management interface access"
```

#### User VLAN (10) Rules
```yaml
Rule Priority: 2000

Rules:
  # Allow DNS
  - Action: Pass
    Source: 192.168.10.0/24
    Destination: 192.168.100.5
    Ports: 53
    Protocol: UDP/TCP
    Description: "Allow DNS queries to Pi-hole"

  # Allow user services
  - Action: Pass
    Source: 192.168.10.0/24
    Destination: 192.168.10.0/24
    Ports: 2283,5678,8000,3000,8090,8080,445,2049
    Description: "Allow access to user services"

  # Allow internet access
  - Action: Pass
    Source: 192.168.10.0/24
    Destination: !192.168.0.0/16
    Ports: Any
    Description: "Allow internet access"

  # Block management interfaces
  - Action: Block
    Source: 192.168.10.0/24
    Destination: 192.168.100.0/24
    Ports: 22,443,8006,80,5432,3010,9443
    Description: "Block management interface access"
    Log: Yes

  # Block inter-VLAN (except allowed services)
  - Action: Block
    Source: 192.168.10.0/24
    Destination: 192.168.20.0/24
    Ports: Any
    Description: "Block User to IoT VLAN communication"
    Log: Yes
```

#### IoT VLAN (20) Rules
```yaml
Rule Priority: 3000

Rules:
  # Allow DNS only
  - Action: Pass
    Source: 192.168.20.0/24
    Destination: 192.168.100.5
    Ports: 53
    Protocol: UDP/TCP
    Description: "Allow DNS queries to Pi-hole"

  # Allow limited internet access
  - Action: Pass
    Source: 192.168.20.0/24
    Destination: !192.168.0.0/16
    Ports: 80,443,123
    Description: "Allow limited internet access (HTTP/HTTPS/NTP)"

  # Block all internal access
  - Action: Block
    Source: 192.168.20.0/24
    Destination: 192.168.0.0/16
    Ports: Any
    Description: "Block access to internal networks"
    Log: Yes

  # Default deny
  - Action: Block
    Source: 192.168.20.0/24
    Destination: Any
    Ports: Any
    Description: "Default deny for IoT devices"
    Log: Yes
```

## Access Control Enforcement

### Authentication Requirements

| Service Type | Management VLAN | User VLAN | Authentication Method |
|--------------|----------------|-----------|----------------------|
| **SSH Access** | MFA + Key-based | Blocked | SSH keys + TOTP |
| **Web Admin** | Username + MFA | Blocked | Local auth + TOTP |
| **User Services** | Admin access | User auth | LDAP/Local + session |
| **API Access** | Admin tokens | User tokens | API keys + rate limiting |

### Session Management

```yaml
Management Interfaces:
  Session Timeout: 30 minutes
  Concurrent Sessions: Limited per user
  Session Monitoring: Full audit logging

User Services:
  Session Timeout: 8 hours
  Concurrent Sessions: Unlimited
  Session Monitoring: Basic access logging
```

### Monitoring and Alerting

#### Security Events
```yaml
Alert Triggers:
  - Failed authentication attempts (>5 in 10 minutes)
  - Unauthorized VLAN access attempts
  - Management interface access outside business hours
  - Unusual traffic patterns between VLANs
  - Direct database connection attempts from user VLANs

Alert Destinations:
  - Email: admin@domain.com
  - Dashboard: Uptime Kuma alerts
  - Logs: Centralized syslog server
```

#### Access Auditing
```yaml
Audit Requirements:
  - All management interface access
  - Failed authentication attempts
  - Administrative configuration changes
  - Cross-VLAN traffic attempts
  - Service availability changes

Retention: 90 days minimum
Review: Monthly security audit
```

This service access matrix provides comprehensive access control while maintaining operational functionality and security isolation between management and user services.