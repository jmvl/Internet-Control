#!/bin/sh

# OpenWrt Multi-WiFi Time-Based Bandwidth Throttling Setup Script
# This script can manage multiple WiFi interfaces simultaneously
# Usage: sh openwrt_multi_wifi_throttle.sh

# Configuration Variables
THROTTLE_DOWNLOAD="256"      # Throttled download speed in kbit/s
THROTTLE_UPLOAD="256"        # Throttled upload speed in kbit/s
NORMAL_DOWNLOAD="85000"     # Normal download speed in kbit/s
NORMAL_UPLOAD="10000"       # Normal upload speed in kbit/s
THROTTLE_START="00:00"      # Start throttling time
THROTTLE_END="09:00"        # End throttling time

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Detect all wireless interfaces
detect_all_wireless() {
    log_info "Detecting all WiFi interfaces..."
    
    WIRELESS_INTERFACES=$(iw dev | grep Interface | awk '{print $2}')
    if [ -z "$WIRELESS_INTERFACES" ]; then
        log_error "No wireless interfaces found!"
        exit 1
    fi
    
    echo ""
    log_info "Available WiFi interfaces:"
    for iface in $WIRELESS_INTERFACES; do
        SSID=$(iw dev "$iface" info 2>/dev/null | grep ssid | awk '{print $2}')
        BSSID=$(iw dev "$iface" info 2>/dev/null | grep addr | awk '{print $2}')
        STATUS=$(ip link show "$iface" | grep -q "UP" && echo "UP" || echo "DOWN")
        echo "  - $iface: SSID=${SSID:-Not set}, BSSID=${BSSID:-N/A}, Status=$STATUS"
    done
    echo ""
}

# Select multiple interfaces
select_multiple_interfaces() {
    log_info "Select WiFi interfaces to throttle (space-separated numbers):"
    echo ""
    
    # Create numbered list
    i=1
    for iface in $WIRELESS_INTERFACES; do
        eval "IFACE_$i=$iface"
        SSID=$(iw dev "$iface" info 2>/dev/null | grep ssid | awk '{print $2}')
        echo "  $i) $iface (${SSID:-No SSID})"
        i=$((i + 1))
    done
    echo ""
    
    read -p "Enter numbers (e.g., '1 2' for first two interfaces): " selections
    
    SELECTED_INTERFACES=""
    for selection in $selections; do
        if [ "$selection" -ge 1 ] 2>/dev/null && [ "$selection" -lt "$i" ] 2>/dev/null; then
            eval "selected_iface=\$IFACE_$selection"
            SELECTED_INTERFACES="$SELECTED_INTERFACES $selected_iface"
        else
            log_warning "Invalid selection: $selection"
        fi
    done
    
    if [ -z "$SELECTED_INTERFACES" ]; then
        log_error "No valid interfaces selected"
        exit 1
    fi
    
    log_success "Selected interfaces:$SELECTED_INTERFACES"
}

# Configure speed settings interactively
configure_speeds() {
    log_info "Configure throttling speeds..."
    echo ""
    log_info "Current configuration:"
    echo "  Normal speeds: ${NORMAL_DOWNLOAD}/${NORMAL_UPLOAD} kbps (down/up)"
    echo "  Throttled speeds: ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps (down/up)"
    echo "  Throttle time: ${THROTTLE_START} - ${THROTTLE_END}"
    echo ""
    
    read -p "Modify these settings? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        log_info "Enter new speed settings:"
        
        read -p "Normal download speed (kbps, current: $NORMAL_DOWNLOAD): " new_normal_down
        read -p "Normal upload speed (kbps, current: $NORMAL_UPLOAD): " new_normal_up
        read -p "Throttle download speed (kbps, current: $THROTTLE_DOWNLOAD): " new_throttle_down
        read -p "Throttle upload speed (kbps, current: $THROTTLE_UPLOAD): " new_throttle_up
        
        echo ""
        log_info "Enter throttling schedule:"
        read -p "Throttle start time (HH:MM, current: $THROTTLE_START): " new_start_time
        read -p "Throttle end time (HH:MM, current: $THROTTLE_END): " new_end_time
        
        # Use new values if provided
        NORMAL_DOWNLOAD=${new_normal_down:-$NORMAL_DOWNLOAD}
        NORMAL_UPLOAD=${new_normal_up:-$NORMAL_UPLOAD}
        THROTTLE_DOWNLOAD=${new_throttle_down:-$THROTTLE_DOWNLOAD}
        THROTTLE_UPLOAD=${new_throttle_up:-$THROTTLE_UPLOAD}
        THROTTLE_START=${new_start_time:-$THROTTLE_START}
        THROTTLE_END=${new_end_time:-$THROTTLE_END}
        
        log_success "Configuration updated"
    fi
    
    echo ""
    log_info "Final configuration:"
    echo "  Normal speeds: ${NORMAL_DOWNLOAD}/${NORMAL_UPLOAD} kbps (down/up)"
    echo "  Throttled speeds: ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps (down/up)"
    echo "  Throttle time: ${THROTTLE_START} - ${THROTTLE_END}"
    echo ""
}

