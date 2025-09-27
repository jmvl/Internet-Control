#!/bin/bash

# Script to fix Radicale access on Hestia server
# Run this script on the Hestia server (192.168.1.30)

echo "=== Fixing Radicale Access ==="

# Step 1: Stop current Radicale container
echo "1. Stopping current Radicale container..."
docker stop radicale
docker rm radicale

# Step 2: Create necessary directories
echo "2. Creating directories..."
mkdir -p /root/radicale/{data,config}

# Step 3: Copy configuration file
echo "3. Setting up configuration..."
cat > /root/radicale/config/config << 'EOF'
[server]
hosts = 0.0.0.0:5232
max_connections = 20
max_content_length = 100000000
timeout = 30

[encoding]
request = utf-8
stock = utf-8

[auth]
type = htpasswd
htpasswd_filename = /data/users
htpasswd_encryption = bcrypt
delay = 1

[rights]
type = owner_only

[storage]
filesystem_folder = /data/collections
filesystem_fsync = True

[web]
type = internal

[logging]
level = info
mask_passwords = True

[headers]
Access-Control-Allow-Origin = *
Access-Control-Allow-Methods = GET, POST, PUT, DELETE, PROPFIND, PROPPATCH, REPORT
Access-Control-Allow-Headers = Content-Type, X-Auth-Token, X-Requested-With, Authorization
Access-Control-Expose-Headers = X-Auth-Token
EOF

# Step 4: Create docker-compose file
echo "4. Creating docker-compose file..."
cat > /root/radicale/docker-compose.yml << 'EOF'
version: '3.8'

services:
  radicale:
    image: tomsquest/docker-radicale
    container_name: radicale
    ports:
      - "192.168.1.30:5232:5232"  # Bind to specific IP for security
    volumes:
      - ./data:/data
      - ./config:/config:ro
    environment:
      - RADICALE_CONFIG=/config/config
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5232/.web/"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
EOF

# Step 5: Configure firewall (if using ufw)
echo "5. Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow from 192.168.1.9 to any port 5232 comment "Allow Nginx Proxy Manager to Radicale"
    echo "Firewall rule added for Nginx Proxy Manager access"
fi

# Step 6: Start Radicale with new configuration
echo "6. Starting Radicale with new configuration..."
cd /root/radicale
docker-compose up -d

# Step 7: Create initial user (optional)
echo "7. Creating initial user account..."
echo -n "Create initial user? (y/n): "
read create_user
if [ "$create_user" = "y" ]; then
    echo -n "Username: "
    read username
    docker exec -it radicale htpasswd -B -c /data/users $username
fi

# Step 8: Test access
echo "8. Testing Radicale access..."
sleep 5
if curl -s http://192.168.1.30:5232/.web/ > /dev/null; then
    echo "✓ Radicale is accessible on http://192.168.1.30:5232"
else
    echo "✗ Radicale is not responding. Check docker logs:"
    docker logs radicale
fi

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "1. Configure Nginx Proxy Manager at http://192.168.1.9:81"
echo "2. Add proxy host for radicale.vega-messenger.com → http://192.168.1.30:5232"
echo "3. Enable SSL certificate in Nginx Proxy Manager"
echo "4. Configure DNS to point radicale.vega-messenger.com to your public IP"
echo ""
echo "CalDAV URL: https://radicale.vega-messenger.com/"
echo "CardDAV URL: https://radicale.vega-messenger.com/"