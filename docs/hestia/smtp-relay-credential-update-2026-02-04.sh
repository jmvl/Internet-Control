#!/bin/bash
#
# Hestia SMTP Relay Credential Update Script
# Date: 2026-02-04
# Purpose: Update EDPnet SMTP relay password on Hestia mail server
#
# Usage: ssh root@192.168.1.30 'bash -s' < smtp-relay-credential-update-2026-02-04.sh
# Or: Copy this script to Hestia and execute directly
#

set -e  # Exit on error

# Configuration
NEW_PASSWORD='*Gq%BdxS4JuN'
RELAY_HOST="relay.edpnet.be"
RELAY_PORT="587"
RELAY_USER="micheljean2.m2"
GLOBAL_CONFIG="/etc/exim4/smtp_relay.conf"

# Domain-specific configs
DOMAIN_CONFIGS=(
    "/etc/exim4/domains/accelior.com/smtp_relay.conf"
    "/etc/exim4/domains/acmea.tech/smtp_relay.conf"
    "/etc/exim4/domains/vega-messenger.com/smtp_relay.conf"
)

echo "=========================================="
echo "Hestia SMTP Relay Credential Update"
echo "=========================================="
echo "Date: $(date)"
echo ""

# Function to backup config
backup_config() {
    local config_file=$1
    if [ -f "$config_file" ]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d-%H%M%S)"
        echo "Creating backup: $backup_file"
        cp "$config_file" "$backup_file"
        chmod 640 "$backup_file"
        chown root:Debian-exim "$backup_file"
    else
        echo "Warning: $config_file does not exist, skipping backup"
        return 1
    fi
}

# Function to update config
update_config() {
    local config_file=$1
    echo ""
    echo "Processing: $config_file"

    if [ ! -f "$config_file" ]; then
        echo "File does not exist, skipping..."
        return 0
    fi

    # Backup
    backup_config "$config_file" || return 0

    # Display current config (with password hidden)
    echo "Current config (password hidden):"
    sed 's/^pass:.*/pass: [HIDDEN]/' "$config_file"

    # Update the password
    echo "Updating password..."
    cat > "$config_file" << EOF
host: ${RELAY_HOST}
port: ${RELAY_PORT}
user: ${RELAY_USER}
pass: ${NEW_PASSWORD}
EOF

    # Set correct permissions
    chmod 640 "$config_file"
    chown root:Debian-exim "$config_file"

    # Verify update
    echo "Updated config (password hidden):"
    sed 's/^pass:.*/pass: [HIDDEN]/' "$config_file"
    echo "Permissions: $(ls -l "$config_file" | awk '{print $1, $3, $4}')"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Step 1: Backup and update global config
echo "Step 1: Updating global SMTP relay configuration"
echo "=========================================="
update_config "$GLOBAL_CONFIG"

# Step 2: Check and update domain-specific configs
echo ""
echo "Step 2: Checking domain-specific configurations"
echo "=========================================="
for domain_config in "${DOMAIN_CONFIGS[@]}"; do
    if [ -f "$domain_config" ]; then
        echo ""
        echo "Found domain-specific config: $domain_config"
        update_config "$domain_config"
    else
        echo "No domain-specific config at: $domain_config"
    fi
done

# Step 3: Restart Exim
echo ""
echo "Step 3: Restarting Exim service"
echo "=========================================="
systemctl restart exim4
sleep 2

# Step 4: Verify Exim status
echo ""
echo "Step 4: Verifying Exim service status"
echo "=========================================="
if systemctl status exim4 --no-pager | head -n 10; then
    echo ""
    echo "Exim service is running"
else
    echo ""
    echo "Warning: Exim service may not be running properly"
fi

# Step 5: Check recent logs for authentication
echo ""
echo "Step 5: Checking recent Exim logs"
echo "=========================================="
echo "Recent relay activity:"
grep "send_via_smtp_relay" /var/log/exim4/mainlog | tail -5 || echo "No recent relay activity found"

echo ""
echo "Recent authentication attempts:"
grep "smtp_relay_login" /var/log/exim4/mainlog | tail -5 || echo "No recent authentication attempts found"

# Step 6: Test configuration syntax
echo ""
echo "Step 6: Testing Exim configuration"
echo "=========================================="
if exim4 -bV > /dev/null 2>&1; then
    echo "Exim configuration syntax: OK"
else
    echo "Warning: Exim configuration may have syntax errors"
    exim4 -bV
fi

# Summary
echo ""
echo "=========================================="
echo "Update Complete"
echo "=========================================="
echo ""
echo "Files updated:"
for domain_config in "${DOMAIN_CONFIGS[@]}"; do
    [ -f "$domain_config" ] && echo "  - $domain_config"
done
echo "  - $GLOBAL_CONFIG"
echo ""
echo "New credentials:"
echo "  Host: ${RELAY_HOST}"
echo "  Port: ${RELAY_PORT}"
echo "  User: ${RELAY_USER}"
echo "  Pass: [HIDDEN]"
echo ""
echo "To test email sending, run:"
echo "  echo 'Test email' | mail -s 'SMTP Relay Test' test@example.com"
echo ""
echo "To monitor logs in real-time:"
echo "  tail -f /var/log/exim4/mainlog"
echo ""
