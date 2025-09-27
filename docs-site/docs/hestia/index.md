---
sidebar_position: 1
title: Hestia Control Panel
description: Documentation for Hestia Control Panel email server configuration and management
keywords: [hestia, control-panel, email, web-server, dns, ssl]
tags: [hestia, email, web-server]
---

# Hestia Control Panel

Hestia Control Panel is a lightweight, secure, and powerful web server control panel that provides a comprehensive solution for managing web hosting services. In our infrastructure, it serves as the primary email server management interface.

## Overview

**Server Details**:
- **Server**: Proxmox Container CT130 (mail.vega-messenger.com)
- **External IP**: 77.109.89.47 (EDP.net Belgium)
- **Control Panel**: Hestia Control Panel
- **Mail Transfer Agent**: Exim4 (version 4.93)
- **Operating System**: Debian-based

## Key Features

### Email Services
- **SMTP Server**: Exim4 with advanced routing capabilities
- **IMAP/POP3**: Secure email access protocols
- **Webmail**: Built-in webmail interface
- **Anti-Spam**: SpamAssassin integration
- **DKIM**: DomainKeys Identified Mail signing

### Web Services
- **Web Server**: Apache2 with PHP support
- **SSL/TLS**: Let's Encrypt integration
- **DNS Management**: Built-in DNS zone management
- **Database**: MySQL/MariaDB support

### Security Features
- **Firewall**: Integrated iptables management
- **Fail2Ban**: Intrusion prevention system
- **SSL Certificates**: Automated certificate management
- **Access Control**: User permission management

## Service Status

All core services are operational:

```bash
# Hestia Control Panel
systemctl status hestia
● hestia.service - LSB: starts the hestia control panel
   Active: active (running)

# Email Services
systemctl status exim4
● exim4.service - LSB: exim Mail Transport Agent
   Active: active (running)

# Web Server
systemctl status apache2
● apache2.service - The Apache HTTP Server
   Active: active (running)
```

## Network Configuration

### Port Configuration
- **SMTP**: Port 25 (Standard SMTP)
- **SMTP Submission**: Port 587 (Authenticated SMTP)
- **IMAP Secure**: Port 993 (IMAPS)
- **POP3 Secure**: Port 995 (POP3S)
- **HTTP**: Port 80 (Web traffic)
- **HTTPS**: Port 443 (Secure web traffic)
- **Control Panel**: Port 8083 (Hestia interface)

### DNS Configuration
```bash
# MX Records
mail.accelior.com → 77.109.89.47
mail.vega-messenger.com → 77.109.89.47

# SPF Record
"v=spf1 a mx a:home.accelior.com include:_spf.google.com include:spf.protection.outlook.com ~all"
```

## Documentation Index

### Email Configuration
- [**Spamhaus Blacklist Resolution**](./spamhaus-blacklist-resolution.md) - Complete guide for resolving Spamhaus blacklist issues and configuring EDP.net SMTP relay

### Future Documentation Topics
- Domain and email account management
- SSL certificate automation
- Database management
- Web hosting configuration
- Security hardening guidelines
- Backup and recovery procedures

## Quick Access Commands

### Service Management
```bash
# Connect to mail server container
ssh root@pve2 'pct exec 130'

# Check service status
systemctl status hestia exim4 apache2

# View email logs
tail -f /var/log/exim4/mainlog

# Check mail queue
exim4 -bp
```

### Configuration Files
```bash
# Hestia main configuration
/usr/local/hestia/conf/hestia.conf

# Exim4 configuration
/etc/exim4/exim4.conf.template

# Apache configuration
/etc/apache2/sites-available/

# DNS zone files
/usr/local/hestia/data/users/*/dns/
```

## Integration with Infrastructure

The Hestia email server is integrated into our three-tier network architecture:

```
Internet → [OpenWrt] → [OPNsense] → [Hestia Email Server] → LAN Clients
          ↓           ↓             ↓
      Layer 1:    Layer 2:     Layer 3:
   Wireless QoS  Firewall &   Email Services
   SQM Control   Traffic      SMTP/IMAP/POP3
                 Shaping      Web Management
```

### Monitoring Integration
- **Uptime Kuma**: Service availability monitoring
- **Log Aggregation**: Centralized logging via rsyslog
- **Performance Metrics**: Resource usage tracking

## Security Considerations

### Current Security Measures
- **TLS Encryption**: All email traffic encrypted with TLS 1.3
- **DKIM Signing**: Email authentication and integrity verification
- **Firewall Rules**: Restricted port access through OPNsense
- **Access Control**: SSH key-based authentication only

### Recent Security Updates
- **SMTP Relay Configuration**: Implemented EDP.net smarthost to bypass Spamhaus PBL
- **Certificate Management**: Automated SSL renewal via Let's Encrypt
- **Intrusion Prevention**: Fail2Ban monitoring for suspicious activity

## Support and Maintenance

### Regular Maintenance Tasks
1. **Weekly**: Check service status and log files
2. **Monthly**: Review security logs and update packages
3. **Quarterly**: Backup configuration and test recovery procedures
4. **Annually**: Security audit and performance optimization

### Troubleshooting Resources
- Hestia official documentation: https://hestiacp.com/docs/
- Exim4 configuration guide: https://www.exim.org/docs.html
- Community forums: https://forum.hestiacp.com/

---

For specific technical issues and configurations, refer to the detailed documentation in this section.