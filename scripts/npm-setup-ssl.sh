#!/bin/bash
# Nginx Proxy Manager SSL Automation Script
# Usage: ./scripts/npm-setup-ssl.sh <domain> <forward_host> <forward_port>

set -e

# Configuration
NPM_URL="${NPM_URL:-http://192.168.1.9:81}"
NPM_USER="${NPM_USER:-jmvl@accelior.com}"
NPM_PASS="${NPM_PASS:-jklqsd1970}"
DOMAIN="${1:-keep.acmea.tech}"
FORWARD_HOST="${2:-192.168.1.20}"
FORWARD_PORT="${3:-3003}"
EMAIL="${NPM_EMAIL:-jmvl@accelior.com}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Get authentication token
log_info "Authenticating to Nginx Proxy Manager..."
TOKEN_RESPONSE=$(curl -s -X POST "$NPM_URL/api/tokens" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$NPM_USER\",\"secret\":\"$NPM_PASS\"}")

TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token // empty')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    log_error "Failed to get authentication token"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

log_info "Authentication successful"

# Step 2: Check if proxy host already exists
log_info "Checking for existing proxy host for $DOMAIN..."
EXISTING_HOST=$(curl -s -X GET "$NPM_URL/api/nginx/proxy-hosts" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" | jq -r ".[] | select(.domain_names[] == \"$DOMAIN\") | .id")

if [ -n "$EXISTING_HOST" ]; then
    log_warn "Proxy host already exists (ID: $EXISTING_HOST)"
    PROXY_HOST_ID=$EXISTING_HOST
else
    # Step 3: Create proxy host (without SSL first)
    log_info "Creating proxy host for $DOMAIN -> $FORWARD_HOST:$FORWARD_PORT..."

    PROXY_HOST_RESPONSE=$(curl -s -X POST "$NPM_URL/api/nginx/proxy-hosts" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"domain_names\": [\"$DOMAIN\"],
            \"forward_host\": \"$FORWARD_HOST\",
            \"forward_port\": $FORWARD_PORT,
            \"access_list_id\": null,
            \"certificate_id\": null,
            \"ssl_forced\": false,
            \"caching_enabled\": false,
            \"block_exploits\": true,
            \"http2_support\": false,
            \"hsts_enabled\": false,
            \"hsts_subdomains\": false,
            \"allow_websocket_upgrade\": true,
            \"forward_scheme\": \"http\",
            \"enabled\": true,
            \"meta\": {
                \"letsencrypt_agree\": false,
                \"dns_challenge\": false
            }
        }")

    PROXY_HOST_ID=$(echo "$PROXY_HOST_RESPONSE" | jq -r '.id // empty')

    if [ -z "$PROXY_HOST_ID" ] || [ "$PROXY_HOST_ID" = "null" ]; then
        log_error "Failed to create proxy host"
        echo "Response: $PROXY_HOST_RESPONSE"
        exit 1
    fi

    log_info "Proxy host created (ID: $PROXY_HOST_ID)"
fi

# Step 4: Request SSL certificate
log_info "Requesting Let's Encrypt SSL certificate for $DOMAIN..."

# Wait a moment for DNS propagation if this is a new domain
sleep 2

CERT_RESPONSE=$(curl -s -X POST "$NPM_URL/api/nginx/certificates" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"provider\": \"letsencrypt\",
        \"domain_names\": [\"$DOMAIN\"],
        \"meta\": {
            \"letsencrypt_agree\": true,
            \"letsencrypt_email\": \"$EMAIL\",
            \"dns_challenge\": false
        }
    }")

CERT_ID=$(echo "$CERT_RESPONSE" | jq -r '.id // empty')

if [ -z "$CERT_ID" ] || [ "$CERT_ID" = "null" ]; then
    log_error "Failed to request SSL certificate"
    echo "Response: $CERT_RESPONSE"
    log_warn "Continuing without SSL. You may need to wait for DNS propagation and try again."
    exit 0
fi

log_info "SSL certificate requested (ID: $CERT_ID)"

# Step 5: Wait for certificate to be issued
log_info "Waiting for certificate to be issued (this may take 30-60 seconds)..."

MAX_WAIT=60
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))

    CERT_STATUS=$(curl -s -X GET "$NPM_URL/api/nginx/certificates/$CERT_ID" \
        -H "Authorization: Bearer $TOKEN" | jq -r '.meta.letsencrypt_status // .status // "unknown"')

    echo -n "."

    if [ "$CERT_STATUS" = "issued" ] || [ "$CERT_STATUS" = "valid" ]; then
        echo ""
        log_info "Certificate issued successfully!"
        break
    fi

    if [ "$CERT_STATUS" = "error" ] || [ "$CERT_STATUS" = "failed" ]; then
        echo ""
        log_error "Certificate issuance failed"
        curl -s -X GET "$NPM_URL/api/nginx/certificates/$CERT_ID" \
            -H "Authorization: Bearer $TOKEN" | jq '.'
        exit 1
    fi
done

echo ""

# Step 6: Update proxy host with SSL
log_info "Updating proxy host with SSL certificate..."

UPDATE_RESPONSE=$(curl -s -X PUT "$NPM_URL/api/nginx/proxy-hosts/$PROXY_HOST_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"domain_names\": [\"$DOMAIN\"],
        \"forward_host\": \"$FORWARD_HOST\",
        \"forward_port\": $FORWARD_PORT,
        \"access_list_id\": null,
        \"certificate_id\": $CERT_ID,
        \"ssl_forced\": true,
        \"caching_enabled\": false,
        \"block_exploits\": true,
        \"http2_support\": true,
        \"hsts_enabled\": true,
        \"hsts_subdomains\": true,
        \"allow_websocket_upgrade\": true,
        \"forward_scheme\": \"http\",
        \"enabled\": true,
        \"meta\": {
            \"letsencrypt_agree\": true,
            \"dns_challenge\": false
        }
    }")

UPDATED_ID=$(echo "$UPDATE_RESPONSE" | jq -r '.id // empty')

if [ -z "$UPDATED_ID" ] || [ "$UPDATED_ID" = "null" ]; then
    log_error "Failed to update proxy host with SSL"
    echo "Response: $UPDATE_RESPONSE"
    exit 1
fi

log_info "Proxy host updated with SSL (ID: $UPDATED_ID)"

# Step 7: Verify configuration
log_info "Verifying configuration..."
FINAL_CONFIG=$(curl -s -X GET "$NPM_URL/api/nginx/proxy-hosts/$PROXY_HOST_ID" \
    -H "Authorization: Bearer $TOKEN")

SSL_ENABLED=$(echo "$FINAL_CONFIG" | jq -r '.ssl_forced')
HTTP2_ENABLED=$(echo "$FINAL_CONFIG" | jq -r '.http2_support')
CERT_NAME=$(echo "$FINAL_CONFIG" | jq -r '.certificate.nice_name // "none"')

echo ""
log_info "=== Configuration Summary ==="
echo "Domain:        $DOMAIN"
echo "Proxy Host ID: $PROXY_HOST_ID"
echo "Certificate:   $CERT_NAME (ID: $CERT_ID)"
echo "SSL Forced:    $SSL_ENABLED"
echo "HTTP/2:        $HTTP2_ENABLED"
echo "Forward to:    $FORWARD_HOST:$FORWARD_PORT"
echo ""
log_info "SSL setup complete!"
echo ""
echo "Test your site:"
echo "  HTTP:  http://$DOMAIN"
echo "  HTTPS: https://$DOMAIN"
echo ""
