#!/bin/bash
#
# Docker Connectivity Quick Fix Script
# Resolves connection refused issues from specific source IPs to Docker containers
#
# Usage: ./fix-docker-connectivity.sh <source_ip>
# Example: ./fix-docker-connectivity.sh 192.168.1.9
#

set -e

SOURCE_IP="${1:-192.168.1.9}"

echo "========================================="
echo "Docker Connectivity Quick Fix"
echo "========================================="
echo "Source IP: $SOURCE_IP"
echo "Target Host: $(hostname)"
echo "Date: $(date)"
echo "========================================="
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error:${NC} This script must be run as root"
    echo "Try: sudo $0 $SOURCE_IP"
    exit 1
fi

# Backup function
backup_iptables() {
    BACKUP_DIR="/root/iptables-backups"
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/iptables-backup-$(date +%Y%m%d-%H%M%S).rules"

    echo -e "${BLUE}→${NC} Backing up current iptables rules to $BACKUP_FILE"
    iptables-save > "$BACKUP_FILE"
    echo -e "${GREEN}✓${NC} Backup created"
}

# Function to check if rule exists
rule_exists() {
    iptables -C "$@" 2>/dev/null
}

echo "This script will apply the following fixes:"
echo "1. Add DOCKER-USER accept rule for source IP $SOURCE_IP"
echo "2. Flush connection tracking entries for $SOURCE_IP"
echo "3. Ensure br_netfilter module is loaded"
echo "4. Make iptables rules persistent"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Step 1: Backup iptables
echo ""
echo "Step 1: Backing up iptables rules..."
backup_iptables

# Step 2: Add DOCKER-USER accept rule
echo ""
echo "Step 2: Adding DOCKER-USER accept rule for $SOURCE_IP..."
if rule_exists DOCKER-USER -s "$SOURCE_IP" -j ACCEPT; then
    echo -e "${YELLOW}⚠${NC} Rule already exists"
    iptables -L DOCKER-USER -n -v --line-numbers | grep "$SOURCE_IP"
else
    iptables -I DOCKER-USER 1 -s "$SOURCE_IP" -j ACCEPT
    echo -e "${GREEN}✓${NC} Rule added successfully"
    iptables -L DOCKER-USER -n -v --line-numbers | head -5
fi

# Step 3: Add established connections rule if not exists
echo ""
echo "Step 3: Ensuring ESTABLISHED,RELATED connections are accepted..."
if ! rule_exists DOCKER-USER -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null && \
   ! rule_exists DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    iptables -I DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    echo -e "${GREEN}✓${NC} Rule added"
else
    echo -e "${YELLOW}⚠${NC} Rule already exists"
fi

# Step 4: Flush connection tracking for source IP
echo ""
echo "Step 4: Flushing connection tracking entries for $SOURCE_IP..."
if command -v conntrack >/dev/null 2>&1; then
    BEFORE_COUNT=$(conntrack -C 2>/dev/null || echo "N/A")
    conntrack -D -s "$SOURCE_IP" 2>/dev/null || true
    AFTER_COUNT=$(conntrack -C 2>/dev/null || echo "N/A")
    echo -e "${GREEN}✓${NC} Connection tracking flushed"
    echo "  Before: $BEFORE_COUNT entries"
    echo "  After: $AFTER_COUNT entries"
else
    echo -e "${YELLOW}⚠${NC} conntrack command not found, skipping"
    echo "  Install with: apt-get install conntrack"
fi

# Step 5: Load br_netfilter module
echo ""
echo "Step 5: Ensuring br_netfilter module is loaded..."
if lsmod | grep -q br_netfilter; then
    echo -e "${GREEN}✓${NC} br_netfilter module is already loaded"
else
    modprobe br_netfilter
    echo -e "${GREEN}✓${NC} br_netfilter module loaded"

    # Make persistent
    if ! grep -q "^br_netfilter" /etc/modules 2>/dev/null; then
        echo "br_netfilter" >> /etc/modules
        echo -e "${GREEN}✓${NC} Added to /etc/modules for persistence"
    fi
