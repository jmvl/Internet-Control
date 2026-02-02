# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Essential Reading First
- **Infrastructure Overview**: `/docs/infrastructure.md` - Complete network architecture documentation
- **Quick Start Guide**: `QUICK-START.md` - Emergency recovery and daily operations
- **Architecture Details**: `/docs/architecture.md` - Traffic control strategy and implementation

## 🚀 CRITICAL: AGENT WORKFLOW - ORCHESTRATION & PARALLELIZATION

**MAIN SESSION ROLE: Orchestration, Information Passing, Summarization, Documentation**

You are the **orchestrator**, not the implementer. Your job is to coordinate specialized agents and synthesize their work.

### Core Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    MAIN SESSION (Orchestrator)                  │
│                  - Receives user request                       │
│                  - Plans parallel agent tasks                  │
│                  - Delegates to specialized agents            │
│                  - Synthesizes results                        │
│                  - Documents outcomes                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ↓
        ┌─────────────────────┼─────────────────────┐
        ↓                     ↓                     ↓
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   DevOps     │    │   Code       │    │   Research   │
│   Agent      │    │   Agent      │    │   Agent      │
│ (Linux/Docker)│   │ (Implement)  │    │ (Docs/Search) │
└──────────────┘    └──────────────┘    └──────────────┘
        │                     │                     │
        ↓                     ↓                     ↓
   Execute tasks       Write code           Find info
   in parallel         in parallel         in parallel
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ↓
                    ┌─────────────────────┐
                    │  MAIN SESSION        │
                    │  - Summarize         │
                    │  - Document          │
                    │  - Report to user    │
                    └─────────────────────┘
```

### When to Use DevOps Agent

**ALWAYS use the `devops` agent for:**
- Linux system administration tasks
- Docker container management
- Network troubleshooting
- Infrastructure monitoring setup
- Service configuration changes
- Security hardening
- Performance tuning

**DevOps agent location**: `/Users/jm/Codebase/internet-control/.claude/agents/devops-expert-agent.md`

**Invoke with:**
```
@"devops (agent)" <your task description>
```

### Parallelization Rules

**ALWAYS parallelize independent tasks:**

| Scenario | Parallel Agents |
|----------|------------------|
| Multiple service checks | DevOps (container 1) + DevOps (container 2) |
| Code + Infrastructure | Code Agent + DevOps Agent |
| Research + Implementation | Research Agent + DevOps Agent |
| Documentation + Testing | Write documentation + Run tests |

**Example:**
```
User: "Check OpenClaw status and set up monitoring"

WRONG (sequential):
1. Check OpenClaw status
2. Then set up monitoring

CORRECT (parallel):
1. @"devops (agent)" Check OpenClaw gateway status
2. @"devops (agent)" Check Telegram connection
3. @"devops (agent)" Set up Uptime Kuma monitors
→ All run simultaneously, then summarize results
```

### Task Delegation Protocol

**For ANY infrastructure task:**

1. **Assess**: Can this be parallelized?
   - If YES → Launch multiple agents in one message
   - If NO → Launch single agent

2. **Delegate**: Use `@"devops (agent)"` with clear task description

3. **Wait**: Let agents complete (check progress with notifications)

4. **Synthesize**: Combine results into clear summary

5. **Document**: Create/update documentation in `/docs/` as needed

### What Main Session DOES

| Activity | Main Session | Agents |
|----------|--------------|--------|
| Plan approach | ✅ | ❌ |
| Execute infrastructure tasks | ❌ | ✅ DevOps |
| Write implementation code | ❌ | ✅ Code |
| Search for latest info | ❌ | ✅ Research/DevOps |
| Synthesize multiple results | ✅ | ❌ |
| Document outcomes | ✅ | ❌ |
| Report to user | ✅ | ❌ |
| Make decisions | ✅ | ❌ |

### What Main Session DOES NOT DO

- ❌ Execute SSH commands directly (use DevOps agent)
- ❌ Modify Docker containers (use DevOps agent)
- ❌ Configure services (use DevOps agent)
- ❌ Write implementation code (use Code agent)
- ❌ Make assumptions about infrastructure (verify first)

### Example Interactions

**User: "Set up monitoring for OpenClaw"**

```
Main Session:
1. Plans: Need to check status + set up monitors
2. Delegates parallel tasks:
   - @"devops (agent)" Check OpenClaw gateway and Telegram status
   - @"devops (agent)" Enable Uptime Kuma API
   - @"devops (agent)" Create cron monitor script
