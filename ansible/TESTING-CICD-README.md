# Testing & CI/CD Guide

This guide covers the testing framework and CI/CD setup for the Ansible infrastructure automation.

## Quick Reference

| Tool | Purpose | Command |
|------|---------|---------|
| **Molecule** | Automated role testing | `cd roles/hestia && molecule test` |
| **ansible-lint** | Ansible best practices validation | `ansible-lint roles/ playbooks/` |
| **yamllint** | YAML syntax validation | `yamllint roles/ playbooks/` |
| **GitHub Actions** | CI/CD automation | https://github.com/jmvl/internet-control/actions |
| **ARA** | Playbook analytics dashboard | `open http://localhost:8000` |

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Testing Framework](#testing-framework)
3. [CI/CD Workflows](#cicd-workflows)
4. [Development Workflow](#development-workflow)
5. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Install Testing Dependencies

```bash
cd /Users/jm/Codebase/internet-control/ansible

# Install all testing dependencies
pip install -r requirements-testing.txt

# Verify installations
molecule --version
ansible-lint --version
yamllint --version
```

### Docker for Molecule

```bash
# Docker Desktop for Mac
open /Applications/Docker.app

# Or start Docker daemon
sudo systemctl start docker  # Linux
```

---

## Testing Framework

### Molecule Testing

**What it does**: Tests Ansible roles in isolated Docker containers

**Test structure**:
```
roles/hestia/molecule/
├── default/
│   ├── molecule.yml       # Molecule configuration
│   ├── converge.yml       # Playbook to apply role
│   ├── verify.yml         # Verification tests
│   └── requirements.yml   # Test dependencies
└── README.md             # Usage documentation
```

**Quick Start**:
```bash
cd /Users/jm/Codebase/internet-control/ansible/roles/hestia

# Run full test suite
molecule test

# Development workflow
molecule create     # Create test instance
molecule converge   # Apply role
molecule idempotence  # Test idempotency
molecule verify     # Run verification tests
molecule login      # SSH into test instance
molecule destroy    # Clean up
```

**What gets tested**:
- ✅ Configuration files deployed correctly
- ✅ Scripts are executable
- ✅ Cron jobs created
- ✅ Services can be restarted
- ✅ Role is idempotent (can be run multiple times safely)

### Linting

**ansible-lint**: Enforces Ansible best practices
```bash
cd /Users/jm/Codebase/internet-control/ansible

# Lint all roles and playbooks
ansible-lint roles/ playbooks/

# Auto-fix some issues
ansible-lint roles/ playbooks/ --fix

# Check specific file
ansible-lint roles/hestia/tasks/main.yml
```

**yamllint**: Validates YAML syntax
```bash
# Lint all YAML files
yamllint roles/ playbooks/ group_vars/ host_vars/

# Check specific file
yamllint ansible.cfg
```

**Common linting issues**:
| Issue | Fix |
|-------|-----|
| `line too long` | Break long lines with `>` or `|` |
| `syntax error` | Check YAML indentation (use spaces, not tabs) |
| `command instead of module` | Replace `command:` with appropriate Ansible module |
| `no handler` | Add `notify:` directive to trigger handler |

---

## CI/CD Workflows

### GitHub Actions Overview

The repository has 3 automated workflows:

| Workflow | Triggers | Purpose |
|----------|----------|---------|
| **ansible-lint.yml** | Push, PR | Linting and validation |
| **ansible-test.yml** | Push, PR, Schedule | Molecule testing |
| **hestia-maintenance.yml** | Schedule (Sundays 4 AM), Manual | Run maintenance playbooks |

### Workflow 1: ansible-lint.yml

**What it does**:
- Runs `ansible-lint` on all roles and playbooks
- Runs `yamllint` on all YAML files
- Checks playbook syntax
- Validates vault encryption
- Scans for hardcoded secrets

**Triggers**:
- Push to `main`, `master`, or `develop` branches
- Pull requests to `main`, `master`, or `develop`
- Changes to `ansible/**` or workflow file

**Status badges** (add to README.md):
```markdown
![Ansible Lint](https://github.com/jmvl/internet-control/workflows/Ansible%20Lint/badge.svg)
```

### Workflow 2: ansible-test.yml

**What it does**:
- Runs Molecule tests in GitHub Actions
- Tests Hestia role in Docker container
- Verifies idempotency
- Uploads test results as artifacts

**Triggers**:
- Push to `main`, `master`, or `develop` branches
- Pull requests to `main`, `master`, or `develop`
- Scheduled: Every Sunday at 2 AM UTC
- Manual trigger from Actions UI

**Artifacts**:
- Test results retained for 7 days
- Download from Actions run page

### Workflow 3: hestia-maintenance.yml

**What it does**:
- Runs Hestia mail server maintenance playbook
- Performs health checks after maintenance
- Verifies service status (Dovecot, Exim)
- Checks mail queue
- Creates maintenance report

**Triggers**:
- Scheduled: Every Sunday at 4 AM UTC (matches cron job)
- Manual trigger with options:
  - Select playbook to run
  - Specify tags to run

**GitHub Secrets Required**:
```bash
# SSH key for connecting to servers
ANSIBLE_SSH_KEY

# Vault password for decrypting secrets
ANSIBLE_VAULT_PASSWORD
```

**Setup**:
1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add secrets:
   ```
   Name: ANSIBLE_SSH_KEY
   Value: <output of: cat ~/.ssh/id_rsa>

   Name: ANSIBLE_VAULT_PASSWORD
   Value: <output of: cat ~/.ansible-vault-password>
   ```

---

## Development Workflow

### Making Changes to Roles

```bash
# 1. Create feature branch
git checkout -b feature/update-hestia-role

# 2. Make changes to role
cd /Users/jm/Codebase/internet-control/ansible/roles/hestia
# Edit tasks, templates, defaults, etc.

# 3. Test locally with Molecule
molecule test

# 4. If tests pass, commit changes
git add roles/hestia/
git commit -m "feat: update Hestia role with new feature"

# 5. Push to remote
git push origin feature/update-hestia-role

# 6. Create pull request
# → GitHub Actions automatically run tests
# → Review results in PR checks tab

# 7. After approval, merge to main
# → Tests run again on main branch
```

### Making Changes to Playbooks

```bash
# 1. Edit playbook
cd /Users/jm/Codebase/internet-control/ansible
vim playbooks/hestia-mail-maintenance-refactored.yml

# 2. Check syntax
ansible-playbook playbooks/hestia-mail-maintenance-refactored.yml --syntax-check

# 3. Lint
ansible-lint playbooks/hestia-mail-maintenance-refactored.yml

# 4. Commit and push
git add playbooks/
git commit -m "fix: update Hestia maintenance playbook"
git push origin main

# 5. GitHub Actions automatically validate
```

### Adding Molecule Tests for New Roles

```bash
# 1. Create Molecule directory
cd /Users/jm/Codebase/internet-control/ansible/roles/new-role
mkdir -p molecule/default

# 2. Create molecule.yml
cat > molecule/default/molecule.yml <<'EOF'
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: debian12-test
    image: debian:12
    pre_build_image: true
provisioner:
  name: ansible
verifier:
  name: ansible
EOF

# 3. Create converge.yml
cat > molecule/default/converge.yml <<'EOF'
---
- name: Converge
  hosts: all
  become: true
  roles:
    - role: new-role
EOF

# 4. Create verify.yml
cat > molecule/default/verify.yml <<'EOF'
---
- name: Verify
  hosts: all
  tasks:
    - name: Check if role was applied
      stat:
        path: /etc/new-role-config
      register: config
      failed_when: not config.stat.exists
EOF

# 5. Test
molecule test
```

---

## Troubleshooting

### Molecule Issues

**"Docker daemon not running"**:
```bash
# Start Docker Desktop or Docker daemon
sudo systemctl start docker  # Linux
open /Applications/Docker.app  # Mac
```

**"Idempotence test failed"**:
```bash
# Check what changed on second run
cd roles/hestia
molecule create
molecule converge
molecule converge  # Run again to see what changes
molecule login     # SSH in to debug
molecule destroy
```

**Common causes**:
- Tasks using `command:` without proper conditionals
- Missing `changed_when: false` on read-only tasks
- Tasks that always report as changed

**"Privileged mode required"**:
- Molecule needs privileged mode for systemd
- Already configured in `molecule.yml`
- If issue persists, check Docker is running correctly

### Linting Issues

**ansible-lint errors**:
```bash
# Get detailed error information
ansible-lint roles/hestia/tasks/main.yml -v

# Auto-fix some issues
ansible-lint roles/ playbooks/ --fix

# Ignore specific rules (if necessary)
# Create .ansible-lint file
cat > .ansible-lint <<'EOF'
skip_list:
  - package-latest  # Allow latest package installations
  - no-handler  # Skip handler checks
EOF
```

**yamllint errors**:
```bash
# Fix indentation issues
yamllint roles/hestia/ -f parsable

# Common fixes:
# - Use spaces, not tabs
# - Keep line length under 120 characters
# - Add 2 spaces for list indentation
```

### GitHub Actions Failures

**"Module 'ara' not found"**:
- ARA is optional, error can be ignored
- Or install ARA: `pip install ara[server]`

**"Vault encryption check failed"**:
```bash
# Re-encrypt vault file
cd /Users/jm/Codebase/internet-control/ansible
ansible-vault encrypt group_vars/all/vault.yml --vault-password-file scripts/vault-password.sh
```

**"SSH connection failed"** (in maintenance workflow):
- Check GitHub secrets are configured correctly
- Verify SSH key is valid
- Test SSH connection manually:
  ```bash
  ssh -i ~/.ssh/id_rsa root@192.168.1.30
  ```

### CI/CD Pipeline Stuck

**Cancel workflow**:
1. Go to Actions tab
2. Click on running workflow
3. Click "Cancel run"

**Re-run workflow**:
1. Go to Actions tab
2. Click on failed workflow
3. Click "Re-run all jobs"

---

## Best Practices

### Testing

1. **Test locally first**: Run `molecule test` before pushing
2. **Test idempotency**: Ensure roles can be run multiple times safely
3. **Test failure scenarios**: Verify role handles errors correctly
4. **Keep tests fast**: Use `molecule converge` for rapid iteration

### Commit Messages

Use conventional commit format:
```
feat: add new feature
fix: fix bug in role
docs: update documentation
test: add molecule tests
refactor: improve code structure
```

### Pull Requests

1. **Descriptive title**: Summarize changes
2. **Detailed description**: Explain why changes are needed
3. **Link issues**: Reference related issues or docs
4. **Check status**: Ensure all CI checks pass before requesting review

### Branching

```
main (protected)
├── feature/add-monitoring
├── fix/dovecot-cache
└── refactor/cleanup-tasks
```

---

## Advanced Topics

### Custom Molecule Scenarios

Create multiple test scenarios:

```bash
cd roles/hestia

# Scenario 1: Default (Debian 12)
molecule/test/default/

# Scenario 2: Minimal (Ubuntu 22.04)
mkdir -p molecule/minimal
# Create molecule.yml, converge.yml, verify.yml

# Test specific scenario
molecule test --scenario-name minimal
```

### Parallel Testing

Run tests in parallel (faster for multiple roles):

```bash
# Test all roles in parallel
find roles/ -name "molecule.yml" -execdir molecule test \; &
```

### Test Coverage

Track test coverage:

```bash
# List all tasks
cd roles/hestia
grep -r "name:" tasks/ | wc -l

# Count verified tests
grep -c "failed_when" molecule/default/verify.yml
```

---

## Resources

### Documentation
- [Molecule Documentation](https://molecule.readthedocs.io/)
- [Ansible Lint Rules](https://ansible-lint.readthedocs.io/)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [ARA Documentation](https://ara.readthedocs.io/)

### Internal Guides
- `/ansible/roles/hestia/molecule/README.md` - Molecule usage
- `/ansible/ARA-SETUP.md` - ARA setup guide
- `/ansible/VAULT-README.md` - Vault usage

---

## Summary

✅ **Testing Framework**: Molecule for automated role testing
✅ **Linting**: ansible-lint and yamllint for code quality
✅ **CI/CD**: GitHub Actions for automated testing and deployment
✅ **Scheduled Maintenance**: Automated with redundancy (cron + GitHub Actions)
✅ **Analytics**: ARA for playbook insights (optional)

**Key Commands**:
```bash
# Test locally
molecule test

# Lint code
ansible-lint roles/ playbooks/

# View CI/CD status
open https://github.com/jmvl/internet-control/actions

# View ARA dashboard (optional)
open http://localhost:8000
```

---

**Last Updated**: 2026-01-08
**Status**: ✅ Phase 3 Complete