# Configure SQM for multiple interfaces
configure_multi_sqm() {
    log_info "Configuring SQM for selected interfaces..."
    
    for iface in $SELECTED_INTERFACES; do
        log_info "Configuring SQM for $iface..."
        
        SQM_NAME="wifi_$(echo $iface | tr -d '-')"
        
        # Remove existing config
        uci -q delete sqm.${SQM_NAME} 2>/dev/null
        
        # Create new config
        uci set sqm.${SQM_NAME}=queue
        uci set sqm.${SQM_NAME}.enabled='1'
        uci set sqm.${SQM_NAME}.interface="$iface"
        uci set sqm.${SQM_NAME}.download="$NORMAL_DOWNLOAD"
        uci set sqm.${SQM_NAME}.upload="$NORMAL_UPLOAD"
        uci set sqm.${SQM_NAME}.qdisc='fq_codel'
        uci set sqm.${SQM_NAME}.script='simple.qos'
        uci set sqm.${SQM_NAME}.linklayer='none'
        uci set sqm.${SQM_NAME}.overhead='0'
        uci set sqm.${SQM_NAME}.verbosity='5'
        uci set sqm.${SQM_NAME}.debug_logging='0'
        
        log_success "SQM configured for $iface"
    done
    
    uci commit sqm
    /etc/init.d/sqm restart
}

# Create master throttling scripts
create_master_scripts() {
    log_info "Creating master throttling scripts..."
    
    mkdir -p /root/scripts
    
    # Create master throttle script
    cat > /root/scripts/multi_wifi_throttle.sh << 'EOF'
#!/bin/sh
# Master WiFi throttling script - throttles all configured interfaces

THROTTLE_DOWNLOAD="64"
THROTTLE_UPLOAD="64"
SELECTED_INTERFACES="INTERFACES_PLACEHOLDER"

logger -t "Multi-WiFi-Throttle" "Starting multi-WiFi throttling..."

# Stop SQM
/etc/init.d/sqm stop

# Configure each interface for throttling
for iface in $SELECTED_INTERFACES; do
    SQM_NAME="wifi_$(echo $iface | tr -d '-')"
    
    # Update SQM configuration
    uci set sqm.${SQM_NAME}.download="$THROTTLE_DOWNLOAD"
    uci set sqm.${SQM_NAME}.upload="$THROTTLE_UPLOAD"
    
    logger -t "Multi-WiFi-Throttle" "Throttling $iface to ${THROTTLE_DOWNLOAD}kbps"
done

# Commit changes and restart SQM
uci commit sqm
/etc/init.d/sqm start

logger -t "Multi-WiFi-Throttle" "Multi-WiFi throttling activated"
echo "Multi-WiFi throttling activated: $SELECTED_INTERFACES"
EOF

    # Create master restore script
    cat > /root/scripts/multi_wifi_normal.sh << 'EOF'
#!/bin/sh
# Master WiFi normal speed script - restores all configured interfaces

NORMAL_DOWNLOAD="85000"
NORMAL_UPLOAD="10000"
SELECTED_INTERFACES="INTERFACES_PLACEHOLDER"

logger -t "Multi-WiFi-Throttle" "Restoring normal speeds for all WiFi..."

# Stop SQM
/etc/init.d/sqm stop

# Configure each interface for normal speeds
for iface in $SELECTED_INTERFACES; do
    SQM_NAME="wifi_$(echo $iface | tr -d '-')"
    
    # Update SQM configuration
    uci set sqm.${SQM_NAME}.download="$NORMAL_DOWNLOAD"
    uci set sqm.${SQM_NAME}.upload="$NORMAL_UPLOAD"
    
    logger -t "Multi-WiFi-Throttle" "Restoring $iface to ${NORMAL_DOWNLOAD}kbps"
done

# Commit changes and restart SQM
uci commit sqm
/etc/init.d/sqm start

logger -t "Multi-WiFi-Throttle" "Normal speeds restored for all WiFi"
echo "Normal speeds restored: $SELECTED_INTERFACES"
EOF

    # Replace placeholder with actual interfaces
    sed -i "s/INTERFACES_PLACEHOLDER/$SELECTED_INTERFACES/g" /root/scripts/multi_wifi_throttle.sh
    sed -i "s/INTERFACES_PLACEHOLDER/$SELECTED_INTERFACES/g" /root/scripts/multi_wifi_normal.sh
    
    # Make executable
    chmod +x /root/scripts/multi_wifi_*.sh
    
    log_success "Master throttling scripts created"
}

