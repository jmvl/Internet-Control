#!/bin/sh
# Fixed version of restore_normal_speeds function with comprehensive debugging

# Function to restore normal speeds (improved with better error handling and debugging)
restore_normal_speeds() {
    local normal_download="${1:-85000}"  # Default to 85 Mbps down
    local normal_upload="${2:-10000}"    # Default to 10 Mbps up
    
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
        
        # Check if this interface is throttled (speeds below normal)
        local is_throttled=0
        if [ "$current_down" != "unknown" ] && [ "$current_down" -lt "$normal_download" ]; then
            is_throttled=1
        fi
        if [ "$current_up" != "unknown" ] && [ "$current_up" -lt "$normal_upload" ]; then
            is_throttled=1
        fi
        
        if [ "$is_throttled" -eq 1 ] || [ "$1" = "force" ]; then
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
    echo "  Processed interfaces:$processed_interfaces"
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
        echo "✓ Processed interfaces:$processed_interfaces"
    else
        log_message "INFO" "No throttled interfaces found to restore"
        echo "No throttled interfaces found to restore"
        
        # Still restart SQM service to ensure it's running
        echo "Restarting SQM service anyway..."
        sleep 1
        /etc/init.d/sqm start >/dev/null 2>&1
    fi
    
    # Show final status
    echo ""
    echo "=== Final SQM Status ==="
    for config_name in $all_sqm_configs; do
        local iface=$(uci get "sqm.${config_name}.interface" 2>/dev/null)
        local down=$(uci get "sqm.${config_name}.download" 2>/dev/null || echo "unknown")
        local up=$(uci get "sqm.${config_name}.upload" 2>/dev/null || echo "unknown")
        local enabled=$(uci get "sqm.${config_name}.enabled" 2>/dev/null || echo "0")
        
        if [ -n "$iface" ] && [ -e "/sys/class/net/$iface" ]; then
            local status="Disabled"
            [ "$enabled" = "1" ] && status="Enabled"
            echo "$iface: ${down}/${up} kbps ($status)"
        fi
    done
}

# Test function to show what would be restored
test_restore() {
    echo "=== Test Mode: What would be restored ==="
    echo ""
    
    local all_sqm_configs=$(uci show sqm 2>/dev/null | grep "^sqm\.[^.]*=queue$" | cut -d'=' -f1 | cut -d'.' -f2)
    
    for config_name in $all_sqm_configs; do
        local iface=$(uci get "sqm.${config_name}.interface" 2>/dev/null)
        if [ -n "$iface" ] && [ -e "/sys/class/net/$iface" ]; then
            local current_down=$(uci get "sqm.${config_name}.download" 2>/dev/null || echo "unknown")
            local current_up=$(uci get "sqm.${config_name}.upload" 2>/dev/null || echo "unknown")
            local enabled=$(uci get "sqm.${config_name}.enabled" 2>/dev/null || echo "0")
            
            echo "Interface: $iface ($config_name)"
            echo "  Current: ${current_down}/${current_up} kbps (enabled: $enabled)"
            
            if [ "$current_down" != "unknown" ] && [ "$current_down" -lt "85000" ]; then
                echo "  Would restore: YES (throttled)"
            else
                echo "  Would restore: NO (already normal)"
            fi
            echo ""
        fi
    done
}

# Usage information
case "$1" in
    test)
        test_restore
        ;;
    force)
        restore_normal_speeds "85000" "10000" "force"
        ;;
    *)
        echo "Usage: $0 {test|force}"
        echo "  test  - Show what would be restored without making changes"
        echo "  force - Restore all interfaces regardless of current speed"
        ;;
esac