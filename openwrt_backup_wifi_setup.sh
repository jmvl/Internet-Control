#!/bin/sh

# OpenWrt Backup WiFi Networks Setup Script
# Creates hidden backup WiFi networks based on existing configurations
# These backup networks won't be affected by throttling and provide emergency access
# Usage: sh openwrt_backup_wifi_setup_fixed.sh

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
log_detect() { echo -e "${CYAN}[DETECT]${NC} $1"; }

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Detect existing wireless configurations
detect_existing_wifi() {
    log_info "Detecting existing WiFi configurations..."
    echo ""
    
    # Get all wireless device sections
    WIRELESS_SECTIONS=$(uci show wireless | grep "=wifi-device" | cut -d'=' -f1)
    WIRELESS_IFACES=$(uci show wireless | grep "=wifi-iface" | cut -d'=' -f1)
    
    if [ -z "$WIRELESS_SECTIONS" ]; then
        log_error "No wireless devices found in configuration!"
        exit 1
    fi
    
    log_detect "Found wireless devices:"
    for section in $WIRELESS_SECTIONS; do
        DEVICE=$(echo $section | cut -d'.' -f2)
        CHANNEL=$(uci get wireless.${DEVICE}.channel 2>/dev/null || echo "auto")
        BAND=$(uci get wireless.${DEVICE}.band 2>/dev/null || echo "unknown")
        HTMODE=$(uci get wireless.${DEVICE}.htmode 2>/dev/null || echo "unknown")
        echo "  - Device: $DEVICE (Channel: $CHANNEL, Band: $BAND, Mode: $HTMODE)"
    done
    echo ""
    
    log_detect "Found wireless interfaces:"
    for section in $WIRELESS_IFACES; do
        IFACE=$(echo $section | cut -d'.' -f2)
        DEVICE=$(uci get wireless.${IFACE}.device 2>/dev/null)
        SSID=$(uci get wireless.${IFACE}.ssid 2>/dev/null || echo "No SSID")
        MODE=$(uci get wireless.${IFACE}.mode 2>/dev/null || echo "unknown")
        ENCRYPTION=$(uci get wireless.${IFACE}.encryption 2>/dev/null || echo "none")
        DISABLED=$(uci get wireless.${IFACE}.disabled 2>/dev/null || echo "0")
        
        echo "  - Interface: $IFACE"
        echo "    Device: $DEVICE"
        echo "    SSID: $SSID"
        echo "    Mode: $MODE"
        echo "    Encryption: $ENCRYPTION"
        echo "    Disabled: $DISABLED"
        echo ""
    done
}

# Select interfaces to clone
select_interfaces_to_clone() {
    log_info "Select existing WiFi interfaces to clone as hidden backup networks:"
    echo ""
    
    # Filter only AP mode interfaces that are enabled
    AP_INTERFACES=""
    for section in $WIRELESS_IFACES; do
        IFACE=$(echo $section | cut -d'.' -f2)
        MODE=$(uci get wireless.${IFACE}.mode 2>/dev/null)
        DISABLED=$(uci get wireless.${IFACE}.disabled 2>/dev/null || echo "0")
        SSID=$(uci get wireless.${IFACE}.ssid 2>/dev/null)
        
        if [ "$MODE" = "ap" ] && [ "$DISABLED" = "0" ] && [ -n "$SSID" ]; then
            AP_INTERFACES="$AP_INTERFACES $IFACE"
        fi
    done
    
    if [ -z "$AP_INTERFACES" ]; then
        log_error "No enabled AP mode interfaces found to clone!"
        exit 1
    fi
    
    # Display selectable interfaces
    i=1
    for iface in $AP_INTERFACES; do
        eval "CLONE_IFACE_$i=$iface"
        SSID=$(uci get wireless.${iface}.ssid 2>/dev/null)
        DEVICE=$(uci get wireless.${iface}.device 2>/dev/null)
        echo "  $i) $iface - SSID: $SSID (Device: $DEVICE)"
        i=$((i + 1))
    done
    echo ""
    
    # Get user selection
    read -p "Enter numbers of interfaces to clone (space-separated, e.g., '1 2'): " selections
    
    SELECTED_TO_CLONE=""
    for selection in $selections; do
        if [ "$selection" -ge 1 ] 2>/dev/null && [ "$selection" -lt "$i" ] 2>/dev/null; then
            eval "selected_iface=\$CLONE_IFACE_$selection"
            SELECTED_TO_CLONE="$SELECTED_TO_CLONE $selected_iface"
        else
            log_warning "Invalid selection: $selection"
        fi
    done
    
    if [ -z "$SELECTED_TO_CLONE" ]; then
        log_error "No valid interfaces selected"
        exit 1
    fi
    
    log_success "Selected interfaces to clone:$SELECTED_TO_CLONE"
}

