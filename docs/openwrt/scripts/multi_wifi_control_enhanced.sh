#!/bin/sh
# Enhanced Multi-WiFi throttle control script with interface selection

# Function to get all WiFi interfaces and their SSIDs
get_wifi_interfaces() {
    echo "=== Available WiFi Networks ==="
    echo ""
    i=1
    INTERFACES=""
    for iface in $(iw dev | grep Interface | awk '{print $2}'); do
        SSID=$(iw dev "$iface" info 2>/dev/null | grep ssid | awk '{print $2}' || echo "No SSID")
        if [ "$SSID" != "No SSID" ]; then
            echo "  $i) $iface - SSID: $SSID"
            INTERFACES="$INTERFACES$iface "
            i=$((i + 1))
        fi
    done
    echo ""
}

# Function to select interfaces
select_interfaces() {
    get_wifi_interfaces
    
    echo "Select WiFi networks to throttle (space-separated numbers, e.g., '1 3' or 'all'):"
    read -r selection
    
    SELECTED_INTERFACES=""
    if [ "$selection" = "all" ]; then
        SELECTED_INTERFACES=$INTERFACES
    else
        i=1
        for iface in $INTERFACES; do
            for num in $selection; do
                if [ "$i" = "$num" ]; then
                    SELECTED_INTERFACES="$SELECTED_INTERFACES$iface "
                fi
            done
            i=$((i + 1))
        done
    fi
    
    if [ -z "$SELECTED_INTERFACES" ]; then
        echo "No interfaces selected. Exiting."
        exit 1
    fi
    
    echo ""
    echo "Selected interfaces: $SELECTED_INTERFACES"
    echo ""
}

# Function to select speed
select_speed() {
    echo "=== Select Throttling Speed ==="
    echo ""
    echo "  1) 128 Kbps (Very Restricted)"
    echo "  2) 256 Kbps (Restricted)"
    echo "  3) 512 Kbps (Limited)"
    echo "  4) 768 Kbps (Moderate)"
    echo "  5) 1024 Kbps (Light Restriction)"
    echo "  6) Custom speed"
    echo ""
    
    read -p "Select speed option (1-6): " -n 1 -r
    echo ""
    
    case $REPLY in
        1) THROTTLE_DOWNLOAD="128"; THROTTLE_UPLOAD="128" ;;
        2) THROTTLE_DOWNLOAD="256"; THROTTLE_UPLOAD="256" ;;
        3) THROTTLE_DOWNLOAD="512"; THROTTLE_UPLOAD="512" ;;
        4) THROTTLE_DOWNLOAD="768"; THROTTLE_UPLOAD="768" ;;
        5) THROTTLE_DOWNLOAD="1024"; THROTTLE_UPLOAD="1024" ;;
        6) 
            echo ""
            read -p "Enter download speed (kbps): " THROTTLE_DOWNLOAD
            read -p "Enter upload speed (kbps): " THROTTLE_UPLOAD
            ;;
        *) 
            echo "Invalid selection. Using default 256 Kbps."
            THROTTLE_DOWNLOAD="256"
            THROTTLE_UPLOAD="256"
            ;;
    esac
    
    echo ""
    echo "Selected speed: ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps (down/up)"
    echo ""
}

# Function to configure timezone and schedule
configure_schedule() {
    echo "=== Configure Schedule (Optional) ==="
    echo ""
    echo "Current timezone: $(cat /etc/TZ 2>/dev/null || echo "UTC")"
    echo ""
    echo "Do you want to set up scheduled throttling? (y/n)"
    read -p "> " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Enter start time (24h format, e.g., 21:00):"
        read -r START_TIME
        echo "Enter end time (24h format, e.g., 07:00):"
        read -r END_TIME
        
        # Create cron entries
        START_HOUR=$(echo $START_TIME | cut -d: -f1)
        START_MIN=$(echo $START_TIME | cut -d: -f2)
        END_HOUR=$(echo $END_TIME | cut -d: -f1)
        END_MIN=$(echo $END_TIME | cut -d: -f2)
        
        SCHEDULE_INFO="Scheduled: $START_TIME to $END_TIME daily"
    else
        SCHEDULE_INFO="No schedule configured"
    fi
    echo ""
}

