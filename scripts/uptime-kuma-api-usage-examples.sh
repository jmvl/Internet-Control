#!/bin/bash
# Uptime Kuma API Usage Examples
# This script demonstrates how to use the Python script to manage Uptime Kuma monitors

set -e

# Configuration
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-http://192.168.1.9:3010}"
UPTIME_KUMA_USERNAME="${UPTIME_KUMA_USERNAME:-admin}"
SCRIPT_DIR="/Users/jm/Codebase/internet-control/scripts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if password is set
if [ -z "$UPTIME_KUMA_PASSWORD" ]; then
    echo -e "${RED}ERROR: UPTIME_KUMA_PASSWORD environment variable is not set${NC}"
    echo ""
    echo "Usage: UPTIME_KUMA_PASSWORD='your-password' ./uptime-kuma-api-usage-examples.sh"
    exit 1
fi

export UPTIME_KUMA_URL
export UPTIME_KUMA_USERNAME
export UPTIME_KUMA_PASSWORD

echo -e "${GREEN}=== Uptime Kuma API Usage Examples ===${NC}"
echo ""
echo "URL: $UPTIME_KUMA_URL"
echo "Username: $UPTIME_KUMA_USERNAME"
echo ""

# Example 1: List all monitors
echo -e "${YELLOW}Example 1: List all monitors${NC}"
echo "Command: python3 $SCRIPT_DIR/add_uptime_kuma_monitor.py list"
echo ""
python3 "$SCRIPT_DIR/add_uptime_kuma_monitor.py list"
echo ""
echo "---"
echo ""

# Example 2: Add an HTTP monitor
echo -e "${YELLOW}Example 2: Add an HTTP monitor${NC}"
echo "Command: python3 $SCRIPT_DIR/add_uptime_kuma_monitor.py add-http --name 'Google DNS' --url 'https://8.8.8.8' --interval 60"
echo ""
# Uncomment to actually add the monitor:
# python3 "$SCRIPT_DIR/add_uptime_kuma_monitor.py" add-http --name "Google DNS" --url "https://8.8.8.8" --interval 60
echo -e "${GREEN}Monitor added successfully!${NC}"
echo ""
echo "---"
echo ""

# Example 3: Add a PING monitor
echo -e "${YELLOW}Example 3: Add a PING monitor${NC}"
echo "Command: python3 $SCRIPT_DIR/add_uptime_kuma_monitor.py add-ping --name 'Cloudflare DNS' --hostname '1.1.1.1' --interval 30"
echo ""
# Uncomment to actually add the monitor:
# python3 "$SCRIPT_DIR/add_uptime_kuma_monitor.py" add-ping --name "Cloudflare DNS" --hostname "1.1.1.1" --interval 30
echo -e "${GREEN}Monitor added successfully!${NC}"
echo ""
echo "---"
echo ""

# Example 4: Add a TCP port monitor
echo -e "${YELLOW}Example 4: Add a TCP port monitor${NC}"
echo "Command: python3 $SCRIPT_DIR/add_uptime_kuma_monitor.py add-port --name 'SSH Server' --hostname '192.168.1.9' --port 22 --interval 60"
echo ""
# Uncomment to actually add the monitor:
# python3 "$SCRIPT_DIR/add_uptime_kuma_monitor.py" add-port --name "SSH Server" --hostname "192.168.1.9" --port 22 --interval 60
echo -e "${GREEN}Monitor added successfully!${NC}"
echo ""
echo "---"
echo ""

# Example 5: Delete a monitor
echo -e "${YELLOW}Example 5: Delete a monitor${NC}"
echo "Command: python3 $SCRIPT_DIR/add_uptime_kuma_monitor.py delete --id 42"
echo ""
# Uncomment to actually delete the monitor:
# python3 "$SCRIPT_DIR/add_uptime_kuma_monitor.py" delete --id 42
echo -e "${GREEN}Monitor deleted successfully!${NC}"
echo ""
echo "---"
echo ""

echo -e "${GREEN}=== All examples completed ===${NC}"
echo ""
echo "Note: The actual add/delete commands are commented out to prevent"
echo "unintended changes to your Uptime Kuma instance."
echo ""
echo "To run these examples for real, uncomment the relevant lines in this script."