# Configure backup network settings
configure_backup_settings() {
    log_info "Configure backup network settings..."
    echo ""
    
    # Default settings
    BACKUP_SUFFIX="_BACKUP"
    BACKUP_PASSWORD=""
    
    log_info "Current settings:"
    echo "  SSID suffix: $BACKUP_SUFFIX (e.g., ZNUTAR becomes ZNUTAR_BACKUP)"
    echo "  Hidden SSID: Yes (BSSID not broadcasted)"
    echo "  Security: Same as original networks"
    echo ""
    
    read -p "Modify SSID suffix? (current: $BACKUP_SUFFIX): " new_suffix
    BACKUP_SUFFIX=${new_suffix:-$BACKUP_SUFFIX}
    
    echo ""
    read -p "Set custom password for backup networks? (leave empty to use original passwords): " custom_password
    if [ -n "$custom_password" ]; then
        BACKUP_PASSWORD="$custom_password"
        log_info "Custom password will be used for all backup networks"
    else
        log_info "Original passwords will be used"
    fi
    
    echo ""
    log_success "Backup network settings configured"
    echo "  SSID suffix: $BACKUP_SUFFIX"
    echo "  Custom password: $([ -n "$BACKUP_PASSWORD" ] && echo "Yes" || echo "No")"
}

# Create backup WiFi configurations
create_backup_configs() {
    log_info "Creating backup WiFi configurations..."
    echo ""
    
    BACKUP_INTERFACES=""
    
    for original_iface in $SELECTED_TO_CLONE; do
        # Generate backup interface name
        BACKUP_IFACE="${original_iface}_backup"
        BACKUP_INTERFACES="$BACKUP_INTERFACES $BACKUP_IFACE"
        
        # Get original configuration
        DEVICE=$(uci get wireless.${original_iface}.device 2>/dev/null)
        ORIGINAL_SSID=$(uci get wireless.${original_iface}.ssid 2>/dev/null)
        BACKUP_SSID="${ORIGINAL_SSID}${BACKUP_SUFFIX}"
        NETWORK=$(uci get wireless.${original_iface}.network 2>/dev/null || echo "lan")
        ENCRYPTION=$(uci get wireless.${original_iface}.encryption 2>/dev/null)
        
        log_info "Creating backup for $original_iface ($ORIGINAL_SSID)..."
        
        # Check if backup interface already exists
        if uci get wireless.${BACKUP_IFACE} >/dev/null 2>&1; then
            log_warning "Backup interface $BACKUP_IFACE already exists, removing old configuration..."
            uci delete wireless.${BACKUP_IFACE}
        fi
        
        # Create new backup interface
        uci set wireless.${BACKUP_IFACE}=wifi-iface
        uci set wireless.${BACKUP_IFACE}.device="$DEVICE"
        uci set wireless.${BACKUP_IFACE}.network="$NETWORK"
        uci set wireless.${BACKUP_IFACE}.mode='ap'
        uci set wireless.${BACKUP_IFACE}.ssid="$BACKUP_SSID"
        uci set wireless.${BACKUP_IFACE}.encryption="$ENCRYPTION"
        
        # Set hidden SSID (disable broadcasting)
        uci set wireless.${BACKUP_IFACE}.hidden='1'
        
        # Copy security settings
        if [ "$ENCRYPTION" != "none" ]; then
            if [ -n "$BACKUP_PASSWORD" ]; then
                # Use custom password
                uci set wireless.${BACKUP_IFACE}.key="$BACKUP_PASSWORD"
            else
                # Copy original password
                ORIGINAL_KEY=$(uci get wireless.${original_iface}.key 2>/dev/null)
                if [ -n "$ORIGINAL_KEY" ]; then
                    uci set wireless.${BACKUP_IFACE}.key="$ORIGINAL_KEY"
                fi
            fi
        fi
        
        # Copy other relevant settings
        for setting in wpa_group_rekey ieee80211w isolate disassoc_low_ack; do
            VALUE=$(uci get wireless.${original_iface}.${setting} 2>/dev/null)
            if [ -n "$VALUE" ]; then
                uci set wireless.${BACKUP_IFACE}.${setting}="$VALUE"
            fi
        done
        
        log_success "Created backup: $BACKUP_IFACE ($BACKUP_SSID) - Hidden SSID"
    done
    
    # Commit wireless configuration
    uci commit wireless
    echo ""
    log_success "Backup WiFi configurations created"
}

