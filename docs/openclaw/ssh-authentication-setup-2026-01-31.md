# OpenClaw SSH Authentication Setup

**Date**: 2026-01-31
**Author**: Claude Code (Infrastructure Engineer)
**Status**: Completed

## Overview

This document describes the SSH authentication setup between the OpenClaw LXC container (nestor) and the local macOS development machine. This setup enables bidirectional SSH communication for automated tasks, remote execution, and workflow automation.

## Network Configuration

- **nestor LXC Container**: 192.168.1.151 (Container ID: 101)
- **macOS Development Machine**: 192.168.1.165
- **Hypervisor**: pve2 (192.168.1.10)
- **Access Method**: `ssh root@pve2 "pct exec 101 -- <command>"`

## SSH Key Configuration

### macOS SSH Keys (Local Machine)

**Key 1 - Primary RSA Key**:
```
Type: RSA 3072-bit
Fingerprint: SHA256:Mn2FCI8K73tbzygo5qP1+enEsTrRsU/vxlfkjS0v9Kc
Comment: jm@JMs-MacBook-Air.local
Location: ~/.ssh/id_rsa
```

**Key 2 - Secondary RSA Key**:
```
Type: RSA 2048-bit
Fingerprint: SHA256:dPWtSPJ7YfIAB0OmwGfNZ0/WpwSlQUUpssafcSWdyVs
Comment: ssh-key-2022-08-24
Location: ~/.ssh/id_rsa (backup key)
```

### nestor LXC SSH Keys

**Generated SSH Key Pair** (2026-01-31):
```
Type: RSA 4096-bit
Fingerprint: SHA256:CbkBVtr4qEwyMFCfkViGLqa/xB1TnkO6H6J+nvbNBAQ
Comment: nestor@openclaw
Location on nestor: /root/.ssh/id_rsa
Location on macOS: ~/.ssh/authorized_keys
```

**Public Key Content**:
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCj6SuxMjSfAgsZI6l+9wZixqUj5cLEwuHRpfck7YWyj0WW1ugYSaVHzTDeJbyoLEdHwqkjQ0UeD9yd3Qw1FQfiKK4D/bf2IzgyXD2g41YuFwySN2xsBAXxVGXx7jLhf0aTBtCtA3PfHMb3FdLbYPbpihCrdyu/Wzv5mXUfJjCtcs79d+3yDBsj/hIiYGOymNvglenWQuSESxG8g0Q1c+1C61z6PARsCG1S5d2JEYDeGeOjiXSQBdFD2fqigEOTlhBIp8ItDu90EJm9RGlyqXdjw6/KaU1wRk/yQp1Ll1xz5C90GvwM8x5fMtL5P60liNuMNWYLhmLS+rHInMaLX3wahJbWa1fdgrRRINEbT6d7oMsICdsINJ0LibPYE++9AYmNmNJpBBRPSqpk8m/oLlsYmhHSaSjiojVfr3OxPct1elJeo3iU9wdw5EJYzDnPHAV86zfkm5Whfid/sOdujkG8ZWzmxceg/ltpPkr+ZoJfjmU1BXDmRkkD2LBbO6zyqX4/laBUIkEOas+WtVfJmBQlr7Cwt/EGqOhQmLV5/0WIOE96vmj22KtdMbZZU3xp/rgKvGja+9sTJTHa+vjKod2MgYHxYwi5vSz/P7Y47jexzBBAg9hEHkhSHvpNzVYCvY6RKgSbR60l6tX6d4XGxU7F0lo6UvHjInL6U5S7yrKXJw== nestor@openclaw
```

## Authentication Flow

### Direction 1: macOS → nestor
**Purpose**: Remote administration and configuration

**Configuration**:
- macOS public keys stored in nestor's `/root/.ssh/authorized_keys`
- Both primary and secondary macOS keys are authorized
- Connection method: `ssh root@192.168.1.151` or via pve2: `ssh root@pve2 "pct exec 101 -- <command>"`

**Test Command**:
```bash
ssh root@pve2 "pct exec 101 -- hostname"
# Output: nestor
```

### Direction 2: nestor → macOS (NEW)
**Purpose**: Automated callbacks, data synchronization, workflow automation

**Configuration**:
- nestor's public key stored in macOS `~/.ssh/authorized_keys`
- nestor uses `/root/.ssh/id_rsa` private key for authentication
- Connection method: `ssh jm@192.168.1.165`

**Test Command**:
```bash
ssh root@pve2 "pct exec 101 -- ssh -o BatchMode=yes jm@192.168.1.165 'hostname'"
# Output: MacBookPro-JM.local
```

## Setup Steps Completed

### 1. SSH Key Generation on nestor
```bash
ssh root@pve2 "pct exec 101 -- ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N \"\" -C \"nestor@openclaw\""
```

**Result**: 4096-bit RSA key pair generated with fingerprint `SHA256:CbkBVtr4qEwyMFCfkViGLqa/xB1TnkO6H6J+nvbNBAQ`

### 2. Public Key Distribution to macOS
```bash
# On macOS, ensure .ssh directory exists with proper permissions
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Add nestor's public key to authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCj6SuxMjSfAgsZI6l+9wZixqUj5cLEwuHRpfck7YWyj0WW1ugYSaVHzTDeJbyoLEdHwqkjQ0UeD9yd3Qw1FQfiKK4D/bf2IzgyXD2g41YuFwySN2xsBAXxVGXx7jLhf0aTBtCtA3PfHMb3FdLbYPbpihCrdyu/Wzv5mXUfJjCtcs79d+3yDBsj/hIiYGOymNvglenWQuSESxG8g0Q1c+1C61z6PARsCG1S5d2JEYDeGeOjiXSQBdFD2fqigEOTlhBIp8ItDu90EJm9RGlyqXdjw6/KaU1wRk/yQp1Ll1xz5C90GvwM8x5fMtL5P60liNuMNWYLhmLS+rHInMaLX3wahJbWa1fdgrRRINEbT6d7oMsICdsINJ0LibPYE++9AYmNmNJpBBRPSqpk8m/oLlsYmhHSaSjiojVfr3OxPct1elJeo3iU9wdw5EJYzDnPHAV86zfkm5Whfid/sOdujkG8ZWzmxceg/ltpPkr+ZoJfjmU1BXDmRkkD2LBbO6zyqX4/laBUIkEOas+WtVfJmBQlr7Cwt/EGqOhQmLV5/0WIOE96vmj22KtdMbZZU3xp/rgKvGja+9sTJTHa+vjKod2MgYHxYwi5vSz/P7Y47jexzBBAg9hEHkhSHvpNzVYCvY6RKgSbR60l6tX6d4XGxU7F0lo6UvHjInL6U5S7yrKXJw== nestor@openclaw" >> ~/.ssh/authorized_keys

