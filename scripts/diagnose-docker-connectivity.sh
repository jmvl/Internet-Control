#!/bin/bash
#
# Docker Connectivity Diagnostic Script
# Diagnoses connection refused issues from specific source IPs to Docker containers
#
# Usage: ./diagnose-docker-connectivity.sh <source_ip> <destination_port>
# Example: ./diagnose-docker-connectivity.sh 192.168.1.9 8092
#

set -e

SOURCE_IP="${1:-192.168.1.9}"
DEST_PORT="${2:-8092}"

echo "========================================="
echo "Docker Connectivity Diagnostic Tool"
echo "========================================="
echo "Source IP: $SOURCE_IP"
echo "Destination Port: $DEST_PORT"
echo "Hostname: $(hostname)"
echo "Date: $(date)"
echo "========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print section headers
print_section() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required tools
print_section "1. Checking Required Tools"
for tool in iptables docker conntrack ss; do
    if command_exists "$tool"; then
        echo -e "${GREEN}✓${NC} $tool is installed"
    else
        echo -e "${RED}✗${NC} $tool is NOT installed"
        MISSING_TOOLS=1
    fi
done

if [ -n "$MISSING_TOOLS" ]; then
    echo ""
    echo -e "${YELLOW}Warning:${NC} Some tools are missing. Install with:"
    echo "  apt-get update && apt-get install -y iptables conntrack iproute2"
fi

# Check Docker service
print_section "2. Docker Service Status"
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓${NC} Docker service is running"
    docker --version
else
    echo -e "${RED}✗${NC} Docker service is NOT running"
    exit 1
fi

# List Docker networks
print_section "3. Docker Networks"
docker network ls
echo ""
echo "Bridge networks:"
docker network ls --filter driver=bridge --format "{{.Name}}: {{.ID}}"

# Check for docker-proxy processes listening on target port
print_section "4. Docker Proxy Listeners on Port $DEST_PORT"
if ss -tlnp | grep -q ":$DEST_PORT"; then
    echo -e "${GREEN}✓${NC} Process listening on port $DEST_PORT:"
    ss -tlnp | grep ":$DEST_PORT"
else
    echo -e "${RED}✗${NC} No process listening on port $DEST_PORT"
fi

# Check NAT rules for the port
print_section "5. iptables NAT Rules for Port $DEST_PORT"
echo "DOCKER chain:"
iptables -t nat -L DOCKER -n -v --line-numbers | grep -E "Chain DOCKER|$DEST_PORT" || echo "No rules found"
echo ""
echo "PREROUTING chain:"
iptables -t nat -L PREROUTING -n -v --line-numbers | grep -E "Chain PREROUTING|$DEST_PORT" || echo "No rules found"

# Check DOCKER-USER chain (critical for source IP filtering)
print_section "6. DOCKER-USER Chain (Source IP Filtering)"
DOCKER_USER_RULES=$(iptables -L DOCKER-USER -n -v --line-numbers | tail -n +3)
if [ -z "$DOCKER_USER_RULES" ] || echo "$DOCKER_USER_RULES" | grep -q "RETURN"; then
    echo -e "${GREEN}✓${NC} DOCKER-USER chain has no blocking rules (only RETURN)"
    iptables -L DOCKER-USER -n -v --line-numbers
else
    echo -e "${YELLOW}⚠${NC} DOCKER-USER chain has custom rules:"
    iptables -L DOCKER-USER -n -v --line-numbers
    echo ""
    echo -e "${YELLOW}Checking for rules affecting source IP $SOURCE_IP:${NC}"
    iptables -L DOCKER-USER -n -v --line-numbers | grep "$SOURCE_IP" && \
        echo -e "${RED}✗ FOUND RULES MATCHING SOURCE IP!${NC}" || \
        echo -e "${GREEN}✓ No rules specifically matching source IP${NC}"
fi

# Check FORWARD chain
print_section "7. FORWARD Chain Rules"
echo "FORWARD chain summary:"
iptables -L FORWARD -n -v | head -20
echo ""
echo "DOCKER-ISOLATION-STAGE-1:"
iptables -L DOCKER-ISOLATION-STAGE-1 -n -v || echo "Chain not found"
echo ""
echo "DOCKER-ISOLATION-STAGE-2:"
iptables -L DOCKER-ISOLATION-STAGE-2 -n -v || echo "Chain not found"

# Check connection tracking
print_section "8. Connection Tracking Status"
if command_exists conntrack; then
    CONNTRACK_COUNT=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo "0")
    CONNTRACK_MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo "0")
    CONNTRACK_PERCENT=$((CONNTRACK_COUNT * 100 / CONNTRACK_MAX))

    echo "Connection tracking table usage: $CONNTRACK_COUNT / $CONNTRACK_MAX ($CONNTRACK_PERCENT%)"
    if [ "$CONNTRACK_PERCENT" -gt 80 ]; then
        echo -e "${RED}✗${NC} Connection tracking table is >80% full! May cause connection issues."
    else
        echo -e "${GREEN}✓${NC} Connection tracking table has sufficient space"
    fi

    echo ""
    echo "Active connections from source IP $SOURCE_IP:"
    conntrack -L -s "$SOURCE_IP" 2>/dev/null | head -20 || echo "No connections found or insufficient permissions"

    echo ""
    echo "Connections to destination port $DEST_PORT:"
    conntrack -L | grep "dport=$DEST_PORT" 2>/dev/null | head -10 || echo "No connections found"