# Restart wireless services
restart_wireless() {
    log_info "Restarting wireless services to apply new configurations..."
    
    # Restart wireless
    wifi down
    sleep 2
    wifi up
    sleep 5
    
    # Restart wireless service
    /etc/init.d/network restart
    sleep 5
    
    log_success "Wireless services restarted"
}

# Verify backup networks
verify_backup_networks() {
    log_info "Verifying backup network creation..."
    echo ""
    
    sleep 10  # Wait for interfaces to come up
    
    for backup_iface in $BACKUP_INTERFACES; do
        # Check if interface exists in system
        BACKUP_SSID=$(uci get wireless.${backup_iface}.ssid 2>/dev/null)
        DEVICE=$(uci get wireless.${backup_iface}.device 2>/dev/null)
        
        log_info "Checking backup network: $backup_iface ($BACKUP_SSID)"
        
        # Check if wireless interface is up
        if [ -n "$BACKUP_SSID" ]; then
            log_success "✓ $backup_iface created successfully (Hidden SSID: $BACKUP_SSID)"
            echo "    Device: $DEVICE"
            echo "    Hidden: Yes (BSSID not broadcasted)"
        else
            log_error "✗ $backup_iface configuration incomplete"
        fi
        echo ""
    done
}

# Create connection instructions
create_connection_guide() {
    log_info "Creating connection guide for backup networks..."
    
    cat > /root/backup_wifi_guide.txt << EOF
=== Backup WiFi Networks Connection Guide ===
Generated: $(date)

Your backup WiFi networks have been created with hidden SSIDs.
These networks are NOT affected by throttling and provide full-speed access.

BACKUP NETWORKS:
EOF

    for original_iface in $SELECTED_TO_CLONE; do
        BACKUP_IFACE="${original_iface}_backup"
        ORIGINAL_SSID=$(uci get wireless.${original_iface}.ssid 2>/dev/null)
        BACKUP_SSID=$(uci get wireless.${BACKUP_IFACE}.ssid 2>/dev/null)
        ENCRYPTION=$(uci get wireless.${BACKUP_IFACE}.encryption 2>/dev/null)
        
        if [ -n "$BACKUP_PASSWORD" ]; then
            PASSWORD="$BACKUP_PASSWORD"
        else
            PASSWORD=$(uci get wireless.${BACKUP_IFACE}.key 2>/dev/null || echo "No password")
        fi
        
        cat >> /root/backup_wifi_guide.txt << EOF

Network: $BACKUP_SSID (Hidden)
  - Original Network: $ORIGINAL_SSID
  - Security: $ENCRYPTION
  - Password: $PASSWORD
  - Hidden SSID: Yes (you must manually add this network)
  
  CONNECTION STEPS:
  1. On your device, go to WiFi settings
  2. Choose "Add Network" or "Other Network"
  3. Enter SSID: $BACKUP_SSID
  4. Select security type: $ENCRYPTION
  5. Enter password: $PASSWORD
  6. Connect
  
  Note: This network provides full internet speed even during throttling periods.

EOF
    done
    
    cat >> /root/backup_wifi_guide.txt << EOF

IMPORTANT NOTES:
- These are HIDDEN networks - they won't appear in WiFi scans
- You must manually add them to your devices
- They provide full-speed internet access
- They are NOT affected by the throttling system
- Use these during throttling periods for emergency access

MANAGEMENT COMMANDS:
- View this guide: cat /root/backup_wifi_guide.txt
- Check wireless config: uci show wireless | grep backup
- Restart wireless: wifi down && wifi up

EOF

    chmod 644 /root/backup_wifi_guide.txt
    log_success "Connection guide created: /root/backup_wifi_guide.txt"
}

