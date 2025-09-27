#!/bin/sh
# Debug script to check SQM and interface status

echo "=== SQM Debug Information ==="
echo "Date: $(date)"
echo ""

echo "=== SQM Service Status ==="
/etc/init.d/sqm status 2>&1
echo ""

echo "=== All UCI SQM Configurations ==="
uci show sqm 2>/dev/null | sort
echo ""

echo "=== Detailed SQM Configuration Analysis ==="
all_configs=$(uci show sqm 2>/dev/null | grep "^sqm\.[^.]*=queue$" | cut -d'=' -f1 | cut -d'.' -f2)

for config_name in $all_configs; do
    echo "Config: $config_name"
    
    iface=$(uci get "sqm.${config_name}.interface" 2>/dev/null || echo "NOT_SET")
    enabled=$(uci get "sqm.${config_name}.enabled" 2>/dev/null || echo "NOT_SET")
    download=$(uci get "sqm.${config_name}.download" 2>/dev/null || echo "NOT_SET")
    upload=$(uci get "sqm.${config_name}.upload" 2>/dev/null || echo "NOT_SET")
    
    echo "  Interface: $iface"
    echo "  Enabled: $enabled"
    echo "  Download: $download kbps"
    echo "  Upload: $upload kbps"
    
    # Check if interface exists and is up
    if [ "$iface" != "NOT_SET" ] && [ -e "/sys/class/net/$iface" ]; then
        if ip link show "$iface" 2>/dev/null | grep -q "UP"; then
            echo "  Interface Status: UP"
        else
            echo "  Interface Status: DOWN"
        fi
        
        # Check if interface has an IP
        ip_info=$(ip addr show "$iface" 2>/dev/null | grep "inet " | head -1 | awk '{print $2}')
        if [ -n "$ip_info" ]; then
            echo "  IP Address: $ip_info"
        else
            echo "  IP Address: No IP assigned"
        fi
    elif [ "$iface" != "NOT_SET" ]; then
        echo "  Interface Status: MISSING/NOT_FOUND"
    fi
    
    echo ""
done

echo "=== Available Network Interfaces ==="
echo "All interfaces:"
ls -1 /sys/class/net/ 2>/dev/null | sed 's/^/  /'
echo ""

echo "Wireless interfaces (iw dev):"
iw dev 2>/dev/null | grep Interface | sed 's/^/  /'
echo ""

echo "Interface status (ip link):"
ip link show 2>/dev/null | grep -E "^[0-9]+:" | sed 's/^/  /'
echo ""

echo "=== SQM Process Information ==="
ps | grep -i sqm | grep -v grep || echo "No SQM processes found"
echo ""

echo "=== SQM Log Messages (last 10) ==="
logread 2>/dev/null | grep -i sqm | tail -10 | sed 's/^/  /' || echo "No SQM log messages found"
echo ""

echo "=== System Load and Memory ==="
echo "Load: $(cat /proc/loadavg 2>/dev/null)"
echo "Memory: $(free 2>/dev/null | grep Mem:)" 
echo ""

echo "=== Debug Complete ==="