# Agent DVR Infrastructure Documentation

## Overview
This directory contains comprehensive documentation for the planned Agent DVR video surveillance platform deployment on the home network infrastructure. Agent DVR is an advanced, free, and open-source surveillance platform that will provide centralized IP camera management, recording, motion detection, and remote viewing capabilities.

## Documentation Status
**Status**: Planning/Pre-Implementation
**Created**: 2025-10-01
**Implementation Target**: TBD
**Project**: IFS (Infrastructure Services) in JIRA

## Directory Contents

### Core Documentation

#### 1. [agent-dvr-installation.md](./agent-dvr-installation.md)
**Comprehensive Installation and Operations Guide**

Complete technical documentation covering:
- **Overview**: Agent DVR features, capabilities, and use cases
- **Architecture**: Network topology and infrastructure integration
- **Docker Configuration**: Docker Compose setup, environment variables, volume mounts
- **Installation**: Step-by-step deployment instructions
- **Resource Requirements**: CPU, memory, storage planning
- **Configuration**: Initial setup, camera integration, recording settings
- **Operations**: Service management, backup procedures, updates
- **Troubleshooting**: Common issues, diagnostics, solutions
- **Security**: Network security, authentication, access control
- **Monitoring**: Health checks, performance metrics, alerting
- **Maintenance**: Daily, weekly, monthly operational tasks
- **Integration**: n8n automation, Uptime Kuma monitoring, Home Assistant

**Key Technical Details**:
- Docker Image: `mekayelanik/ispyagentdvr:latest`
- Web Interface: `http://192.168.1.20:8090` (internal)
- External Access: `https://cam.home.accelior.com` (via NPM)
- Ports: 8090 (TCP), 3478 (UDP), 50000-50100 (UDP)
- Storage: 500GB-1TB recommended for recordings
- Resources: 2-4GB RAM, 4-6 CPU cores recommended

#### 2. [nginx-reverse-proxy-configuration.md](./nginx-reverse-proxy-configuration.md)
**Nginx Proxy Manager Configuration for External Access**

Complete reverse proxy setup documentation covering:
- **Overview**: Secure external access via cam.home.accelior.com
- **Network Architecture**: Traffic flow from internet to Agent DVR
- **Configuration Requirements**: DNS, SSL, proxy settings
- **DNS Setup**: External A record and optional internal Pi-hole override
- **OPNsense Configuration**: Port forwarding rules and firewall policies
- **NPM Proxy Host**: Detailed step-by-step configuration
- **SSL Certificates**: Let's Encrypt setup and auto-renewal
- **Advanced Settings**: WebSocket support, timeouts, buffering
- **WebRTC Ports**: UDP port forwarding for low-latency streaming
- **Testing**: Internal and external validation procedures
- **Monitoring**: Access logs, error tracking, performance metrics
- **Troubleshooting**: Common issues and resolution steps
- **Security**: Access control lists, rate limiting, SSL hardening
- **Backup**: Configuration backup and disaster recovery

**Key Technical Details**:
- External Domain: `cam.home.accelior.com`
- Backend: `http://192.168.1.20:8090`
- SSL: Let's Encrypt (auto-renewal)
- NPM Host: OMV NAS (192.168.1.9)
- Admin Interface: `http://192.168.1.121:81`

#### 3. [jira-tickets.md](./jira-tickets.md)
**JIRA Implementation Tickets for IFS Project**

Ready-to-import JIRA tickets containing:
- **Ticket 1: Agent DVR Installation**
  - Complete Docker deployment on 192.168.1.20
  - Prerequisites, implementation steps, testing plan
  - Resource impact analysis, acceptance criteria
  - Estimated time: 4 hours

- **Ticket 2: Nginx Reverse Proxy Configuration**
  - DNS, firewall, and NPM proxy host setup
  - SSL certificate generation and validation
  - WebRTC port configuration (optional)
  - Estimated time: 2 hours