3. Waits for agents to complete
4. Synthesizes: "All checks passed, monitoring active"
5. Documents: Creates /docs/openclaw/monitoring-setup.md
```

**User: "Update nginx config"**

```
Main Session:
1. Verifies: "Let me check the database for Nginx config location"
2. Delegates: @"devops (agent)" Update nginx configuration
3. Waits for completion
4. Reports: "Nginx updated, service restarted"
5. Updates database: Records configuration change
```

### Agent Best Practices

1. **One agent per independent task** - Launch multiple in parallel
2. **Clear task descriptions** - Include context, goals, and constraints
3. **Wait for completion** - Don't interrupt unless critical
4. **Review results** - Check agent outputs before finalizing
5. **Document everything** - Create docs in `/docs/` for changes

## ⚠️ CRITICAL: NO ASSUMPTIONS - VERIFY EVERYTHING

**ALWAYS READ THE DOCUMENTATION FIRST - NEVER GUESS OR ASSUME:**

1. **Service URLs**: Before mentioning any service URL (Nginx Proxy Manager, Portainer, etc.):
   ```bash
   # Search the database FIRST
   sqlite3 /Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db \
     "SELECT service_name, endpoint_url FROM services WHERE service_name LIKE '%nginx%';"

   # Search documentation
   rg -i "nginx.home.accelior.com" /Users/jm/Codebase/internet-control/docs/
   ```

2. **IP Addresses & Ports**: Always verify:
   ```bash
   # Check database for host IPs
   sqlite3 infrastructure.db "SELECT hostname, ip FROM hosts WHERE hostname LIKE '%dev%';"
   ```

3. **Service Locations**: Never assume - query the database or grep docs

4. **Configuration Details**: Always read actual config files, don't assume defaults

**Recent Correction Example:**
- ❌ **WRONG**: "NPM is at npm.acmea.tech" (assumption without verification)
- ✅ **CORRECT**: "Nginx Proxy Manager is at https://nginx.home.accelior.com/" (verified in docs and database)

**Verification Protocol Before Any Infrastructure Statement:**
1. Search infrastructure database: `sqlite3 infrastructure.db "SELECT ..."`
2. Search documentation: `rg -i "<term>" /Users/jm/Codebase/internet-control/docs/`
3. Only then state the information as fact

If you cannot find information in documentation or database, clearly state: "I need to verify this in the documentation" rather than guessing.

## Project Overview

This repository contains a comprehensive enterprise-grade home network infrastructure with multi-layer traffic control, including:

- **Three-Tier Network Architecture**: Hardware-isolated traffic control through OpenWrt → OPNsense → Pi-hole
- **Infrastructure-as-Code**: Complete Proxmox virtualization setup with automated backup/recovery
- **Container Platform**: Full Supabase stack + n8n automation + media services

## Documentation Architecture
All infrastructure services are documented in organized subdirectories:
- `/docs/` - Main documentation hub with service-specific subdirectories
- `/docs/OPNsense/`, `/docs/Supabase/`, `/docs/docker/` etc. - Service-specific docs
- `/docs/infrastructure-db/` - **SQLite Infrastructure Database** - Single source of truth for infrastructure inventory
- `/docs/troubleshooting/` - **Maintenance & Issue Tracking** - Timestamped troubleshooting logs and resolutions
- **Discovery Protocol**: When encountering undocumented services, create comprehensive technical documentation in the appropriate `/docs/` subdirectory

### Documentation Naming Conventions

**Troubleshooting & Incident Logs** (`/docs/troubleshooting/`):
- **Format**: `YYYY-MM-DD-<issue-description>.md` (datestamp first for chronological sorting)
- **Use for**: System-wide issues, incidents, cross-service problems, security events
- **Examples**: `2025-01-02-pve2-crypto-miner-incident.md`, `2025-12-10-pihole-sysctl-crash.md`

**Service-Specific Documentation** (`/docs/<service>/`):
- **Format**: `<service>-<event-type>-YYYY-MM-DD.md` for dated events, or descriptive names for reference docs
- **Use for**: Service upgrades, migrations, configuration changes specific to one service
- **Examples**: `seafile-13-upgrade-2025-12-22.md`, `n8n-supabase-to-local-postgres-migration-2025-11-26.md`

**When to Use Which**:
| Scenario | Location |
|----------|----------|
| Multi-service outage | `/docs/troubleshooting/` |
| Security incident | `/docs/troubleshooting/` |
| Service upgrade | `/docs/<service>/` |
| Service-specific bug fix | `/docs/<service>/` |
| Infrastructure-wide issue | `/docs/troubleshooting/` |

### Infrastructure Database (SQLite) - READ AND UPDATE
**CRITICAL - This is the single source of truth for infrastructure inventory**:
- **Database Location**: `/Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db`
- **Schema Reference**: `/Users/jm/Codebase/internet-control/infrastructure-db/schema.sql`
- **Purpose**: Centralized infrastructure inventory - **Claude MUST read AND update this database**
- **Last Updated**: 2025-11-26 (n8n PostgreSQL migration)

**MANDATORY: When making infrastructure changes, UPDATE the database**:
- Adding/removing Docker containers → UPDATE `docker_containers` table
- Adding/removing services → UPDATE `services` table
- Changing service dependencies → UPDATE `service_dependencies` table
- Network changes → UPDATE `docker_networks` or `networks` tables
- Host changes → UPDATE `hosts` table

**Contains**:
  - 40+ Docker containers across 2 hosts (192.168.1.20, 192.168.1.9)
  - 15+ physical/virtual hosts with resource tracking
  - 23+ Docker networks with subnet information
  - 60+ services with health monitoring
  - Complete dependency mapping (including n8n → n8n-postgres)

**Key Tables**:
| Table | Purpose |
|-------|---------|
| `hosts` | Physical servers, VMs, LXC containers, Docker hosts |
| `docker_containers` | Container inventory with image, status, ports, env vars |
| `docker_networks` | Docker network topology with subnets |
| `services` | Application services with health status |
| `service_dependencies` | Service-to-service dependency graph |

**Query Examples**:
  ```bash
  cd /Users/jm/Codebase/internet-control/infrastructure-db

  # Quick container inventory
  sqlite3 infrastructure.db "SELECT h.hostname, dc.container_name, dc.status FROM docker_containers dc JOIN hosts h ON dc.docker_host_id = h.id WHERE dc.status = 'running';"

  # Network topology
  sqlite3 infrastructure.db "SELECT network_name, subnet, gateway FROM docker_networks WHERE subnet IS NOT NULL;"

  # Service dependencies
  sqlite3 infrastructure.db ".read queries/dependency_analysis.sql"
  ```

**Update Examples**:
  ```bash
  cd /Users/jm/Codebase/internet-control/infrastructure-db

  # Add new container
  sqlite3 infrastructure.db "INSERT INTO docker_containers (docker_host_id, container_id, container_name, image, status, health_status) VALUES (17, 'container-id', 'my-container', 'image:tag', 'running', 'healthy');"

  # Update container status
  sqlite3 infrastructure.db "UPDATE docker_containers SET status = 'stopped', updated_at = CURRENT_TIMESTAMP WHERE container_name = 'my-container';"

  # Add service dependency
  sqlite3 infrastructure.db "INSERT INTO service_dependencies (dependent_service_id, dependency_service_id, dependency_type) VALUES (19, 61, 'hard');"
  ```

- **When to READ**: ALWAYS query this database first when asked about:
  - Docker containers and their status
  - Network topology and IP allocations
  - Service dependencies and impact analysis
  - Infrastructure inventory questions

- **When to UPDATE**: ALWAYS update this database after:
  - Adding/removing/migrating containers or services
  - Changing service configurations or dependencies
  - Infrastructure maintenance that changes state
  - Any change documented in `/docs/` should also update the DB

- **n8n Quick Query**:
  ```bash
  # n8n stack status
  sqlite3 infrastructure.db "SELECT dc.container_name, dc.status, dc.health_status FROM docker_containers dc WHERE dc.container_name LIKE '%n8n%';"

  # n8n service dependencies
  sqlite3 infrastructure.db "SELECT s1.service_name, sd.dependency_type, s2.service_name as depends_on FROM services s1 JOIN service_dependencies sd ON s1.id = sd.dependent_service_id JOIN services s2 ON sd.dependency_service_id = s2.id WHERE s1.service_name LIKE '%n8n%';"
  ```
- **Full Documentation**: See `/Users/jm/Codebase/internet-control/infrastructure-db/README.md` for complete schema and usage

### Confluence Documentation Server
**IMPORTANT - Atlassian MCP Configuration**:
- **Confluence URL**: `https://confluence.accelior.com`
- **Configuration Source**: MCP server configured via Claude Code's Atlassian MCP integration
- **Spaces Available**: INFRA, and others
- ⚠️ **CRITICAL**: Always use the exact URL `https://confluence.accelior.com` - DO NOT hallucinate or guess other URLs
- When posting documentation to Confluence, use the `confluence-doc-expert` agent with proper space and page parameters
- All technical documentation created in `/docs/` subdirectories should be mirrored to appropriate Confluence spaces for team access

