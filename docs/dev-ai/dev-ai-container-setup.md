# dev-ai LXC Container Documentation

## Overview

**Container Name**: dev-ai  
**CT ID**: 120  
**Hostname**: dev-ai  
**Purpose**: High-performance development environment for AI-assisted coding with AutoMaker  
**Created**: 2026-01-08  

## Quick Access

- **SSH**: `ssh root@192.168.1.120`
- **Web UI**: https://ai-coder.acmea.tech (via Nginx Proxy Manager)
- **From PVE2**: `pct enter 120`

## Specifications

### Hardware Allocation
| Resource | Allocated | Notes |
|----------|-----------|-------|
| **CPU Cores** | 14 cores | (out of 16 total on PVE2) |
| **RAM** | 32 GB | High memory for AI tools |
| **Storage** | 150 GB SSD | On ssd-4tb storage |
| **Network** | 192.168.1.120/24 | Static IP on vmbr0 |
| **Gateway** | 192.168.1.3 | OPNsense firewall |

### Container Type
- **Unprivileged**: Yes (with nesting=1, keyctl=1 features for Docker support)
- **OS**: Debian 12 (bookworm)
- **Template**: debian-12-standard_12.12-1_amd64.tar.zst

## Software Stack

### Development Tools
| Tool | Version | Installation Method |
|------|---------|---------------------|
| **Node.js** | v24.12.0 (LTS) | nvm (Node Version Manager) |
| **npm** | 11.6.2 | Bundled with Node.js |
| **Python** | 3.11.2 | apt (system package) |
| **pip** | 23.0.1 | apt (system package) |
| **Docker** | 29.1.3 | Official Docker script |
| **Docker Compose** | Plugin (v2.x) | Included with Docker |

### Base Packages Installed
- `build-essential` - GCC, make, etc. for compiling
- `curl` - HTTP client
- `git` - Version control
- `vim` - Text editor
- `sudo` - Privilege escalation
- `wget` - File downloader
- `ca-certificates` - SSL certificates
- `gnupg` - GPG privacy guard
- `lsb-release` - Distribution info
- `python3-dev` - Python development headers
- `python3-venv` - Python virtual environments
- `python3-pip` - Python package manager

## Network Configuration

### DNS
- **Primary DNS**: 192.168.1.5 (Pi-hole)
- **Secondary DNS**: 1.1.1.1 (Cloudflare)

### Domain Access
- **Public URL**: https://ai-coder.acmea.tech
- **DNS Record**: CNAME to base.acmea.tech (77.109.112.226)
- **Proxy**: Nginx Proxy Manager on 192.168.1.9

### Nginx Proxy Manager Configuration

| Setting | Value |
|---------|-------|
| **Domain Names** | ai-coder.acmea.tech |
| **Forward Scheme** | http |
| **Forward Host** | 192.168.1.120 |
| **Forward Port** | 3007 (AutoMaker Web UI) |
| **WebSocket Support** | Enabled |
| **HTTP/2** | Enabled |
| **Block Exploits** | Enabled |
| **SSL** | Let's Encrypt (jmvl@acmea.tech) |
| **Certificate ID** | 0 (pending SSL provisioning) |

## Memory Optimization

### Stopped Containers (Freeing ~22 GB RAM)
The following containers were stopped to free up memory for dev-ai:
- **CT 100** (Confluence): 16 GB allocated, 6.36 GB used
- **CT 102** (Jira): 8 GB allocated, 7.65 GB used
- **CT 501** (GitLab): 6 GB allocated, 5.62 GB used
- **CT 502** (GitLab related): 6 GB allocated, 2.20 GB used
- **CT 505** (gitlab-bulk): 8 GB allocated, 0.08 GB used

**Total freed**: ~22 GB of actual RAM usage

## AutoMaker Configuration

### Port Mapping
| Service | Port | Purpose |
|---------|------|---------|
| **Web UI** | 3007 | Main AutoMaker web interface |
| **API Server** | 3008 | Backend API |

### Access AutoMaker
1. From your browser: https://ai-coder.acmea.tech
2. Direct access: http://192.168.1.120:3007

### Installation Instructions (To Be Done)
```bash
# Clone AutoMaker repository
git clone https://github.com/AutoMaker-Org/automaker.git
cd automaker

# Install dependencies (if needed)
npm install

# Run AutoMaker
npm start

# Web UI will be available on port 3007
```

## Shell Configuration

