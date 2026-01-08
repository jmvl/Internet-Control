# Ansible Vault Implementation Guide

**Date**: 2026-01-08
**Status**: ✅ Phase 2 Complete
**Purpose**: Secure secrets management for Ansible playbooks

---

## Overview

Ansible Vault has been implemented to encrypt sensitive passwords and API tokens used in playbooks. This prevents secrets from being stored in plain text in the repository.

---

## Files Created

| File | Purpose | Permissions |
|------|---------|-------------|
| `group_vars/all/vault.yml` | Encrypted secrets | 0600 (encrypted) |
| `scripts/vault-password.sh` | Vault password retrieval script | 0755 |
| `~/.ansible-vault-password` | Local vault password file | 0600 |
| `ansible.cfg` | Vault configuration | Updated |

---

## How It Works

### Automatic Decryption

When running playbooks, Ansible automatically:
1. Calls `scripts/vault-password.sh`
2. Script retrieves password from `~/.ansible-vault-password` file
3. Ansible decrypts `group_vars/all/vault.yml`
4. Variables are available in playbooks as `{{ smtp_relay_credentials.host }}`

### Vault Password Script

The `scripts/vault-password.sh` script checks multiple sources (in order):
1. Environment variable `ANSIBLE_VAULT_PASSWORD`
2. Password manager (1Password CLI) - optional
3. GPG-encrypted file - optional
4. Plain text file `~/.ansible-vault-password` - current method

---

## Usage

### Viewing Encrypted Secrets

```bash
cd /Users/jm/Codebase/internet-control/ansible

# View vault contents
ansible-vault view group_vars/all/vault.yml

# Edit vault contents
ansible-vault edit group_vars/all/vault.yml

# Rekey vault (change password)
ansible-vault rekey group_vars/all/vault.yml
```

### Running Playbooks with Vault

No special flags needed - vault is automatically decrypted:

```bash
# Normal playbook execution
ansible-playbook playbooks/hestia-mail-maintenance-refactored.yml

# With tags
ansible-playbook playbooks/hestia-mail-maintenance-refactored.yml --tags exim

# Dry run
ansible-playbook playbooks/hestia-mail-maintenance-refactored.yml --check
```

---

## Current Encrypted Variables

### SMTP Relay Credentials (EDP.net)

```yaml
smtp_relay_credentials:
  host: "relay.edpnet.be"
  port: 587
  user: ""  # Currently empty (unauthenticated relay)
  pass: ""  # Currently empty (unauthenticated relay)
```

**Note**: Currently using unauthenticated SMTP relay through EDP.net. If authentication is required in the future, update these values in the vault.

### Other Placeholders

- `hestia_api`: HestiaCP API credentials
- `database_credentials`: MySQL/PostgreSQL passwords
- `monitoring`: API keys for monitoring services
- `email_notifications`: Email alert settings

---

## Adding New Secrets

### Step 1: Edit Vault File

```bash
cd /Users/jm/Codebase/internet-control/ansible
ansible-vault edit group_vars/all/vault.yml
```

### Step 2: Add Your Secret

```yaml
my_new_service:
  api_key: "secret-key-here"
  username: "service-user"
  password: "service-password"
```

### Step 3: Use in Playbook

```yaml
- name: Deploy service config
  template:
    src: service.conf.j2
    dest: /etc/service/config.conf
  vars:
    api_key: "{{ my_new_service.api_key }}"
```

---

## Security Best Practices

### ✅ Current Implementation

- Vault password stored locally in `~/.ansible-vault-password` (0600 permissions)
- Vault file encrypted with AES256
- `.gitignore` should exclude vault password file
- Vault YAML file can be committed to git (encrypted)

### ⚠️ Important Notes

1. **Never commit** `~/.ansible-vault-password` to git
2. **Never commit** unencrypted secrets to git
3. **Vault password file** is machine-specific (each user generates their own)
4. **Team collaboration**: Share vault password securely (1Password, GPG, etc.)

### 🔒 Production Deployment

For production environments, consider:
1. Using password manager integration (1Password CLI, LastPass CLI, etc.)
2. Using GPG-encrypted vault password file
3. Using environment variables in CI/CD (GitHub Actions Secrets, etc.)

