# ARA (Ansible Runner Analysis) Setup Guide

**ARA** provides a web interface for viewing Ansible playbook results, statistics, and performance data. Think of it as a dashboard for your Ansible automation.

## What ARA Does

- Records every playbook run with detailed results
- Shows task execution time and performance metrics
- Displays play and task statistics (ok, changed, failed, skipped)
- Provides searchable playbook history
- Offers comparison between playbook runs
- Tracks host-level statistics and facts

## Installation

### Step 1: Install ARA

```bash
cd /Users/jm/Codebase/internet-control/ansible

# Install ARA server and callback plugin
pip install ara[server]

# Verify installation
ara-manage version
```

### Step 2: Initialize ARA Database

```bash
# Run database migrations
ara-manage migrate

# Create an ARA user (optional, for authentication)
ara-manage createsuperuser
```

### Step 3: Enable ARA Callback in ansible.cfg

Edit `ansible.cfg` and uncomment the ARA callback:

```ini
# In [defaults] section, update callback_whitelist:
callback_whitelist = profile_tasks,timer,ara_default
```

### Step 4: Start ARA Server

```bash
# Option 1: Start in foreground (for testing)
ara-manage runserver

# Option 2: Start in background (recommended)
nohup ara-manage runserver > /tmp/ara-server.log 2>&1 &

# Option 3: Use systemd service (production)
sudo tee /etc/systemd/system/ara-server.service > /dev/null <<EOF
[Unit]
Description=ARA Ansible Runner Analysis Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/Users/jm/Codebase/internet-control/ansible
ExecStart=$(which ara-manage) runserver 127.0.0.1:8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ara-server
sudo systemctl start ara-server
```

### Step 5: Access ARA Web UI

Open your browser:
- **Local**: http://localhost:8000
- **Remote**: http://your-server-ip:8000

## Usage

### Running Playbooks with ARA

Once ARA is enabled, all playbooks are automatically recorded:

```bash
# Run any playbook - it will be recorded in ARA
ansible-playbook playbooks/hestia-mail-maintenance-refactored.yml

# View the results in the ARA web UI
open http://localhost:8000
```

### ARA Web Interface Features

**Dashboard** (`http://localhost:8000`):
- Overview of recent playbook runs
- Quick statistics (total plays, tasks, hosts)
- Performance metrics

**Playbooks** (`http://localhost:8000/playbooks`):
- List of all recorded playbook runs
- Filter by status, date, labels
- Compare playbook runs

**Hosts** (`http://localhost:8000/hosts`):
- Statistics per host
- Fact history
- Task results per host

**Reports** (`http://localhost:8000/reports`):
- Summary statistics
- Failed tasks overview
- Performance analysis

### Example: Compare Playbook Runs

1. Navigate to http://localhost:8000/playbooks
2. Select two playbook runs (checkboxes)
3. Click "Compare"
4. View side-by-side comparison of:
   - Task execution time
   - Changed/failed/skipped tasks
   - Host results

### Example: View Task Performance

1. Navigate to http://localhost:8000/playbooks
2. Click on a playbook run
3. See task execution time for each task
4. Identify slow tasks for optimization

## Advanced Configuration

### Persistent Database (SQLite vs PostgreSQL)

**Default (SQLite)**:
```bash
# ARA uses SQLite by default at ~/.ara/ansible.sqlite
# No configuration needed
```

**PostgreSQL (Production)**:
```bash
# Install PostgreSQL
sudo apt install postgresql python3-psycopg2

# Create database
sudo -u postgres psql
CREATE DATABASE ara;
CREATE USER ara WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE ara TO ara;
\q

# Configure ARA to use PostgreSQL
export ARA_DATABASE_ENGINE=django.db.backends.postgresql
export ARA_DATABASE_NAME=ara
export ARA_DATABASE_USER=ara
export ARA_DATABASE_PASSWORD=your_password
export ARA_DATABASE_HOST=localhost
export ARA_DATABASE_PORT=5432

# Run migrations
ara-manage migrate
```

### Authentication

Enable authentication for the ARA web UI:

```bash
# Create admin user
ara-manage createsuperuser

# Update ansible.cfg with authentication
[callback_ara]
api_username = your_username
api_password = your_password
```

### Custom Labels

Add labels to playbook runs for better organization:

```bash
# Label playbook runs
ansible-playbook playbooks/hestia-mail-maintenance-refactored.yml \
  --extra-vars "ara_playbook_labels=mail,weekly,production"
```

### Ignoring Sensitive Data

Prevent ARA from recording sensitive data:

```ini
[callback_ara]
ignored_facts = ansible_env,password,secret,token
ignored_arguments = vault_password_file,extra_vars
```

## Integrating with CI/CD

### GitHub Actions with ARA

Add ARA recording to your CI/CD pipeline:

```yaml
- name: Install ARA
  run: pip install ara[server]

- name: Initialize ARA database
  run: |
    ara-manage migrate
    ara-manage runserver > /tmp/ara.log 2>&1 &
    sleep 5  # Wait for server to start

- name: Run playbook with ARA recording
  run: ansible-playbook playbooks/test.yml

- name: Upload ARA results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: ara-results
    path: ~/.ara/ansible.sqlite
```

## Troubleshooting

### "Module 'ara' not found"

```bash
# Ensure ARA is installed
pip install ara[server]

# Verify installation
python -c "import ara; print(ara.__version__)"
```

### "Database is locked"

```bash
# Stop any running ARA servers
pkill -f "ara-manage runserver"

# Remove lock file
rm -f ~/.ara/ansible.sqlite-wal
```

### "Playbook not recorded in ARA"

1. Check callback is enabled:
   ```bash
   ansible-config dump | grep CALLBACK
   ```

2. Verify ARA server is running:
   ```bash
   ps aux | grep ara-manage
   ```

3. Check ARA logs:
   ```bash
   tail -f /tmp/ara-server.log
   ```

### Performance Issues

For large playbooks, ARA can slow down execution:

```ini
[callback_ara]
# Compress playbook data
compression_level = 6

# Limit fact recording
ignored_facts = ansible_env,ansible_facts

# Disable for very large playbooks
# Comment out 'ara_default' from callback_whitelist
```

## Alternatives to ARA

If ARA doesn't meet your needs, consider:

- **Ansible Tower/AWX**: Full-featured Ansible automation platform
- **Semaphore**: Modern Ansible UI (lightweight Tower alternative)
- **Rundeck**: Job scheduler and runbook automation
- **CI/CD Integration**: Use GitHub Actions, GitLab CI, or Jenkins

## Quick Start Example

```bash
# 1. Install ARA
pip install ara[server]

# 2. Initialize database
ara-manage migrate

# 3. Start server (background)
nohup ara-manage runserver > /tmp/ara.log 2>&1 &

# 4. Enable ARA in ansible.cfg
# Edit ansible.cfg: callback_whitelist = profile_tasks,timer,ara_default

# 5. Run a playbook
cd /Users/jm/Codebase/internet-control/ansible
ansible-playbook playbooks/hestia-mail-maintenance-refactored.yml

# 6. View results
open http://localhost:8000
```

## Resources

- [ARA Documentation](https://ara.readthedocs.io/)
- [ARA GitHub Repository](https://github.com/ansible-community/ara)
- [Ansible Callback Plugins](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/ara_default_callback.html)

---

**Note**: ARA is optional. Your Ansible setup works perfectly without it. ARA just adds visualization and analytics on top of your existing automation.