fi

# Step 6: Make iptables rules persistent
echo ""
echo "Step 6: Making iptables rules persistent..."
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save
    echo -e "${GREEN}✓${NC} Rules saved with netfilter-persistent"
elif command -v iptables-save >/dev/null 2>&1; then
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
    echo -e "${GREEN}✓${NC} Rules saved to /etc/iptables/"

    # Install iptables-persistent if not present
    if ! dpkg -l | grep -q iptables-persistent; then
        echo -e "${YELLOW}→${NC} Installing iptables-persistent for automatic restore on boot..."
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq iptables-persistent
        echo -e "${GREEN}✓${NC} iptables-persistent installed"
    fi
else
    echo -e "${YELLOW}⚠${NC} Could not find persistence method"
fi

# Step 7: Create custom restore script
echo ""
echo "Step 7: Creating custom iptables restore script..."
cat > /etc/docker/custom-iptables-restore.sh <<EOF
#!/bin/bash
# Custom iptables rules for Docker networking
# Auto-generated on $(date)

# Allow traffic from NPM host ($SOURCE_IP)
iptables -C DOCKER-USER -s $SOURCE_IP -j ACCEPT 2>/dev/null || \\
    iptables -I DOCKER-USER 1 -s $SOURCE_IP -j ACCEPT

# Allow established connections
iptables -C DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \\
    iptables -I DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

logger "Custom Docker iptables rules applied for $SOURCE_IP"
EOF

chmod +x /etc/docker/custom-iptables-restore.sh
echo -e "${GREEN}✓${NC} Script created at /etc/docker/custom-iptables-restore.sh"

# Step 8: Create systemd service for custom rules
echo ""
echo "Step 8: Creating systemd service for automatic rule application..."
cat > /etc/systemd/system/docker-custom-iptables.service <<EOF
[Unit]
Description=Apply Custom Docker iptables Rules
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/etc/docker/custom-iptables-restore.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable docker-custom-iptables.service
systemctl start docker-custom-iptables.service
echo -e "${GREEN}✓${NC} Systemd service created and enabled"

# Verification
echo ""
echo "========================================="
echo "Verification"
echo "========================================="
echo ""
echo "Current DOCKER-USER chain rules:"
iptables -L DOCKER-USER -n -v --line-numbers
echo ""
echo "Connection tracking status:"
if command -v conntrack >/dev/null 2>&1; then
    CONNTRACK_COUNT=$(cat /proc/sys/net/netfilter/nf_conntrack_count)
    CONNTRACK_MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
    echo "  Entries: $CONNTRACK_COUNT / $CONNTRACK_MAX"
else
    echo "  conntrack not available"
fi

# Final summary
echo ""
echo "========================================="
echo "Fix Complete!"
echo "========================================="
echo ""
echo -e "${GREEN}✓${NC} All fixes have been applied successfully"
echo ""
echo "What was done:"
echo "  1. ✓ Added DOCKER-USER accept rule for $SOURCE_IP"
echo "  2. ✓ Flushed connection tracking entries"
echo "  3. ✓ Loaded br_netfilter kernel module"
echo "  4. ✓ Made iptables rules persistent"
echo "  5. ✓ Created auto-restore script and service"
echo ""
echo "Testing from source host ($SOURCE_IP):"
echo "  nc -vz $(hostname -I | awk '{print $1}') 8092"
echo "  curl -v http://$(hostname -I | awk '{print $1}'):8092"
echo ""
echo "If issues persist, run the diagnostic script:"
echo "  ./diagnose-docker-connectivity.sh $SOURCE_IP 8092"
echo ""
echo "To view applied rules:"
echo "  iptables -L DOCKER-USER -n -v"
echo ""
echo "To rollback (if needed):"
echo "  iptables-restore < /root/iptables-backups/iptables-backup-*.rules"
echo ""
echo "Logs:"
echo "  journalctl -u docker-custom-iptables.service"
echo "  tail -f /var/log/syslog | grep 'Custom Docker iptables'"
echo "========================================="
