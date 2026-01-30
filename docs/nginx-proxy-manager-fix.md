# Fix Nginx Proxy Manager Configuration for mail.acmea.tech

## Current Issue
The Nginx Proxy Manager is currently configured to forward `mail.acmea.tech` to port 8083 (Hestia control panel), but Let's Encrypt validation requires access to port 80 (web server) where ACME challenge files are served.

## Solution Steps

### Step 1: Access Nginx Proxy Manager
1. Open browser and go to: `http://192.168.1.121:81`
2. Login with your credentials

### Step 2: Modify mail.acmea.tech Proxy Host
1. Go to "Hosts" → "Proxy Hosts"
2. Find the entry for `mail.acmea.tech`
3. Click the "Edit" button (pencil icon)

### Step 3: Update the Configuration
**Current Configuration:**
- Domain Names: `mail.acmea.tech`
- Scheme: `http`
- Forward Hostname/IP: `192.168.1.30`
- Forward Port: `8083` ← This is the problem!

**New Configuration:**
- Domain Names: `mail.acmea.tech`
- Scheme: `http`
- Forward Hostname/IP: `192.168.1.30`
- Forward Port: `80` ← Change to web server port

### Step 4: Configure Advanced Settings
Click on the "Advanced" tab and add the following nginx configuration:

```nginx
# Handle Let's Encrypt ACME challenges
location /.well-known/acme-challenge/ {
    proxy_pass http://192.168.1.30:80;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

# Forward everything else to the webmail service
location / {
    proxy_pass http://192.168.1.30:80;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Increase timeouts for webmail
    proxy_connect_timeout 90;
    proxy_send_timeout 90;
    proxy_read_timeout 90;
    
    # Support for large uploads
    client_max_body_size 100M;
    client_body_buffer_size 1M;
}
```

### Step 5: Save and Test
1. Click "Save"
2. Wait for the configuration to be applied
3. Test access to: `http://mail.acmea.tech/.well-known/acme-challenge/test`

## Alternative Quick Fix
If you prefer a simpler approach, just change the port from `8083` to `80` in the basic configuration. This will forward all requests to the web server, which will then handle both webmail and ACME challenges properly.

## Why This Works
- Port 80 serves the nginx web server that can handle ACME challenges
- Port 8083 serves the Hestia control panel which cannot handle ACME challenges
- The nginx web server configuration we fixed includes proper routing for both webmail and ACME challenges

## Testing
After making these changes, you should be able to:
1. Access webmail at: `http://mail.acmea.tech`
2. Generate Let's Encrypt certificates through Hestia without errors
3. Access secure webmail at: `https://mail.acmea.tech`