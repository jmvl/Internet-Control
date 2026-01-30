#!/bin/bash
#
# Deploy Infrastructure API to npm-pve2
# This script sets up the Flask API on the npm-pve2 LXC container
#

set -e

# Configuration
PVE2_HOST="192.168.10"
NPM_PVE2_ID="121"
API_USER="root"
API_DIR="/opt/infrastructure-api"
SERVICE_NAME="infrastructure-api"
PYTHON_BIN="/usr/bin/python3"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "================================================"
echo "  Infrastructure API Deployment to npm-pve2"
echo "================================================"
echo ""

log_info "This will deploy the infrastructure API to npm-pve2 (192.168.1.121)"
echo ""
echo "The script will:"
echo "  1. Copy API files to npm-pve2"
echo "  2. Install Python dependencies"
echo "  3. Create systemd service"
echo "  4. Start the service"
echo ""
read -p "Continue? (y/N): " -n 1
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && echo "Cancelled" && exit 0

# Step 1: Create API directory on npm-pve2
log_info "Creating API directory on npm-pve2..."
ssh root@192.168.1.121 "mkdir -p $API_DIR/static"
log_success "Directory created"

# Step 2: Copy files
log_info "Copying API files to npm-pve2..."
scp /Users/jm/Codebase/internet-control/infrastructure-db/api/app.py root@192.168.1.121:$API_DIR/app.py
scp /Users/jm/Codebase/internet-control/infrastructure-db/api/requirements.txt root@192.168.1.121:$API_DIR/requirements.txt
cp /Users/jm/Codebase/internet-control/infrastructure-db/api/static/index.html /Users/jm/Codebase/internet-control/infrastructure-db/api/static/index.html
scp /Users/jm/Codebase/internet-control/infrastructure-db/api/static/index.html root@192.168.1.121:$API_DIR/static/index.html
log_success "Files copied"

# Step 3: Copy database to npm-pve2
log_info "Copying infrastructure database to npm-pve2..."
scp /Users/jm/Codebase/internet-control/infrastructure-db/infrastructure.db root@192.168.1.121:$API_DIR/infrastructure.db
log_success "Database copied"

# Step 4: Install Python dependencies
log_info "Installing Python dependencies on npm-pve2..."
ssh root@192.168.1.121 "cd $API_DIR && pip3 install -r requirements.txt --break-system-packages"
log_success "Dependencies installed"

# Step 5: Create systemd service
log_info "Creating systemd service..."
ssh root@192.168.1.121 "cat > /etc/systemd/system/$SERVICE_NAME.service << 'EOF'
[Unit]
Description=Infrastructure API Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$API_DIR
Environment=\"PATH=/usr/local/bin:/usr/bin:/bin\"
ExecStart=/usr/bin/python3 $API_DIR/app.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
"
log_success "Service file created"

# Step 6: Enable and start service
log_info "Enabling and starting service..."
ssh root@192.168.1.121 "systemctl daemon-reload"
ssh root@192.168.1.121 "systemctl enable $SERVICE_NAME"
ssh root@192.168.1.121 "systemctl restart $SERVICE_NAME"
ssh root@192.168.1.121 "systemctl status $SERVICE_NAME --no-pager"
log_success "Service started"

# Step 7: Create Nginx proxy configuration
log_info "Creating Nginx proxy configuration..."

# Get next available proxy host ID
PROXY_ID=$(ssh root@192.168.1.121 "curl -s -X GET 'http://127.0.0.1:81/api/proxy-hosts' -u 'admin:$NPM_ADMIN_PASSWORD' | python3 -c \"import sys, json; hosts = json.load(sys.stdin); print(max([h['id'] for h in hosts] + [0]) + 1)\"")
PROXY_HOST="pve2-geek-map"
DOMAIN="geek-map.home.accelior.com"

ssh root@192.168.1.121 "curl -s -X POST 'http://127.0.0.1:81/api/proxy-hosts' \\
  -u 'admin:$NPM_ADMIN_PASSWORD' \\
  -H 'Content-Type: application/json' \\
  -d '{
    \"domain_names\": [\"$DOMAIN\"],
    \"forward_host\": \"127.0.0.1\",
    \"forward_port\": 5000,
    \"certificate_id\": 0,
    \"meta\": {\"letsencrypt_request\": \"false\"},
    \"advanced_config\": {}
  }'" 2>/dev/null || log_warn "Nginx proxy host creation skipped (may already exist)"

log_success "Nginx configuration complete"

# Summary
echo ""
echo "================================================"
echo "  Deployment Complete!"
echo "================================================"
echo ""
log_info "Infrastructure API is now running:"
echo "  • API: http://192.168.1.121:5000"
echo "  • Web: http://$DOMAIN (via Nginx Proxy Manager)"
echo ""
echo "API Endpoints:"
echo "  • GET /api/hosts - All hosts with LXC/VM info"
echo "  • GET /api/containers - All Docker containers"
echo "  • GET /api/stats - Summary statistics"
echo "  • GET /api/topology - Network topology"
echo "  • GET /api/host/<hostname> - Host details"
echo ""
echo "Management:"
echo "  • Stop: ssh root@192.168.1.121 systemctl stop $SERVICE_NAME"
echo "  • Start: ssh root@192.168.1.121 systemctl start $SERVICE_NAME"
echo "  • Logs: ssh root@192.168.1.121 journalctl -u $SERVICE_NAME -f"
echo ""
