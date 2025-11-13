#!/bin/bash
#
# Nginx Proxy Manager Configuration Script
# Creates proxy host for atlassian-mcp.acmea.tech
#
# This script provides both automated (API) and manual setup instructions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NPM_HOST="192.168.1.9"
NPM_PORT="81"
NPM_API="http://${NPM_HOST}:${NPM_PORT}/api"
DOMAIN="atlassian-mcp.acmea.tech"
BACKEND_HOST="192.168.1.20"
BACKEND_PORT="9000"
LETSENCRYPT_EMAIL="jmvl@accelior.com"

echo -e "${GREEN}=== Nginx Proxy Manager Setup for MCP Atlassian ===${NC}\n"

# Function to print manual setup instructions
print_manual_instructions() {
    echo -e "${YELLOW}Manual Setup Instructions:${NC}\n"
    echo "1. Open your browser and navigate to: http://${NPM_HOST}:${NPM_PORT}"
    echo "2. Login with admin credentials"
    echo ""
    echo "3. Click 'Add Proxy Host' and configure:"
    echo "   ${GREEN}Details Tab:${NC}"
    echo "   - Domain Names: ${DOMAIN}"
    echo "   - Scheme: http"
    echo "   - Forward Hostname/IP: ${BACKEND_HOST}"
    echo "   - Forward Port: ${BACKEND_PORT}"
    echo "   - ☑ Block Common Exploits"
    echo "   - ☑ Websockets Support"
    echo ""
    echo "   ${GREEN}SSL Tab:${NC}"
    echo "   - ☑ Request a new SSL Certificate"
    echo "   - Email: ${LETSENCRYPT_EMAIL}"
    echo "   - ☑ Force SSL"
    echo "   - ☑ HTTP/2 Support"
    echo "   - ☑ I Agree to the Let's Encrypt Terms of Service"
    echo ""
    echo "   ${GREEN}Advanced Tab:${NC}"
    echo "   Paste the following configuration:"
    echo ""
    cat << 'NGINX_CONFIG'
# Increase timeouts for long-running MCP operations
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
proxy_connect_timeout 75s;

# WebSocket support
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

# Standard headers
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;

# Large request body support (for Confluence page uploads)
client_max_body_size 100M;
NGINX_CONFIG
    echo ""
    echo "4. Click 'Save'"
    echo ""
    echo "5. Wait 1-2 minutes for Let's Encrypt certificate issuance"
    echo ""
}

