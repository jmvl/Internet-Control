# Hestia Mail Server - Ansible Improvement Plan

**Date**: 2026-01-08
**Last Updated**: 2026-01-08 15:00 UTC
**System**: Hestia Mail Server (192.168.1.30)
**Current Ansible Setup**: **Refactored role-based structure** (January 2026)
**Target**: Enterprise-grade Ansible automation with integrated mail fixes

---

## Executive Summary

**Update**: This plan has been revised to acknowledge the **outstanding refactoring work completed in January 2026** (see `ansible/README-REFACTORED.md`). The original plan recommended converting monolithic playbooks to roles - **this has already been accomplished**.

**Current State Assessment**:
- ✅ **Role-based structure implemented** (common + service-specific roles)
- ✅ **95% idempotency achieved** (up from ~30%)
- ✅ **Code reduced by 44%** through DRY principle
- ✅ **Comprehensive tagging system** (15+ tags per playbook)
- ⚠️ **Critical gap**: Today's Dovecot/Exim fixes not yet automated
- ⚠️ **Security gap**: No Ansible Vault for secrets

**Revised Priority**: Focus on integrating today's mail server fixes into the refactored Ansible roles, then implement remaining security and testing enhancements.

**Original research-based recommendations remain valid** for testing (Molecule) and CI/CD (GitHub Actions), but these are lower priority than automating today's critical mail fixes.

---

## Current Setup Analysis

### ✅ ALREADY IMPLEMENTED (January 2026 Refactoring)

**Outstanding work completed** - See `ansible/README-REFACTORED.md` for full details:

| Area | Before | After | Improvement |
|------|--------|-------|-------------|
| **Code Structure** | Monolithic playbooks | Role-based (common + services) | Modular & reusable |
| **Code Duplication** | ~600 lines duplicated | 0 lines | 100% reduction |
| **Total Lines** | 1,600+ lines | 900+ lines | 44% reduction |
| **Idempotency** | ~30% tasks | 95%+ tasks | 3x improvement |
| **Tagging System** | ~5 tags/playbook | ~15 tags/playbook | 3x more granularity |
| **Maintainability** | Low (monolithic) | High (modular roles) | DRY principle |
| **Directory Structure** | Flat files | Standard Ansible hierarchy | Best practice compliant |

**Directory Structure Achieved**:
```
ansible/
├── roles/
│   ├── common/                    # ✅ Shared maintenance tasks
│   │   ├── handlers/main.yml      # ✅ Handlers structure exists
│   │   └── tasks/
│   │       ├── maintenance_init.yml
│   │       ├── system_logs.yml
│   │       ├── system_updates.yml
│   │       └── maintenance_report.yml
│   └── services/
│       ├── hestia/                 # ✅ HestiaCP-specific tasks
│       ├── jira/                   # ✅ JIRA-specific tasks
│       ├── confluence/             # ✅ Confluence-specific tasks
│       └── docker/                 # ✅ Docker VM-specific tasks
├── playbooks/
│   ├── hestia-mail-maintenance-refactored.yml
│   ├── jira-maintenance-refactored.yml
│   ├── confluence-maintenance-refactored.yml
│   └── docker-vm-maintenance-refactored.yml
└── hosts.ini
```

### ⚠️ REMAINING GAPS (Priority Order)

| Priority | Gap | Impact | Effort |
|----------|-----|--------|--------|
| 🔴 **Critical** | **Today's mail fixes not in Ansible** | High | 4h |
| 🔴 **Critical** | **Ansible Vault for secrets** | High | 2h |
| 🟡 **High** | **Handlers not actively used** | Medium | 2h |
| 🟡 **Medium** | **Monitoring scripts not deployed** | Medium | 2h |
| 🟢 **Low** | **Molecule automated testing** | High | 6h |
| 🟢 **Low** | **CI/CD with GitHub Actions** | Medium | 4h |
| 🟢 **Low** | **ARA for playbook reporting** | Low | 2h |

#### Gap Details

**1. CRITICAL: Today's Mail Fixes Not Automated** ⚠️
- **Issue**: Dovecot cache cleanup and Exim4 config fixes from today's intervention are manual only
- **Impact**: Issues can recur without manual intervention
- **What's Missing**:
  - Dovecot cache management tasks (`roles/services/hestia/tasks/dovecot_cache.yml`)
  - Exim4 configuration management (`roles/services/hestia/tasks/exim_config.yml`)
  - Monitoring scripts deployment (`roles/services/hestia/tasks/monitoring.yml`)
  - Template files for configs (`roles/services/hestia/templates/`)