Both tickets include:
- Detailed descriptions with current/desired state
- Complete technical implementation details
- Step-by-step procedures with commands
- Comprehensive testing and validation plans
- Acceptance criteria and deliverables
- Troubleshooting guides and rollback procedures
- Dependencies and related tickets
- Time estimates and breakdowns

## Infrastructure Context

### Network Architecture
```
Internet
    ↓
[OpenWrt Router] 192.168.1.2 (Wireless AP)
    ↓
[OPNsense Firewall] 192.168.1.3 (Gateway, Traffic Shaper)
    ↓
[Pi-hole DNS] 192.168.1.5 (DNS Filtering)
    ↓
┌─────────────────────────────────────────┐
│ LAN Network (192.168.1.0/24)           │
├─────────────────────────────────────────┤
│ OMV NAS                    192.168.1.9  │ ← Nginx Proxy Manager
│ Docker VM                  192.168.1.20 │ ← Agent DVR (planned)
│ IP Cameras                 192.168.1.x  │ ← Camera network
└─────────────────────────────────────────┘
```

### Deployment Hosts

#### Docker VM (192.168.1.20)
**Current State**:
- Container: LXC 111 (docker-debian) on Proxmox pve2
- Resources: 10 cores, 20GB RAM (20.5% utilized)
- Storage: 60GB (110GB total)
- Network: vmbr0 (LAN bridge)

**Current Services**:
- Supabase full stack (PostgreSQL, Auth, Storage, REST API)
- n8n workflow automation
- Portainer container management
- Netdata system monitoring
- ntopng network monitoring
- Pi-hole DNS (Docker instance)

**Planned Addition**:
- Agent DVR surveillance platform

#### OMV NAS (192.168.1.9)
**Current State**:
- OpenMediaVault on bare metal
- Storage: 18TB MergerFS pool + 3.7TB BTRFS RAID
- Network: Gigabit Ethernet

**Current Services**:
- Nginx Proxy Manager (reverse proxy, SSL termination)
- Immich photo management
- Calibre e-book library
- Uptime Kuma monitoring
- Portainer container management

**Planned Configuration**:
- Nginx reverse proxy for cam.home.accelior.com

### Storage Considerations

#### Docker VM Local Storage
- **Available**: ~50GB free space
- **Not Recommended** for long-term recordings
- **Use Case**: Configuration and short-term buffer

#### OMV NAS Storage (Recommended)
- **Available**: 4TB+ free space on MergerFS pool
- **Recommended** for production recordings
- **Access Method**: NFS mount from Docker VM
- **Mount Path**: `/mnt/omv-storage/agent-dvr-media`

#### Storage Requirements
- **Per Camera**: ~5-10GB per day (1080p, 15fps, H.264)
- **4 Cameras**: ~150-300GB per week
- **30-Day Retention**: ~600GB-1.2TB for 4 cameras

## Implementation Plan

### Phase 1: Infrastructure Preparation (Pre-Implementation)
- [x] Research Agent DVR capabilities and requirements
- [x] Review existing infrastructure capacity
- [x] Create comprehensive documentation
- [x] Prepare JIRA tickets for implementation
- [ ] Review and approve implementation plan
- [ ] Schedule implementation window

### Phase 2: Backend Deployment
**Ticket**: IFS-XXX (Agent DVR Installation)
**Estimated Time**: 4 hours

1. **Preparation** (30 minutes)
   - Verify Docker VM resources
   - Create storage directories
   - Test camera network connectivity
   - Plan storage strategy (local vs NFS)

2. **Deployment** (30 minutes)
   - Pull Docker image
   - Create docker-compose.yml
   - Deploy container
   - Verify container startup

3. **Configuration** (1 hour)
   - Initial setup wizard
   - Create admin account
   - Configure storage paths
   - Set timezone and preferences

4. **Testing** (1 hour)
   - Add test camera
   - Verify recording functionality
   - Test motion detection
   - Validate storage writes

5. **Documentation** (1 hour)
   - Update operational documentation
   - Document camera configurations
   - Create troubleshooting runbook

### Phase 3: External Access Configuration
**Ticket**: IFS-XXX (Nginx Reverse Proxy)
**Estimated Time**: 2 hours