# Set proper permissions
chmod 600 ~/.ssh/authorized_keys
```

### 3. Connection Verification
```bash
# Test SSH connection from nestor to macOS
ssh root@pve2 "pct exec 101 -- ssh -o BatchMode=yes -o StrictHostKeyChecking=no jm@192.168.1.165 'echo SSH connection successful!'"

# Output: SSH connection successful!
```

## Security Considerations

### Key Strength
- **macOS → nestor**: RSA 3072-bit and 2048-bit keys
- **nestor → macOS**: RSA 4096-bit key (industry standard for high-security applications)

### Access Control
- nestor connects as user `jm` (non-privileged user on macOS)
- No password authentication required (key-based auth only)
- macOS SSH server running on standard port 22

### File Permissions
- nestor: `/root/.ssh/` (700), `/root/.ssh/id_rsa` (600), `/root/.ssh/authorized_keys` (600)
- macOS: `~/.ssh/` (700), `~/.ssh/authorized_keys` (600), `~/.ssh/id_rsa` (600)

### Network Security
- Communication over LAN (192.168.1.0/24 subnet)
- Protected by OPNsense firewall (192.168.1.3)
- No exposure to external networks

## Use Cases

### Automated Backups
nestor can push logs and data to macOS for archival:
```bash
ssh root@pve2 "pct exec 101 -- scp /var/log/openclaw/*.log jm@192.168.1.165:~/backups/"
```

### Workflow Automation
n8n workflows can trigger commands on nestor that callback to macOS:
```bash
# From n8n workflow on nestor
ssh jm@192.168.1.165 "osascript -e 'display notification \"OpenClaw workflow complete\"'"
```

### Remote Monitoring
nestor can send health status to macOS monitoring dashboards:
```bash
ssh root@pve2 "pct exec 101 -- curl -s http://localhost:3000/api/health | ssh jm@192.168.1.165 'cat > ~/status/openclaw-health.json'"
```

## Troubleshooting

### Connection Refused
**Symptom**: `ssh: connect to host 192.168.1.165 port 22: Connection refused`

**Diagnosis**:
```bash
# Check if SSH server is running on macOS
netstat -an | grep "\.22 " | grep LISTEN