### Node.js (nvm)
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use --lts  # Switch to LTS version
```

### Python (pyenv - optional)
```bash
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
```

## Container Management

### Start/Stop/Restart
```bash
# From PVE2 host
pct start 120
pct stop 120
pct restart 120
pct status 120

# Enter container
pct enter 120
```

### Configuration File
- **Location**: `/etc/pve/lxc/120.conf` on PVE2
- **Current Config**:
```bash
arch: amd64
cores: 14
features: nesting=1,keyctl=1
hostname: dev-ai
memory: 32768
net0: name=eth0,bridge=vmbr0,gw=192.168.1.3,hwaddr=BC:24:11:79:CC:D7,ip=192.168.1.120/24,type=veth
ostype: debian
rootfs: ssd-4tb:120/vm-120-disk-0.raw,size=150G
swap: 4096
timezone: Europe/Paris
unprivileged: 1
```

## Backup Strategy

### Backup Schedule
- **Proxmox Backup Server**: pbs.home (192.168.1.107)
- **Backup Job**: Daily backups at 02:00
- **Retention**: 7 daily, 4 weekly, 6 monthly

### Manual Backup
```bash
# From PVE2 host
vzdump 120 --mode snapshot --storage pbs.home --compress zstd
```

## Security Considerations

### SSH Access
- **Root login**: Enabled (for development convenience)
- **Authentication**: SSH key-based (recommended)
- **Password auth**: Available (fallback)

### Docker Security
- **Docker group**: root user added
- **Socket**: `/var/run/docker.sock`
- **Nesting enabled**: Allows running Docker inside LXC

### Firewall
- **OPNsense**: 192.168.1.3 (firewall & gateway)
- **Allowed ports**: 80, 443 (via NPM), 3007, 3008 (AutoMaker)

## Troubleshooting

### Network Issues
```bash
# Test connectivity from container
pct exec 120 -- ping -c 2 192.168.1.3  # Gateway
pct exec 120 -- ping -c 2 8.8.8.8      # Internet

# Check DNS resolution
pct exec 120 -- cat /etc/resolv.conf
pct exec 120 -- nslookup google.com
```

### Resource Usage
```bash
# Check memory usage
pct exec 120 -- free -h

# Check disk usage
pct exec 120 -- df -h

# Check processes
pct exec 120 -- top -bn1 | head -20
```

### Docker Issues
```bash
# Check Docker status
pct exec 120 -- systemctl status docker

# View Docker logs
pct exec 120 -- docker logs <container_name>

# Restart Docker
pct exec 120 -- systemctl restart docker
```

## Development Workflow

### Setting Up a New Project
```bash
# SSH into container
ssh root@192.168.1.120

# Create project directory
mkdir -p /root/projects/myapp
cd /root/projects/myapp

# Initialize Node.js project
nvm use --lts
npm init -y

# Or initialize Python project
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Running Multiple Services
With 32 GB RAM and 14 cores, you can comfortably run:
- AutoMaker (Web UI + API)
- Multiple Node.js development servers
- Python virtual environments
- Docker containers for testing
- Database instances (PostgreSQL, MongoDB, etc.)

## Maintenance

### System Updates
```bash
# Update package list
apt-get update

# Upgrade packages
apt-get upgrade -y

# Dist upgrade (cautious!)
apt-get dist-upgrade -y

# Clean up
apt-get autoremove -y
```

### Log Rotation
Logs are managed by systemd-journald:
```bash
# View logs
journalctl -u docker -f

# Clean old logs
journalctl --vacuum-time=7d
```

## References

- **AutoMaker GitHub**: https://github.com/AutoMaker-Org/automaker
- **Nginx Proxy Manager**: https://nginxproxymanager.com/
- **PVE2 Documentation**: `/docs/proxmox/` in this repository
- **Infrastructure DB**: `/infrastructure-db/infrastructure.db`

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-01-08 | Initial container creation with 32GB RAM, 14 cores | Claude |
| 2026-01-08 | Stopped unused containers (Jira, Confluence, GitLab) to free memory | Claude |
| 2026-01-08 | Configured ai-coder.acmea.tech domain with NPM proxy | Claude |
| 2026-01-08 | Created this documentation | Claude |

## AutoMaker Installation (2026-01-08)

AutoMaker is an AI-powered autonomous development studio that transforms how you build software by managing AI agents through a web interface.

### Installation Details

**Location**: `/root/codebase/AutoMaker-Org/automaker`  
**Repository**: https://github.com/AutoMaker-Org/automaker  
**Web UI**: http://ai-coder.acmea.tech (port 3007)  
**API Server**: http://192.168.1.120:3008

### Custom Modifications Applied

