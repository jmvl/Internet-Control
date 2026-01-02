# PVE2 Crypto Miner Incident

**Date**: 2025-01-02
**Severity**: Critical
**Status**: Remediated
**Host**: pve2 (192.168.1.10)

## Incident Summary

A Monero cryptocurrency miner was discovered running on the Proxmox host pve2, consuming approximately 358% CPU (75% of available cores) and causing high fan speeds.

## Timeline

| Time | Event |
|------|-------|
| ~01:19 | Miner process started (based on process start time) |
| 13:29 | User reported high CPU/fan noise |
| 13:29 | Investigation revealed miner process |
| 13:30 | Miner killed and files removed |
| 13:31 | Load began dropping (6.60 → 3.91) |

## Technical Details

### Miner Process

```
PID: 3523966
UID: 100000 (LXC container namespace root)
CPU: 358%
Runtime: 2617 minutes
Command: /dev/shm/.x/m -o gulf.moneroocean.stream:10128 \
         -u 43yiB8RenFLGQdK97HGVpLjVeQaCSWDbaec2ZQcav6e7a3QnDEmKq3t3oUoQD9HgwXAW8RQTWUdXxN5WGtpStxAtRrH5Pmf \
         -p wmjw4mxwh --cpu-max-threads-hint=75 -B --donate-level=0
```

### Miner Configuration

| Parameter | Value |
|-----------|-------|
| Mining Pool | gulf.moneroocean.stream:10128 |
| Wallet | 43yiB8RenFLGQdK97HGVpLjVeQaCSWDbaec2ZQcav6e7a3QnDEmKq3t3oUoQD9HgwXAW8RQTWUdXxN5WGtpStxAtRrH5Pmf |
| Password | wmjw4mxwh |
| CPU Limit | 75% |
| Background | Yes (-B) |
| Donate Level | 0% |

### File Location

```
/dev/shm/.x/m
```

The miner was placed in `/dev/shm` (shared memory tmpfs) which:
- Is cleared on reboot
- Doesn't persist to disk
- Is a common hiding spot for malware

## Remediation Actions

1. **Killed miner process**: `kill -9 3523966`
2. **Removed miner files**: `rm -rf /dev/shm/.x`
3. **Verified removal**: Confirmed /dev/shm is clean
4. **Checked crontabs**: No suspicious entries found in root crontab
5. **Checked LXC containers**: GitLab, Confluence, docker-debian appear clean

## Attack Vector Analysis

The miner ran as UID 100000, which is the mapped UID for root (0) inside unprivileged LXC containers. This indicates the compromise likely occurred in one of:

| Container | VMID | Risk Level | Notes |
|-----------|------|------------|-------|
| GitLab | 501 | High | Common CVE target, publicly exposed |
| Confluence | 100 | High | Common CVE target, publicly exposed |
| JIRA | 102 | Medium | Publicly exposed |
| docker-debian | 111 | Medium | Runs multiple services |

### Possible Entry Points

1. **GitLab CVE** - Multiple critical CVEs in 2024-2025
2. **Confluence CVE** - Known RCE vulnerabilities
3. **Exposed Docker API** - If accidentally exposed
4. **Weak SSH credentials** - Brute force attack
5. **Compromised web application** - RCE through app vulnerability

## Post-Incident Checks

### Persistence Scan Results (2025-01-02 13:31)

| Check | Status | Notes |
|-------|--------|-------|
| Root crontab | ✅ Clean | Only legitimate backup/monitoring jobs |
| Systemd services | ✅ Clean | No suspicious services |
| SSH authorized_keys | ✅ Clean | 7 known keys (pve, node7, MacBook, OMV, ansible) |
| /dev/shm (host) | ✅ Clean | Miner files removed |
| /dev/shm (containers) | ✅ Clean | Only PostgreSQL shared mem in GitLab |
| Mining pool connections | ✅ None | No active connections to known pools |
| Hidden processes | ✅ None | No miner processes running |
| Container 100 (Confluence) | ✅ Clean | Normal crons only |
| Container 501 (GitLab) | ✅ Clean | Normal crons only |
| Container 102 (JIRA) | ✅ Clean | Normal crons only |
| Container 111 (docker-debian) | ✅ Clean | Only certbot cron |

**No persistence mechanisms found.** The miner was likely a one-time execution that would not survive reboot.

### Recommended Actions

1. **Update GitLab** to latest version
2. **Update Confluence** to latest version
3. **Run security scanners**: rkhunter, chkrootkit, lynis
4. **Review firewall rules** - minimize exposed ports
5. **Check all SSH keys** - remove unknown keys
6. **Enable fail2ban** on all exposed services
7. **Review Docker containers** for unauthorized images
8. **Consider container isolation** improvements

## Monitoring

After remediation, monitor for:

- CPU usage spikes
- Unusual network connections to mining pools
- New processes in /dev/shm
- Crontab modifications

### Useful Commands

```bash
# Check for mining pool connections
netstat -an | grep -E "(10128|3333|4444|5555)"

# Monitor /dev/shm
watch -n 5 'ls -la /dev/shm/'

# Check running processes for miners
ps aux | grep -iE "(xmr|miner|crypto|stratum)"

# Check network connections
ss -tulpn | grep ESTABLISHED
```

## Lessons Learned

1. Regular security updates are critical for exposed services
2. Container isolation doesn't prevent host resource abuse
3. /dev/shm should be monitored or restricted
4. Need automated monitoring for CPU anomalies

## Related Documentation

- [GitLab Security Updates](https://about.gitlab.com/releases/categories/releases/)
- [Confluence Security Advisories](https://confluence.atlassian.com/security)