## Key Commands

w
### Infrastructure Management
```bash
# Proxmox backup and recovery
ssh root@pve2 '/root/disaster-recovery/backup-status.sh'
ssh root@pve2 '/root/proxmox-bare-metal-backup.sh backup'
ssh root@pve2 '/root/disaster-recovery/proxmox-backup-monitor.sh check'

# Container management (Docker host: 192.168.1.20)
ssh root@192.168.1.20 'docker ps'
ssh root@192.168.1.20 'docker compose -f /path/to/compose.yml up -d'

# Network troubleshooting
ping 192.168.1.3   # OPNsense firewall
ping 192.168.1.5   # Pi-hole DNS
ping 192.168.1.9   # OMV storage server
```

### Supabase Development
```bash
# Local development (from /supabase directory)
supabase start                    # Start local Supabase stack
supabase db reset                 # Reset local database with migrations
supabase gen types typescript    # Generate TypeScript types
supabase db push                  # Push local schema to remote

# Migration management
supabase migration new <name>     # Create new migration
supabase db diff --schema public  # Generate diff migration
```

## Architecture Overview

### Hardware-Isolated Network Topology
This infrastructure implements enterprise-grade hardware isolation with dedicated NICs for complete WAN/LAN separation:

**Physical Network Separation**:
- **WAN NIC**: RTL8111 1GbE (enp2s0f0) → Direct internet connection
- **LAN NIC**: RTL8125 2.5GbE (enp1s0) → Internal network traffic
- **Bridge Architecture**: vmbr1 (WAN) and vmbr0 (LAN) provide complete isolation
- **OPNsense Dual NIC**: VM acts as gateway between isolated network segments