# Update cron jobs
update_cron_jobs() {
    log_info "Updating cron jobs for multi-WiFi throttling..."
    
    # Create new cron file
    cat > /tmp/multi_wifi_cron << EOF
# Multi-WiFi time-based bandwidth throttling schedule
# Targets: $SELECTED_INTERFACES
# Format: minute hour day month weekday command

# === DAILY SCHEDULE ===
# Enable multi-WiFi throttling at $THROTTLE_START
0 $(echo $THROTTLE_START | cut -d: -f1) * * * /root/scripts/multi_wifi_throttle.sh

# Restore normal WiFi speeds at $THROTTLE_END
0 $(echo $THROTTLE_END | cut -d: -f1) * * * /root/scripts/multi_wifi_normal.sh

# === BACKUP: Individual interface controls (for manual use) ===
# These are created but not scheduled - use manually if needed
EOF

    # Install cron jobs
    crontab /tmp/multi_wifi_cron
    /etc/init.d/cron restart
    
    rm /tmp/multi_wifi_cron
    log_success "Cron jobs updated for multi-WiFi throttling"
}

# Create status and control scripts
create_control_scripts() {
    log_info "Creating control scripts..."
    
    # Master control script
    cat > /root/scripts/multi_wifi_control.sh << 'EOF'
#!/bin/sh
# Multi-WiFi throttle control script

case "$1" in
    on|enable|throttle)
        echo "=== Multi-WiFi Throttling Control ==="
        echo ""
        echo "Default throttling speeds:"
        echo "  Download: 64 kbps"
        echo "  Upload: 64 kbps"
        echo ""
        read -p "Use custom speeds? (y/n): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "Enter custom throttling speeds:"
            read -p "Download speed (kbps): " custom_download
            read -p "Upload speed (kbps): " custom_upload
            
            # Validate input
            if ! [[ "$custom_download" =~ ^[0-9]+$ ]] || ! [[ "$custom_upload" =~ ^[0-9]+$ ]]; then
                echo "Invalid input. Using default speeds (64/64 kbps)."
                custom_download="64"
                custom_upload="64"
            fi
            
            echo ""
            echo "Applying custom throttling: ${custom_download}/${custom_upload} kbps (down/up)"
            
            # Create temporary custom throttling script
            cat > /tmp/custom_throttle.sh << CUSTOM_EOF
#!/bin/sh
THROTTLE_DOWNLOAD="$custom_download"
THROTTLE_UPLOAD="$custom_upload"
SELECTED_INTERFACES="INTERFACES_PLACEHOLDER"

logger -t "Multi-WiFi-Throttle" "Starting custom multi-WiFi throttling (\${THROTTLE_DOWNLOAD}/\${THROTTLE_UPLOAD} kbps)..."

# Stop SQM
/etc/init.d/sqm stop

# Configure each interface for custom throttling
for iface in \$SELECTED_INTERFACES; do
    SQM_NAME="wifi_\$(echo \$iface | tr -d '-')"
    
    # Update SQM configuration
    uci set sqm.\${SQM_NAME}.download="\$THROTTLE_DOWNLOAD"
    uci set sqm.\${SQM_NAME}.upload="\$THROTTLE_UPLOAD"
    
    logger -t "Multi-WiFi-Throttle" "Custom throttling \$iface to \${THROTTLE_DOWNLOAD}/\${THROTTLE_UPLOAD} kbps"
