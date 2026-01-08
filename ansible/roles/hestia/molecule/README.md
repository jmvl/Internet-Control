# Molecule Testing for Hestia Role

This directory contains Molecule tests for the Hestia mail server role.

## What is Molecule?

Molecule is a testing framework for Ansible roles that:
- Creates disposable Docker containers for testing
- Applies your role to test instances
- Verifies the role works correctly
- Tests idempotency (running the role multiple times produces the same result)
- Cleans up test instances automatically

## Prerequisites

Install Molecule and Docker driver:

```bash
# Install Molecule and plugins
pip install molecule molecule-docker molecule-plugins[docker] ansible-lint yamllint

# Verify installation
molecule --version
```

## Running Tests

### Test Everything (Full Cycle)

This runs the complete test suite:
1. Destroys any existing test instances
2. Creates new test instances
3. Applies the role
4. Tests idempotency
5. Verifies the results
6. Cleans up

```bash
cd /Users/jm/Codebase/internet-control/ansible/roles/hestia
molecule test
```

### Development Workflow

**Create test instance only** (keep it running for debugging):
```bash
molecule create
```

**Apply the role to test instance**:
```bash
molecule converge
```

**Run idempotence check** (role should show no changes on second run):
```bash
molecule idempotence
```

**Verify the role works correctly**:
```bash
molecule verify
```

**Login to test instance for manual debugging**:
```bash
molecule login
```

**Destroy test instances**:
```bash
molecule destroy
```

## Test Scenarios

### default (molecule/default/)

Tests the role with:
- **Platform**: Debian 12 (Docker container)
- **Privileged mode**: Required for systemd services
- **Tests**:
  - Dovecot configuration deployment
  - Exim4 relay configuration
  - Monitoring scripts deployment
  - Cron job creation
  - Log directory setup
  - File permissions

## What Gets Tested

### Configuration Files
- ✅ `/etc/dovecot/conf.d/90-custom.conf` exists and has memory limits
- ✅ `/etc/exim4/smtp_relay.conf` exists with relay configuration
- ✅ Configuration files have correct ownership and permissions

### Monitoring Scripts
- ✅ `/usr/local/bin/dovecot-cache-cleanup.sh` is deployed and executable (0755)
- ✅ `/usr/local/bin/exim-queue-monitor.sh` is deployed and executable (0755)
- ✅ Scripts have correct content (shebang, paths)

### Automation
- ✅ Cron jobs created in `/etc/cron.d/`
- ✅ Cron schedules are correct (Sundays at 3 AM for cleanup)
- ✅ Maintenance log directory exists at `/var/log/hestia-maintenance`

### Idempotency
- ✅ Running the role twice produces no changes
- ✅ Configuration files only updated when content changes
- ✅ Services only restarted when configuration changes

## CI/CD Integration

These tests run automatically in GitHub Actions:
- On every push to `main` or `develop` branches
- On every pull request
- Before deployment to production

## Troubleshooting

### "Docker daemon not running"
```bash
# Start Docker Desktop or start Docker daemon
sudo systemctl start docker
```

### "Privileged mode required"
The test instance requires privileged mode for systemd. This is configured in `molecule.yml`.

### "Idempotence test failed"
This means the role is not idempotent. Common causes:
- Tasks using `command:` or `shell:` without proper conditionals
- Missing `changed_when:` clauses
- Tasks that always report as changed

Fix by adding proper conditionals and `changed_when: false` where appropriate.

### "Verification failed"
Check the verify output to see which test failed:
```bash
molecule verify
```

Login to the instance to debug:
```bash
molecule login
# Inside the container:
ls -la /etc/dovecot/conf.d/
cat /etc/dovecot/conf.d/90-custom.conf
```

## Adding New Tests

To add a new test, edit `molecule/default/verify.yml`:

```yaml
- name: Check if new configuration exists
  stat:
    path: /etc/new/config/file.conf
  register: new_config
  failed_when: not new_config.stat.exists
```

## Test Coverage

Current test coverage:
- ✅ Configuration deployment (Dovecot, Exim)
- ✅ Monitoring scripts deployment
- ✅ Cron job creation
- ✅ File permissions
- ✅ Idempotency

Future additions:
- ⏳ Service status checks (Dovecot, Exim running)
- ⏳ Port binding checks (25, 587, 993)
- ⏳ Configuration validation (exim4 -bt, dovecot -n)
- ⏳ Log rotation verification

## Resources

- [Molecule Documentation](https://molecule.readthedocs.io/)
- [Ansible Testing Guide](https://docs.ansible.com/ansible/latest/user_guide/testing_strategies.html)
- [Testinfra Documentation](https://testinfra.readthedocs.io/)