# Function to apply configuration
apply_configuration() {
    echo "=== Configuration Summary ==="
    echo ""
    echo "Interfaces: $SELECTED_INTERFACES"
    echo "Speed: ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps (down/up)"
    echo "$SCHEDULE_INFO"
    echo ""
    echo "Apply this configuration? (y/n)"
    read -p "> " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Applying configuration..."
        
        logger -t "Multi-WiFi-Throttle" "Starting throttling: $SELECTED_INTERFACES at ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps"
        
        # Stop SQM
        /etc/init.d/sqm stop
        
        # Configure each interface
        for iface in $SELECTED_INTERFACES; do
            SQM_NAME="wifi_$(echo $iface | tr -d '-')"
            
            # Create SQM instance if it doesn't exist
            if ! uci get sqm.${SQM_NAME} >/dev/null 2>&1; then
                uci set sqm.${SQM_NAME}=queue
                uci set sqm.${SQM_NAME}.interface="$iface"
                uci set sqm.${SQM_NAME}.enabled='1'
                uci set sqm.${SQM_NAME}.script='piece_of_cake.qos'
            fi
            
            # Update speeds
            uci set sqm.${SQM_NAME}.download="$THROTTLE_DOWNLOAD"
            uci set sqm.${SQM_NAME}.upload="$THROTTLE_UPLOAD"
            
            logger -t "Multi-WiFi-Throttle" "Configured $iface: ${THROTTLE_DOWNLOAD}/${THROTTLE_UPLOAD} kbps"
            echo "  ✓ Configured $iface"
        done
        
        # Commit changes and restart SQM
        uci commit sqm
        /etc/init.d/sqm start
        
        # Save configuration for status command
        cat > /tmp/wifi_throttle_config << EOF
SELECTED_INTERFACES="$SELECTED_INTERFACES"
THROTTLE_DOWNLOAD="$THROTTLE_DOWNLOAD"
THROTTLE_UPLOAD="$THROTTLE_UPLOAD"
SCHEDULE_INFO="$SCHEDULE_INFO"
CONFIG_TIME="$(date)"
EOF
        
        # Set up cron if scheduled
        if [ ! -z "$START_TIME" ] && [ ! -z "$END_TIME" ]; then
            # Remove existing entries
            crontab -l 2>/dev/null | grep -v "multi_wifi_control" > /tmp/cron.tmp
            
            # Add new entries
            echo "$START_MIN $START_HOUR * * * /root/scripts/multi_wifi_control_enhanced.sh apply_saved" >> /tmp/cron.tmp
            echo "$END_MIN $END_HOUR * * * /root/scripts/multi_wifi_normal.sh" >> /tmp/cron.tmp
            
            crontab /tmp/cron.tmp
            rm /tmp/cron.tmp
            echo "  ✓ Schedule configured"
        fi
        
        echo ""
        echo "✓ Configuration applied successfully!"
        logger -t "Multi-WiFi-Throttle" "Configuration completed"
    else
        echo ""
        echo "Configuration cancelled."
    fi
}

# Function to apply saved configuration (for cron)
apply_saved_config() {
    if [ -f /tmp/wifi_throttle_config ]; then
        . /tmp/wifi_throttle_config
        
        logger -t "Multi-WiFi-Throttle" "Applying saved configuration via schedule"
        
        /etc/init.d/sqm stop
        
        for iface in $SELECTED_INTERFACES; do
            SQM_NAME="wifi_$(echo $iface | tr -d '-')"
            uci set sqm.${SQM_NAME}.download="$THROTTLE_DOWNLOAD"
            uci set sqm.${SQM_NAME}.upload="$THROTTLE_UPLOAD"
        done
        
        uci commit sqm
        /etc/init.d/sqm start
        
        logger -t "Multi-WiFi-Throttle" "Scheduled throttling activated"
    fi
}

# Main script logic
case "$1" in
    on|enable|throttle)
        select_interfaces
        select_speed
        configure_schedule
        apply_configuration
        ;;
    off|disable|normal)
        echo "Restoring normal speeds for all WiFi..."
        /root/scripts/multi_wifi_normal.sh
        ;;
    status)
        echo "=== Multi-WiFi Throttling Status ==="
        echo "Current time: $(date)"
        echo ""
        
        if [ -f /tmp/wifi_throttle_config ]; then
            echo "Last Configuration:"
            cat /tmp/wifi_throttle_config | sed 's/^/  /'
            echo ""
        fi
        
        echo "Current SQM Status:"
        for entry in $(uci show sqm | grep "=queue" | cut -d= -f1); do
            iface=$(uci get ${entry}.interface 2>/dev/null)
            if [ ! -z "$iface" ] && iw dev "$iface" info >/dev/null 2>&1; then
                DOWN=$(uci get ${entry}.download 2>/dev/null || echo "Not set")
                UP=$(uci get ${entry}.upload 2>/dev/null || echo "Not set")
                ENABLED=$(uci get ${entry}.enabled 2>/dev/null || echo "0")
                STATUS=$([ "$ENABLED" = "1" ] && echo "Active" || echo "Inactive")
                echo "  $iface: ${DOWN}/${UP} kbps ($STATUS)"
            fi
        done
        echo ""
        
        echo "Scheduled Tasks:"
        crontab -l 2>/dev/null | grep "multi_wifi" | sed 's/^/  /' || echo "  No schedules configured"
        echo ""
        
        echo "Recent events:"
        logread | grep "Multi-WiFi-Throttle" | tail -5
        ;;
    apply_saved)
        apply_saved_config
        ;;
    *)
        echo "Usage: $0 {on|off|status}"
        echo "  on  - Configure and enable throttling"
        echo "  off - Restore normal speeds"
        echo "  status - Show current status"
        exit 1
        ;;
esac