Three custom changes were applied to enable GLM 4.7 support and add bulk delete functionality:

1. **Custom Endpoint Support** (Section 0 - Prerequisite)
   - Modified: `apps/server/src/providers/claude-provider.ts`
   - Added support for `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and `API_TIMEOUT_MS` environment variables
   - Allows AutoMaker to use Z.AI gateway with GLM models

2. **GLM Model Support** (Section 1)
   - Modified: `libs/types/src/model.ts` - Changed default models to GLM (glm-4.7, glm-4.5-air)
   - Modified: `libs/model-resolver/src/resolver.ts` - Added GLM to model pass-through check
   - Created: `apps/server/.env` - GLM configuration file

3. **Bulk Delete Feature** (Section 2)
   - Created: `apps/ui/src/components/views/board-view/dialogs/bulk-delete-features-dialog.tsx`
   - Modified: `apps/ui/src/components/views/board-view/components/selection-action-bar.tsx`
   - Modified: `apps/ui/src/components/views/board-view.tsx`
   - Added: Ability to delete multiple selected backlog features at once

### Configuration Files

**Claude Code CLI** (`~/.claude/settings.json`):
```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "API_TIMEOUT_MS": "3000000",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.5-air",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-4.7"
  }
}
```

**AutoMaker Server** (`apps/server/.env`):
```bash
ANTHROPIC_API_KEY=your_glm_api_key_here
ANTHROPIC_AUTH_TOKEN=your_glm_api_key_here
ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
API_TIMEOUT_MS=3000000
ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air
ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.7
ANTHROPIC_DEFAULT_OPUS_MODEL=glm-4.7
```

⚠️ **IMPORTANT**: Set your actual GLM API key in `apps/server/.env` before starting AutoMaker.

### Service Management

**Systemd Service**: `/etc/systemd/system/automaker.service`  
**Startup Script**: `/root/automaker-start.sh`

```bash
# Start AutoMaker
systemctl start automaker

# Enable auto-start on boot
systemctl enable automaker

# Check status
systemctl status automaker

# View logs
journalctl -u automaker -f

# Stop AutoMaker
systemctl stop automaker

# Restart AutoMaker
systemctl restart automaker
```

### Manual Start (for testing)

```bash
cd /root/codebase/AutoMaker-Org/automaker
/root/automaker-start.sh
```

This starts both:
- Backend server on port 3008
- Web UI on port 3007

### Maintenance

#### Rebuilding after code changes

```bash
cd /root/codebase/AutoMaker-Org/automaker

# Rebuild shared packages
npm run build:packages

# Rebuild server
npm run build:server

# Rebuild UI
npm run build

# Restart service
systemctl restart automaker
```

#### Re-applying custom changes after git pull

See `/root/codebase/AutoMaker-Org/CUSTOM_CHANGES.md` (if present) for detailed re-application instructions. Key files to check:
- `apps/server/src/providers/claude-provider.ts` - Custom endpoint support
- `libs/types/src/model.ts` - GLM model mappings
- `libs/model-resolver/src/resolver.ts` - GLM pass-through
- `apps/server/.env` - GLM configuration
- Bulk delete components in `apps/ui/src/components/views/board-view/`

### Troubleshooting

**Service won't start**:
```bash
# Check logs
journalctl -u automaker -n 50

# Verify dependencies are built
cd /root/codebase/AutoMaker-Org/automaker
ls -la apps/server/dist/
ls -la apps/ui/dist/
```

**API errors**:
- Verify `apps/server/.env` has correct API key
- Check that GLM endpoint is accessible: `curl https://api.z.ai/api/anthropic/v1/messages`

**Frontend build errors**:
- Ensure Node.js version is compatible (AutoMaker requires Node 22.x)
- Consider downgrading from v24: `nvm install 22 && nvm use 22`

**Port conflicts**:
```bash
# Check if ports 3007/3008 are in use
netstat -tlnp | grep -E '3007|3008'
```

### Network Configuration

**DNS**: ai-coder.acmea.tech → CNAME → base.acmea.tech → NPM → 192.168.1.120:3007  
**Firewall**: Port 3007 accessible via Nginx Proxy Manager  
**Internal Access**: http://192.168.1.120:3007 (web UI), http://192.168.1.120:3008 (API)

### Notes

- AutoMaker runs on Node.js v24 (consider downgrading to v22 for full compatibility)
- Custom changes must be re-applied after upstream updates
- GLM 4.7 model provides fast AI responses via Z.AI gateway
- Bulk delete feature helps clean up backlog quickly