# Check Remote Login status (requires sudo)
sudo systemsetup -getremotelogin
```

**Resolution**: Enable Remote Login on macOS
- System Settings → General → Sharing → Remote Login

### Permission Denied
**Symptom**: `Permission denied (publickey,password,keyboard-interactive)`

**Diagnosis**:
```bash
# Verify nestor has private key
ssh root@pve2 "pct exec 101 -- ls -la /root/.ssh/id_rsa"

# Verify macOS has nestor's public key
grep "nestor@openclaw" ~/.ssh/authorized_keys

# Check file permissions
ssh root@pve2 "pct exec 101 -- ls -la /root/.ssh/"
```

**Resolution**:
```bash
# Regenerate keys if missing
ssh root@pve2 "pct exec 101 -- ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N \"\" -C \"nestor@openclaw\""

# Re-add public key to macOS
echo "<nestor_public_key>" >> ~/.ssh/authorized_keys
```

### Host Key Verification
**Symptom**: `The authenticity of host '192.168.1.165' can't be established`

**Resolution**: Add macOS to nestor's known_hosts
```bash
ssh root@pve2 "pct exec 101 -- ssh-keyscan -H 192.168.1.165 >> /root/.ssh/known_hosts"
```

## Testing and Validation

### Basic Connectivity Test
```bash
ssh root@pve2 "pct exec 101 -- ping -c 3 192.168.1.165"
```

### SSH Authentication Test
```bash
ssh root@pve2 "pct exec 101 -- ssh -o BatchMode=yes -o ConnectTimeout=5 jm@192.168.1.165 'whoami && hostname'"
# Expected output:
# jm
# MacBookPro-JM.local
```

### Remote Command Execution Test
```bash
ssh root@pve2 "pct exec 101 -- ssh jm@192.168.1.165 'date'"
# Expected output: Current date and time on macOS
```

### File Transfer Test
```bash
# From nestor to macOS
ssh root@pve2 "pct exec 101 -- echo 'test data' | ssh jm@192.168.1.165 'cat > ~/test-nestor-ssh.txt'"

# Verify on macOS
cat ~/test-nestor-ssh.txt
# Expected output: test data
```

## Maintenance

### Key Rotation
**Recommended**: Annually or if compromise suspected

**Procedure**:
1. Generate new key pair on nestor
2. Add new public key to macOS `authorized_keys`
3. Test new authentication
4. Remove old key from `authorized_keys`
5. Delete old private key from nestor

### Audit Trail
Check SSH access logs:
```bash
# On macOS
log show --predicate 'process == "sshd"' --last 1h

# On nestor
ssh root@pve2 "pct exec 101 -- journalctl -u sshd -n 50"
```

## References

- **OpenClaw Documentation**: `/docs/openclaw/README.md`
- **Proxmox LXC Documentation**: https://pve.proxmox.com/wiki/Linux_Container
- **SSH Key Management**: https://www.ssh.com/academy/ssh/key
- **macOS Remote Login**: https://support.apple.com/guide/mac-help/share-your-mac-s-screen-remotely-mh14141/mac

## Appendix: Quick Reference

### Essential Commands

**Access nestor from macOS**:
```bash
# Direct SSH
ssh root@192.168.1.151

# Via pve2
ssh root@pve2 "pct exec 101 -- bash -c '<command>'"
```

**Execute command on macOS from nestor**:
```bash
ssh root@pve2 "pct exec 101 -- ssh jm@192.168.1.165 '<command>'"
```

**Copy files from nestor to macOS**:
```bash
ssh root@pve2 "pct exec 101 -- cat /path/to/file" > ~/local-file.txt
```

**Copy files from macOS to nestor**:
```bash
cat ~/local-file.txt | ssh root@pve2 "pct exec 101 -- cat > /path/to/remote-file"
```

### Configuration Files

**nestor**:
- SSH config: `/root/.ssh/config` (if exists)
- Private key: `/root/.ssh/id_rsa`
- Public key: `/root/.ssh/id_rsa.pub`
- Authorized keys: `/root/.ssh/authorized_keys`
- Known hosts: `/root/.ssh/known_hosts`

**macOS**:
- SSH config: `~/.ssh/config`
- Private key: `~/.ssh/id_rsa`
- Public key: `~/.ssh/id_rsa.pub`
- Authorized keys: `~/.ssh/authorized_keys`
- Known hosts: `~/.ssh/known_hosts`

---

**Document Status**: Complete
**Last Updated**: 2026-01-31
**Next Review**: 2026-07-31 (6 months)
