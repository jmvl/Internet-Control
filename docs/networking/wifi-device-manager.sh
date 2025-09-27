#!/bin/bash

# WiFi Device Manager - OpenWrt Device-Specific Throttling Tool
# Compatible with bash 3.x+ (macOS and Linux)

set -e  # Exit on error (removed -u to avoid unbound variable issues)

# Configuration
ROUTER_IP="192.168.1.2"
OPNSENSE_IP="192.168.1.3"
WIFI_INTERFACES="phy0-ap0 phy1-ap0"  # 2.4GHz and 5GHz interfaces
DEFAULT_INTERFACE="phy1-ap0"         # Default to 5GHz
SSH_USER="root"

# Throttling profiles (format: "name|rate|ceil")
THROTTLE_PROFILES=(
    "Ultra Slow|128kbit|256kbit"
    "Slow|512kbit|1mbit"
    "Limited|1mbit|2mbit"
    "Moderate|5mbit|10mbit"
    "Normal|50mbit|100mbit"
    "Custom|custom|custom"
)

# Global variables (initialize early)
DEVICE_LIST=""
SELECTED_INTERFACE=""
SELECTED_MAC=""
SELECTED_IP=""
SELECTED_NAME=""
SELECTED_SIGNAL=""
SELECTED_RATE=""
SELECTED_CEIL=""
PROFILE_NAMES=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/tmp/wifi-device-manager.log"

# Helper functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >> "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    WiFi Device Manager                      ║${NC}"
    echo -e "${CYAN}║              OpenWrt Traffic Control Tool                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    log "ERROR: $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS: $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  Warning: $1${NC}"
    log "WARNING: $1"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
check_dependencies() {
    local missing_deps=""

    for dep in ssh awk grep sort; do
        if ! command_exists "$dep"; then
            missing_deps="$missing_deps $dep"
        fi
    done

    if [ -n "$missing_deps" ]; then
        print_error "Missing dependencies:$missing_deps"
        exit 1
    fi
}

