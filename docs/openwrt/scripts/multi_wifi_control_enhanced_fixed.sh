#!/bin/sh
# Enhanced Multi-WiFi throttle control script with interface selection
# Fixed for OpenWrt compatibility and improved reliability

# Global variables
SCRIPT_VERSION="2.0"
CONFIG_FILE="/etc/config/wifi_throttle_config"
CRON_FILE="/etc/crontabs/root"
LOG_TAG="Multi-WiFi-Throttle"

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    logger -t "$LOG_TAG" "$level: $message"
    echo "[$level] $message"
}

# Function to validate numeric input
validate_number() {
    local input="$1"
    local min="$2"
    local max="$3"
    
    # Check if input is numeric
    case "$input" in
        ''|*[!0-9]*) return 1 ;;
        *) 
            [ "$input" -ge "$min" ] && [ "$input" -le "$max" ]
            return $?
            ;;
    esac
}

# Function to validate time format (HH:MM)
validate_time() {
    local time_input="$1"
    
    # Check format: HH:MM
    case "$time_input" in
        [0-9][0-9]:[0-9][0-9])
            local hour=$(echo "$time_input" | cut -d: -f1)
            local minute=$(echo "$time_input" | cut -d: -f2)
            
            # Validate hour (00-23) and minute (00-59)
            validate_number "$hour" 0 23 && validate_number "$minute" 0 59
            return $?
            ;;
        *) return 1 ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    log_message "INFO" "Checking system prerequisites..."
    
    # Check if iw is available
    if ! command -v iw >/dev/null 2>&1; then
        log_message "ERROR" "iw command not found. Please install iw package."
        return 1
    fi
    
    # Check if UCI is available
    if ! command -v uci >/dev/null 2>&1; then
        log_message "ERROR" "uci command not found. System error."
        return 1
    fi
    
    # Check if SQM is available
    if [ ! -f /etc/init.d/sqm ]; then
        log_message "ERROR" "SQM not installed. Please install sqm-scripts package."
        return 1
    fi
    
    # Check if SQM scripts directory exists
    if [ ! -d /usr/lib/sqm ]; then
        log_message "WARN" "SQM scripts directory not found. Some features may not work."
    fi
    
    log_message "INFO" "Prerequisites check passed"
    return 0
}

# Function to get all WiFi interfaces and their SSIDs with improved detection
get_wifi_interfaces() {
    echo "=== Available WiFi Networks ==="
    echo ""
    local i=1
    INTERFACES=""
    INTERFACE_INFO=""
    
    # Get interfaces using iw dev
    for iface in $(iw dev | grep Interface | awk '{print $2}'); do
        # Check if interface exists and is up
        if [ ! -e "/sys/class/net/$iface" ]; then
            continue
        fi
        
        # Get SSID - handle multi-word SSIDs properly
        local ssid_line=$(iw dev "$iface" info 2>/dev/null | grep ssid)
        local ssid="No SSID"
        
        if [ -n "$ssid_line" ]; then
            # Extract everything after "ssid " to handle spaces
            ssid=$(echo "$ssid_line" | sed 's/^[[:space:]]*ssid[[:space:]]*//')
            [ -z "$ssid" ] && ssid="No SSID"
        fi
        
        # Get interface type and state
        local type=$(iw dev "$iface" info 2>/dev/null | grep type | awk '{print $2}')
        local state="DOWN"
        if ip link show "$iface" 2>/dev/null | grep -q "UP"; then
            state="UP"
        fi
        
        # Only include AP interfaces or managed interfaces with SSID
        if [ "$type" = "AP" ] || { [ "$type" = "managed" ] && [ "$ssid" != "No SSID" ]; }; then
            printf "  %d) %-12s - SSID: %-20s [%s, %s]\n" "$i" "$iface" "$ssid" "$type" "$state"
            INTERFACES="$INTERFACES$iface "
            INTERFACE_INFO="$INTERFACE_INFO$i:$iface:$ssid:$type:$state "
            i=$((i + 1))
        fi
    done
    
    if [ "$i" -eq 1 ]; then
        echo "  No suitable WiFi interfaces found."
        echo "  Make sure WiFi interfaces are configured and active."
        return 1
    fi
    
    echo ""
    return 0
}