1. **DNS Configuration** (15 minutes + propagation)
   - Create A record: cam.home.accelior.com → 77.109.89.47
   - Optional: Pi-hole local override
   - Verify DNS propagation

2. **Firewall Configuration** (15 minutes)
   - Verify OPNsense port forwarding (443 → 192.168.1.9)
   - Optional: WebRTC UDP ports (3478, 50000-50100)
   - Test connectivity

3. **NPM Proxy Host** (30 minutes)
   - Create proxy host in NPM
   - Configure backend (192.168.1.20:8090)
   - Request Let's Encrypt SSL certificate
   - Configure WebSocket support
   - Add advanced Nginx settings

4. **Testing** (30 minutes)
   - Internal HTTPS access
   - External HTTPS access
   - SSL certificate validation
   - WebRTC video streaming
   - Mobile device testing

5. **Monitoring** (15 minutes)
   - Add Uptime Kuma monitor
   - Configure alert notifications
   - Test failure detection

### Phase 4: Production Deployment
**Post-Implementation Tasks**

1. **Camera Integration**
   - Connect IP cameras to network
   - Configure RTSP streams in Agent DVR
   - Set recording schedules and retention
   - Test motion detection and alerts

2. **Optimization**
   - Enable hardware acceleration (if GPU available)
   - Optimize recording settings (resolution, FPS, codec)
   - Configure motion detection sensitivity
   - Implement automated cleanup policies

3. **Monitoring and Alerting**
   - Configure n8n workflows (optional)
   - Set up motion detection notifications
   - Monitor storage usage and growth
   - Track system performance metrics

4. **Documentation**
   - Update camera inventory
   - Document RTSP URLs and credentials
   - Create user guides for viewing cameras
   - Update operational runbooks

## Key Technical Specifications

### Agent DVR Container
| Specification | Value |
|--------------|-------|
| **Image** | mekayelanik/ispyagentdvr:latest |
| **Web UI** | http://192.168.1.20:8090 |
| **External URL** | https://cam.home.accelior.com |
| **HTTP Port** | 8090/TCP |
| **TURN Port** | 3478/UDP |
| **WebRTC Ports** | 50000-50100/UDP |
| **Config Volume** | /srv/docker-data/agent-dvr/config |
| **Media Volume** | /srv/docker-data/agent-dvr/media |
| **Commands Volume** | /srv/docker-data/agent-dvr/commands |
| **User ID** | 1000 (PUID) |
| **Group ID** | 1000 (PGID) |
| **Timezone** | America/New_York |
| **Restart Policy** | unless-stopped |

### Resource Requirements
| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **CPU Cores** | 2 | 4-6 |
| **Memory** | 2GB | 4GB |
| **Storage (Config)** | 100MB | 500MB |
| **Storage (Media)** | 50GB | 500GB-1TB |
| **Network** | 100Mbps | 1Gbps |

### Expected Performance
| Metric | Target |
|--------|--------|
| **Cameras Supported** | 4-8 |
| **Video Latency** | < 2 seconds |
| **Recording FPS** | 15+ FPS |
| **Motion Detection** | < 1 second |
| **Web UI Load Time** | < 3 seconds |
| **CPU Usage** | < 50% |
| **Memory Usage** | < 4GB |

## Security Considerations

