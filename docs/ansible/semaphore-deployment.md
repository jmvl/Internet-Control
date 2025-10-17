# Semaphore Web UI Deployment

**Deployment Date**: October 9, 2025
**Status**: ✅ Deployed and Running
**Location**: Docker VM (PCT-111 at 192.168.1.20)

---

## ✅ Deployment Summary

### What is Semaphore?
Semaphore is a modern, open-source alternative to Ansible Tower/AWX that provides:
- **Web UI** for Ansible playbook execution
- **Scheduling** for automated runs
- **Role-based access control** for team collaboration
- **Execution history** and logs
- **Real-time output** during playbook runs

### Container Details
- **Image**: `semaphoreui/semaphore:latest` (v2.16.31)
- **Container Name**: `semaphore`
- **Status**: Running (healthy)
- **Database**: BoltDB (embedded SQLite-like database)
- **Port**: 3001 (external) → 3000 (internal)
- **Timezone**: Europe/Brussels

---

## 🌐 Access Information

### Internal Access (LAN)
- **URL**: http://192.168.1.20:3001
- **Login**:
  - Username: `admin` or `jmvl@accelior.com`
  - Password: `ChangeMe123!SecurePassword` ⚠️ **Change this immediately!**

### External Access (Planned)
- **URL**: https://semaphore.acmea.tech
- **Status**: ⚠️ Not yet configured (requires NPM proxy setup)

---

## 📂 File Locations

### On Docker VM (192.168.1.20):
```
/root/semaphore/
├── docker-compose.yml    # Container configuration
├── .env                  # Environment variables (contains passwords)
└── volumes/
    ├── semaphore-data/   # Semaphore configuration and database
    └── semaphore-ssh/    # SSH keys for Ansible connections
```

### Configuration Files:
- **Compose file**: `/root/semaphore/docker-compose.yml`
- **Environment**: `/root/semaphore/.env`
- **Database**: Docker volume `semaphore-data` (persistent)
- **SSH keys**: Docker volume `semaphore-ssh` (persistent)

---

## 🔧 Container Configuration

### Docker Compose Configuration:
```yaml
version: '3.8'

services:
  semaphore:
    image: semaphoreui/semaphore:latest
    container_name: semaphore
    restart: unless-stopped
    ports:
      - "3001:3000"  # Changed from 3000 due to Perplexica conflict
    environment:
      SEMAPHORE_DB_DIALECT: bolt
      SEMAPHORE_ADMIN_PASSWORD: ${SEMAPHORE_ADMIN_PASSWORD}
      SEMAPHORE_ADMIN_NAME: admin
      SEMAPHORE_ADMIN_EMAIL: jmvl@accelior.com
      SEMAPHORE_ADMIN: admin
      SEMAPHORE_ACCESS_KEY_ENCRYPTION: ${SEMAPHORE_ACCESS_KEY}
      SEMAPHORE_WEB_ROOT: https://semaphore.acmea.tech
      TZ: Europe/Brussels
    volumes:
      - semaphore-data:/etc/semaphore
      - semaphore-ssh:/root/.ssh
    networks:
      - semaphore-net
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/api/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### Environment Variables (.env):
```bash
SEMAPHORE_ADMIN_PASSWORD=ChangeMe123!SecurePassword
SEMAPHORE_ACCESS_KEY=changeme1234567890abcdefghijklmnop
```

---

## ⚙️ Initial Configuration Steps

### 1. Change Default Passwords ⚠️

**IMPORTANT**: Change the default admin password immediately!

```bash
# Method 1: Via Web UI
# Login → User Settings → Change Password

# Method 2: Regenerate strong passwords
ssh root@192.168.1.20
cd /root/semaphore

# Generate new admin password
NEW_ADMIN_PASS=$(openssl rand -base64 24)
echo "New Admin Password: $NEW_ADMIN_PASS"

# Generate new access key (32+ characters)
NEW_ACCESS_KEY=$(openssl rand -base64 32 | tr -d '\n' | head -c 32)
echo "New Access Key: $NEW_ACCESS_KEY"

# Update .env file
sed -i "s/SEMAPHORE_ADMIN_PASSWORD=.*/SEMAPHORE_ADMIN_PASSWORD=$NEW_ADMIN_PASS/" .env
sed -i "s/SEMAPHORE_ACCESS_KEY=.*/SEMAPHORE_ACCESS_KEY=$NEW_ACCESS_KEY/" .env

# Restart container
docker compose down
docker compose up -d

# Save new credentials securely
echo "Admin Password: $NEW_ADMIN_PASS" >> /root/semaphore-credentials.txt
echo "Access Key: $NEW_ACCESS_KEY" >> /root/semaphore-credentials.txt
chmod 600 /root/semaphore-credentials.txt
```

### 2. Configure SSH Access to Ansible Container (PCT-110)

Semaphore needs SSH access to the Ansible container to execute playbooks:

```bash
# On Docker VM (192.168.1.20)
ssh root@192.168.1.20

