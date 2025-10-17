# Semaphore Setup Guide - Quick Reference

**Last Updated**: October 9, 2025
**Semaphore URL**: http://192.168.1.20:3001
**Login**: admin / admin123

---

## 🔐 SSH Private Key (Copy This)

When setting up the SSH Key in Semaphore, use this private key:

```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAoXspgHQrzbzK2LmGmJSsPHSNhlloEQ66mwsG791XDlAAAAJjXBDWg1wQ1
oAAAAAtzc2gtZWQyNTUxOQAAACAoXspgHQrzbzK2LmGmJSsPHSNhlloEQ66mwsG791XDlA
AAAECkFuJezAEoNeZEd3BBn1N75EsnVywGx472wH3lHZLtgSheymAdCvNvMrYuYaYlKw8d
I2GWWgRDrqbCwbv3VcOUAAAAEXNlbWFwaG9yZUBhbnNpYmxlAQIDBA==
-----END OPENSSH PRIVATE KEY-----
```

**Public Key Fingerprint**: `SHA256:q+WQS+HhZMrS83OTaIyYIe9gjJGFc0jqtAZS8/ZsbKE`

---

## 📋 Step-by-Step Setup

### Step 1: Create Project

1. Login to http://192.168.1.20:3001 with `admin` / `admin123`
2. Click **CREATE** (or **CREATE DEMO PROJECT** to see examples first)
3. Fill in:
   - **Project Name**: `Infrastructure Maintenance`
   - **Max parallel tasks**: `1` (prevents concurrent playbook conflicts)
   - Leave other fields empty
4. Click **CREATE**

### Step 2: Add SSH Key

1. In your new project, go to **Key Store** (left sidebar)
2. Click **New Key** (top right)
3. Fill in:
   - **Name**: `Proxmox Host`
   - **Type**: `SSH Key`
   - **Login**: `root`
   - **Private Key**: Paste the private key from above
4. Click **Create**

### Step 3: Create Inventory

1. Go to **Inventory** (left sidebar)
2. Click **New Inventory**
3. Fill in:
   - **Name**: `Production Servers`
   - **User Credentials**: Select `Proxmox Host`
   - **Type**: `Static`
   - **Inventory**:
   ```ini
   [mail-server]
   192.168.1.30

   [jira-server]
   192.168.1.22

   [confluence-server]
   192.168.1.21
   ```
4. Click **Create**

**Alternative YAML Format** (if you prefer YAML):
```yaml
all:
  children:
    mail_server:
      hosts:
        hestia:
          ansible_host: 192.168.1.30
    jira_server:
      hosts:
        jira:
          ansible_host: 192.168.1.22
    confluence_server:
      hosts:
        confluence:
          ansible_host: 192.168.1.21
```

### Step 4: Create Repository

**IMPORTANT**: Since Semaphore runs in Docker and the playbooks are on the Ansible container, we'll use SSH to access them.

1. Go to **Repositories** (left sidebar)
2. Click **New Repository**
3. Fill in:
   - **Name**: `Ansible Playbooks`
   - **URL**: `ssh://root@192.168.1.8/root/playbooks-proxy`
   - **Branch**: `main` (leave empty if no git)
   - **SSH Key**: Select `Proxmox Host`

**Alternative Setup** (Recommended): Create a wrapper script approach.

Since the playbooks are in a Proxmox container, we need to use a special setup:

#### Option A: Mount Playbooks via NFS/SSHFS (Recommended)

On Docker VM:
```bash
# Install sshfs
apt-get update && apt-get install -y sshfs

# Create mount point
mkdir -p /mnt/ansible-playbooks

# Mount Ansible container's playbook directory
sshfs root@192.168.1.8:/var/lib/lxc/110/rootfs/etc/ansible/playbooks /mnt/ansible-playbooks -o allow_other,default_permissions

# Make it persistent (add to /etc/fstab)
echo "root@192.168.1.8:/var/lib/lxc/110/rootfs/etc/ansible/playbooks /mnt/ansible-playbooks fuse.sshfs defaults,_netdev,allow_other 0 0" >> /etc/fstab
```

Then in Semaphore:
```
Repository → New Repository
- Name: Ansible Playbooks
- Type: Local
- Path: /mnt/ansible-playbooks
```

#### Option B: Git Repository (Best Practice)

Convert your playbooks to a Git repository:

```bash
# On Ansible container (via Proxmox)
ssh root@pve2 'pct exec 110 -- bash' << 'EOF'
cd /etc/ansible/playbooks
git init
git add .
git commit -m "Initial commit: Ansible playbooks"

# Push to a private Git server (Gitea, GitHub, GitLab, etc.)
git remote add origin git@your-git-server:ansible/playbooks.git
git push -u origin main
EOF
```