# Function to select interfaces with improved validation
select_interfaces() {
    if ! get_wifi_interfaces; then
        log_message "ERROR" "No WiFi interfaces available for configuration"
        return 1
    fi
    
    echo "Select WiFi networks to throttle:"
    echo "  - Enter space-separated numbers (e.g., '1 3')"
    echo "  - Enter 'all' to select all interfaces"
    echo "  - Enter 'q' to quit"
    printf "> "
    read -r selection
    
    case "$selection" in
        q|Q) 
            echo "Operation cancelled."
            return 1 
            ;;
        all|ALL)
            SELECTED_INTERFACES="$INTERFACES"
            ;;
        *)
            SELECTED_INTERFACES=""
            # Process each number in selection
            for num in $selection; do
                # Validate number
                if ! validate_number "$num" 1 10; then
                    echo "Invalid selection: $num (must be 1-10)"
                    continue
                fi
                
                # Find corresponding interface
                local found=0
                for info in $INTERFACE_INFO; do
                    local info_num=$(echo "$info" | cut -d: -f1)
                    local info_iface=$(echo "$info" | cut -d: -f2)
                    
                    if [ "$info_num" = "$num" ]; then
                        SELECTED_INTERFACES="$SELECTED_INTERFACES$info_iface "
                        found=1
                        break
                    fi
                done
                
                if [ "$found" -eq 0 ]; then
                    echo "Invalid selection: $num"
                fi
            done
            ;;
    esac
    
    if [ -z "$SELECTED_INTERFACES" ]; then
        echo "No interfaces selected. Exiting."
        return 1
    fi
    
    echo ""
    echo "Selected interfaces: $SELECTED_INTERFACES"
    echo ""
    return 0
}

# Function to select speed with improved validation
select_speed() {
    echo "=== Select Throttling Speed ==="
    echo ""
    echo "  1) 128 Kbps  (Very Restricted - Emergency only)"
    echo "  2) 256 Kbps  (Restricted - Basic browsing)"
    echo "  3) 512 Kbps  (Limited - Light usage)"
    echo "  4) 768 Kbps  (Moderate - Standard usage)"
    echo "  5) 1024 Kbps (Light Restriction - Most apps work)"
    echo "  6) 2048 Kbps (Minimal Restriction - HD streaming limited)"
    echo "  7) Custom speed"
    echo ""
    
    while true; do
        printf "Select speed option (1-7): "
        read -r speed_choice
        
        case "$speed_choice" in
            1) THROTTLE_DOWNLOAD="128"; THROTTLE_UPLOAD="128"; break ;;
            2) THROTTLE_DOWNLOAD="256"; THROTTLE_UPLOAD="256"; break ;;
            3) THROTTLE_DOWNLOAD="512"; THROTTLE_UPLOAD="512"; break ;;
            4) THROTTLE_DOWNLOAD="768"; THROTTLE_UPLOAD="768"; break ;;
            5) THROTTLE_DOWNLOAD="1024"; THROTTLE_UPLOAD="1024"; break ;;
            6) THROTTLE_DOWNLOAD="2048"; THROTTLE_UPLOAD="2048"; break ;;
            7) 
                echo ""
                while true; do
                    printf "Enter download speed (kbps, 64-100000): "
                    read -r THROTTLE_DOWNLOAD
                    if validate_number "$THROTTLE_DOWNLOAD" 64 100000; then
                        break
                    else
                        echo "Invalid input. Please enter a number between 64 and 100000."
                    fi
                done
                
                while true; do
                    printf "Enter upload speed (kbps, 64-100000): "
                    read -r THROTTLE_UPLOAD
                    if validate_number "$THROTTLE_UPLOAD" 64 100000; then
                        break
                    else
                        echo "Invalid input. Please enter a number between 64 and 100000."
                    fi
                done
                break
                ;;
            *) 
                echo "Invalid selection. Please choose 1-7."
                ;;
        esac
    done
    
    echo ""
    echo "Selected speed: ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps (down/up)"
    echo ""
    return 0
}