# Test SSH connectivity
test_ssh_connection() {
    local host="$1"
    local timeout="${2:-5}"

    if ssh -o ConnectTimeout="$timeout" -o BatchMode=yes "$SSH_USER@$host" "echo 'SSH OK'" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Safe SSH execution with error handling
safe_ssh() {
    local host="$1"
    local command="$2"
    local silent="${3:-false}"  # Optional third parameter for silent mode
    local result=""

    result=$(ssh -o ConnectTimeout=10 "$SSH_USER@$host" "$command" 2>&1) || {
        if [ "$silent" != "true" ]; then
            print_error "SSH command failed on $host: $command"
        fi
        return 1
    }

    echo "$result"
    return 0
}

# Get connected devices from WiFi interfaces with throttling details
get_connected_devices_with_throttling() {
    local temp_file="/tmp/wifi_devices_$$"
    local device_count=0

    print_info "Scanning WiFi interfaces for connected devices with throttling status..."
    print_warning "This may take a moment as we check throttling status for each device..."

    # Clear temp file and device list
    > "$temp_file"
    DEVICE_LIST=""

    # Scan each interface using hostapd ubus (more comprehensive)
    for interface in $WIFI_INTERFACES; do
        echo -e "${CYAN}Scanning $interface...${NC}"

        # Get clients via hostapd ubus interface
        local clients_json=""
        clients_json=$(safe_ssh "$ROUTER_IP" "ubus call hostapd.$interface get_clients" 2>/dev/null || echo "")

        if [ -n "$clients_json" ]; then
            # Simple Python-like approach using shell
            local clients=""
            local json_temp="/tmp/json_parse_$$"
            echo "$clients_json" > "$json_temp"

            # Extract all MAC addresses and their corresponding signals
            clients=$(awk '
                /^[[:space:]]*"[a-fA-F0-9:]{17}"[[:space:]]*:[[:space:]]*\{/ {
                    gsub(/^[[:space:]]*"/, "")
                    gsub(/"[[:space:]]*:[[:space:]]*\{.*$/, "")
                    mac = $0
                }
                /"signal"[[:space:]]*:[[:space:]]*-?[0-9]+/ {
                    gsub(/^.*"signal"[[:space:]]*:[[:space:]]*/, "")
                    gsub(/[,[:space:]]*$/, "")
                    if (mac && $0) {
                        print mac "|" $0
                        mac = ""
                    }
                }
            ' "$json_temp")

            rm -f "$json_temp"

            if [ -n "$clients" ]; then
                echo "$clients" | while IFS='|' read -r mac signal; do
                    if [ -n "$mac" ] && [ -n "$signal" ]; then
                        echo "$interface|$mac|$signal" >> "$temp_file"
                    fi
                done
            fi
        else
            # Fallback to iw command if hostapd ubus fails
            print_warning "hostapd ubus failed for $interface, trying fallback method"
            local stations=""
            stations=$(safe_ssh "$ROUTER_IP" "iw dev $interface station dump 2>/dev/null | grep '^Station' | awk '{print \$2}'" || echo "")

            if [ -n "$stations" ]; then
                echo "$stations" | while read -r mac; do
                    if [ -n "$mac" ]; then
                        local signal=""
                        signal=$(safe_ssh "$ROUTER_IP" "iw dev $interface station get $mac 2>/dev/null | grep 'signal:' | awk '{print \$2}'" || echo "N/A")
                        echo "$interface|$mac|$signal" >> "$temp_file"
                    fi
                done
            fi
        fi
    done

    # Get ARP data for IP resolution (combine both OPNsense and OpenWrt)
    print_info "Resolving IP addresses..."
    local arp_data=""

    # Get ARP data from OPNsense
    local opnsense_arp=""
    opnsense_arp=$(ssh -o ConnectTimeout=5 "$SSH_USER@$OPNSENSE_IP" "arp -a" 2>/dev/null)

    # Get ARP data from OpenWrt as additional source
    local openwrt_arp=""
    openwrt_arp=$(ssh -o ConnectTimeout=5 "$SSH_USER@$ROUTER_IP" "cat /proc/net/arp 2>/dev/null | tail -n +2" 2>/dev/null)

    # Combine both sources
    if [ -n "$opnsense_arp" ]; then
        arp_data="$opnsense_arp"
    fi

    if [ -n "$openwrt_arp" ]; then
        # Convert OpenWrt ARP format and append
        local converted_arp=""
        converted_arp=$(echo "$openwrt_arp" | awk '{if($4!="00:00:00:00:00:00") print "? (" $1 ") at " $4 " on br-lan"}')
        if [ -n "$arp_data" ]; then
            arp_data="$arp_data
$converted_arp"
        else
            arp_data="$converted_arp"
        fi
        print_info "Combined ARP data from both OPNsense and OpenWrt"
    fi

    if [ -z "$arp_data" ]; then
        print_warning "Could not retrieve ARP data from either source"
    fi

    print_info "Checking throttling status for each device..."

    # Display header
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                           Connected WiFi Devices                                           ║${NC}"
    echo -e "${CYAN}╠════╦═══════════════════════════╦═══════════════╦═══════════════════════╦═════════════╦══════════════╦════════════════╣${NC}"
    echo -e "${CYAN}║ #  ║ Device Name               ║ IP Address    ║ MAC Address           ║ Interface   ║ Signal (dBm) ║ Throttled      ║${NC}"
    echo -e "${CYAN}╠════╬═══════════════════════════╬═══════════════╬═══════════════════════╬═════════════╬══════════════╬════════════════╣${NC}"

    # Process devices
    if [ -f "$temp_file" ]; then
        while IFS='|' read -r interface mac signal; do
            if [ -n "$mac" ] && [ -n "$interface" ]; then
                device_count=$((device_count + 1))

                # Find IP and hostname from ARP
                local device_name="Unknown"
                local ip_addr="N/A"

                if [ -n "$arp_data" ]; then
                    local arp_line=""
                    # Try case-insensitive search for MAC address
                    arp_line=$(echo "$arp_data" | grep -i "$mac" | head -1 || echo "")

                    if [ -n "$arp_line" ]; then
                        ip_addr=$(echo "$arp_line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "N/A")
                        # Extract device name, handle both hostname.lan and ? (IP) formats
                        local raw_name=$(echo "$arp_line" | awk '{print $1}')
                        if [ "$raw_name" = "?" ]; then
                            device_name="Device-${ip_addr##*.}"  # Use last octet of IP
                        else
                            device_name=$(echo "$raw_name" | sed 's/\.lan$//' || echo "Unknown")
                        fi
                    else
                        # Debug: print which MAC we're looking for
                        # Uncomment for debugging: echo "DEBUG: No ARP entry found for MAC: $mac" >&2
                        :
                    fi
                fi

                # Store device info for later selection
                local device_info="$interface|$mac|$ip_addr|$device_name|$signal"
                if [ -z "$DEVICE_LIST" ]; then
                    DEVICE_LIST="$device_info"
                else
                    DEVICE_LIST="$DEVICE_LIST
$device_info"
                fi

                # Truncate device name if too long (keep separate from IP)
                local display_device_name="$device_name"
                if [ ${#display_device_name} -gt 25 ]; then
                    display_device_name="${display_device_name:0:22}..."
                fi

                # Handle IP address display
                local display_ip="$ip_addr"
                if [ "$display_ip" = "N/A" ]; then
                    display_ip="N/A"
                fi

                # Check ACTUAL throttling status for this device (detailed version)
                local display_throttle=""
                display_throttle=$(check_device_throttling_status "$interface" "$mac")

                # Display device info with separate device name, IP, and throttling status columns
                printf "${CYAN}║${NC} %-2s ${CYAN}║${NC} %-25s ${CYAN}║${NC} %-13s ${CYAN}║${NC} %-21s ${CYAN}║${NC} %-11s ${CYAN}║${NC} %-12s ${CYAN}║${NC} %-14s ${CYAN}║${NC}\n" \
                    "$device_count" \
                    "$display_device_name" \
                    "$display_ip" \
                    "$mac" \
                    "$interface" \
                    "$signal" \
                    "$display_throttle"
            fi
        done < "$temp_file"
    fi

    echo -e "${CYAN}╚════╩═══════════════════════════╩═══════════════╩═══════════════════════╩═════════════╩══════════════╩════════════════╝${NC}"

    # Cleanup
    rm -f "$temp_file"

    if [ $device_count -eq 0 ]; then
        print_warning "No devices found connected to WiFi interfaces"
        return 1
    fi

    print_success "Found $device_count connected device(s)"
    return 0
}

# Get connected devices from WiFi interfaces
get_connected_devices() {
    local temp_file="/tmp/wifi_devices_$$"
    local device_count=0

    print_info "Scanning WiFi interfaces for connected devices..."

    # Clear temp file and device list
    > "$temp_file"
    DEVICE_LIST=""

    # Scan each interface using hostapd ubus (more comprehensive)
    for interface in $WIFI_INTERFACES; do
        echo -e "${CYAN}Scanning $interface...${NC}"

        # Get clients via hostapd ubus interface
        local clients_json=""
        clients_json=$(safe_ssh "$ROUTER_IP" "ubus call hostapd.$interface get_clients" 2>/dev/null || echo "")

        if [ -n "$clients_json" ]; then
            # Simple Python-like approach using shell
            local clients=""
            local json_temp="/tmp/json_parse_$$"
            echo "$clients_json" > "$json_temp"

            # Extract all MAC addresses and their corresponding signals
            clients=$(awk '
                /^[[:space:]]*"[a-fA-F0-9:]{17}"[[:space:]]*:[[:space:]]*\{/ {
                    gsub(/^[[:space:]]*"/, "")
                    gsub(/"[[:space:]]*:[[:space:]]*\{.*$/, "")
                    mac = $0
                }
                /"signal"[[:space:]]*:[[:space:]]*-?[0-9]+/ {
                    gsub(/^.*"signal"[[:space:]]*:[[:space:]]*/, "")
                    gsub(/[,[:space:]]*$/, "")
                    if (mac && $0) {
                        print mac "|" $0
                        mac = ""
                    }
                }
            ' "$json_temp")

            rm -f "$json_temp"

            if [ -n "$clients" ]; then
                echo "$clients" | while IFS='|' read -r mac signal; do
                    if [ -n "$mac" ] && [ -n "$signal" ]; then
                        echo "$interface|$mac|$signal" >> "$temp_file"
                    fi
                done
            fi
        else
            # Fallback to iw command if hostapd ubus fails
            print_warning "hostapd ubus failed for $interface, trying fallback method"
            local stations=""
            stations=$(safe_ssh "$ROUTER_IP" "iw dev $interface station dump 2>/dev/null | grep '^Station' | awk '{print \$2}'" || echo "")

            if [ -n "$stations" ]; then
                echo "$stations" | while read -r mac; do
                    if [ -n "$mac" ]; then
                        local signal=""
                        signal=$(safe_ssh "$ROUTER_IP" "iw dev $interface station get $mac 2>/dev/null | grep 'signal:' | awk '{print \$2}'" || echo "N/A")
                        echo "$interface|$mac|$signal" >> "$temp_file"
                    fi
                done
            fi
        fi
    done

    # Get ARP data for IP resolution (combine both OPNsense and OpenWrt)
    print_info "Resolving IP addresses..."
    local arp_data=""

    # Get ARP data from OPNsense
    local opnsense_arp=""
    opnsense_arp=$(ssh -o ConnectTimeout=5 "$SSH_USER@$OPNSENSE_IP" "arp -a" 2>/dev/null)

    # Get ARP data from OpenWrt as additional source
    local openwrt_arp=""
    openwrt_arp=$(ssh -o ConnectTimeout=5 "$SSH_USER@$ROUTER_IP" "cat /proc/net/arp 2>/dev/null | tail -n +2" 2>/dev/null)

    # Combine both sources
    if [ -n "$opnsense_arp" ]; then
        arp_data="$opnsense_arp"
    fi

    if [ -n "$openwrt_arp" ]; then
        # Convert OpenWrt ARP format and append
        local converted_arp=""
        converted_arp=$(echo "$openwrt_arp" | awk '{if($4!="00:00:00:00:00:00") print "? (" $1 ") at " $4 " on br-lan"}')
        if [ -n "$arp_data" ]; then
            arp_data="$arp_data
$converted_arp"
        else
            arp_data="$converted_arp"
        fi
        print_info "Combined ARP data from both OPNsense and OpenWrt"
    fi

    if [ -z "$arp_data" ]; then
        print_warning "Could not retrieve ARP data from either source"
    fi

    # Display header
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                           Connected WiFi Devices                                           ║${NC}"
    echo -e "${CYAN}╠════╦═══════════════════════════╦═══════════════╦═══════════════════════╦═════════════╦══════════════╦════════════════╣${NC}"
    echo -e "${CYAN}║ #  ║ Device Name               ║ IP Address    ║ MAC Address           ║ Interface   ║ Signal (dBm) ║ Throttled      ║${NC}"
    echo -e "${CYAN}╠════╬═══════════════════════════╬═══════════════╬═══════════════════════╬═════════════╬══════════════╬════════════════╣${NC}"

    # Process devices
    if [ -f "$temp_file" ]; then
        while IFS='|' read -r interface mac signal; do
            if [ -n "$mac" ] && [ -n "$interface" ]; then
                device_count=$((device_count + 1))

                # Find IP and hostname from ARP
                local device_name="Unknown"
                local ip_addr="N/A"

                if [ -n "$arp_data" ]; then
                    local arp_line=""
                    # Try case-insensitive search for MAC address
                    arp_line=$(echo "$arp_data" | grep -i "$mac" | head -1 || echo "")

                    if [ -n "$arp_line" ]; then
                        ip_addr=$(echo "$arp_line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "N/A")
                        # Extract device name, handle both hostname.lan and ? (IP) formats
                        local raw_name=$(echo "$arp_line" | awk '{print $1}')
                        if [ "$raw_name" = "?" ]; then
                            device_name="Device-${ip_addr##*.}"  # Use last octet of IP
                        else
                            device_name=$(echo "$raw_name" | sed 's/\.lan$//' || echo "Unknown")
                        fi
                    else
                        # Debug: print which MAC we're looking for
                        # Uncomment for debugging: echo "DEBUG: No ARP entry found for MAC: $mac" >&2
                        :
                    fi
                fi

                # Store device info for later selection
                local device_info="$interface|$mac|$ip_addr|$device_name|$signal"
                if [ -z "$DEVICE_LIST" ]; then
                    DEVICE_LIST="$device_info"
                else
                    DEVICE_LIST="$DEVICE_LIST
$device_info"
                fi

                # Truncate device name if too long (keep separate from IP)
                local display_device_name="$device_name"
                if [ ${#display_device_name} -gt 25 ]; then
                    display_device_name="${display_device_name:0:22}..."
                fi

                # Handle IP address display
                local display_ip="$ip_addr"
                if [ "$display_ip" = "N/A" ]; then
                    display_ip="N/A"
                fi

                # For now, show "Unknown" for throttling status (fast loading)
                # Will be updated progressively after initial display
                local display_throttle="Checking..."

                # Display device info with separate device name, IP, and throttling status columns
                printf "${CYAN}║${NC} %-2s ${CYAN}║${NC} %-25s ${CYAN}║${NC} %-13s ${CYAN}║${NC} %-21s ${CYAN}║${NC} %-11s ${CYAN}║${NC} %-12s ${CYAN}║${NC} %-14s ${CYAN}║${NC}\n" \
                    "$device_count" \
                    "$display_device_name" \
                    "$display_ip" \
                    "$mac" \
                    "$interface" \
                    "$signal" \
                    "$display_throttle"
            fi
        done < "$temp_file"
    fi

    echo -e "${CYAN}╚════╩═══════════════════════════╩═══════════════╩═══════════════════════╩═════════════╩══════════════╩════════════════╝${NC}"

    # Store device list for progressive update
    local stored_devices="/tmp/device_list_$$"
    cp "$temp_file" "$stored_devices" 2>/dev/null

    # Cleanup
    rm -f "$temp_file"

    if [ $device_count -eq 0 ]; then
        print_warning "No devices found connected to WiFi interfaces"
        return 1
    fi

    print_success "Found $device_count connected device(s)"

    # Progressive throttling status update - rewrite table with updates
    echo
    print_info "Updating throttling status progressively..."
    sleep 1

    # Create array to store all device info for progressive updates
    device_array=()
    device_data_array=()

    # First pass: collect all device data
    temp_current=0
    while IFS='|' read -r interface mac signal; do
        if [ -n "$mac" ] && [ -n "$interface" ]; then
            temp_current=$((temp_current + 1))

            # Find IP and hostname from ARP (same logic as original)
            device_name="Unknown"
            ip_addr="N/A"

            if [ -n "$arp_data" ]; then
                arp_line=""
                arp_line=$(echo "$arp_data" | grep -i "$mac" | head -1 || echo "")

                if [ -n "$arp_line" ]; then
                    ip_addr=$(echo "$arp_line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "N/A")
                    raw_name=$(echo "$arp_line" | awk '{print $1}')
                    if [ "$raw_name" = "?" ]; then
                        device_name="Device-${ip_addr##*.}"
                    else
                        device_name=$(echo "$raw_name" | sed 's/\.lan$//' || echo "Unknown")
                    fi
                fi
            fi

            # Store device data
            device_data_array[$temp_current]="$temp_current|$device_name|$ip_addr|$mac|$interface|$signal|Checking..."
        fi
    done < "$stored_devices"

    # Now progressively update each device
    for device_index in $(seq 1 $temp_current); do
        # Extract device info
        device_info="${device_data_array[$device_index]}"
        IFS='|' read -r dev_num device_name ip_addr mac interface signal throttle_status <<< "$device_info"

        # Check throttling status for this specific device
        throttle_status=$(check_device_throttling_status "$interface" "$mac" 2>/dev/null || echo "Error")

        # Update the array with new throttling status
        device_data_array[$device_index]="$dev_num|$device_name|$ip_addr|$mac|$interface|$signal|$throttle_status"

        # Clear screen and move to top, then reprint the entire updated table
        printf "\033[H\033[2J"

        echo
        print_info "Updating throttling status progressively... (Device $device_index of $temp_current)"
        echo

        # Reprint table header
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                                           Connected WiFi Devices                                           ║${NC}"
        echo -e "${CYAN}╠════╦═══════════════════════════╦═══════════════╦═══════════════════════╦═════════════╦══════════════╦════════════════╣${NC}"
        echo -e "${CYAN}║ #  ║ Device Name               ║ IP Address    ║ MAC Address           ║ Interface   ║ Signal (dBm) ║ Throttled      ║${NC}"
        echo -e "${CYAN}╠════╬═══════════════════════════╬═══════════════╬═══════════════════════╬═════════════╬══════════════╬════════════════╣${NC}"

        # Print all devices with current status
        for print_index in $(seq 1 $temp_current); do
            print_info="${device_data_array[$print_index]}"
            IFS='|' read -r p_num p_device_name p_ip_addr p_mac p_interface p_signal p_throttle_status <<< "$print_info"

            # Truncate device name if too long
            display_device_name="$p_device_name"
            if [ ${#display_device_name} -gt 25 ]; then
                display_device_name="${display_device_name:0:22}..."
            fi

            # Handle IP address display
            display_ip="$p_ip_addr"
            if [ "$display_ip" = "N/A" ]; then
                display_ip="N/A"
            fi

            printf "${CYAN}║${NC} %-2s ${CYAN}║${NC} %-25s ${CYAN}║${NC} %-13s ${CYAN}║${NC} %-21s ${CYAN}║${NC} %-11s ${CYAN}║${NC} %-12s ${CYAN}║${NC} %-14s ${CYAN}║${NC}\n" \
                "$p_num" \
                "$display_device_name" \
                "$display_ip" \
                "$p_mac" \
                "$p_interface" \
                "$p_signal" \
                "$p_throttle_status"
        done

        echo -e "${CYAN}╚════╩═══════════════════════════╩═══════════════╩═══════════════════════╩═════════════╩══════════════╩════════════════╝${NC}"

        # Small delay to make the progressive update visible
        sleep 0.8
    done

    # Clean up
    rm -f "$stored_devices"

    echo
    print_success "Throttling status updated for all devices"

    return 0
}


# Select device from list
select_device() {
    if [ -z "$DEVICE_LIST" ]; then
        print_error "No devices available for selection"
        return 1
    fi

    local device_count=$(echo "$DEVICE_LIST" | wc -l)
    echo
    print_info "Select a device to manage:"
    echo

    while true; do
        read -p "Enter device number (1-$device_count): " selection

        if echo "$selection" | grep -qE '^[0-9]+$' && [ "$selection" -ge 1 ] && [ "$selection" -le "$device_count" ]; then
            # Extract selected device info
            local device_info=""
            device_info=$(echo "$DEVICE_LIST" | sed -n "${selection}p")

            # Parse device info
            SELECTED_INTERFACE=$(echo "$device_info" | cut -d'|' -f1)
            SELECTED_MAC=$(echo "$device_info" | cut -d'|' -f2)
            SELECTED_IP=$(echo "$device_info" | cut -d'|' -f3)
            SELECTED_NAME=$(echo "$device_info" | cut -d'|' -f4)
            SELECTED_SIGNAL=$(echo "$device_info" | cut -d'|' -f5)

            print_success "Selected: $SELECTED_NAME ($SELECTED_IP) - $SELECTED_MAC on $SELECTED_INTERFACE"
            return 0
        else
            print_error "Invalid selection. Please enter a number between 1 and $device_count"
        fi
    done
}

# Show throttling profiles
show_throttle_profiles() {
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                 Throttling Profiles                   ║${NC}"
    echo -e "${CYAN}╠════╦══════════════════╦══════════════════════════════╣${NC}"
    echo -e "${CYAN}║ #  ║ Profile Name     ║ Speed (Rate : Burst Limit)   ║${NC}"
    echo -e "${CYAN}╠════╬══════════════════╬══════════════════════════════╣${NC}"

    local profile_count=0
    PROFILE_NAMES=""

    for profile in "${THROTTLE_PROFILES[@]}"; do
        profile_count=$((profile_count + 1))
        local name=$(echo "$profile" | cut -d'|' -f1)
        local rate=$(echo "$profile" | cut -d'|' -f2)
        local ceil=$(echo "$profile" | cut -d'|' -f3)

        # Store profile names for selection
        if [ -z "$PROFILE_NAMES" ]; then
            PROFILE_NAMES="$name"
        else
            PROFILE_NAMES="$PROFILE_NAMES|$name"
        fi

        printf "${CYAN}║${NC} %-2s ${CYAN}║${NC} %-16s ${CYAN}║${NC} %-28s ${CYAN}║${NC}\n" \
            "$profile_count" \
            "$name" \
            "$rate : $ceil"
    done

    echo -e "${CYAN}╚════╩══════════════════╩══════════════════════════════╝${NC}"
}

# Select throttling profile
select_throttle_profile() {
    show_throttle_profiles
    echo

    local profile_count=${#THROTTLE_PROFILES[@]}

    while true; do
        read -p "Select throttling profile (1-$profile_count): " selection

        if echo "$selection" | grep -qE '^[0-9]+$' && [ "$selection" -ge 1 ] && [ "$selection" -le "$profile_count" ]; then
            # Get selected profile
            local profile="${THROTTLE_PROFILES[$((selection-1))]}"
            local profile_name=$(echo "$profile" | cut -d'|' -f1)
            local rate=$(echo "$profile" | cut -d'|' -f2)
            local ceil=$(echo "$profile" | cut -d'|' -f3)

            if [ "$profile_name" = "Custom" ]; then
                echo
                print_info "Enter custom speeds (examples: 1mbit, 500kbit, 10mbit)"

                while true; do
                    read -p "Download rate: " custom_rate
                    read -p "Download burst limit: " custom_ceil

                    # Basic validation
                    if echo "$custom_rate" | grep -qE '^[0-9]+[kmg]?bit$' && echo "$custom_ceil" | grep -qE '^[0-9]+[kmg]?bit$'; then
                        SELECTED_RATE="$custom_rate"
                        SELECTED_CEIL="$custom_ceil"
                        print_success "Custom profile: $SELECTED_RATE (burst: $SELECTED_CEIL)"
                        break
                    else
                        print_error "Invalid speed format. Use format like: 1mbit, 500kbit, 10mbit"
                    fi
                done
            else
                SELECTED_RATE="$rate"
                SELECTED_CEIL="$ceil"
                print_success "Selected profile: $profile_name - $SELECTED_RATE (burst: $SELECTED_CEIL)"
            fi

            return 0
        else
            print_error "Invalid selection. Please enter a number between 1 and $profile_count"
        fi
    done
}

# Check if device is currently throttled and get throttle speed
# Fast throttling check with timeout
check_device_throttling_status_fast() {
    local interface="$1"
    local mac="$2"

    # Use a faster SSH with shorter timeout
    local ssh_cmd="ssh -o ConnectTimeout=3 -o ServerAliveInterval=1 -o ServerAliveCountMax=1 $SSH_USER@$ROUTER_IP"

    # Check if HTB qdisc exists on interface - if not, definitely not throttled
    local qdisc_status=""
    qdisc_status=$($ssh_cmd "tc qdisc show dev $interface 2>/dev/null | grep -c htb" 2>/dev/null || echo "0")

    if [ "$qdisc_status" = "0" ]; then
        echo "No"
        return 0
    fi

    # Quick check if there are filters for this MAC address
    local filter_count=""
    filter_count=$($ssh_cmd "tc filter show dev $interface 2>/dev/null | grep -ci '$mac'" 2>/dev/null || echo "0")

    if [ "$filter_count" != "0" ]; then
        # Try to get throttle rate quickly
        local rate_info=""
        rate_info=$($ssh_cmd "tc class show dev $interface classid 1:10 2>/dev/null | grep -oE 'rate [0-9]+[kmgKMG]?bit' | head -1" 2>/dev/null || echo "")

        if [ -n "$rate_info" ]; then
            local rate=$(echo "$rate_info" | awk '{print $2}')
            echo "Yes ($rate)"
        else
            echo "Yes"
        fi
    else
        echo "No"
    fi
}

# Original throttling check (for backward compatibility)
check_device_throttling_status() {
    local interface="$1"
    local mac="$2"

    # Check if HTB qdisc exists on interface
    local qdisc_status=""
    qdisc_status=$(safe_ssh "$ROUTER_IP" "tc qdisc show dev $interface | grep htb" true 2>/dev/null || echo "")

    if [ -z "$qdisc_status" ]; then
        echo "No"
        return 0
    fi

    # Check if there are filters for this MAC address
    local filter_check=""
    filter_check=$(safe_ssh "$ROUTER_IP" "tc filter show dev $interface | grep -i '$mac'" true 2>/dev/null || echo "")

    if [ -n "$filter_check" ]; then
        # Get throttle rate from the throttled class (class 1:10)
        local class_info=""
        class_info=$(safe_ssh "$ROUTER_IP" "tc class show dev $interface classid 1:10" true 2>/dev/null || echo "")

        if [ -n "$class_info" ]; then
            # Extract rate from something like "rate 1Mbit ceil 2Mbit"
            local rate=""
            rate=$(echo "$class_info" | grep -oE 'rate [0-9]+[kmgKMG]?bit' | awk '{print $2}' || echo "")
            if [ -n "$rate" ]; then
                echo "Yes ($rate)"
            else
                echo "Yes"
            fi
        else
            echo "Yes"
        fi
    else
        echo "No"
    fi
}

# Enhanced throttling status with real-time usage statistics
check_device_throttling_with_usage() {
    local interface="$1"
    local mac="$2"

    # Fast check with timeout and error handling
    local result=""
    result=$(timeout 5s bash -c '
        interface="$1"
        mac="$2"
        ROUTER_IP="192.168.1.2"
        SSH_USER="root"

        # Quick check if HTB qdisc exists
        qdisc_status=$(ssh -o ConnectTimeout=3 "$SSH_USER@$ROUTER_IP" "tc qdisc show dev $interface | grep -c htb" 2>/dev/null || echo "0")

        if [ "$qdisc_status" = "0" ]; then
            echo "Unlimited"
            exit 0
        fi

        # Quick check if there are filters for this MAC
        filter_count=$(ssh -o ConnectTimeout=3 "$SSH_USER@$ROUTER_IP" "tc filter show dev $interface | grep -ci \"$mac\"" 2>/dev/null || echo "0")

        if [ "$filter_count" != "0" ]; then
            # Try to get rate info quickly
            class_rate=$(ssh -o ConnectTimeout=3 "$SSH_USER@$ROUTER_IP" "tc class show dev $interface classid 1:10 | grep -oE \"rate [0-9]+[kmgKMG]?bit\" | awk \"{print \\$2}\"" 2>/dev/null || echo "")
            if [ -n "$class_rate" ]; then
                echo "$class_rate (limited)"
            else
                echo "Limited"
            fi
        else
            echo "Unlimited"
        fi
    ' -- "$interface" "$mac" 2>/dev/null)

    # Return result or default
    if [ -n "$result" ]; then
        echo "$result"
    else
        echo "Unknown"
    fi
}

# Get network interface statistics for device monitoring
get_interface_bandwidth_stats() {
    local interface="$1"

    # Get overall interface statistics
    local interface_stats=""
    interface_stats=$(safe_ssh "$ROUTER_IP" "cat /proc/net/dev | grep '$interface:'" true 2>/dev/null || echo "")

    if [ -n "$interface_stats" ]; then
        # Extract bytes received and transmitted
        local rx_bytes=""
        local tx_bytes=""
        rx_bytes=$(echo "$interface_stats" | awk '{print $2}')
        tx_bytes=$(echo "$interface_stats" | awk '{print $10}')

        # Convert to human readable format
        if [ -n "$rx_bytes" ] && [ -n "$tx_bytes" ]; then
            local rx_mb=$((rx_bytes / 1024 / 1024))
            local tx_mb=$((tx_bytes / 1024 / 1024))
            echo "RX: ${rx_mb}MB TX: ${tx_mb}MB"
        else
            echo "Stats N/A"
        fi
    else
        echo "No stats"
    fi
}

# Apply device throttling
apply_throttling() {
    local interface="$1"
    local mac="$2"
    local rate="$3"
    local ceil="$4"

    print_info "Applying throttling to $SELECTED_NAME ($mac) on $interface..."
    print_info "Rate: $rate, Burst: $ceil"

    # Remove existing qdisc
    safe_ssh "$ROUTER_IP" "tc qdisc del dev $interface root 2>/dev/null || true"

    # Apply new configuration step by step
    if safe_ssh "$ROUTER_IP" "tc qdisc add dev $interface root handle 1: htb default 30" &&
       safe_ssh "$ROUTER_IP" "tc class add dev $interface parent 1: classid 1:1 htb rate 500mbit" &&
       safe_ssh "$ROUTER_IP" "tc class add dev $interface parent 1:1 classid 1:10 htb rate $rate ceil $ceil" &&
       safe_ssh "$ROUTER_IP" "tc class add dev $interface parent 1:1 classid 1:30 htb rate 450mbit" &&
       safe_ssh "$ROUTER_IP" "tc filter add dev $interface protocol ip parent 1: prio 1 u32 match ether dst $mac flowid 1:10" &&
       safe_ssh "$ROUTER_IP" "tc filter add dev $interface protocol ip parent 1: prio 1 u32 match ether src $mac flowid 1:10"; then

        print_success "Throttling applied successfully!"
        log "Throttled device: $SELECTED_NAME ($mac) to $rate/$ceil on $interface"

        # Show current status
        echo
        print_info "Current configuration:"
        safe_ssh "$ROUTER_IP" "tc qdisc show dev $interface && tc class show dev $interface"

    else
        print_error "Failed to apply throttling configuration"
        return 1
    fi
}

# Remove device throttling
remove_throttling() {
    local interface="$1"

    print_info "Removing throttling from $interface..."

    if safe_ssh "$ROUTER_IP" "tc qdisc del dev $interface root 2>/dev/null || true"; then
        print_success "Throttling removed successfully!"
        log "Removed throttling from $interface"

        echo
        print_info "Current interface status:"
        safe_ssh "$ROUTER_IP" "tc qdisc show dev $interface"
    else
        print_error "Failed to remove throttling"
        return 1
    fi
}

# Show current throttling status
show_throttle_status() {
    print_info "Checking current throttling status for all interfaces..."
    echo

    for interface in $WIFI_INTERFACES; do
        echo -e "${CYAN}Interface: $interface${NC}"
        echo "────────────────────────────"

        local qdisc_info=""
        qdisc_info=$(safe_ssh "$ROUTER_IP" "tc qdisc show dev $interface 2>/dev/null" || echo "No qdisc found")
        echo "Queue Discipline: $qdisc_info"

        if echo "$qdisc_info" | grep -q "htb"; then
            echo
            echo "Traffic Classes:"
            safe_ssh "$ROUTER_IP" "tc -s class show dev $interface 2>/dev/null" || echo "No classes found"

            echo
            echo "Active Filters:"
            safe_ssh "$ROUTER_IP" "tc filter show dev $interface 2>/dev/null" || echo "No filters found"
        fi

        echo
    done
}

# Disconnect device from WiFi
disconnect_device() {
    local interface="$1"
    local mac="$2"

    print_info "Disconnecting $SELECTED_NAME ($mac) from $interface..."

    # Disconnect from WiFi
    if safe_ssh "$ROUTER_IP" "iw dev $interface station del $mac"; then
        print_success "Device disconnected from WiFi"
        log "Disconnected device: $SELECTED_NAME ($mac) from $interface"

        # Kill network states from OPNsense if IP is available
        if [ "$SELECTED_IP" != "N/A" ] && [ -n "$SELECTED_IP" ]; then
            print_info "Killing network states for IP $SELECTED_IP..."
            if safe_ssh "$OPNSENSE_IP" "pfctl -k $SELECTED_IP" true; then
                print_success "Network states cleared for $SELECTED_IP"
            else
                print_warning "Could not kill network states (OPNsense not accessible)"
            fi
        fi
    else
        print_error "Failed to disconnect device"
        return 1
    fi
}

# Main menu
show_main_menu() {
    echo
    echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                Main Menu                   ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║ 1. List Connected Devices (Fast)          ║${NC}"
    echo -e "${CYAN}║ 2. List Devices with Throttle Status      ║${NC}"
    echo -e "${CYAN}║ 3. Apply Device Throttling                ║${NC}"
    echo -e "${CYAN}║ 4. Remove Device Throttling               ║${NC}"
    echo -e "${CYAN}║ 5. Show Current Throttling Status         ║${NC}"
    echo -e "${CYAN}║ 6. Disconnect Device from WiFi            ║${NC}"
    echo -e "${CYAN}║ 7. Quick Device Management                ║${NC}"
    echo -e "${CYAN}║ 8. Show Real-time Bandwidth Usage        ║${NC}"
    echo -e "${CYAN}║ 0. Exit                                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo
}

# Background device scanning function
start_background_scan() {
    local bg_temp_file="/tmp/wifi_devices_bg_$$"
    local bg_pid_file="/tmp/scan_pid_$$"

    print_info "Starting background device scan..."

    # Start background scan
    (
        # Clear temp file
        > "$bg_temp_file"

        # Scan each interface using hostapd ubus
        for interface in $WIFI_INTERFACES; do
            # Get clients via hostapd ubus interface
            clients_json=$(safe_ssh "$ROUTER_IP" "ubus call hostapd.$interface get_clients" 2>/dev/null || echo "")

            if [ -n "$clients_json" ]; then
                json_temp="/tmp/json_parse_bg_$$"
                echo "$clients_json" > "$json_temp"

                # Extract all MAC addresses and their corresponding signals
                clients=$(awk '
                    /^[[:space:]]*"[a-fA-F0-9:]{17}"[[:space:]]*:[[:space:]]*\{/ {
                        gsub(/^[[:space:]]*"/, "")
                        gsub(/"[[:space:]]*:[[:space:]]*\{.*$/, "")
                        mac = $0
                    }
                    /"signal"[[:space:]]*:[[:space:]]*-?[0-9]+/ {
                        gsub(/^.*"signal"[[:space:]]*:[[:space:]]*/, "")
                        gsub(/[,[:space:]]*$/, "")
                        if (mac && $0) {
                            print mac "|" $0
                            mac = ""
                        }
                    }
                ' "$json_temp")

                rm -f "$json_temp"

                if [ -n "$clients" ]; then
                    echo "$clients" | while IFS='|' read -r mac signal; do
                        if [ -n "$mac" ] && [ -n "$signal" ]; then
                            echo "$interface|$mac|$signal" >> "$bg_temp_file"
                        fi
                    done
                fi
            fi
        done

        # Get ARP data for IP resolution
        opnsense_arp=$(ssh -o ConnectTimeout=5 "$SSH_USER@$OPNSENSE_IP" "arp -a" 2>/dev/null)
        openwrt_arp=$(ssh -o ConnectTimeout=5 "$SSH_USER@$ROUTER_IP" "cat /proc/net/arp 2>/dev/null | tail -n +2" 2>/dev/null)

        # Process and resolve device names
        if [ -f "$bg_temp_file" ]; then
            while IFS='|' read -r interface mac signal; do
                if [ -n "$mac" ] && [ -n "$interface" ]; then
                    # Find IP and hostname from ARP
                    device_name="Unknown"
                    ip_addr="N/A"

                    # Try OPNsense ARP first
                    if [ -n "$opnsense_arp" ]; then
                        arp_line=$(echo "$opnsense_arp" | grep -i "$mac" | head -1 || echo "")
                        if [ -n "$arp_line" ]; then
                            ip_addr=$(echo "$arp_line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "N/A")
                            raw_name=$(echo "$arp_line" | awk '{print $1}')
                            if [ "$raw_name" = "?" ]; then
                                device_name="Device-${ip_addr##*.}"
                            else
                                device_name=$(echo "$raw_name" | sed 's/\.lan$//' || echo "Unknown")
                            fi
                        fi
                    fi

                    # Try OpenWrt ARP if no match found
                    if [ "$device_name" = "Unknown" ] && [ -n "$openwrt_arp" ]; then
                        arp_line=$(echo "$openwrt_arp" | grep -i "$mac" | head -1 || echo "")
                        if [ -n "$arp_line" ]; then
                            ip_addr=$(echo "$arp_line" | awk '{print $1}')
                            device_name="Device-${ip_addr##*.}"
                        fi
                    fi

                    echo "$interface|$mac|$ip_addr|$device_name|$signal" >> "${bg_temp_file}.processed"
                fi
            done < "$bg_temp_file"
        fi

        # Signal completion
        touch "${bg_temp_file}.complete"
    ) &

    # Store background process PID
    echo $! > "$bg_pid_file"

    # Return file paths for monitoring
    echo "$bg_temp_file"
}

# Check if background scan is complete
check_scan_progress() {
    local bg_temp_file="$1"

    if [ -f "${bg_temp_file}.complete" ]; then
        return 0  # Complete
    else
        return 1  # Still running
    fi
}

# Get current scan results (even if incomplete)
get_scan_results() {
    local bg_temp_file="$1"
    local processed_file="${bg_temp_file}.processed"

    if [ -f "$processed_file" ]; then
        cat "$processed_file" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Quick device management workflow with immediate display and background updates
quick_device_management() {
    print_info "Quick Device Management - All-in-one workflow"
    echo

    # First, get initial device list quickly (like option 1 fast mode)
    local temp_file="/tmp/wifi_devices_quick_$$"
    local device_count=0

    print_info "Scanning WiFi interfaces for connected devices..."

    # Clear temp file and device list
    > "$temp_file"
    DEVICE_LIST=""

    # Quick scan each interface using hostapd ubus
    for interface in $WIFI_INTERFACES; do
        echo -e "${CYAN}Scanning $interface...${NC}"

        # Get clients via hostapd ubus interface
        local clients_json=""
        clients_json=$(safe_ssh "$ROUTER_IP" "ubus call hostapd.$interface get_clients" 2>/dev/null || echo "")

        if [ -n "$clients_json" ]; then
            local json_temp="/tmp/json_parse_$$"
            echo "$clients_json" > "$json_temp"

            # Extract all MAC addresses and their corresponding signals
            clients=$(awk '
                /^[[:space:]]*"[a-fA-F0-9:]{17}"[[:space:]]*:[[:space:]]*\{/ {
                    gsub(/^[[:space:]]*"/, "")
                    gsub(/"[[:space:]]*:[[:space:]]*\{.*$/, "")
                    mac = $0
                }
                /"signal"[[:space:]]*:[[:space:]]*-?[0-9]+/ {
                    gsub(/^.*"signal"[[:space:]]*:[[:space:]]*/, "")
                    gsub(/[,[:space:]]*$/, "")
                    if (mac && $0) {
                        print "'"$interface"'|" mac "|" $0
                        mac = ""
                    }
                }
            ' "$json_temp")

            rm -f "$json_temp"

            if [ -n "$clients" ]; then
                echo "$clients" >> "$temp_file"
            fi
        fi
    done

    # Get ARP data for IP resolution (quick version)
    print_info "Resolving IP addresses..."
    local arp_data=""

    # Get ARP data from OPNsense
    local opnsense_arp=""
    opnsense_arp=$(ssh -o ConnectTimeout=5 "$SSH_USER@$OPNSENSE_IP" "arp -a" 2>/dev/null)

    # Get ARP data from OpenWrt as additional source
    local openwrt_arp=""
    openwrt_arp=$(ssh -o ConnectTimeout=5 "$SSH_USER@$ROUTER_IP" "cat /proc/net/arp 2>/dev/null | tail -n +2" 2>/dev/null)

    # Combine both sources
    if [ -n "$opnsense_arp" ]; then
        arp_data="$opnsense_arp"
    fi

    if [ -n "$openwrt_arp" ]; then
        # Convert OpenWrt ARP format and append
        local converted_arp=""
        converted_arp=$(echo "$openwrt_arp" | awk '{if($4!="00:00:00:00:00:00") print "? (" $1 ") at " $4 " on br-lan"}')
        if [ -n "$arp_data" ]; then
            arp_data="$arp_data
$converted_arp"
        else
            arp_data="$converted_arp"
        fi
    fi

    # Display header
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    Quick Device Management                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo

    echo -e "${CYAN}╔════╦═══════════════════════════╦═══════════════╦═══════════════════════╦═════════════╗${NC}"
    echo -e "${CYAN}║ #  ║ Device Name               ║ IP Address    ║ MAC Address           ║ Interface   ║${NC}"
    echo -e "${CYAN}╠════╬═══════════════════════════╬═══════════════╬═══════════════════════╬═════════════╣${NC}"

    # Process and display devices immediately
    if [ -f "$temp_file" ]; then
        while IFS='|' read -r interface mac signal; do
            if [ -n "$mac" ] && [ -n "$interface" ]; then
                device_count=$((device_count + 1))

                # Find IP and hostname from ARP
                local device_name="Unknown"
                local ip_addr="N/A"

                if [ -n "$arp_data" ]; then
                    local arp_line=""
                    # Try case-insensitive search for MAC address
                    arp_line=$(echo "$arp_data" | grep -i "$mac" | head -1 || echo "")

                    if [ -n "$arp_line" ]; then
                        ip_addr=$(echo "$arp_line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "N/A")
                        # Extract device name, handle both hostname.lan and ? (IP) formats
                        local raw_name=$(echo "$arp_line" | awk '{print $1}')
                        if [ "$raw_name" = "?" ]; then
                            device_name="Device-${ip_addr##*.}"  # Use last octet of IP
                        else
                            device_name=$(echo "$raw_name" | sed 's/\.lan$//' || echo "Unknown")
                        fi
                    fi
                fi

                # Store device info for selection
                local device_info="$interface|$mac|$ip_addr|$device_name|$signal"
                if [ -z "$DEVICE_LIST" ]; then
                    DEVICE_LIST="$device_info"
                else
                    DEVICE_LIST="$DEVICE_LIST
$device_info"
                fi

                # Truncate device name if too long
                local display_device_name="$device_name"
                if [ ${#display_device_name} -gt 25 ]; then
                    display_device_name="${display_device_name:0:22}..."
                fi

                # Handle IP address display
                local display_ip="$ip_addr"
                if [ "$display_ip" = "N/A" ]; then
                    display_ip="N/A"
                fi

                # Display device info
                printf "${CYAN}║${NC} %-2s ${CYAN}║${NC} %-25s ${CYAN}║${NC} %-13s ${CYAN}║${NC} %-21s ${CYAN}║${NC} %-11s ${CYAN}║${NC}\n" \
                    "$device_count" \
                    "$display_device_name" \
                    "$display_ip" \
                    "$mac" \
                    "$interface"
            fi
        done < "$temp_file"
    fi

    echo -e "${CYAN}╚════╩═══════════════════════════╩═══════════════╩═══════════════════════╩═════════════╝${NC}"

    # Cleanup temp file
    rm -f "$temp_file"

    if [ $device_count -eq 0 ]; then
        print_warning "No devices found connected to WiFi interfaces"
        echo
        read -p "Press Enter to return to main menu..."
        return 1
    fi

    print_success "Found $device_count connected device(s)"

    # Show device selection menu
    echo
    echo "Select a device to manage:"
    echo "1-$device_count. Select device number"
    echo "0. Return to main menu"
    echo

    while true; do
        read -p "Enter device number (1-$device_count) or 0 to exit: " selection

        if [ "$selection" = "0" ]; then
            return 0
        elif [ "$selection" -ge 1 ] 2>/dev/null && [ "$selection" -le "$device_count" ] 2>/dev/null; then
            # Extract selected device info
            selected_line=$(echo "$DEVICE_LIST" | sed -n "${selection}p")
            IFS='|' read -r SELECTED_INTERFACE SELECTED_MAC SELECTED_IP SELECTED_NAME SELECTED_SIGNAL <<< "$selected_line"
            break
        else
            print_error "Invalid selection. Please enter a number between 1 and $device_count, or 0 to exit."
        fi
    done

    # Show available actions for selected device
    echo
    echo "Selected: $SELECTED_NAME ($SELECTED_MAC)"
    echo
    echo "Available actions:"
    echo "1. Apply throttling"
    echo "2. Remove throttling"
    echo "3. Disconnect device"
    echo "4. Return to main menu"

    read -p "Select action (1-4): " action
    case $action in
        1)
            if select_throttle_profile; then
                apply_throttling "$SELECTED_INTERFACE" "$SELECTED_MAC" "$SELECTED_RATE" "$SELECTED_CEIL"
            fi
            ;;
        2)
            remove_throttling "$SELECTED_INTERFACE"
            ;;
        3)
            disconnect_device "$SELECTED_INTERFACE" "$SELECTED_MAC"
            ;;
        4)
            return 0
            ;;
        *)
            print_error "Invalid action"
            ;;
    esac
}

# Show real-time bandwidth usage with enhanced throttling info
show_realtime_bandwidth_usage() {
    print_info "Real-time Bandwidth Usage Monitor"
    echo

    # First, get device list quickly (use same logic as get_connected_devices)
    local temp_file="/tmp/wifi_devices_bandwidth_$$"
    local device_count=0

    print_info "Scanning WiFi interfaces for connected devices..."

    # Clear temp file and device list
    > "$temp_file"
    DEVICE_LIST=""

    # Scan each interface using hostapd ubus (exact same logic as working function)
    for interface in $WIFI_INTERFACES; do
        echo -e "${CYAN}Scanning $interface...${NC}"

        # Get clients via hostapd ubus interface
        local clients_json=""
        clients_json=$(safe_ssh "$ROUTER_IP" "ubus call hostapd.$interface get_clients" 2>/dev/null || echo "")

        if [ -n "$clients_json" ]; then
            # Simple Python-like approach using shell
            local clients=""
            local json_temp="/tmp/json_parse_$$"
            echo "$clients_json" > "$json_temp"

            # Extract all MAC addresses and their corresponding signals
            clients=$(awk '
                /^[[:space:]]*"[a-fA-F0-9:]{17}"[[:space:]]*:[[:space:]]*\{/ {
                    gsub(/^[[:space:]]*"/, "")
                    gsub(/"[[:space:]]*:[[:space:]]*\{.*$/, "")
                    mac = $0
                }
                /"signal"[[:space:]]*:[[:space:]]*-?[0-9]+/ {
                    gsub(/^.*"signal"[[:space:]]*:[[:space:]]*/, "")
                    gsub(/[,[:space:]]*$/, "")
                    if (mac && $0) {
                        print mac "|" $0
                        mac = ""
                    }
                }
            ' "$json_temp")

            rm -f "$json_temp"

            if [ -n "$clients" ]; then
                echo "$clients" | while IFS='|' read -r mac signal; do
                    if [ -n "$mac" ] && [ -n "$signal" ]; then
                        echo "$interface|$mac|$signal" >> "$temp_file"
                    fi
                done
            fi
        else
            # Fallback to iw command if hostapd ubus fails
            print_warning "hostapd ubus failed for $interface, trying fallback method"
            local stations=""
            stations=$(safe_ssh "$ROUTER_IP" "iw dev $interface station dump 2>/dev/null | grep '^Station' | awk '{print \$2}'" || echo "")

            if [ -n "$stations" ]; then
                echo "$stations" | while read -r mac; do
                    if [ -n "$mac" ]; then
                        local signal=""
                        signal=$(safe_ssh "$ROUTER_IP" "iw dev $interface station get $mac 2>/dev/null | grep 'signal:' | awk '{print \$2}'" || echo "N/A")
                        echo "$interface|$mac|$signal" >> "$temp_file"
                    fi
                done
            fi
        fi
    done

    # Get ARP data for IP resolution
    print_info "Resolving IP addresses..."
    local arp_data=""

    # Get ARP data from OPNsense
    local opnsense_arp=""
    opnsense_arp=$(ssh -o ConnectTimeout=5 "$SSH_USER@$OPNSENSE_IP" "arp -a" 2>/dev/null)

    # Get ARP data from OpenWrt as additional source
    local openwrt_arp=""
    openwrt_arp=$(ssh -o ConnectTimeout=5 "$SSH_USER@$ROUTER_IP" "cat /proc/net/arp 2>/dev/null | tail -n +2" 2>/dev/null)

    # Combine both sources
    if [ -n "$opnsense_arp" ]; then
        arp_data="$opnsense_arp"
    fi

    if [ -n "$openwrt_arp" ]; then
        # Convert OpenWrt ARP format and append
        local converted_arp=""
        converted_arp=$(echo "$openwrt_arp" | awk '{if($4!="00:00:00:00:00:00") print "? (" $1 ") at " $4 " on br-lan"}')
        if [ -n "$arp_data" ]; then
            arp_data="$arp_data
$converted_arp"
        else
            arp_data="$converted_arp"
        fi
    fi

    # Display header
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                             Real-time Bandwidth Usage Monitor                                             ║${NC}"
    echo -e "${CYAN}╠════╦═══════════════════════════╦═══════════════╦═══════════════════════╦═════════════╦══════════════╦═══════════════════════════╣${NC}"
    echo -e "${CYAN}║ #  ║ Device Name               ║ IP Address    ║ MAC Address           ║ Interface   ║ Signal (dBm) ║ Bandwidth Status          ║${NC}"
    echo -e "${CYAN}╠════╬═══════════════════════════╬═══════════════╬═══════════════════════╬═════════════╬══════════════╬═══════════════════════════╣${NC}"

    # Process and display devices with enhanced bandwidth info
    if [ -f "$temp_file" ]; then
        while IFS='|' read -r interface mac signal; do
            if [ -n "$mac" ] && [ -n "$interface" ]; then
                device_count=$((device_count + 1))

                # Find IP and hostname from ARP
                local device_name="Unknown"
                local ip_addr="N/A"

                if [ -n "$arp_data" ]; then
                    local arp_line=""
                    arp_line=$(echo "$arp_data" | grep -i "$mac" | head -1 || echo "")

                    if [ -n "$arp_line" ]; then
                        ip_addr=$(echo "$arp_line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "N/A")
                        local raw_name=$(echo "$arp_line" | awk '{print $1}')
                        if [ "$raw_name" = "?" ]; then
                            device_name="Device-${ip_addr##*.}"
                        else
                            device_name=$(echo "$raw_name" | sed 's/\.lan$//' || echo "Unknown")
                        fi
                    fi
                fi

                # Truncate device name if too long
                local display_device_name="$device_name"
                if [ ${#display_device_name} -gt 25 ]; then
                    display_device_name="${display_device_name:0:22}..."
                fi

                # Handle IP address display
                local display_ip="$ip_addr"
                if [ "$display_ip" = "N/A" ]; then
                    display_ip="N/A"
                fi

                # Get enhanced throttling status with usage info
                local bandwidth_status=""
                bandwidth_status=$(check_device_throttling_with_usage "$interface" "$mac")

                # Display device info with enhanced bandwidth status
                printf "${CYAN}║${NC} %-2s ${CYAN}║${NC} %-25s ${CYAN}║${NC} %-13s ${CYAN}║${NC} %-21s ${CYAN}║${NC} %-11s ${CYAN}║${NC} %-12s ${CYAN}║${NC} %-25s ${CYAN}║${NC}\n" \
                    "$device_count" \
                    "$display_device_name" \
                    "$display_ip" \
                    "$mac" \
                    "$interface" \
                    "$signal" \
                    "$bandwidth_status"
            fi
        done < "$temp_file"
    fi

    echo -e "${CYAN}╚════╩═══════════════════════════╩═══════════════╩═══════════════════════╩═════════════╩══════════════╩═══════════════════════════╝${NC}"

    # Cleanup temp file
    rm -f "$temp_file"

    if [ $device_count -eq 0 ]; then
        print_warning "No devices found connected to WiFi interfaces"
        return 1
    fi

    print_success "Found $device_count connected device(s) with bandwidth usage information"

    # Show legend
    echo
    print_info "Bandwidth Status Legend:"
    echo "  • Unlimited    - No throttling applied"
    echo "  • 1Mbit (idle) - Limited to 1Mbit, currently not active"
    echo "  • 1Mbit (500Kbps active) - Limited to 1Mbit, currently using 500Kbps"
    echo "  • Limited      - Throttled but rate unknown"

    return 0
}

# Main function
main() {
    # Check dependencies first
    check_dependencies
    log "WiFi Device Manager started"

    # Test SSH connections
    print_info "Testing SSH connections..."

    if ! test_ssh_connection "$ROUTER_IP"; then
        print_error "Cannot connect to OpenWrt router at $ROUTER_IP"
        echo "Please ensure:"
        echo "1. Router is accessible at $ROUTER_IP"
        echo "2. SSH is enabled on the router"
        echo "3. SSH keys are configured or password authentication is available"
        exit 1
    fi

    if test_ssh_connection "$OPNSENSE_IP" 3; then
        print_success "All SSH connections verified"
    else
        print_warning "Cannot connect to OPNsense at $OPNSENSE_IP"
        print_warning "Device names may show as 'Unknown' and disconnect features will be limited"
    fi

    # Main interactive loop
    while true; do
        print_header
        show_main_menu

        read -p "Enter your choice: " choice

        case $choice in
            1)
                get_connected_devices
                echo
                read -p "Press Enter to continue..."
                ;;
            2)
                get_connected_devices_with_throttling
                echo
                read -p "Press Enter to continue..."
                ;;
            3)
                if get_connected_devices && select_device && select_throttle_profile; then
                    apply_throttling "$SELECTED_INTERFACE" "$SELECTED_MAC" "$SELECTED_RATE" "$SELECTED_CEIL"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            4)
                if get_connected_devices && select_device; then
                    remove_throttling "$SELECTED_INTERFACE"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            5)
                show_throttle_status
                echo
                read -p "Press Enter to continue..."
                ;;
            6)
                if get_connected_devices && select_device; then
                    disconnect_device "$SELECTED_INTERFACE" "$SELECTED_MAC"
                fi
                echo
                read -p "Press Enter to continue..."
                ;;
            7)
                quick_device_management
                echo
                read -p "Press Enter to continue..."
                ;;
            8)
                show_realtime_bandwidth_usage
                echo
                read -p "Press Enter to continue..."
                ;;
            0)
                print_info "Exiting WiFi Device Manager"
                log "WiFi Device Manager exited"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Run main function with all arguments
main "$@"