# Enter Semaphore container
docker exec -it semaphore bash

# Generate SSH key pair (inside container)
ssh-keygen -t ed25519 -C "semaphore@docker" -f /root/.ssh/id_ed25519 -N ""

# Display public key
cat /root/.ssh/id_ed25519.pub
# Copy this key
exit

# On Ansible container (PCT-110 at 192.168.1.11)
ssh root@pve2 'pct exec 110 -- bash'

# Add Semaphore's public key to authorized_keys
echo "PASTE_PUBLIC_KEY_HERE" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Test connection from Semaphore container
docker exec -it semaphore ssh -o StrictHostKeyChecking=no root@192.168.1.11 "ansible --version"
```

### 3. Setup NPM Reverse Proxy for External Access

**Configure Nginx Proxy Manager** for https://semaphore.acmea.tech:

```
Proxy Host Settings:
- Domain Names: semaphore.acmea.tech
- Scheme: http
- Forward Hostname/IP: 192.168.1.20
- Forward Port: 3001
- Cache Assets: No
- Block Common Exploits: Yes
- Websockets Support: Yes (important for live output)
- Access List: None (or restrict to specific IPs)
- SSL: Request Let's Encrypt certificate
- Force SSL: Yes
- HTTP/2 Support: Yes
- HSTS Enabled: Yes
```

**Custom Nginx Configuration** (Advanced tab):
```nginx
# Increase timeouts for long-running Ansible playbooks
proxy_read_timeout 3600;
proxy_connect_timeout 3600;
proxy_send_timeout 3600;

# WebSocket support for real-time output
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

---

## 📋 Semaphore Project Configuration

### Create New Project in Semaphore UI:

1. **Login** to http://192.168.1.20:3001
2. **Create Key Store** for SSH:
   - Type: SSH Key
   - Name: "Ansible PCT-110"
   - Private Key: Use the key generated in step 2 above

3. **Create Inventory**:
   - Name: "Production Inventory"
   - Type: Static
   - Inventory:
     ```ini
     [mail-server]
     192.168.1.30

     [jira-server]
     192.168.1.22

     [confluence-server]
     192.168.1.21
     ```
   - SSH Key: Select "Ansible PCT-110"

4. **Create Repository**:
   - Name: "Ansible Playbooks"
   - Type: SSH
   - URL: `root@192.168.1.11:/etc/ansible/playbooks`
   - Branch: `master` (or leave empty)
   - SSH Key: Select "Ansible PCT-110"

5. **Create Environment**:
   - Name: "Production"
   - Variables: (add any needed variables)

6. **Create Task Templates**:

   **HestiaCP Daily Log Cleanup**:
   - Name: "HestiaCP - Daily Log Cleanup"
   - Playbook: `hestia-mail-maintenance.yml`
   - Inventory: "Production Inventory"
   - Environment: "Production"
   - Extra Variables: `--tags logs`
   - Survey: None

   **HestiaCP Full Maintenance**:
   - Name: "HestiaCP - Full Maintenance"
   - Playbook: `hestia-mail-maintenance.yml`
   - Inventory: "Production Inventory"
   - Environment: "Production"

   **JIRA Full Maintenance**:
   - Name: "JIRA - Full Maintenance"
   - Playbook: `jira-maintenance.yml`
   - Inventory: "Production Inventory"
   - Environment: "Production"

   **Confluence Full Maintenance**:
   - Name: "Confluence - Full Maintenance"
   - Playbook: `confluence-maintenance.yml`
   - Inventory: "Production Inventory"
   - Environment: "Production"

---

## 📊 Monitoring and Usage

### Container Health Check:
```bash
# Check container status
ssh root@192.168.1.20 'docker ps | grep semaphore'

# View container logs
ssh root@192.168.1.20 'docker logs -f semaphore'

# Check health status
ssh root@192.168.1.20 'docker inspect semaphore | grep -A 5 Health'
```

### Access Logs:
```bash
# Application logs
ssh root@192.168.1.20 'docker logs semaphore --tail 100'

# Database location (inside container)
docker exec semaphore ls -lh /var/lib/semaphore/database.boltdb
```

### Resource Usage:
```bash
# Container stats
ssh root@192.168.1.20 'docker stats semaphore --no-stream'
```

---

## 🔄 Maintenance Commands

### Restart Semaphore:
```bash
ssh root@192.168.1.20 'cd /root/semaphore && docker compose restart'
```

### Stop Semaphore:
```bash
ssh root@192.168.1.20 'cd /root/semaphore && docker compose down'
```

### Start Semaphore:
```bash
ssh root@192.168.1.20 'cd /root/semaphore && docker compose up -d'
```

### Update Semaphore:
```bash
ssh root@192.168.1.20 'cd /root/semaphore && docker compose pull && docker compose up -d'
```