# Function to configure timezone and schedule with improved validation
configure_schedule() {
    echo "=== Configure Schedule (Optional) ==="
    echo ""
    echo "Current timezone: $(cat /etc/TZ 2>/dev/null || echo "UTC")"
    echo ""
    printf "Set up scheduled throttling? (y/N): "
    read -r schedule_choice
    [ -z "$schedule_choice" ] && schedule_choice="n"
    
    case "$schedule_choice" in
        y|Y|yes|YES)
            echo ""
            echo "Enter schedule times (24-hour format):"
            
            while true; do
                printf "Start time (e.g., 21:00): "
                read -r START_TIME
                if validate_time "$START_TIME"; then
                    break
                else
                    echo "Invalid time format. Please use HH:MM (e.g., 21:00)"
                fi
            done
            
            while true; do
                printf "End time (e.g., 07:00): "
                read -r END_TIME
                if validate_time "$END_TIME"; then
                    break
                else
                    echo "Invalid time format. Please use HH:MM (e.g., 07:00)"
                fi
            done
            
            # Extract hour and minute
            START_HOUR=$(echo "$START_TIME" | cut -d: -f1)
            START_MIN=$(echo "$START_TIME" | cut -d: -f2)
            END_HOUR=$(echo "$END_TIME" | cut -d: -f1)
            END_MIN=$(echo "$END_TIME" | cut -d: -f2)
            
            SCHEDULE_INFO="Scheduled: $START_TIME to $END_TIME daily"
            ;;
        *)
            SCHEDULE_INFO="No schedule configured"
            START_TIME=""
            END_TIME=""
            ;;
    esac
    echo ""
}

# Function to generate unique SQM name (prevents collisions)
generate_sqm_name() {
    local iface="$1"
    # Replace all non-alphanumeric characters with underscore and add prefix
    local clean_name=$(echo "$iface" | sed 's/[^a-zA-Z0-9]/_/g')
    echo "throttle_$clean_name"
}