**Three-Tier Traffic Control**:
```
Internet → [OpenWrt] → [OPNsense] → [Pi-hole] → LAN Clients
          ↓           ↓             ↓
      Layer 1:    Layer 2:     Layer 3:
   Wireless QoS  Firewall &   DNS Filtering
   SQM Control   Traffic      Rate Limiting
                 Shaping
```
### Container Platform (192.168.1.20)
**Supabase Full Stack**:
- **PostgreSQL 15.8.1** with pgvecto-rs vector support
- **Auth Service** + **Storage API** + **REST API** (PostgREST)
- **Kong Gateway** (ports 8000/8443) for API management
- **Edge Functions** (Deno-based serverless runtime)
- **Realtime Service** (WebSocket subscriptions) - ⚠️ Currently unhealthy

**Development & Automation**:
- **n8n** (port 5678) - Workflow automation platform with local PostgreSQL (migrated from Supabase 2025-11-26)
- **n8n-postgres** - PostgreSQL 16-alpine database for n8n (local container, not Supabase)
- **Gotenberg** - Document conversion service
- **Analytics Stack** (Logflare, Vector, ImgProxy)

### Storage Infrastructure (192.168.1.9)
**Dual-Tier Storage Architecture**:
- **BTRFS RAID Mirror**: 3.7TB (sdb + sde) for critical data with redundancy
- **MergerFS Pool**: 18TB unified storage (sdc + sdd + sdf) for bulk data
- **System Drive**: 240GB SSD for OS and applications

**Container Services**:
- **Immich Stack**: AI-powered photo management with PostgreSQL + Redis + ML engine
- **Media Management**: Calibre e-books, Nginx Proxy Manager, Syncthing sync
- **Monitoring**: Uptime Kuma service monitoring, Portainer container management

### Common Troubleshooting Patterns
- **Interface Detection Issues**: Check `iw dev` output vs UCI wireless configuration
- **SQM Configuration**: Verify with `uci show sqm` and `/etc/init.d/sqm status`
- **Cron Scheduling**: Test with `crontab -l` and `logread | grep "Multi-WiFi-Throttle"`
- **UCI Persistence**: Confirm changes with `uci commit` and router reboot testing

## Cloudflare DNS Management
**IMPORTANT - flarectl CLI Available**:
- **Tool**: flarectl version dev installed at `/opt/homebrew/bin/flarectl`
- **Account**: jmvl@accelior.com (ACMEA tech account: c115f051a956d0c2582963d1caf4884b)
- **API Token**: Configured in `.env` as `CF_API_TOKEN`
- **CRITICAL**: ALWAYS use flarectl for DNS operations - DO NOT provide manual instructions
- **Common Commands**:
  ```bash
  # Set token (if not in .env)
  export CF_API_TOKEN="RZ5klBDFKSUqBSnb8lJgzuUzwbh4v5Yd8UwgpNzA"

  # List zones
  flarectl zone list

  # List DNS records
  flarectl dns list --zone acmea.tech

  # Create CNAME record with proxy
  flarectl dns create --zone acmea.tech --name subdomain --type CNAME --content target.domain.com --proxy

  # Delete DNS record
  flarectl dns delete --zone acmea.tech --id <record-id>
  ```
- **Note**: Wrangler v4.42.0 is also available but only supports Workers/Pages, not DNS

## Tooling for Shell Interactions
Use modern CLI tools for efficient shell operations:
- **Finding FILES**: Use `fd` (fast file discovery)
- **Finding TEXT/strings**: Use `rg` (ripgrep for text search)
- **Finding CODE STRUCTURE**: Use `ast-grep` (AST-based code search)
- **Selecting from multiple results**: Pipe to `fzf` (fuzzy finder)
- **Interacting with JSON**: Use `jq` (JSON processor)
- **Interacting with YAML or XML**: Use `yq` (YAML/XML processor)