---

## Troubleshooting

### Error: "Decryption failed"

**Problem**: Ansible cannot decrypt vault file

**Solutions**:
```bash
# 1. Check vault password file exists
ls -la ~/.ansible-vault-password

# 2. Verify vault file is encrypted
head -1 group_vars/all/vault.yml
# Should show: $ANSIBLE_VAULT;1.1;AES256

# 3. Test decryption
ansible-vault view group_vars/all/vault.yml

# 4. Check ansible.cfg has vault_password_file
grep vault_password_file ansible.cfg
```

### Error: "Variable undefined"

**Problem**: Vault variable not accessible in playbook

**Solution**:
```yaml
# WRONG - direct access (not from vault)
smtp_user: "{{ smtp_relay_user }}"

# CORRECT - access vault dictionary
smtp_user: "{{ smtp_relay_credentials.user }}"
```

### Regenerating Vault Password

If vault password is compromised:

```bash
# Generate new password
openssl rand -base64 24 > ~/.ansible-vault-password
chmod 600 ~/.ansible-vault-password

# Rekey vault (change password)
ansible-vault rekey group_vars/all/vault.yml --new-vault-password-file ~/.ansible-vault-password

# Test decryption
ansible-vault view group_vars/all/vault.yml
```

---

## Migration from Plain Text

### Before (Plain Text - INSECURE)

```yaml
# defaults/main.yml
smtp_relay_user: "username"
smtp_relay_pass: "plaintext-password"  # ❌ INSECURE
```

### After (Vault Encrypted - SECURE)

```yaml
# group_vars/all/vault.yml (encrypted)
smtp_relay_credentials:
  user: "username"
  pass: "encrypted-password"  # ✅ SECURE

# defaults/main.yml
smtp_relay_user: "{{ smtp_relay_credentials.user }}"
smtp_relay_pass: "{{ smtp_relay_credentials.pass }}"
```

---

## CI/CD Integration

For GitHub Actions or other CI/CD systems:

### Method 1: Environment Variable

```yaml
# .github/workflows/ansible-deploy.yml
- name: Run Ansible playbook
  env:
    ANSIBLE_VAULT_PASSWORD: ${{ secrets.VAULT_PASSWORD }}
  run: |
    ansible-playbook playbooks/deploy.yml
```

### Method 2: Vault Password File

```yaml
# .github/workflows/ansible-deploy.yml
- name: Create vault password file
  run: |
    echo "${{ secrets.VAULT_PASSWORD }}" > ~/.ansible-vault-password
    chmod 600 ~/.ansible-vault-password

- name: Run Ansible playbook
  run: |
    cd ansible
    ansible-playbook playbooks/deploy.yml
```

---

## Checklist

### Initial Setup ✅
- [x] Generate vault password
- [x] Create `group_vars/all/vault.yml`
- [x] Encrypt vault file
- [x] Create `scripts/vault-password.sh`
- [x] Update `ansible.cfg` with vault_password_file
- [x] Update role defaults to use vault variables
- [x] Test vault decryption
- [ ] Add `.gitignore` entry for vault password file

### Team Collaboration
- [ ] Document vault password sharing procedure
- [ ] Set up password manager integration (optional)
- [ ] Add CI/CD vault configuration (optional)
- [ ] Train team members on vault usage

### Maintenance
- [ ] Rotate vault passwords quarterly
- [ ] Audit vault access logs
- [ ] Update secrets when services change
- [ ] Review vault contents for stale entries

---

## Next Steps

Phase 2 is now complete! The Ansible Vault infrastructure is in place.

**Recommended Next Actions**:
1. Test playbook execution with vault variables
2. Add actual SMTP relay credentials if authentication is required
3. Set up `.gitignore` to exclude local vault password file
4. Document team password sharing procedure
5. (Optional) Phase 3: Wire up handlers in existing tasks

---

**Implementation Time**: ~30 minutes
**Status**: ✅ Phase 2 Complete
**Security Level**: 🔒 Significantly improved (secrets encrypted)