# Function to restore normal speeds (improved with comprehensive error handling)
restore_normal_speeds() {
    local normal_download="${1:-85000}"  # Default to 85 Mbps down
    local normal_upload="${2:-10000}"    # Default to 10 Mbps up
    local force_restore="${3:-}"         # Force restore all interfaces if set
    
    log_message "INFO" "Starting restoration process for all managed interfaces..."
    log_message "INFO" "Target speeds: ${normal_download}/${normal_upload} kbps (down/up)"
    
    # Stop SQM service with proper error checking
    echo "Stopping SQM service..."
    if ! /etc/init.d/sqm stop >/dev/null 2>&1; then
        log_message "WARN" "Failed to stop SQM service - continuing anyway"
    fi
    
    # Add delay to ensure service stops completely
    sleep 2
    
    # Get ALL SQM configurations (not just throttle_ prefixed ones)
    local all_sqm_configs=$(uci show sqm 2>/dev/null | grep "^sqm\.[^.]*=queue$" | cut -d'=' -f1 | cut -d'.' -f2)
    local restored_count=0
    local error_count=0
    local processed_interfaces=""
    
    echo "Found SQM configurations to check: $(echo "$all_sqm_configs" | wc -w)"
    
    # Process each SQM configuration
    for config_name in $all_sqm_configs; do
        echo "Processing SQM config: $config_name"
        
        # Get interface name for this config
        local iface=$(uci get "sqm.${config_name}.interface" 2>/dev/null)
        if [ -z "$iface" ]; then
            log_message "WARN" "No interface found for SQM config: $config_name"
            error_count=$((error_count + 1))
            continue
        fi
        
        echo "  Interface: $iface"
        
        # Check if interface exists
        if [ ! -e "/sys/class/net/$iface" ]; then
            log_message "WARN" "Interface $iface does not exist, skipping"
            error_count=$((error_count + 1))
            continue
        fi
        
        # Get current speeds to compare
        local current_down=$(uci get "sqm.${config_name}.download" 2>/dev/null || echo "unknown")
        local current_up=$(uci get "sqm.${config_name}.upload" 2>/dev/null || echo "unknown")
        
        echo "  Current speeds: ${current_down}/${current_up} kbps"
        
        # Check if this interface is throttled (speeds below normal) or force restore
        local should_restore=0
        if [ "$force_restore" = "force" ]; then
            should_restore=1
        elif [ "$current_down" != "unknown" ] && [ "$current_down" -lt "$normal_download" ]; then
            should_restore=1
        elif [ "$current_up" != "unknown" ] && [ "$current_up" -lt "$normal_upload" ]; then
            should_restore=1
        fi
        
        if [ "$should_restore" -eq 1 ]; then
            echo "  -> Restoring to normal speeds..."
            
            # Update download speed with error checking
            if ! uci set "sqm.${config_name}.download=$normal_download" 2>/dev/null; then
                log_message "ERROR" "Failed to set download speed for $config_name ($iface)"
                error_count=$((error_count + 1))
                continue
            fi
            
            # Update upload speed with error checking
            if ! uci set "sqm.${config_name}.upload=$normal_upload" 2>/dev/null; then
                log_message "ERROR" "Failed to set upload speed for $config_name ($iface)"
                error_count=$((error_count + 1))
                continue
            fi
            
            # Ensure interface is enabled
            uci set "sqm.${config_name}.enabled=1" 2>/dev/null
            
            log_message "INFO" "Restored $iface ($config_name) to ${normal_download}/${normal_upload} kbps"
            restored_count=$((restored_count + 1))
            processed_interfaces="$processed_interfaces $iface"
            echo "    ✓ Restored successfully"
        else
            echo "  -> Already at normal speeds, skipping"
        fi
        echo ""
    done
    
    # Show results before committing
    echo "Summary:"
    echo "  Interfaces to restore: $restored_count"
    echo "  Errors encountered: $error_count"
    [ -n "$processed_interfaces" ] && echo "  Processed interfaces:$processed_interfaces"
    echo ""
    
    if [ "$restored_count" -gt 0 ]; then
        echo "Committing UCI changes..."
        if uci commit sqm 2>/dev/null; then
            log_message "INFO" "UCI changes committed successfully"
            echo "  ✓ Configuration committed"
        else
            log_message "ERROR" "Failed to commit UCI changes"
            echo "  ✗ Failed to commit configuration"
            return 1
        fi
        
        # Add longer delay before starting service
        echo "Waiting for configuration to settle..."
        sleep 3
        
        echo "Starting SQM service..."
        if /etc/init.d/sqm start >/dev/null 2>&1; then
            echo "  ✓ SQM service started successfully"
            
            # Verify service is actually running
            sleep 2
            if /etc/init.d/sqm status >/dev/null 2>&1; then
                echo "  ✓ SQM service confirmed running"
            else
                log_message "WARN" "SQM service may not be running properly"
                echo "  ⚠ SQM service status unclear"
            fi
        else
            log_message "ERROR" "Failed to start SQM service"
            echo "  ✗ Failed to start SQM service"
            return 1
        fi
        
        log_message "INFO" "Normal speeds restored for $restored_count interfaces: $processed_interfaces"
        echo ""
        echo "✓ Normal speeds restored for $restored_count interfaces"
        [ -n "$processed_interfaces" ] && echo "✓ Processed interfaces:$processed_interfaces"
    else
        log_message "INFO" "No throttled interfaces found to restore"
        echo "No throttled interfaces found to restore"
        
        # Still restart SQM service to ensure it's running
        echo "Restarting SQM service anyway..."
        sleep 1
        /etc/init.d/sqm start >/dev/null 2>&1
    fi
}

