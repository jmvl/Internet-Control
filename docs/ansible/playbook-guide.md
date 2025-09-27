# Ansible Playbook Guide - What Each Playbook Does

This guide explains what each playbook accomplishes and when to use them, written in plain language without technical implementation details.

## Infrastructure Maintenance Playbooks

### Docker VM Maintenance
**File**: `docker-vm-maintenance.yml`
**Target**: Docker container host (PCT-111 at 192.168.1.20)

**What this playbook solves**:
Your Docker containers create lots of log files and unused data that fills up disk space over time. Without regular cleanup, the Docker VM can run out of space or become slow.

**What it does for you**:
- **Frees up disk space**: Cleans out old Docker logs and removes unused container images, volumes, and build cache
- **Keeps system secure**: Installs important security updates automatically
- **Prevents performance issues**: Stops Docker from using too much CPU or memory
- **Health monitoring**: Checks if your important containers (Supabase, n8n, Pi-hole) are running properly
- **Tracks improvements**: Shows you exactly how much space was recovered and what was fixed

**When to use manually**:
- When Docker VM is running low on disk space
- Before major system changes or updates
- If containers are behaving slowly or strangely
- Monthly review to see maintenance trends

### Proxmox Host Maintenance
**File**: `proxmox-host-maintenance.yml`
**Target**: Proxmox hypervisor host (pve2 at 192.168.1.10)

**What this playbook solves**:
The main server running all your containers and VMs needs regular maintenance to stay healthy. Without it, you might face system crashes, storage issues, or security vulnerabilities.

**What it does for you**:
- **Prevents system failures**: Monitors hardware health like temperature and disk status
- **Keeps system secure**: Installs Proxmox security updates and patches
- **Prevents storage problems**: Cleans old log files and monitors storage usage before it becomes critical
- **Service reliability**: Ensures all core Proxmox services are running correctly
- **Early warning system**: Alerts you to potential problems before they cause outages
- **Backup integration**: Works with your existing disaster recovery procedures

**When to use manually**:
- Before creating new VMs or containers
- If you notice performance issues with containers
- After hardware changes or upgrades
- When planning capacity or storage expansion

### OMV Storage Server Maintenance ✨ **NEW**
**File**: `omv-storage-maintenance.yml`
**Target**: OpenMediaVault storage server (192.168.1.9)

**What this playbook solves**:
Your storage server hosts 20+ Docker containers and manages 27TB of data across 6 drives. Without maintenance, containers fill up with logs, storage pools can become corrupted, and file sharing can fail.

**What it does for you**:
- **Prevents storage disasters**: Runs BTRFS filesystem scrubs to detect and repair data corruption before you lose files
- **Keeps containers healthy**: Manages 20+ containers including photo management (Immich), monitoring (Uptime Kuma), and proxy services
- **Frees up massive disk space**: Cleans Docker logs and unused resources across multiple storage pools
- **Monitors critical services**: Ensures file sharing (Samba), photo management, and monitoring services stay running
- **Storage health alerts**: Warns you when storage pools approach capacity or show signs of failure
- **Multi-drive management**: Coordinates maintenance across BTRFS RAID arrays and MergerFS pools

**When to use manually**:
- When storage pools are running low on space
- Before adding new drives or expanding storage
- If photo management or file sharing is slow
- After hardware changes or drive replacements
- When containers are behaving unexpectedly

**Automated schedule**:
- Every night at 2:30 AM: Light maintenance and health checks (5-8 minutes)
- Every Sunday at 3:30 AM: Full maintenance with BTRFS scrubs (20-30 minutes)
- First Sunday of month at 4:30 AM: Comprehensive storage maintenance (30-45 minutes)

### Mail Server Maintenance ✨ **NEW**
**File**: `mail-server-maintenance.yml`
**Target**: Mail server container (PCT-130 at 192.168.1.30)

**What this playbook solves**:
Email servers can fail silently - mail queues back up, SSL certificates expire, or services stop working. Without maintenance, you might miss important emails or be unable to send them.

**What it does for you**:
- **Prevents email delivery failures**: Cleans mail queues and removes stuck messages that block new emails
- **SSL certificate monitoring**: Checks email SSL certificates and warns before they expire (prevents email security issues)
- **Service health verification**: Ensures mail services (sending and receiving) are working properly
- **Security maintenance**: Keeps anti-spam and security configurations up to date
- **Queue management**: Automatically handles large mail queues and identifies problematic messages
- **Connectivity testing**: Verifies all email ports work correctly (SMTP, IMAP, secure versions)

**When to use manually**:
- When emails are not sending or receiving properly
- Before SSL certificate renewal
- If mail queue is backing up with stuck messages
- After email configuration changes
- When investigating email delivery issues

**Automated schedule**:
- Every Sunday at 4 AM: Full mail maintenance (10-15 minutes)
- No daily maintenance needed (mail services are stable when properly configured)

## Application Container Maintenance

