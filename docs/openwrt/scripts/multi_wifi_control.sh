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
SELECTED_INTERFACES=" phy1-ap0 phy0-ap0"

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
        echo "Configured interfaces:  phy1-ap0 phy0-ap0"
        echo ""
        echo "Current SQM Settings:"
        for iface in  phy1-ap0 phy0-ap0; do
            SQM_NAME="wifi_$(echo $iface | tr -d '-')"
            DOWN=$(uci get sqm.${SQM_NAME}.download 2>/dev/null || echo "Not configured")
            UP=$(uci get sqm.${SQM_NAME}.upload 2>/dev/null || echo "Not configured")
            echo "  $iface: ${DOWN}/${UP} kbps (down/up)"
        done
        echo ""
        echo "Interface Status:"
        for iface in  phy1-ap0 phy0-ap0; do
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