# Function to attempt API configuration
attempt_api_config() {
    echo -e "${YELLOW}Attempting API configuration...${NC}\n"

    # Try to get a token (you'll need to provide the actual admin password)
    echo "Enter NPM admin email (default: admin@example.com):"
    read -r ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}

    echo "Enter NPM admin password:"
    read -rs ADMIN_PASSWORD
    echo ""

    # Authenticate
    TOKEN=$(curl -s -X POST "${NPM_API}/tokens" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"${ADMIN_EMAIL}\",\"secret\":\"${ADMIN_PASSWORD}\"}" | jq -r '.token')

    if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
        echo -e "${RED}Authentication failed. Please use manual setup.${NC}\n"
        return 1
    fi

    echo -e "${GREEN}Authentication successful!${NC}\n"

    # Create proxy host
    echo "Creating proxy host..."
    PROXY_HOST_RESPONSE=$(curl -s -X POST "${NPM_API}/nginx/proxy-hosts" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"domain_names\": [\"${DOMAIN}\"],
            \"forward_scheme\": \"http\",
            \"forward_host\": \"${BACKEND_HOST}\",
            \"forward_port\": ${BACKEND_PORT},
            \"access_list_id\": 0,
            \"certificate_id\": 0,
            \"ssl_forced\": false,
            \"caching_enabled\": false,
            \"block_exploits\": true,
            \"advanced_config\": \"# Increase timeouts for long-running MCP operations\nproxy_read_timeout 3600s;\nproxy_send_timeout 3600s;\nproxy_connect_timeout 75s;\n\n# WebSocket support\nproxy_http_version 1.1;\nproxy_set_header Upgrade \$http_upgrade;\nproxy_set_header Connection \\\"upgrade\\\";\n\n# Standard headers\nproxy_set_header Host \$host;\nproxy_set_header X-Real-IP \$remote_addr;\nproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\nproxy_set_header X-Forwarded-Proto \$scheme;\n\n# Large request body support\nclient_max_body_size 100M;\",
            \"allow_websocket_upgrade\": true,
            \"http2_support\": true,
            \"hsts_enabled\": false,
            \"hsts_subdomains\": false,
            \"meta\": {}
        }")

    PROXY_HOST_ID=$(echo "$PROXY_HOST_RESPONSE" | jq -r '.id')

    if [ "$PROXY_HOST_ID" = "null" ] || [ -z "$PROXY_HOST_ID" ]; then
        echo -e "${RED}Failed to create proxy host:${NC}"
        echo "$PROXY_HOST_RESPONSE" | jq .
        return 1
    fi

    echo -e "${GREEN}Proxy host created successfully! ID: ${PROXY_HOST_ID}${NC}\n"

    # Request SSL certificate
    echo "Requesting Let's Encrypt certificate..."
    CERT_RESPONSE=$(curl -s -X POST "${NPM_API}/nginx/certificates" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"provider\": \"letsencrypt\",
            \"domain_names\": [\"${DOMAIN}\"],
            \"meta\": {
                \"letsencrypt_email\": \"${LETSENCRYPT_EMAIL}\",
                \"letsencrypt_agree\": true,
                \"dns_challenge\": false
            }
        }")

    CERT_ID=$(echo "$CERT_RESPONSE" | jq -r '.id')

    if [ "$CERT_ID" = "null" ] || [ -z "$CERT_ID" ]; then
        echo -e "${YELLOW}Certificate request may have failed. Check NPM UI.${NC}"
        echo "$CERT_RESPONSE" | jq .
    else
        echo -e "${GREEN}Certificate requested successfully! ID: ${CERT_ID}${NC}\n"

        # Update proxy host with certificate and force SSL
        echo "Updating proxy host to use SSL certificate..."
        UPDATE_RESPONSE=$(curl -s -X PUT "${NPM_API}/nginx/proxy-hosts/${PROXY_HOST_ID}" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{
                \"certificate_id\": ${CERT_ID},
                \"ssl_forced\": true,
                \"http2_support\": true
            }")

        echo -e "${GREEN}SSL configuration updated!${NC}\n"
    fi

    return 0
}

# Function to test access
test_access() {
    echo -e "\n${YELLOW}Testing access...${NC}\n"

    echo "Waiting 10 seconds for configuration to apply..."
    sleep 10

    # Test HTTP (should redirect to HTTPS if SSL is forced)
    echo "Testing HTTP access (should redirect)..."
    HTTP_RESPONSE=$(curl -sI "http://${DOMAIN}/healthz" 2>/dev/null || echo "Failed")
    echo "$HTTP_RESPONSE" | head -5
    echo ""

    # Test HTTPS
    echo "Testing HTTPS access..."
    sleep 5
    HTTPS_RESPONSE=$(curl -sI "https://${DOMAIN}/healthz" 2>/dev/null || echo "Failed - may need more time for SSL cert")
    echo "$HTTPS_RESPONSE" | head -5
    echo ""

    # Test MCP endpoint
    echo "Testing MCP endpoint..."
    MCP_TEST=$(curl -s "https://${DOMAIN}/mcp" 2>/dev/null || echo "Not accessible yet")
    echo "$MCP_TEST" | head -10
}

# Main menu
echo "Choose setup method:"
echo "1) Automated setup via API (requires admin credentials)"
echo "2) Show manual setup instructions"
echo "3) Test access only"
echo ""
read -r -p "Enter choice [1-3]: " CHOICE

case $CHOICE in
    1)
        if attempt_api_config; then
            test_access
        else
            echo -e "\n${YELLOW}API configuration failed. Showing manual instructions...${NC}\n"
            print_manual_instructions
        fi
        ;;
    2)
        print_manual_instructions
        ;;
    3)
        test_access
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}=== Setup Complete ===${NC}"
echo ""
echo "After configuration, you can access your MCP Atlassian server at:"
echo "  ${GREEN}https://${DOMAIN}/mcp${NC}"
echo ""
echo "Update your Claude Code .mcp.json with:"
echo '  {'
echo '    "mcpServers": {'
echo '      "mcp-atlassian": {'
echo "        \"url\": \"https://${DOMAIN}/mcp\""
echo '      }'
echo '    }'
echo '  }'
echo ""