- **Reference**: See `/docs/hestia/hestia-mail-server-maintenance-intervention-2026-01-08.md`

**2. CRITICAL: No Ansible Vault Implementation** 🔐
- **Issue**: Passwords and API tokens in plain text
- **Impact**: Security risk if repository is compromised
- **What's Missing**:
  - `ansible/group_vars/all/vault.yml` (encrypted)
  - Vault password script
  - Integration with existing playbooks

**3. HIGH: Handlers Not Actively Used** 🔄
- **Issue**: Handler files exist but tasks don't use `notify` directives
- **Impact**: Services restart immediately on config changes (inefficient)
- **What's Missing**:
  - Add `notify:` directives to config change tasks
  - Wire up existing handlers for Exim, Dovecot, SpamAssassin

**4. MEDIUM: Monitoring Scripts Not Deployed** 📊
- **Issue**: Scripts created today (`/usr/local/bin/*.sh`) not in Ansible
- **Impact**: Manual deployment required for new servers
- **What's Missing**:
  - Script files in `roles/services/hestia/files/`
  - Cron job configuration in tasks

**5. LOW: No Molecule Testing** 🧪
- **Issue**: Changes tested manually on production
- **Impact**: Risk of breaking changes, slower development
- **What's Missing**:
  - `molecule/` directory with test scenarios
  - Testinfra tests for critical services
  - Automated testing before deployment

**6. LOW: No CI/CD Integration** 🚀
- **Issue**: Manual deployment only
- **Impact**: No automated testing, slower iteration
- **What's Missing**:
  - `.github/workflows/ansible-test.yml`
  - Automated Molecule tests on PR

**7. LOW: No ARA Reporting** 📈
- **Issue**: No playbook analytics dashboard
- **Impact**: Limited visibility into playbook execution
- **What's Missing**:
  - ARA installation and configuration
  - Playbook result tracking

---

## Research-Based Best Practices (2025)

