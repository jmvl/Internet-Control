# Uptime Kuma Password Reset Guide

**Instance:** http://192.168.1.9:3010
**Container:** uptime-kuma (4b6f8ae23bc7)
**Data Location:** /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data
**Created:** 2025-10-17

---

## Problem

Forgot the username/password for Uptime Kuma web interface.

## Solution Options

### Option 1: Reset via Database (RECOMMENDED)

Uptime Kuma stores credentials in a SQLite database. We can reset the password by clearing the user table, which forces the setup wizard to appear on next login.

#### Step 1: Stop the Container
```bash
ssh root@192.168.1.9 'docker stop uptime-kuma'
```

#### Step 2: Backup the Database
```bash
ssh root@192.168.1.9 'cp /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db.backup-$(date +%Y%m%d)'
```

#### Step 3: Reset User Table
```bash
ssh root@192.168.1.9 'sqlite3 /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db "DELETE FROM user;"'
```

#### Step 4: Restart Container
```bash
ssh root@192.168.1.9 'docker start uptime-kuma'
```

#### Step 5: Complete Setup Wizard
1. Open: http://192.168.1.9:3010
2. You'll see the initial setup wizard
3. Create new admin account with username/password
4. Save credentials in password manager

---

### Option 2: Reset via Docker Exec (Alternative)

If you prefer to work inside the container:

#### Step 1: Access Container Shell
```bash
ssh root@192.168.1.9 'docker exec -it uptime-kuma sh'
```

#### Step 2: Install SQLite (if needed)
```bash
apk add sqlite
```

#### Step 3: Reset User Table
```bash
sqlite3 /app/data/kuma.db "DELETE FROM user;"
```

#### Step 4: Exit and Restart
```bash
exit
docker restart uptime-kuma
```

---

### Option 3: Complete Data Reset (NUCLEAR OPTION)

**WARNING:** This will delete ALL monitors, settings, and historical data.

```bash
# Backup everything first
ssh root@192.168.1.9 'cp -r /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data.backup-$(date +%Y%m%d)'

# Stop container
ssh root@192.168.1.9 'docker stop uptime-kuma'

# Remove data
ssh root@192.168.1.9 'rm -rf /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/*'

# Start container (will create fresh database)
ssh root@192.168.1.9 'docker start uptime-kuma'
```

After this, you'll need to:
- Reconfigure all monitors
- Set up notification channels
- Recreate any status pages

**Only use this if you don't care about losing monitoring history.**

---

## Verification

After password reset:

```bash
# Check container is running
ssh root@192.168.1.9 'docker ps | grep uptime-kuma'

# Check logs for any errors
ssh root@192.168.1.9 'docker logs uptime-kuma --tail 50'

# Access web interface
curl -I http://192.168.1.9:3010
```

---

## Prevention

To avoid this in the future:

### 1. Save Credentials in Password Manager
- Store username/password immediately after setup
- Use strong, unique password

### 2. Enable API Token Access
After logging in, generate an API token for programmatic access:

1. Settings → API Keys
2. Generate new key
3. Store securely
4. Use with setup-uptime-kuma.py script

### 3. Document in Infrastructure DB
```bash
# Add credentials to secure vault or documentation
echo "Uptime Kuma Admin: [username] / [password]" >> /path/to/secure/credentials.txt
```

---

## Using API Token for Automated Setup

Once you have API token, you can use it with the setup script:

```bash
cd /Users/jm/Codebase/internet-control/infrastructure-db/monitoring

# Install dependency
pip3 install uptime-kuma-api

# Run with token (no password needed)
python3 setup-uptime-kuma.py \
  --url http://192.168.1.9:3010 \
  --token YOUR_API_TOKEN \
  --discord-webhook YOUR_WEBHOOK_URL
```

---

## Database Structure Reference

Uptime Kuma SQLite database (`kuma.db`) contains:

- **user** - User accounts and passwords (bcrypt hashed)
- **monitor** - All configured monitors
- **heartbeat** - Historical uptime data
- **notification** - Notification channel configurations
- **incident** - Downtime incident records

Only the `user` table needs to be cleared for password reset.

---

## Troubleshooting

### Container Won't Start After Reset
```bash
# Check logs
ssh root@192.168.1.9 'docker logs uptime-kuma'

# Restore backup
ssh root@192.168.1.9 'cp /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db.backup-* /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db'
ssh root@192.168.1.9 'docker restart uptime-kuma'
```

### Setup Wizard Doesn't Appear
```bash
# Verify user table is empty
ssh root@192.168.1.9 'sqlite3 /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db "SELECT COUNT(*) FROM user;"'
# Should return: 0

# Clear browser cache and cookies for http://192.168.1.9:3010
# Try incognito/private browsing mode
```

### Database Locked Error
```bash
# Make sure container is stopped
ssh root@192.168.1.9 'docker stop uptime-kuma'

# Wait 10 seconds
sleep 10

# Try reset again
```

---

## Quick Reference Commands

```bash
# Quick password reset (all-in-one)
ssh root@192.168.1.9 '
  docker stop uptime-kuma && \
  cp /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db \
     /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db.backup && \
  sqlite3 /srv/docker-volume/volumes/uptime-kuma_uptime-kuma/_data/kuma.db "DELETE FROM user;" && \
  docker start uptime-kuma
'

# Then open http://192.168.1.9:3010 and complete setup wizard
```

---

## Related Documentation

- **Uptime Kuma Setup Guide:** `/infrastructure-db/monitoring/UPTIME-KUMA-SETUP.md`
- **Automated Monitor Setup:** `/infrastructure-db/monitoring/setup-uptime-kuma.py`
- **Infrastructure Overview:** `/docs/infrastructure.md`

---

**Created:** 2025-10-17
**Status:** Ready to use
**Priority:** Documentation for future reference