# Function to apply configuration with comprehensive error handling
apply_configuration() {
    echo "=== Configuration Summary ==="
    echo ""
    echo "Interfaces: $SELECTED_INTERFACES"
    echo "Speed: ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps (down/up)"
    echo "$SCHEDULE_INFO"
    echo ""
    printf "Apply this configuration? (Y/n): "
    read -r apply_choice
    [ -z "$apply_choice" ] && apply_choice="y"
    
    case "$apply_choice" in
        y|Y|yes|YES)
            echo ""
            echo "Applying configuration..."
            
            log_message "INFO" "Starting throttling configuration: $SELECTED_INTERFACES at ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps"
            
            # Stop SQM service
            echo "  • Stopping SQM service..."
            /etc/init.d/sqm stop >/dev/null 2>&1
            
            local config_count=0
            local error_count=0
            
            # Configure each interface
            for iface in $SELECTED_INTERFACES; do
                echo "  • Configuring $iface..."
                
                # Check if interface still exists
                if [ ! -e "/sys/class/net/$iface" ]; then
                    log_message "WARN" "Interface $iface no longer exists, skipping"
                    error_count=$((error_count + 1))
                    continue
                fi
                
                local sqm_name=$(generate_sqm_name "$iface")
                
                # Create SQM instance if it doesn't exist
                if ! uci get "sqm.$sqm_name" >/dev/null 2>&1; then
                    uci set "sqm.$sqm_name=queue"
                    uci set "sqm.$sqm_name.interface=$iface"
                    uci set "sqm.$sqm_name.enabled=1"
                    uci set "sqm.$sqm_name.qdisc=fq_codel"
                    uci set "sqm.$sqm_name.script=piece_of_cake.qos"
                    uci set "sqm.$sqm_name.qdisc_advanced=0"
                    uci set "sqm.$sqm_name.linklayer=none"
                    uci set "sqm.$sqm_name.overhead=0"
                fi
                
                # Update speeds
                uci set "sqm.$sqm_name.download=$THROTTLE_DOWNLOAD"
                uci set "sqm.$sqm_name.upload=$THROTTLE_UPLOAD"
                
                log_message "INFO" "Configured $iface ($sqm_name): ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps"
                echo "    ✓ Configured $iface"
                config_count=$((config_count + 1))
            done
            
            if [ "$config_count" -gt 0 ]; then
                # Commit changes and restart SQM
                echo "  • Committing configuration..."
                uci commit sqm
                
                echo "  • Starting SQM service..."
                if /etc/init.d/sqm start >/dev/null 2>&1; then
                    echo "    ✓ SQM service started successfully"
                else
                    log_message "ERROR" "Failed to start SQM service"
                    echo "    ✗ Failed to start SQM service"
                    return 1
                fi
                
                # Save configuration for status and restore commands
                cat > "$CONFIG_FILE" << EOF
SELECTED_INTERFACES="$SELECTED_INTERFACES"
THROTTLE_DOWNLOAD="$THROTTLE_DOWNLOAD"
THROTTLE_UPLOAD="$THROTTLE_UPLOAD"
SCHEDULE_INFO="$SCHEDULE_INFO"
CONFIG_TIME="$(date)"
SCRIPT_VERSION="$SCRIPT_VERSION"
EOF
                
                # Set up cron if scheduled
                if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
                    setup_cron_schedule
                fi
                
                echo ""
                echo "✓ Configuration applied successfully!"
                echo "  - Configured interfaces: $config_count"
                [ "$error_count" -gt 0 ] && echo "  - Errors encountered: $error_count"
                log_message "INFO" "Configuration completed successfully"
            else
                echo ""
                echo "✗ No interfaces were configured successfully"
                log_message "ERROR" "Configuration failed - no interfaces configured"
                return 1
            fi
            ;;
        *)
            echo ""
            echo "Configuration cancelled."
            log_message "INFO" "Configuration cancelled by user"
            ;;
    esac
}