done

# Commit changes and restart SQM
uci commit sqm
/etc/init.d/sqm start

logger -t "Multi-WiFi-Throttle" "Custom multi-WiFi throttling activated"
echo "Custom multi-WiFi throttling activated: \$SELECTED_INTERFACES"
echo "Speed: \${THROTTLE_DOWNLOAD}/\${THROTTLE_UPLOAD} kbps (down/up)"
CUSTOM_EOF
            
            chmod +x /tmp/custom_throttle.sh
            /tmp/custom_throttle.sh
            rm /tmp/custom_throttle.sh
        else
            echo "Using default throttling speeds..."
            /root/scripts/multi_wifi_throttle.sh
        fi
        ;;
    off|disable|normal)
        echo "Restoring normal speeds for all WiFi..."
        /root/scripts/multi_wifi_normal.sh
        ;;
    status)
        echo "=== Multi-WiFi Throttling Status ==="
        echo "Current time: $(date)"
        echo ""
        echo "Configured interfaces: INTERFACES_PLACEHOLDER"
        echo ""
        echo "Current SQM Settings:"
        for iface in INTERFACES_PLACEHOLDER; do
            SQM_NAME="wifi_$(echo $iface | tr -d '-')"
            DOWN=$(uci get sqm.${SQM_NAME}.download 2>/dev/null || echo "Not configured")
            UP=$(uci get sqm.${SQM_NAME}.upload 2>/dev/null || echo "Not configured")
            echo "  $iface: ${DOWN}/${UP} kbps (down/up)"
        done
        echo ""
        echo "Interface Status:"
        for iface in INTERFACES_PLACEHOLDER; do
            STATUS=$(ip link show "$iface" 2>/dev/null | grep -q "UP" && echo "UP" || echo "DOWN")
            SSID=$(iw dev "$iface" info 2>/dev/null | grep ssid | awk '{print $2}' || echo "No SSID")
            echo "  $iface: $STATUS (SSID: $SSID)"
        done
        echo ""
        echo "Recent events:"
        logread | grep "Multi-WiFi-Throttle" | tail -5
        ;;
    *)
        echo "Usage: $0 {on|off|status}"
        echo "  on  - Enable throttling (with optional custom speeds)"
        echo "  off - Restore normal speeds"
        echo "  status - Show current status"
        exit 1
        ;;
esac
EOF

    # Replace placeholder
    sed -i "s/INTERFACES_PLACEHOLDER/$SELECTED_INTERFACES/g" /root/scripts/multi_wifi_control.sh
    chmod +x /root/scripts/multi_wifi_control.sh
    
    # Create alias
    echo "alias multi-wifi-throttle='/root/scripts/multi_wifi_control.sh'" >> /etc/profile
    
    log_success "Control scripts created"
}

# Main execution
main() {
    echo ""
    log_info "=== Multi-WiFi Throttling Setup ==="
    echo ""
    
    check_root
    detect_all_wireless
    select_multiple_interfaces
    configure_speeds
    
    # Show summary
    echo ""
    log_info "Configuration Summary:"
    echo "  Selected interfaces:$SELECTED_INTERFACES"
    echo "  Normal speeds: ${NORMAL_DOWNLOAD}/${NORMAL_UPLOAD} kbps"
    echo "  Throttled speeds: ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps"
    echo "  Throttle time: ${THROTTLE_START} - ${THROTTLE_END}"
    echo ""
    
    read -p "Continue with multi-WiFi setup? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled"
        exit 0
    fi
    
    configure_multi_sqm
    create_master_scripts
    update_cron_jobs
    create_control_scripts
    
    echo ""
    log_success "=== Multi-WiFi Throttling Setup Complete! ==="
    echo ""
    log_info "Commands available:"
    echo "  multi-wifi-throttle on     - Enable throttling for all selected WiFi"
    echo "  multi-wifi-throttle off    - Disable throttling for all selected WiFi"
    echo "  multi-wifi-throttle status - Check status"
    echo ""
    log_info "Automatic throttling: ${THROTTLE_START} - ${THROTTLE_END}"
    echo ""
}

main "$@"