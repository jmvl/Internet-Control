#!/bin/bash
# CouchDB NPM Reverse Proxy Configuration Script
# This script provides instructions and verification for setting up
# CouchDB public access via Nginx Proxy Manager

set -e

echo "================================"
echo "CouchDB Public Access Setup"
echo "================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="couchdb.acmea.tech"
BASE_DOMAIN="base.acmea.tech"
COUCHDB_HOST="192.168.1.20"
COUCHDB_PORT="5984"
NPM_HOST="192.168.1.9"
NPM_PORT="81"

echo -e "${YELLOW}Step 1: DNS Configuration${NC}"
echo "---"
echo "Add CNAME record in Cloudflare:"
echo "  Type: CNAME"
echo "  Name: couchdb"
echo "  Target: ${BASE_DOMAIN}"
echo "  Proxy: OFF (grey cloud - DNS only)"
echo "  TTL: Auto"
echo ""
echo -e "${YELLOW}Press Enter after DNS is configured...${NC}"
read

echo ""
echo -e "${YELLOW}Step 2: Verify DNS Resolution${NC}"
echo "---"
if nslookup ${DOMAIN} > /dev/null 2>&1; then
    RESOLVED_IP=$(nslookup ${DOMAIN} | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    echo -e "${GREEN}✓ DNS resolves to: ${RESOLVED_IP}${NC}"
else
    echo -e "${RED}✗ DNS not resolving yet. Wait a few minutes and try again.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 3: Configure Nginx Proxy Manager${NC}"
echo "---"
echo "1. Open NPM web interface: http://${NPM_HOST}:${NPM_PORT}"
echo "2. Go to 'Proxy Hosts' → 'Add Proxy Host'"
echo ""
echo "Details tab:"
echo "  - Domain Names: ${DOMAIN}"
echo "  - Scheme: http"
echo "  - Forward Hostname/IP: ${COUCHDB_HOST}"
echo "  - Forward Port: ${COUCHDB_PORT}"
echo "  - Cache Assets: OFF"
echo "  - Block Common Exploits: ON"
echo "  - Websockets Support: ON"
echo ""
echo "SSL tab:"
echo "  - SSL Certificate: Request a new SSL Certificate"
echo "  - Force SSL: ON"
echo "  - HTTP/2 Support: ON"
echo "  - HSTS Enabled: OFF (optional)"
echo "  - Email: your-email@domain.com"
echo "  - Accept Let's Encrypt Terms: ON"
echo ""
echo "Advanced tab (optional):"
echo "  Add custom Nginx configuration:"
echo "  ---"
echo "  client_max_body_size 100M;"
echo "  proxy_read_timeout 3600s;"
echo "  proxy_send_timeout 3600s;"
echo "  ---"
echo ""
echo -e "${YELLOW}Press Enter after NPM is configured...${NC}"
read

echo ""
echo -e "${YELLOW}Step 4: Verify Internal Connectivity${NC}"
echo "---"
if curl -s -o /dev/null -w "%{http_code}" http://${COUCHDB_HOST}:${COUCHDB_PORT}/ | grep -q "200"; then
    echo -e "${GREEN}✓ CouchDB is accessible internally${NC}"
else
    echo -e "${RED}✗ Cannot reach CouchDB at http://${COUCHDB_HOST}:${COUCHDB_PORT}/${NC}"
    echo "  Fix this before proceeding"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 5: Test Public HTTPS Access${NC}"
echo "---"
echo "Waiting 30 seconds for Let's Encrypt certificate provisioning..."
sleep 30

if curl -s -o /dev/null -w "%{http_code}" https://${DOMAIN}/ | grep -q "200"; then
    echo -e "${GREEN}✓ Public HTTPS access is working!${NC}"
else
    echo -e "${RED}✗ Cannot reach https://${DOMAIN}/${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check NPM logs: docker logs nginx-proxy-manager-nginx-proxy-manager-1"
    echo "2. Verify OPNsense port 443 forwarding to ${NPM_HOST}:443"
    echo "3. Check Let's Encrypt certificate in NPM web UI"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 6: Test Fauxton Web UI${NC}"
echo "---"
if curl -s -o /dev/null -w "%{http_code}" https://${DOMAIN}/_utils/ | grep -q "200"; then
    echo -e "${GREEN}✓ Fauxton web UI is accessible${NC}"
    echo "  URL: https://${DOMAIN}/_utils"
else
    echo -e "${YELLOW}⚠ Fauxton may require additional configuration${NC}"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Access your CouchDB instance at:"
echo "  - API: https://${DOMAIN}/"
echo "  - Web UI: https://${DOMAIN}/_utils"
echo ""
echo "Test API access:"
echo "  curl https://${DOMAIN}/"
echo "  curl -u admin:password https://${DOMAIN}/_all_dbs"
echo ""
echo "Documentation: /docs/docker/couchdb.md"