Based on research from:
- [Ansible Best Practices - Spacelift](https://spacelift.io/blog/ansible-best-practices)
- [Red Hat Good Practices](https://redhat-cop.github.io/automation-good-practices/)
- [TeachMeAnsible Best Practices](https://teachmeansible.com/learn/best-practices)
- [Email Infrastructure-as-Code](https://mailazy.com/blog/email-infrastructure-as-code)

### Key Principles for 2025

1. **Idempotency**: Every task should be safely runnable multiple times
2. **Modularity**: Use roles for reusable components
3. **Security**: Ansible Vault for all secrets
4. **Testing**: Molecule for role testing
5. **Documentation**: Inline comments + separate README
6. **CI/CD**: GitHub Actions / GitLab CI for automated testing
7. **Monitoring**: ARA (Ansible Runner Analysis) for playbooks stats
8. **Dynamic Inventory**: Automated host discovery

---

## Improvement Plan

### Priority 1: Critical Security & Idempotency (🔴 High)

#### 1.1 Implement Ansible Vault for Secrets

**Current Issue**: Passwords, API tokens in plain text

**Solution**:
```bash
# Create vault
ansible-vault create group_vars/all/vault.yml

# Encrypt existing secrets
ansible-vault encrypt_string 'secret_password' --name 'smtp_relay_password'
```

**File Structure**:
```
ansible/
├── group_vars/
│   └── all/
│       ├── vault.yml (encrypted)
│       └── defaults.yml
```

#### 1.2 Fix Non-Idempotent Tasks

**Current Issue**: Shell commands without proper state checking

**Example Fix**:
```yaml
# BEFORE (not idempotent)
- name: Remove frozen messages older than 7 days
  shell: |
    exim4 -bp | grep frozen | awk '{print $3}' | xargs -I {} exim4 -Mrm {} 2>/dev/null || true

# AFTER (idempotent)
- name: Find frozen messages older than 7 days
  shell: exim4 -bp | grep frozen | awk '{print $3}'
  register: frozen_messages
  changed_when: false

- name: Remove frozen messages
  exim4:
    message_id: "{{ item }}"
    state: absent
  loop: "{{ frozen_messages.stdout_lines }}"
  when: frozen_messages.stdout_lines | length > 0
```

#### 1.3 Add Handlers for Service Management

**Current Issue**: Services don't restart when config changes

**Solution**:
```yaml
# Add handlers section
handlers:
  - name: Reload Exim4
    systemd:
      name: exim4
      state: reloaded
    listen: "reload exim"

  - name: Reload Dovecot
    systemd:
      name: dovecot
      state: reloaded
    listen: "reload dovecot"

  - name: Restart SpamAssassin
    systemd:
      name: spamassassin
      state: restarted
    listen: "restart spamassassin"

# Use in tasks
- name: Update Exim configuration
  template:
    src: exim4.conf.j2
    dest: /etc/exim4/exim4.conf.template
  notify: "reload exim"
```

### Priority 2: Structure & Modularity (🟡 Medium)

#### 2.1 Convert to Role-Based Structure

**Current Structure**:
```
ansible/
├── playbooks/
│   └── hestia-mail-maintenance.yml (413 lines)
└── hosts.ini
```

**Recommended Structure**:
```
ansible/
├── inventory/
│   ├── group_vars/
│   │   ├── mail-server.yml
│   │   └── all/
│   ├── host_vars/
│   └── hosts.ini
├── roles/
│   ├── hestia_mail_server/
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── logs.yml
│   │   │   ├── updates.yml
│   │   │   ├── health.yml
│   │   │   ├── dovecot_cache.yml
│   │   │   └── exim_config.yml
│   │   ├── handlers/
│   │   │   └── main.yml
│   │   ├── templates/
│   │   │   ├── exim4.conf.j2
│   │   │   ├── dovecot-custom.conf.j2
│   │   │   └── smtp_relay.conf.j2
│   │   ├── defaults/
│   │   │   └── main.yml
│   │   ├── vars/
│   │   │   └── main.yml
│   │   ├── files/
│   │   │   ├── cache-cleanup.sh
│   │   │   └── queue-monitor.sh
│   │   ├── meta/
│   │   │   └── main.yml
│   │   └── README.md
│   └── common/
│       ├── tasks/
│       └── handlers/
├── playbooks/
│   ├── hestia-mail-daily.yml
│   ├── hestia-mail-weekly.yml
│   └── hestia-mail-monthly.yml
├── scripts/
│   └── vault-password.sh
├── ansible.cfg
└── requirements.yml
```

#### 2.2 Split Playbooks by Frequency

**Current**: One large playbook for all maintenance

**Recommended**: Separate playbooks for different schedules

**playbooks/hestia-mail-daily.yml**:
```yaml
---
- name: Daily Hestia Mail Server Maintenance
  hosts: mail-server
  become: yes
  roles:
    - role: hestia_mail_server
      tags: ['logs', 'health']
```

**playbooks/hestia-mail-weekly.yml**:
```yaml
---
- name: Weekly Hestia Mail Server Maintenance
  hosts: mail-server
  become: yes
  roles:
    - role: hestia_mail_server
      vars:
        log_retention_days: 30
      tags: ['logs', 'updates', 'health']
```

**playbooks/hestia-mail-monthly.yml**:
```yaml
---
- name: Monthly Comprehensive Maintenance
  hosts: mail-server
  become: yes
  roles:
    - role: hestia_mail_server
      vars:
        comprehensive_maintenance: true
      tags: ['logs', 'updates', 'health', 'comprehensive']
```

### Priority 3: Mail-Specific Improvements (🟡 Medium)

#### 3.1 Add Dovecot Cache Management Tasks

**Based on today's fixes**: Add automated cache cleanup and monitoring

**roles/hestia_mail_server/tasks/dovecot_cache.yml**:
```yaml
---
# Dovecot Index Cache Management
# Addresses issue: large cache files causing "Cannot allocate memory" errors

- name: Check Dovecot cache file sizes
  find:
    paths: /home
    pattern: "dovecot.index.cache"
    size: +50M
  register: large_cache_files
  changed_when: false

- name: Log large cache files found
  lineinfile:
    path: /var/log/dovecot-cache-monitor.log
    line: "{{ ansible_date_time.iso8601 }} - Found {{ large_cache_files.matched }} large cache files"
    create: yes
  when: large_cache_files.matched > 0

- name: Remove oversized cache files (>100MB)
  file:
    path: "{{ item.path }}"
    state: absent
  loop: "{{ large_cache_files.files }}"
  when:
    - large_cache_files.matched > 0
    - item.size > 104857600  # 100MB
  notify: "reload dovecot"

- name: Verify Dovecot configuration
  template:
    src: dovecot-custom.conf.j2
    dest: /etc/dovecot/conf.d/90-custom.conf
    owner: root
    group: root
    mode: '0644'
  notify: "reload dovecot"

- name: Ensure Dovecot vsz_limit is set correctly
  lineinfile:
    path: /etc/dovecot/conf.d/90-custom.conf
    regexp: '^default_vsz_limit'
    line: 'default_vsz_limit = 3G'
  notify: "reload dovecot"
```

#### 3.2 Add Exim4 Configuration Management

**Based on today's fixes**: Ensure tainted filename issues are prevented

**roles/hestia_mail_server/tasks/exim_config.yml**:
```yaml
---
# Exim4 Configuration Management
# Addresses issue: "tainted filename" errors in Exim 4.95+

- name: Ensure global SMTP relay configuration exists
  template:
    src: smtp_relay.conf.j2
    dest: /etc/exim4/smtp_relay.conf
    owner: Debian-exim
    group: mail
    mode: '0640'
  notify: "reload exim"

- name: Update Exim template with simplified macros
  template:
    src: exim4.conf.template.j2
    dest: /etc/exim4/exim4.conf.template
    owner: root
    group: root
    mode: '0644'
  backup: yes
  notify: "reload exim"

- name: Update Exim configuration
  command: update-exim4.conf
  notify: "reload exim"

- name: Verify Exim routing
  command: exim4 -bt jpvanlip@gmail.com
  args:
    stdin: "From: jmvl@accelior.com"
  register: exim_test
  changed_when: false
  failed_when: "'relay.edpnet.be' not in exim_test.stdout"
```

#### 3.3 Add Monitoring & Alerting Tasks

**roles/hestia_mail_server/tasks/monitoring.yml**:
```yaml
---
- name: Create monitoring scripts directory
  file:
    path: /usr/local/bin/monitoring
    state: directory
    mode: '0755'

- name: Deploy Dovecot cache monitoring script
  copy:
    src: files/dovecot-cache-monitor.sh
    dest: /usr/local/bin/dovecot-cache-cleanup.sh
    mode: '0755'

- name: Deploy Exim queue monitoring script
  copy:
    src: files/exim-queue-monitor.sh
    dest: /usr/local/bin/exim-queue-monitor.sh
    mode: '0755'

- name: Configure Dovecot cache cleanup cron job
  cron:
    name: "Dovecot cache cleanup"
    cron_file: /etc/cron.d/dovecot-cache-cleanup
    user: root
    minute: '0'
    hour: '3'
    weekday: '0'
    job: '/usr/local/bin/dovecot-cache-cleanup.sh'

- name: Configure Exim queue monitoring cron job
  cron:
    name: "Exim queue monitoring"
    cron_file: /etc/cron.d/exim-queue-monitor
    user: root
    minute: '*/15'
    job: '/usr/local/bin/exim-queue-monitor.sh'
```

### Priority 4: Testing & CI/CD (🟢 Low)

#### 4.1 Add Molecule Testing Framework

**molecule/default/molecule.yml**:
```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: debian12
    image: debian:12
    pre_build_image: true
    command: /sbin/init
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    tmpfs:
      - /run
      - /tmp
    capabilities:
      - SYS_ADMIN
provisioner:
  name: ansible
verifier:
  name: ansible
```

**molecule/default/tests/test_default.py**:
```python
import os

import pytest

def test_dovecot_service(host):
    """Test Dovecot service is running"""
    assert host.service("dovecot").is_running
    assert host.service("dovecot").is_enabled

def test_exim_service(host):
    """Test Exim service is running"""
    assert host.service("exim4").is_running
    assert host.service("exim4").is_enabled

def test_dovecot_config(host):
    """Test Dovecot memory limits are set"""
    config = host.file("/etc/dovecot/conf.d/90-custom.conf")
    assert config.exists
    assert config.contains("vsz_limit = 3G")

def test_exim_relay_config(host):
    """Test SMTP relay configuration exists"""
    config = host.file("/etc/exim4/smtp_relay.conf")
    assert config.exists
    assert config.contains("relay.edpnet.be")

def test_mail_ports(host):
    """Test mail ports are listening"""
    assert host.socket("tcp://25").is_listening
    assert host.socket("tcp://587").is_listening
    assert host.socket("tcp://993").is_listening
```

**Test command**:
```bash
cd roles/hestia_mail_server
molecule test
```

#### 4.2 Add GitHub Actions CI/CD

**.github/workflows/ansible-test.yml**:
```yaml
name: Ansible Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install ansible molecule molecule-docker docker pytest-testinfra

      - name: Run Molecule tests
        run: |
          cd roles/hestia_mail_server
          molecule test
```

---

## Implementation Roadmap (Updated for Current State)

### ✅ COMPLETED (January 2026 Refactoring)

| Task | Status | Evidence |
|------|--------|----------|
| Role-based structure | ✅ Done | `roles/common/` + `roles/services/*` exist |
| Idempotency improvements | ✅ Done | 95%+ tasks idempotent (up from 30%) |
| Code deduplication | ✅ Done | 600 lines duplicated → 0 lines |
| Comprehensive tagging | ✅ Done | 15+ tags per playbook |
| Modular playbooks | ✅ Done | DRY principle applied |
| Handler structure | ✅ Done | `handlers/main.yml` files exist |

### 🔴 Phase 1: Critical Mail Fixes Integration (Week 1)

**Priority**: HIGH - Today's fixes need to be automated to prevent recurrence

| Task | File | Effort | Impact |
|------|------|--------|--------|
| Add Dovecot cache management | `roles/services/hestia/tasks/dovecot_cache.yml` | 2h | **Critical** - Prevents "Cannot allocate memory" errors |
| Add Exim4 config management | `roles/services/hestia/tasks/exim_config.yml` | 1.5h | **Critical** - Prevents tainted filename errors |
| Create config templates | `roles/services/hestia/templates/*.j2` | 1h | **High** - Ensures consistent configurations |
| Deploy monitoring scripts | `roles/services/hestia/tasks/monitoring.yml` | 1.5h | **High** - Proactive issue detection |
| Add script files | `roles/services/hestia/files/*.sh` | 0.5h | **Medium** - Automated cleanup |

**Total Effort**: ~6-7 hours
**Total Impact**: **CRITICAL** - Prevents today's issues from recurring

### 🔴 Phase 2: Security & Handlers (Week 2)

**Priority**: HIGH - Security hardening and operational efficiency

| Task | File | Effort | Impact |
|------|------|--------|--------|
| Implement Ansible Vault | `group_vars/all/vault.yml` | 2h | **Critical** - Encrypt passwords |
| Wire up existing handlers | Update existing tasks | 2h | **Medium** - Efficient service restarts |
| Create vault password script | `scripts/vault-password.sh` | 1h | **Medium** - Automated vault access |

**Total Effort**: ~5 hours
**Total Impact**: **HIGH** - Security + reliability

### 🟢 Phase 3: Testing & CI/CD (Week 3-4) - Optional

**Priority**: LOW - Quality of life improvements, not blocking

| Task | File | Effort | Impact |
|------|------|--------|--------|
| Add Molecule testing | `molecule/` directory | 6h | **High** - Automated testing |
| Add GitHub Actions | `.github/workflows/` | 4h | **Medium** - CI/CD integration |
| Add ARA reporting | `ansible.cfg` + setup | 2h | **Low** - Playbook analytics |

**Total Effort**: ~12 hours
**Total Impact**: **MEDIUM** - Development workflow improvements

---

## Role Template: hestia_mail_server

**roles/hestia_mail_server/defaults/main.yml**:
```yaml
---
# Log retention settings
log_retention_days: 30

# Dovecot cache settings
dovecot_vsz_limit: "3G"
dovecot_process_limit: 256
max_cache_size_mb: 100

# Exim settings
smtp_relay_host: relay.edpnet.be
smtp_relay_port: 587

# Monitoring thresholds
queue_threshold: 50
disk_threshold_percent: 80

# Maintenance modes
comprehensive_maintenance: false
```

**roles/hestia_mail_server/tasks/main.yml**:
```yaml
---
- name: Import logs tasks
  import_tasks: logs.yml
  tags: ['logs']

- name: Import updates tasks
  import_tasks: updates.yml
  tags: ['updates']

- name: Import health checks
  import_tasks: health.yml
  tags: ['health']

- name: Import Dovecot cache tasks
  import_tasks: dovecot_cache.yml
  tags: ['dovecot']

- name: Import monitoring tasks
  import_tasks: monitoring.yml
  tags: ['monitoring']

- name: Import comprehensive tasks
  import_tasks: comprehensive.yml
  tags: ['comprehensive']
  when: comprehensive_maintenance | bool
```

---

## Key Improvements Summary

| Area | Before | After |
|------|--------|-------|
| **Security** | Plain text passwords | Ansible Vault encrypted |
| **Idempotency** | Some unsafe shell commands | All tasks idempotent |
| **Structure** | 413-line monolithic playbook | Modular role structure |
| **Maintainability** | Hard to update | Easy to modify and extend |
| **Testing** | Manual testing only | Automated Molecule tests |
| **CI/CD** | None | GitHub Actions integration |
| **Handlers** | Immediate service restarts | Efficient batched restarts |
| **Documentation** | Basic README | Comprehensive role docs |
| **Monitoring** | Basic health checks | Advanced alerting + metrics |
| **Issue Prevention** | Reactive fixes | Proactive cache management |

---

## External Resources

### Best Practices & Guides
- [Spacelift: 50+ Ansible Best Practices](https://spacelift.io/blog/ansible-best-practices)
- [Red Hat Good Practices](https://redhat-cop.github.io/automation-good-practices/)
- [TeachMeAnsible Best Practices](https://teachmeansible.com/learn/best-practices)
- [Email Infrastructure-as-Code](https://mailazy.com/blog/email-infrastructure-as-code)

### Mail Server Automation
- [Ansible Galaxy: mailserver.dovecot](https://galaxy.ansible.com/mailserver/dovecot)
- [GitHub: bertvv/ansible-role-mailserver](https://github.com/bertvv/ansible-role-mailserver)
- [GitHub: chrisjsimpson/ansible-mailserver](https://github.com/chrisjsimpson/ansible-mailserver)

### Tools & Frameworks
- [Molecule Testing Framework](https://molecule.readthedocs.io/)
- [ARA: Ansible Runner Analysis](https://github.com/ansible-community/ara)
- [Ansible Vault Documentation](https://docs.ansible.com/ansible/latest/vault_guide/)

### HestiaCP Resources
- [HestiaCP Documentation](https://hestiacp.com/docs/)
- [HestiaCP Best Practices](https://hestiacp.com/docs/introduction/best-practices)
- [HestiaCP CLI Reference](https://hestiacp.com/docs/reference/cli)

---

## Next Steps

### Immediate Actions (This Week)

1. ✅ **Review gap analysis** - Compare current state vs. improvement plan
2. 🔴 **Integrate today's mail fixes** - Add Dovecot/Exim tasks to Hestia role (Phase 1)
3. 🔴 **Implement Ansible Vault** - Encrypt SMTP relay passwords (Phase 2)
4. 🟡 **Wire up handlers** - Add `notify:` directives to config change tasks (Phase 2)

### Follow-up Actions (Next 2-4 Weeks)

5. 🟢 **Set up Molecule testing** - Optional but recommended (Phase 3)
6. 🟢 **Add CI/CD with GitHub Actions** - Optional for automated testing (Phase 3)
7. 📊 **Monitor and iterate** - Review effectiveness of automated fixes

### Quick Start Command

To integrate today's fixes immediately:
```bash
cd /Users/jm/Codebase/internet-control/ansible

# Create new role files
mkdir -p roles/services/hestia/{tasks,templates,files}

# Add the new task files from Priority 3 section above
# Copy scripts from /usr/local/bin/ to files/
# Create Jinja2 templates from today's config changes
```

---

**Document Version**: 2.0 (Updated January 2026)
**Created**: 2026-01-08
**Last Updated**: 2026-01-08 15:00 UTC
**Author**: Infrastructure Team (Claude Code)
**Next Review**: After Phase 1 (Mail Fixes Integration) completion
**Status**: ✅ Gap analysis complete, ready for Phase 1 implementation
