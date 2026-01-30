# Wanderwish Crypto Miner CPU Spike Incident

**Date**: 2026-01-21
**Time**: ~14:25 UTC
**Host**: pve2 (192.168.1.10)
**Affected Container**: CT 109 (wanderwish)
**Severity**: High (CPU exhaustion, resource theft)

## Summary

The `.fullgc` XMRig crypto miner was discovered running in CT 109 (wanderwish), consuming 399% CPU and causing max fan speeds on pve2. The malware had replaced `/usr/bin/node` with a malicious wrapper script.

## Symptoms

- **CPU Spike**: Load average 5.58, `.fullgc` process using 399% CPU
- **Fan Speed**: Max speed on pve2 host
- **Process Name**: `/usr/bin/.fullgc`
- **Location**: CT 109 (wanderwish) at `/home/studio`

## Root Cause Analysis

### Malware Details

**Infected Binary**: `/usr/bin/node`

The legitimate Node.js binary was replaced with a malicious shell script that:
1. Downloads `.fullgc` from `https://file.551911.xyz/fullgc/fullgc-linux-x86_64`
2. Executes crypto miner in background
3. Runs legitimate Node.js as `/usr/bin/nodeo` to avoid detection

**File Hashes**:
```
Malicious /usr/bin/.fullgc: 405bf5c2ab7c35ac9c8f5facf3482d3d (26704 bytes, ELF executable)
```

### Infection Vector (Under Investigation)

**Possible attack vectors**:
1. Compromised npm package dependency
2. Supply chain attack (malicious package download)
3. Unauthorized container access
4. Vulnerable application in wanderwish

## Resolution

### Immediate Actions

1. Killed malicious process: `pct exec 109 -- kill -9 68939`
2. Reinstalled clean nodejs package: `apt-get install --reinstall nodejs -y`
3. Removed malicious files: `/usr/bin/.fullgc`, `/usr/bin/nodeo`

### Results

| Metric | Before | After |
|--------|--------|-------|
| Load Average | 5.58 | 2.26 |
| CPU Idle | 66.7% | 91.5% |

## IOCs (Indicators of Compromise)

### Files
- `/usr/bin/.fullgc` (crypto miner binary)
- `/usr/bin/nodeo` (renamed legitimate node)
- `/usr/bin/node` replaced with shell script wrapper

### Domains
- `file.551911.xyz` (malware C2/download server)

### Process Names
- `.fullgc` (hiding in plain sight with dot prefix)

### File Hashes
- Malware: `405bf5c2ab7c35ac9c8f5facf3482d3d`

## Follow-Up Actions

### Required
1. Investigate npm package dependencies for malicious code
2. Check wanderwish application for vulnerabilities
3. Review container access logs
4. Scan other containers for similar infections
5. Implement CPU usage monitoring/alerting

---

**Status**: Resolved
**Last Updated**: 2026-01-21