Then in Semaphore:
```
Repository → New Repository
- Name: Ansible Playbooks
- URL: git@your-git-server:ansible/playbooks.git
- Branch: main
- SSH Key: Proxmox Host (or create new deploy key)
```

#### Option C: Simple Script Wrapper (Quick & Dirty)

Create wrapper scripts on the Docker VM:

```bash
# On Docker VM
ssh root@192.168.1.20

mkdir -p /opt/ansible-wrappers
cat > /opt/ansible-wrappers/hestia-maintenance.sh << 'EOF'
#!/bin/bash
# Wrapper to execute HestiaCP maintenance via Proxmox
ssh root@192.168.1.8 "pct exec 110 -- ansible-playbook /etc/ansible/playbooks/hestia-mail-maintenance.yml $@"
EOF

cat > /opt/ansible-wrappers/jira-maintenance.sh << 'EOF'
#!/bin/bash
# Wrapper to execute JIRA maintenance via Proxmox
ssh root@192.168.1.8 "pct exec 110 -- ansible-playbook /etc/ansible/playbooks/jira-maintenance.yml $@"
EOF

cat > /opt/ansible-wrappers/confluence-maintenance.sh << 'EOF'
#!/bin/bash
# Wrapper to execute Confluence maintenance via Proxmox
ssh root@192.168.1.8 "pct exec 110 -- ansible-playbook /etc/ansible/playbooks/confluence-maintenance.yml $@"
EOF

chmod +x /opt/ansible-wrappers/*.sh
```

Then use **Task Templates** with **Bash** task type instead of Ansible.

---

## 🎯 Step 5: Create Task Templates

### Template 1: HestiaCP Daily Log Cleanup

1. Go to **Task Templates** (left sidebar)
2. Click **New Template**
3. Fill in:
   - **Name**: `HestiaCP - Daily Log Cleanup`
   - **Playbook Filename**: `hestia-mail-maintenance.yml`
   - **Inventory**: Select `Production Servers`
   - **Repository**: Select `Ansible Playbooks`
   - **Environment**: None (leave empty)
   - **Extra CLI Arguments**: `--tags logs`
   - **Task Type**: `Ansible Playbook`
   - **Start Version**: `main` (or leave empty)

### Template 2: HestiaCP Full Maintenance

```
Name: HestiaCP - Full Maintenance
Playbook: hestia-mail-maintenance.yml
Inventory: Production Servers
Repository: Ansible Playbooks
Extra CLI Arguments: (leave empty for full run)
```

### Template 3: JIRA Full Maintenance

```
Name: JIRA - Full Maintenance
Playbook: jira-maintenance.yml
Inventory: Production Servers
Repository: Ansible Playbooks
```

### Template 4: Confluence Full Maintenance

```
Name: Confluence - Full Maintenance
Playbook: confluence-maintenance.yml
Inventory: Production Servers
Repository: Ansible Playbooks
```

### Template 5: HestiaCP Comprehensive (Monthly)

```
Name: HestiaCP - Comprehensive Maintenance
Playbook: hestia-mail-maintenance.yml
Inventory: Production Servers
Repository: Ansible Playbooks
Extra CLI Arguments: --extra-vars "comprehensive_maintenance=true"
```

### Template 6: JIRA Comprehensive (Monthly)

```
Name: JIRA - Comprehensive Maintenance
Playbook: jira-maintenance.yml
Inventory: Production Servers
Repository: Ansible Playbooks
Extra CLI Arguments: --extra-vars "comprehensive_maintenance=true"
```

### Template 7: Confluence Comprehensive (Monthly)

```
Name: Confluence - Comprehensive Maintenance
Playbook: confluence-maintenance.yml
Inventory: Production Servers
Repository: Ansible Playbooks
Extra CLI Arguments: --extra-vars "comprehensive_maintenance=true"
```

---

## 🔄 Step 6: Run Your First Task

1. Go to **Task Templates**
2. Click on **HestiaCP - Daily Log Cleanup**
3. Click **Run**
4. Watch the live output!

---

## 📅 Step 7: Schedule Automated Runs (Optional)

Semaphore supports scheduling tasks to run automatically:

1. Go to **Task Templates**
2. Select a template (e.g., "HestiaCP - Daily Log Cleanup")
3. Click **Edit**
4. Scroll to **Cron Schedule**
5. Enter cron expression:
   - Daily 2 AM: `0 2 * * *`
   - Weekly Sunday 4 AM: `0 4 * * 0`
   - First Sunday 4 AM: `0 4 1 * *`