else
    echo -e "${YELLOW}⚠${NC} conntrack command not available"
fi

# Check bridge netfilter settings
print_section "9. Bridge Netfilter Settings"
if lsmod | grep -q br_netfilter; then
    echo -e "${GREEN}✓${NC} br_netfilter module is loaded"
else
    echo -e "${YELLOW}⚠${NC} br_netfilter module is NOT loaded"
fi

echo ""
echo "Bridge iptables call settings:"
for setting in bridge-nf-call-iptables bridge-nf-call-ip6tables bridge-nf-filter-vlan-tagged; do
    value=$(sysctl -n "net.bridge.bridge-nf-call-$setting" 2>/dev/null || echo "N/A")
    echo "  net.bridge.$setting = $value"
done

# Check container running on the port
print_section "10. Container Information for Port $DEST_PORT"
CONTAINER_ID=$(docker ps --format "{{.ID}}" --filter "publish=$DEST_PORT" | head -1)
if [ -n "$CONTAINER_ID" ]; then
    echo -e "${GREEN}✓${NC} Found container publishing port $DEST_PORT:"
    docker ps --filter "id=$CONTAINER_ID" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "Container network settings:"
    docker inspect "$CONTAINER_ID" | grep -A 20 '"Networks"'
    echo ""
    echo "Container IP addresses:"
    docker inspect "$CONTAINER_ID" | grep -E '"IPAddress"|"Gateway"'
else
    echo -e "${RED}✗${NC} No container found publishing port $DEST_PORT"
    echo ""
    echo "All containers with published ports:"
    docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}"
fi

# Kernel logs for dropped packets
print_section "11. Recent Kernel Logs for Dropped Packets"
if [ -f /var/log/kern.log ]; then
    echo "Recent DROP/REJECT messages:"
    tail -100 /var/log/kern.log | grep -i "drop\|reject" | tail -20 || echo "No recent drops found"
else
    echo "Checking dmesg:"
    dmesg | grep -i "drop\|reject" | tail -20 || echo "No recent drops found"
fi

# Summary and recommendations
print_section "12. Summary and Recommendations"

echo ""
echo "Quick Diagnostics Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for common issues
HAS_DOCKER_USER_RULES=0
HAS_CONNTRACK_ISSUES=0
HAS_PORT_LISTENER=0
HAS_NETFILTER_MODULE=1

# Analyze results
if ! ss -tlnp | grep -q ":$DEST_PORT"; then
    echo -e "${RED}✗ Issue:${NC} No process listening on port $DEST_PORT"
    echo "  → Start the container or check port mapping"
else
    HAS_PORT_LISTENER=1
fi

if iptables -L DOCKER-USER -n | grep -qv "RETURN"; then
    HAS_DOCKER_USER_RULES=1
    echo -e "${YELLOW}⚠ Potential Issue:${NC} Custom DOCKER-USER rules detected"
    echo "  → These may be blocking traffic from $SOURCE_IP"
    echo "  → Try: iptables -I DOCKER-USER 1 -s $SOURCE_IP -j ACCEPT"
fi

if [ "$CONNTRACK_PERCENT" -gt 80 ]; then
    HAS_CONNTRACK_ISSUES=1
    echo -e "${RED}✗ Issue:${NC} Connection tracking table >80% full"
    echo "  → Try: conntrack -D -s $SOURCE_IP"
    echo "  → Or increase: sysctl -w net.netfilter.nf_conntrack_max=262144"
fi

if ! lsmod | grep -q br_netfilter; then
    HAS_NETFILTER_MODULE=0
    echo -e "${YELLOW}⚠ Warning:${NC} br_netfilter module not loaded"
    echo "  → Load with: modprobe br_netfilter"
fi

echo ""
echo "Recommended Actions (in order):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ACTION_NUM=1
if [ "$HAS_PORT_LISTENER" -eq 0 ]; then
    echo "$ACTION_NUM. Start the Docker container on port $DEST_PORT"
    ACTION_NUM=$((ACTION_NUM + 1))
fi

if [ "$HAS_DOCKER_USER_RULES" -eq 1 ]; then
    echo "$ACTION_NUM. Add DOCKER-USER accept rule:"
    echo "   iptables -I DOCKER-USER 1 -s $SOURCE_IP -j ACCEPT"
    ACTION_NUM=$((ACTION_NUM + 1))
fi

if [ "$HAS_CONNTRACK_ISSUES" -eq 1 ]; then
    echo "$ACTION_NUM. Flush connection tracking for source IP:"
    echo "   conntrack -D -s $SOURCE_IP"
    ACTION_NUM=$((ACTION_NUM + 1))
fi

if [ "$HAS_NETFILTER_MODULE" -eq 0 ]; then
    echo "$ACTION_NUM. Load br_netfilter module:"
    echo "   modprobe br_netfilter"
    echo "   echo 'br_netfilter' >> /etc/modules"
    ACTION_NUM=$((ACTION_NUM + 1))
fi

echo "$ACTION_NUM. Restart Docker networking:"
echo "   systemctl restart docker"
ACTION_NUM=$((ACTION_NUM + 1))

echo "$ACTION_NUM. Test connection from source IP:"
echo "   From $SOURCE_IP: nc -vz \$(hostname -I | awk '{print \$1}') $DEST_PORT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Diagnostic complete. Review output above for issues."
echo "For detailed analysis, see:"
echo "  /Users/jm/Codebase/internet-control/docs/troubleshooting/seafile-docker-connectivity-issue-2025-10-15.md"
echo "========================================="
