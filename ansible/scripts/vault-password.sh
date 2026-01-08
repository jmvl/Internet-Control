#!/bin/bash
# Ansible Vault Password Retrieval Script
# This script retrieves the Ansible Vault password from a secure location
# Usage: Add to ansible.cfg: vault_password_script = ./scripts/vault-password.sh

# Method 1: From environment variable (recommended for automation)
if [ -n "$ANSIBLE_VAULT_PASSWORD" ]; then
    echo "$ANSIBLE_VAULT_PASSWORD"
    exit 0
fi

# Method 2: From password manager (example with 1Password)
# Uncomment and configure if using 1Password CLI
# if command -v op &> /dev/null; then
#     op get item "Ansible Vault" --fields password 2>/dev/null && exit 0
# fi

# Method 3: From encrypted file (GPG)
# Uncomment and configure if using GPG-encrypted file
# if [ -f "$HOME/.ansible-vault-password.gpg" ]; then
#     gpg --decrypt --quiet "$HOME/.ansible-vault-password.gpg" 2>/dev/null && exit 0
# fi

# Method 4: From file (less secure, only for development)
if [ -f "$HOME/.ansible-vault-password" ]; then
    cat "$HOME/.ansible-vault-password"
    exit 0
fi

# Fallback: Prompt for password (interactive)
echo "ERROR: Ansible Vault password not found. Please:" >&2
echo "  1. Set ANSIBLE_VAULT_PASSWORD environment variable, or" >&2
echo "  2. Create ~/.ansible-vault-password file, or" >&2
echo "  3. Configure password manager in this script" >&2
exit 1