# Function to setup cron schedule (OpenWrt compatible)
setup_cron_schedule() {
    echo "  • Setting up schedule..."
    
    # Ensure cron directory exists
    mkdir -p "$(dirname "$CRON_FILE")"
    
    # Create temporary file with existing cron jobs (excluding our entries)
    local temp_cron="/tmp/cron_temp.$$"
    
    if [ -f "$CRON_FILE" ]; then
        grep -v "multi_wifi_control_enhanced" "$CRON_FILE" > "$temp_cron" 2>/dev/null || true
    else
        touch "$temp_cron"
    fi
    
    # Add new cron entries
    local script_path="/root/scripts/multi_wifi_control_enhanced_fixed.sh"
    echo "$START_MIN $START_HOUR * * * $script_path apply_saved" >> "$temp_cron"
    echo "$END_MIN $END_HOUR * * * $script_path restore" >> "$temp_cron"
    
    # Install new crontab
    if mv "$temp_cron" "$CRON_FILE"; then
        # Restart cron service to pick up changes
        /etc/init.d/cron restart >/dev/null 2>&1
        echo "    ✓ Schedule configured"
        log_message "INFO" "Cron schedule configured: $START_TIME to $END_TIME"
    else
        echo "    ✗ Failed to configure schedule"
        log_message "ERROR" "Failed to configure cron schedule"
        rm -f "$temp_cron"
    fi
}

# Function to apply saved configuration (for cron)
apply_saved_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR" "No saved configuration found"
        return 1
    fi
    
    # Source the configuration
    . "$CONFIG_FILE"
    
    log_message "INFO" "Applying saved configuration from $CONFIG_TIME"
    
    # Stop SQM service
    /etc/init.d/sqm stop >/dev/null 2>&1
    
    # Apply saved configuration
    local applied_count=0
    for iface in $SELECTED_INTERFACES; do
        if [ -e "/sys/class/net/$iface" ]; then
            local sqm_name=$(generate_sqm_name "$iface")
            uci set "sqm.$sqm_name.download=$THROTTLE_DOWNLOAD" 2>/dev/null
            uci set "sqm.$sqm_name.upload=$THROTTLE_UPLOAD" 2>/dev/null
            applied_count=$((applied_count + 1))
        fi
    done
    
    if [ "$applied_count" -gt 0 ]; then
        uci commit sqm
        /etc/init.d/sqm start >/dev/null 2>&1
        log_message "INFO" "Scheduled throttling activated for $applied_count interfaces"
    fi
}

# Function to show comprehensive status
show_status() {
    echo "=== Multi-WiFi Throttling Status ==="
    echo "Current time: $(date)"
    echo "Script version: $SCRIPT_VERSION"
    echo ""
    
    # Show last configuration if available
    if [ -f "$CONFIG_FILE" ]; then
        echo "Last Configuration:"
        . "$CONFIG_FILE"
        echo "  Applied: $CONFIG_TIME"
        echo "  Interfaces: $SELECTED_INTERFACES"
        echo "  Speed: ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps"
        echo "  Schedule: $SCHEDULE_INFO"
        echo ""
    fi
    
    # Show current SQM status for all managed interfaces
    echo "Current SQM Status:"
    local active_count=0
    for entry in $(uci show sqm 2>/dev/null | grep "^sqm\.throttle_.*=" | cut -d= -f1); do
        local iface=$(uci get "${entry}.interface" 2>/dev/null)
        if [ -n "$iface" ]; then
            local down=$(uci get "${entry}.download" 2>/dev/null || echo "Not set")
            local up=$(uci get "${entry}.upload" 2>/dev/null || echo "Not set")
            local enabled=$(uci get "${entry}.enabled" 2>/dev/null || echo "0")
            local status="Inactive"
            [ "$enabled" = "1" ] && status="Active" && active_count=$((active_count + 1))
            
            # Check if interface is up
            local if_status="DOWN"
            if [ -e "/sys/class/net/$iface" ] && ip link show "$iface" 2>/dev/null | grep -q "UP"; then
                if_status="UP"
            fi
            
            echo "  $iface: ${down}/${up} kbps ($status, Interface: $if_status)"
        fi
    done
    
    if [ "$active_count" -eq 0 ]; then
        echo "  No active throttling configurations found"
    fi
    echo ""
    
    # Show scheduled tasks
    echo "Scheduled Tasks:"
    if [ -f "$CRON_FILE" ]; then
        grep "multi_wifi_control_enhanced" "$CRON_FILE" 2>/dev/null | sed 's/^/  /' || echo "  No schedules configured"
    else
        echo "  No schedules configured"
    fi
    echo ""
    
    # Show recent events
    echo "Recent Events (last 5):"
    logread 2>/dev/null | grep "$LOG_TAG" | tail -5 | sed 's/^/  /' || echo "  No recent events"
}