### Network Security
- **Firewall Rules**: OPNsense controls all external access
- **SSL/TLS**: HTTPS only for external access (Let's Encrypt)
- **Access Control**: Optional IP whitelisting via NPM access lists
- **Camera Isolation**: Consider separate VLAN for IP cameras (future)

### Authentication
- **Agent DVR Admin**: Strong password required
- **NPM Admin**: Protected by firewall (port 81 internal only)
- **Camera Credentials**: Secure RTSP authentication

### Data Protection
- **Encryption**: SSL/TLS for external access
- **Backup**: Regular configuration backups
- **Retention**: Define and enforce recording retention policies
- **Access Logs**: Monitor NPM logs for suspicious activity

## Monitoring and Alerting

### Health Monitoring
- **Uptime Kuma**: HTTP monitor for https://cam.home.accelior.com
- **Docker Health**: Container status and restart monitoring
- **Resource Usage**: CPU, memory, disk utilization tracking
- **Log Monitoring**: Error detection and alerting

### Performance Metrics
- **Response Time**: Web UI load time
- **Video Latency**: Streaming delay measurement
- **Storage Growth**: Recording storage usage trends
- **Network Bandwidth**: Camera traffic monitoring

### Alert Channels
- **Email**: admin@accelior.com
- **Discord**: #infrastructure-alerts
- **Uptime Kuma**: Built-in notification system

## Operational Procedures

### Daily Operations
- Check container status: `docker ps | grep agent-dvr`
- Monitor storage usage: `df -h /srv/docker-data/agent-dvr/media`
- Review motion detection alerts
- Verify all cameras recording

### Maintenance Tasks
**Weekly**:
- Review access logs for anomalies
- Check SSL certificate validity
- Verify backup completion
- Test external access

**Monthly**:
- Update Docker image
- Review storage retention policies
- Optimize recording settings
- Test disaster recovery

**Quarterly**:
- Audit camera configurations
- Review firewall rules
- Update documentation
- Performance optimization

### Backup Procedures

#### Configuration Backup
```bash
# Automated daily backup
tar -czf /root/backups/agent-dvr-config-$(date +%Y%m%d).tar.gz \
  /srv/docker-data/agent-dvr/config
```

#### Critical Recordings Backup
```bash
# Selective backup of important footage
rsync -avz /srv/docker-data/agent-dvr/media/critical/ \
  root@192.168.1.9:/srv/raid/backups/agent-dvr/
```

#### Disaster Recovery
```bash
# Restore configuration
tar -xzf agent-dvr-config-YYYYMMDD.tar.gz \
  -C /srv/docker-data/agent-dvr/

# Restart container
docker restart agent-dvr
```

## Integration Opportunities

### Current Infrastructure

#### n8n Workflow Automation (192.168.1.20)
**Potential Integrations**:
- Motion detection webhook → Discord/Email notifications
- Automated cleanup of old recordings
- Camera offline/online status monitoring
- Scheduled recording management

#### Uptime Kuma Monitoring (192.168.1.9)
**Monitoring Setup**:
- HTTP monitor: https://cam.home.accelior.com
- Keyword detection for service status
- Alert on downtime or certificate issues
- Public status page for cam service

### Future Integrations

#### Home Assistant
- Native Agent DVR integration available
- Display camera feeds on dashboard
- Automation based on motion events
- Mobile app notifications

#### Grafana/Prometheus
- Performance metrics visualization
- Historical data analysis
- Capacity planning dashboards
- Resource usage trends

## Troubleshooting Quick Reference

### Container Won't Start
```bash
# Check logs
docker logs agent-dvr

# Verify permissions
ls -la /srv/docker-data/agent-dvr/

# Check disk space
df -h /srv/docker-data/

# Verify port availability
ss -tulpn | grep 8090
```

### Cannot Access Web Interface
```bash
# Check container status
docker ps | grep agent-dvr

# Test local connectivity
curl -I http://localhost:8090

# Verify firewall rules
iptables -L -n | grep 8090
```

### Video Streaming Issues
```bash
# Check browser console for errors
# Verify WebSocket support in NPM
# Test RTSP stream directly from Docker VM

docker exec agent-dvr curl -v rtsp://<camera_IP>:554/stream
```

### High Resource Usage
```bash
# Monitor container resources
docker stats agent-dvr

# Check for multiple concurrent streams
# Review recording settings (resolution, FPS)
# Consider hardware acceleration
```

## Related Documentation

### Infrastructure Documentation
- [Infrastructure Overview](/docs/infrastructure.md)
- [Docker VM Setup](/docs/docker/pct-111-docker-setup.md)
- [Nginx Proxy Manager](/docs/npm/npm.md)
- [Docker Containers Overview](/docs/docker-containers-overview.md)

### Service-Specific Documentation
- [n8n Automation](/docs/n8n/README.md)
- [Uptime Kuma](/docs/uptime-kuma/uptime-kuma-installation.md)
- [OMV Storage](/docs/infrastructure.md#openmediavault-storage-server-19216819)

### Network Documentation
- [Architecture Overview](/docs/architecture.md)
- [OPNsense Configuration](/docs/OPNsense/OPNsense_setup.md)
- [Network Troubleshooting](/docs/networking/troubleshooting.md)

## External Resources

### Official Documentation
- **Agent DVR**: https://www.ispyconnect.com/docs/agent/
- **Docker Image**: https://github.com/MekayelAnik/ispyagentdvr-docker
- **Docker Hub**: https://hub.docker.com/r/mekayelanik/ispyagentdvr

### Community Resources
- **iSpy Forum**: Community support and discussions
- **GitHub Issues**: Bug reports and feature requests
- **Docker Community**: Container deployment best practices

### Related Technologies
- **Nginx Proxy Manager**: https://nginxproxymanager.com/
- **Let's Encrypt**: https://letsencrypt.org/
- **WebRTC**: https://webrtc.org/

## Next Steps

### Immediate Actions (Pre-Implementation)
1. [ ] Review documentation with stakeholders
2. [ ] Import JIRA tickets to IFS project
3. [ ] Assign tickets to implementation team
4. [ ] Schedule implementation window
5. [ ] Verify camera hardware availability
6. [ ] Confirm storage strategy (local vs NAS)

### Implementation Phase
1. [ ] Execute Ticket 1: Agent DVR Installation (4 hours)
2. [ ] Execute Ticket 2: Nginx Reverse Proxy (2 hours)
3. [ ] Complete testing and validation
4. [ ] Add cameras and configure recording
5. [ ] Setup monitoring and alerting

### Post-Implementation
1. [ ] Update documentation with actual configurations
2. [ ] Create user guides for camera viewing
3. [ ] Train users on Agent DVR interface
4. [ ] Establish operational procedures
5. [ ] Schedule first maintenance review

## Questions and Clarifications Needed

### Before Implementation
1. **Camera Inventory**: How many IP cameras and what models?
2. **Storage Location**: Local Docker VM or NFS mount to OMV?
3. **Recording Policy**: Continuous or motion-triggered? Retention period?
4. **External Access**: Required for remote viewing or internal only?
5. **Camera Network**: Separate VLAN or existing LAN subnet?

### Technical Decisions
1. **Hardware Acceleration**: Is GPU available on Docker VM for acceleration?
2. **WebRTC Ports**: Required for external streaming or HTTPS tunnel sufficient?
3. **Access Control**: IP whitelist or open external access?
4. **Backup Strategy**: Automated backups to OMV or manual procedures?
5. **Monitoring**: Integration with existing monitoring or separate?

### Operational Questions
1. **Maintenance Windows**: Preferred time for updates/maintenance?
2. **Alert Recipients**: Who receives surveillance system alerts?
3. **User Access**: How many users need camera access?
4. **Mobile Access**: iOS, Android, or both platforms?
5. **Integration Priority**: n8n automation, Home Assistant, or both?

---

## Document Metadata

**Created**: 2025-10-01
**Last Updated**: 2025-10-01
**Status**: Planning Documentation Complete
**Next Review**: Post-Implementation
**Maintainer**: Infrastructure Team
**JIRA Project**: IFS (Infrastructure Services)
**Related Tickets**: IFS-XXX (Installation), IFS-XXX (Reverse Proxy)

---

## Summary

This documentation package provides a complete, production-ready plan for deploying Agent DVR video surveillance platform on the existing home network infrastructure. The documentation covers all technical aspects from Docker container deployment to external HTTPS access configuration, with comprehensive troubleshooting guides, operational procedures, and JIRA tickets ready for implementation.

**Total Estimated Implementation Time**: 6 hours (4 hours backend + 2 hours reverse proxy)

**Implementation Ready**: Yes - All documentation complete, JIRA tickets prepared, technical specifications validated.