### JIRA System Maintenance
**Files**: `update-jira-debian.yml`, `upgrade-jira-debian12-fixed.yml`
**Target**: JIRA container (PCT at 192.168.1.22)

**What this playbook solves**:
JIRA needs regular system updates to stay secure and compatible. Manual updates risk breaking JIRA or causing downtime during business hours.

**What it does for you**:
- **Zero-downtime updates**: Updates system packages without interrupting JIRA service
- **Safe upgrades**: Handles major Debian version upgrades without breaking JIRA configuration
- **Data protection**: Maintains JIRA database integrity during updates
- **Service verification**: Confirms JIRA is working properly after updates
- **Rollback capability**: Can detect and report issues for quick recovery

**When to use manually**:
- Before JIRA application upgrades
- If JIRA performance seems degraded
- After security advisories for Debian packages
- When planning JIRA migrations or major changes

### Confluence System Maintenance
**File**: `upgrade-confluence-ubuntu.yml`
**Target**: Confluence container (PCT at 192.168.1.21)

**What this playbook solves**:
Confluence runs on Ubuntu and needs system-level maintenance separate from Confluence application updates. Manual updates can cause service interruptions.

**What it does for you**:
- **Maintains system security**: Keeps Ubuntu packages updated for security
- **Service continuity**: Ensures Confluence wiki remains accessible during maintenance
- **System optimization**: Handles system-level performance improvements
- **Compatibility maintenance**: Keeps system libraries compatible with Confluence
- **Automated scheduling**: Runs during low-usage periods to minimize impact

**When to use manually**:
- Before Confluence application updates
- If wiki performance is slow
- After Ubuntu security announcements
- When troubleshooting system-level issues

## System Monitoring and Health

### Basic System Monitoring
**File**: `system-maintenance.yml`
**Target**: All managed containers and systems

**What this playbook solves**:
You need visibility into system health across all your containers, but checking each one manually is time-consuming and easy to forget.

**What it does for you**:
- **Health dashboard**: Gives you a quick overview of all system resources (CPU, memory, disk)
- **Early problem detection**: Spots issues before they become critical
- **Resource planning**: Shows usage trends to help plan upgrades or expansions
- **Service verification**: Confirms all important services are running
- **Quick troubleshooting**: Provides baseline information when investigating problems

**When to use manually**:
- Before making infrastructure changes
- When investigating performance issues
- For monthly infrastructure reviews
- When planning capacity or upgrades

### Resilient System Monitoring
**File**: `system-maintenance-resilient.yml`
**Target**: All managed containers and systems

**What this playbook solves**:
Sometimes system checks fail due to temporary issues, but you still want to get health information from systems that are working properly.

**What it does for you**:
- **Fault-tolerant monitoring**: Continues checking other systems even if some fail
- **Partial information**: Gets you useful data even when some services are down
- **Problem isolation**: Helps identify which specific systems need attention
- **Comprehensive coverage**: Ensures you don't miss critical issues on working systems
- **Reliable reporting**: Always provides some level of system status information

**When to use manually**:
- During system outages or maintenance windows
- When some systems are known to be having issues
- For emergency health checks during incidents
- When you need partial system status during repairs

## When to Use Each Playbook

### Daily Operations
- **Automatic**: Docker VM log cleanup runs every night
- **Automatic**: Proxmox health checks run every morning
- **Manual**: Use monitoring playbooks if you notice issues

### Weekly Operations
- **Automatic**: Full maintenance runs every Sunday
- **Manual**: Review maintenance logs for trends
- **Manual**: Run application updates if needed

### Monthly Operations
- **Automatic**: Comprehensive maintenance first Sunday
- **Manual**: Review system performance and capacity
- **Manual**: Plan any needed infrastructure changes

### Emergency Situations
- **Disk space alerts**: Run Docker VM maintenance immediately
- **Performance issues**: Run system monitoring to diagnose
- **Service failures**: Run resilient monitoring to assess impact
- **Security advisories**: Run appropriate application maintenance

### Before Major Changes
- **New deployments**: Run full system monitoring first
- **Hardware changes**: Run Proxmox maintenance before and after
- **Application upgrades**: Run appropriate container maintenance first
- **Network changes**: Run monitoring to establish baseline

## Understanding Maintenance Impact

### Minimal Impact (Safe Anytime)
- System monitoring playbooks
- Health check operations
- Log viewing and analysis

### Low Impact (Safe During Business Hours)
- Docker log cleanup
- Basic security updates
- Service health verification

### Medium Impact (Schedule During Off-Hours)
- Full Docker system maintenance
- Proxmox system updates
- Application container updates

### High Impact (Plan Carefully)
- Comprehensive maintenance operations
- Major system upgrades
- Hardware health interventions

---

**Remember**: All maintenance is automated and scheduled appropriately. Manual execution is typically only needed for troubleshooting, emergency situations, or when making planned infrastructure changes.

**Last Updated**: 2025-09-26
**Automation Status**: Fully scheduled and operational
**Emergency Contact**: Infrastructure team via documentation