#!/bin/bash
# Test script to verify Uptime Kuma API access

echo "=== Uptime Kuma API Test ==="
echo ""

# Test 1: Check Uptime Kuma is accessible
echo "Test 1: Checking Uptime Kuma web interface..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.1.9:3010)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Web interface is accessible (HTTP $HTTP_CODE)"
else
    echo "✗ Web interface returned HTTP $HTTP_CODE"
fi
echo ""

# Test 2: Check metrics endpoint (should work with basic auth)
echo "Test 2: Testing /metrics endpoint..."
METRICS=$(curl -s http://192.168.1.9:3010/metrics 2>&1)
if echo "$METRICS" | grep -q "uptime_kuma"; then
    echo "✓ /metrics endpoint is accessible (no auth required)"
else
    echo "✗ /metrics endpoint requires authentication or is not available"
fi
echo ""

# Test 3: Test badge endpoint
echo "Test 3: Testing badge endpoint (requires public monitor)..."
BADGE=$(curl -s http://192.168.1.9:3010/api/badge/1/status 2>&1)
if echo "$BADGE" | grep -q "svg"; then
    echo "✓ Badge endpoint is working"
else
    echo "ℹ Badge endpoint returned: $(echo "$BADGE" | head -c 100)"
    echo "  (This is normal if there are no public monitors)"
fi
echo ""

# Test 4: Check Python library
echo "Test 4: Checking uptime-kuma-api Python library..."
if python3 -c "import uptime_kuma_api" 2>/dev/null; then
    VERSION=$(python3 -c "import uptime_kuma_api; print(uptime_kuma_api.__version__)" 2>/dev/null || echo "unknown")
    echo "✓ Python library is installed (version: $VERSION)"
else
    echo "✗ Python library is not installed"
    echo "  Install with: pip install uptime-kuma-api"
fi
echo ""

# Test 5: Instructions for using the API
echo "=== How to Use the Uptime Kuma API ==="
echo ""
echo "IMPORTANT: Uptime Kuma does NOT have a REST API for monitor management."
echo "It uses Socket.IO for real-time communication. Use the Python library instead."
echo ""
echo "Available methods:"
echo ""
echo "1. Python Library (Recommended):"
echo "   $ cd /Users/jm/Codebase/internet-control/scripts"
echo "   $ export UPTIME_KUMA_PASSWORD='your-admin-password'"
echo "   $ python3 add_uptime_kuma_monitor.py list"
echo "   $ python3 add_uptime_kuma_monitor.py add-http --name 'Google' --url 'https://google.com'"
echo "   $ python3 add_uptime_kuma_monitor.py add-ping --name 'Router' --hostname '192.168.1.1'"
echo ""
echo "2. Direct Database Access (Not Recommended):"
echo "   You can INSERT into the 'monitor' table directly, but:"
echo "   - You need to restart Uptime Kuma for changes to take effect"
echo "   - You must set all required fields correctly"
echo "   - Risk of data corruption"
echo ""
echo "3. Community REST API Wrappers:"
echo "   Third-party tools like 'uptime-kuma-rest-api' provide REST endpoints"
echo "   but they need to be deployed separately as Docker containers."
echo ""