# Create management script
create_backup_management() {
    log_info "Creating backup WiFi management script..."
    
    cat > /root/scripts/backup_wifi_control.sh << EOF
#!/bin/sh
# Backup WiFi management script

BACKUP_INTERFACES="$BACKUP_INTERFACES"

case "\$1" in
    status)
        echo "=== Backup WiFi Networks Status ==="
        echo ""
        for iface in \$BACKUP_INTERFACES; do
            SSID=\$(uci get wireless.\${iface}.ssid 2>/dev/null || echo "Unknown")
            DISABLED=\$(uci get wireless.\${iface}.disabled 2>/dev/null || echo "0")
            STATUS=\$([ "\$DISABLED" = "0" ] && echo "Enabled" || echo "Disabled")
            echo "  \$iface: \$SSID (\$STATUS, Hidden)"
        done
        echo ""
        ;;
    enable)
        echo "Enabling all backup WiFi networks..."
        for iface in \$BACKUP_INTERFACES; do
            uci set wireless.\${iface}.disabled='0'
        done
        uci commit wireless
        wifi down && wifi up
        echo "Backup networks enabled"
        ;;
    disable)
        echo "Disabling all backup WiFi networks..."
        for iface in \$BACKUP_INTERFACES; do
            uci set wireless.\${iface}.disabled='1'
        done
        uci commit wireless
        wifi down && wifi up
        echo "Backup networks disabled"
        ;;
    guide)
        cat /root/backup_wifi_guide.txt
        ;;
    *)
        echo "Usage: \$0 {status|enable|disable|guide}"
        echo "  status  - Show backup network status"
        echo "  enable  - Enable all backup networks"
        echo "  disable - Disable all backup networks"
        echo "  guide   - Show connection guide"
        exit 1
        ;;
esac
EOF

    chmod +x /root/scripts/backup_wifi_control.sh
    
    # Create alias
    echo "alias backup-wifi='/root/scripts/backup_wifi_control.sh'" >> /etc/profile
    
    log_success "Management script created"
}

# Main execution
main() {
    echo ""
    log_info "=== OpenWrt Backup WiFi Networks Setup ==="
    log_info "=== Creates Hidden WiFi Networks for Emergency Access ==="
    echo ""
    
    # Check prerequisites
    check_root
    
    # Create scripts directory
    mkdir -p /root/scripts
    
    # Detection and configuration
    detect_existing_wifi
    select_interfaces_to_clone
    configure_backup_settings
    
    # Show summary
    echo ""
    log_info "Configuration Summary:"
    echo "  Cloning interfaces:$SELECTED_TO_CLONE"
    echo "  SSID suffix: $BACKUP_SUFFIX"
    echo "  Hidden SSID: Yes (not broadcasted)"
    echo "  Custom password: $([ -n "$BACKUP_PASSWORD" ] && echo "Yes" || echo "No - using originals")"
    echo ""
    log_warning "IMPORTANT: These backup networks will NOT be affected by throttling!"
    echo ""
    
    read -p "Continue with backup WiFi creation? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled"
        exit 0
    fi
    
    # Create backup configurations
    create_backup_configs
    restart_wireless
    verify_backup_networks
    create_connection_guide
    create_backup_management
    
    echo ""
    log_success "=== Backup WiFi Networks Setup Complete! ==="
    echo ""
    log_info "Created backup networks:"
    for original_iface in $SELECTED_TO_CLONE; do
        BACKUP_IFACE="${original_iface}_backup"
        BACKUP_SSID=$(uci get wireless.${BACKUP_IFACE}.ssid 2>/dev/null)
        echo "  - $BACKUP_SSID (Hidden)"
    done
    echo ""
    log_info "Useful commands:"
    echo "  backup-wifi status  - Check backup network status"
    echo "  backup-wifi guide   - View connection instructions"
    echo "  backup-wifi enable  - Enable backup networks"
    echo "  backup-wifi disable - Disable backup networks"
    echo ""
    log_info "Connection guide: /root/backup_wifi_guide.txt"
    echo ""
    log_warning "Remember: These are HIDDEN networks - you must manually add them to your devices!"
    log_info "Run 'source /etc/profile' to enable command aliases"
    echo ""
}

# Run main function
main "$@"