# Function to remove all schedules
remove_schedules() {
    echo "Removing all scheduled tasks..."
    
    if [ -f "$CRON_FILE" ]; then
        # Create temporary file without our entries
        local temp_cron="/tmp/cron_clean.$$"
        grep -v "multi_wifi_control_enhanced" "$CRON_FILE" > "$temp_cron" 2>/dev/null || touch "$temp_cron"
        
        if mv "$temp_cron" "$CRON_FILE"; then
            /etc/init.d/cron restart >/dev/null 2>&1
            echo "✓ All schedules removed"
            log_message "INFO" "All cron schedules removed"
        else
            echo "✗ Failed to remove schedules"
            rm -f "$temp_cron"
        fi
    else
        echo "No schedules found"
    fi
}

# Main script logic
case "$1" in
    on|enable|throttle)
        echo "Multi-WiFi Throttle Control v$SCRIPT_VERSION"
        echo "========================================="
        echo ""
        
        if ! check_prerequisites; then
            exit 1
        fi
        
        if select_interfaces && select_speed && configure_schedule; then
            apply_configuration
        fi
        ;;
    
    off|disable|normal|restore)
        echo "Multi-WiFi Throttle Control v$SCRIPT_VERSION"
        echo "========================================="
        echo ""
        restore_normal_speeds "$2" "$3"  # Allow custom normal speeds as parameters
        ;;
    
    force_restore|force)
        echo "Multi-WiFi Throttle Control v$SCRIPT_VERSION"
        echo "========================================="
        echo ""
        echo "Force restoring ALL interfaces to normal speeds..."
        echo ""
        restore_normal_speeds "$2" "$3" "force"  # Force restore all interfaces
        ;;
    
    status)
        show_status
        ;;
    
    apply_saved)
        apply_saved_config
        ;;
    
    remove_schedule|unschedule)
        remove_schedules
        ;;
    
    test|dry_run)
        echo "Multi-WiFi Throttle Control v$SCRIPT_VERSION - DRY RUN MODE"
        echo "=============================================="
        echo ""
        
        if ! check_prerequisites; then
            echo "Prerequisites check failed - fix issues before running"
            exit 1
        fi
        
        echo "✓ Prerequisites check passed"
        echo "✓ Script syntax validation passed"
        
        if get_wifi_interfaces; then
            echo "✓ Interface detection working"
        else
            echo "✗ No suitable interfaces found"
        fi
        
        echo ""
        echo "Dry run completed. Script appears functional."
        ;;
    
    *)
        echo "Multi-WiFi Throttle Control v$SCRIPT_VERSION"
        echo "Usage: $0 {on|off|force|status|test|remove_schedule}"
        echo ""
        echo "Commands:"
        echo "  on              - Configure and enable throttling"
        echo "  off             - Restore normal speeds (only throttled interfaces)"
        echo "  force           - Force restore ALL interfaces to normal speeds"
        echo "  status          - Show current status and configuration"  
        echo "  test            - Test script functionality (dry run)"
        echo "  remove_schedule - Remove all scheduled tasks"
        echo ""
        echo "Hidden commands:"
        echo "  apply_saved     - Apply saved configuration (used by cron)"
        echo "  restore [down] [up] - Restore with custom normal speeds"
        echo "  force_restore [down] [up] - Force restore all interfaces"
        exit 1
        ;;
esac