### Backup Database:
```bash
# Backup BoltDB database
ssh root@192.168.1.20 'docker exec semaphore tar czf /tmp/semaphore-backup.tar.gz /var/lib/semaphore'
ssh root@192.168.1.20 'docker cp semaphore:/tmp/semaphore-backup.tar.gz /root/backups/'
```

---

## 🚨 Troubleshooting

### Container Won't Start:
```bash
# Check logs for errors
ssh root@192.168.1.20 'docker logs semaphore'

# Check port conflicts
ssh root@192.168.1.20 'netstat -tlnp | grep :3001'

# Verify environment variables
ssh root@192.168.1.20 'docker exec semaphore env | grep SEMAPHORE'
```

### Can't Login:
```bash
# Reset admin password
ssh root@192.168.1.20
cd /root/semaphore
docker compose down
docker compose up -d
# Password will reset to value in .env file
```

### Playbooks Fail to Execute:
```bash
# Test SSH from Semaphore to Ansible container
ssh root@192.168.1.20 'docker exec semaphore ssh root@192.168.1.11 "ansible --version"'

# Check SSH key
ssh root@192.168.1.20 'docker exec semaphore cat /root/.ssh/id_ed25519.pub'

# Test Ansible connectivity
ssh root@192.168.1.20 'docker exec semaphore ssh root@192.168.1.11 "ansible mail-server -m ping"'
```

### WebSocket Connection Issues (Live Output Not Working):
- Verify NPM proxy has WebSocket support enabled
- Check browser console for WebSocket errors
- Ensure firewall allows WebSocket connections

---

## 📈 Integration with Existing Cron Jobs

The existing cron jobs on PCT-110 will continue to run independently. Semaphore provides:

1. **Manual Execution**: Run playbooks on-demand via web UI
2. **Monitoring**: View execution history and logs
3. **Team Access**: Multiple users can trigger/monitor maintenance
4. **Scheduling (Optional)**: Can replace cron jobs with Semaphore schedules

**Recommendation**: Keep cron jobs for automation, use Semaphore for manual runs and monitoring.

---

## 🎯 Next Steps

### Immediate:
- [ ] **Change default passwords** (see step 1 above)
- [ ] **Configure SSH access** to PCT-110 (see step 2 above)
- [ ] **Test login** at http://192.168.1.20:3001
- [ ] **Create first project** and test playbook execution

### Short-term:
- [ ] **Setup NPM proxy** for https://semaphore.acmea.tech (see step 3 above)
- [ ] **Configure all playbook templates** (see Project Configuration section)
- [ ] **Test each playbook** from Semaphore UI
- [ ] **Create user accounts** for team access

### Long-term:
- [ ] **Add email notifications** for failed runs
- [ ] **Create custom dashboards** for maintenance history
- [ ] **Integrate with Uptime Kuma** for alerting
- [ ] **Document team workflows** for Semaphore usage

---

## 📞 Support Resources

### Official Documentation:
- **Semaphore Docs**: https://docs.semaphoreui.com/
- **GitHub**: https://github.com/semaphoreui/semaphore

### Local Resources:
- **Ansible Playbooks**: `/etc/ansible/playbooks/` on PCT-110
- **Playbook Docs**: `/etc/ansible/playbooks/README.md`
- **Cron Schedule**: `/Users/jm/Codebase/internet-control/ansible/CRON-SCHEDULED.md`

---

## ⚠️ Security Notes

1. **Password Management**:
   - Change default passwords immediately
   - Use strong, unique passwords (24+ characters)
   - Store credentials in password manager

2. **Access Control**:
   - Restrict Semaphore to internal network or VPN
   - Use NPM access lists for external access
   - Enable HTTPS for all external access

3. **SSH Keys**:
   - Use ed25519 keys (stronger than RSA)
   - Protect private keys with passphrases
   - Rotate keys periodically

4. **Database Backups**:
   - Backup BoltDB regularly
   - Test restore procedures
   - Store backups securely off-site

---

## 📊 Deployment Summary

**Deployment Status**: ✅ **SUCCESSFUL**

**What Was Deployed**:
- ✅ Semaphore UI v2.16.31 on Docker VM
- ✅ BoltDB database for persistent storage
- ✅ Health monitoring configured
- ✅ Persistent volumes for data and SSH keys
- ✅ Port 3001 (internal access working)

**What Needs Configuration**:
- ⚠️ Change default admin password
- ⚠️ Setup SSH keys for Ansible container access
- ⚠️ Create Semaphore project with playbooks
- ⚠️ Configure NPM proxy for external access

**Timeline**:
- **Deployment**: October 9, 2025 (completed)
- **Configuration**: To be completed
- **Go-live**: After NPM proxy setup

---

*Semaphore deployment completed successfully. Ready for initial configuration and testing.*