**Recommended Schedules**:
```
HestiaCP Daily Log Cleanup:    0 2 * * *    (Daily 2 AM)
HestiaCP Full Maintenance:     0 4 * * 0    (Sunday 4 AM)
JIRA Full Maintenance:         0 5 * * 0    (Sunday 5 AM)
Confluence Full Maintenance:   0 6 * * 0    (Sunday 6 AM)
HestiaCP Comprehensive:        0 4 1 * *    (1st Sunday 4 AM)
JIRA Comprehensive:            0 5 1 * *    (1st Sunday 5 AM)
Confluence Comprehensive:      0 6 1 * *    (1st Sunday 6 AM)
```

**Note**: Keep the existing cron jobs on PCT-110 or migrate them to Semaphore. Don't run both!

---

## 🎨 Customization Options

### Add Email Notifications

1. Go to **Project Settings** → **Integrations**
2. Add **Email** integration
3. Configure SMTP settings
4. Enable notifications for:
   - Task Success
   - Task Failure
   - Task Start

### Add Telegram Notifications

1. Create a Telegram bot via @BotFather
2. Get your Chat ID
3. In Project Settings → Add **Telegram** integration
4. Enter Bot Token and Chat ID
5. Enable notifications

### Create Multi-Step Tasks

You can chain multiple playbooks together:

```
Task Template: Full Infrastructure Maintenance
Type: Build
Steps:
  1. Run HestiaCP maintenance
  2. Run JIRA maintenance
  3. Run Confluence maintenance
```

---

## 🔧 Troubleshooting

### "Repository not found" Error

**Solution**: Use the SSHFS mount approach (Option A) or Git repository (Option B)

### "Permission denied" when running tasks

**Solution**: Verify SSH key is correctly added to Key Store with username `root`

### Tasks stuck in "Running" state

**Solution**:
1. Check container logs: `docker logs semaphore`
2. Verify network connectivity: `docker exec semaphore ssh root@192.168.1.8 "hostname"`
3. Restart Semaphore: `docker compose restart`

### Can't see playbook output

**Solution**: Semaphore shows live output in the Task Details page. Click on the task to see progress.

### Tasks fail with "Ansible not found"

**Solution**: We're using SSH through Proxmox, so Ansible runs on PCT-110. Make sure your playbook execution command is:
```bash
ssh root@192.168.1.8 "pct exec 110 -- ansible-playbook /etc/ansible/playbooks/your-playbook.yml"
```

---

## 📊 Best Practices

### 1. Use Git for Playbooks

Convert your playbooks directory to a Git repository for version control:
- Track changes over time
- Roll back if needed
- Collaborate with team members
- Automatic sync with Semaphore

### 2. Test Before Scheduling

Always run tasks manually first to verify they work correctly before scheduling them.

### 3. Monitor First Week

Keep cron jobs on PCT-110 for the first week while you verify Semaphore works reliably.

### 4. Set Up Notifications

Configure email or Telegram alerts so you know if maintenance fails.

### 5. Regular Backups

Backup Semaphore database regularly:
```bash
ssh root@192.168.1.20 'docker exec semaphore tar czf /tmp/semaphore-backup.tar.gz /var/lib/semaphore'
ssh root@192.168.1.20 'docker cp semaphore:/tmp/semaphore-backup.tar.gz /root/backups/'
```

---

## 🚀 Next Steps

1. ✅ **Login** to Semaphore (http://192.168.1.20:3001)
2. ✅ **Create Project** "Infrastructure Maintenance"
3. ✅ **Add SSH Key** using the private key from this guide
4. ✅ **Create Inventory** with your server IPs
5. ✅ **Setup Repository** (choose Option A, B, or C)
6. ✅ **Create Task Templates** for each playbook
7. ✅ **Test Run** each template manually
8. ⏭️ **Schedule Tasks** or keep using cron on PCT-110
9. ⏭️ **Setup NPM Proxy** for external access
10. ⏭️ **Configure Notifications** for alerts

---

## 🌐 NPM Reverse Proxy Setup (Future)

Once you want external access via https://semaphore.acmea.tech:

1. Open Nginx Proxy Manager
2. Add Proxy Host:
   - Domain: `semaphore.acmea.tech`
   - Scheme: `http`
   - Forward Hostname: `192.168.1.20`
   - Forward Port: `3001`
   - Websockets: **ON** (important!)
   - SSL: Request Let's Encrypt certificate

3. Advanced settings:
```nginx
proxy_read_timeout 3600;
proxy_connect_timeout 3600;
proxy_send_timeout 3600;
```

---

## 📖 Documentation References

- **Semaphore Docs**: https://docs.semaphoreui.com/
- **Ansible Playbooks**: `/etc/ansible/playbooks/README.md` on PCT-110
- **Cron Schedule**: `~/Codebase/internet-control/ansible/CRON-SCHEDULED.md`
- **Deployment Guide**: `~/Codebase/internet-control/docs/ansible/semaphore-deployment.md`

---

**Setup Status**: Ready for configuration
**Support**: Check Semaphore docs or container logs (`docker logs semaphore`)

*Last updated: October 9, 2025*
