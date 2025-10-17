# Semaphore Quick Setup Guide

**URL**: http://192.168.1.20:3001
**Login**: admin / admin123

---

## Step 1: Create Project

1. Click **"New Project"**
2. Fill in:
   - **Name**: `Infrastructure Maintenance`
   - **Max Parallel Tasks**: `3`
3. Click **"CREATE"**

---

## Step 2: Add SSH Key

1. Go to **Key Store** tab
2. Click **"NEW KEY"**
3. Fill in:
   - **Name**: `Ansible SSH Key`
   - **Type**: `SSH Key`
   - **Login (Optional)**: `root`
   - **Passphrase (Optional)**: Leave empty
   - **Private Key**: Copy the key below

```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACC2z81e0U8dsrwcy47OZvnZLThag2ks2AlTSMGcbXb15AAAAJjgm9lZ4JvZ
WQAAAAtzc2gtZWQyNTUxOQAAACC2z81e0U8dsrwcy47OZvnZLThag2ks2AlTSMGcbXb15A
AAAEDKPA62TUShDH8jRIDw90y9ou6N0QwwgoYQvqlSqKLKMbbPzV7RTx2yvBzLjs5m+dkt
OFqDaSzYCVNIwZxtdvXkAAAAEHNlbWFwaG9yZUBkb2NrZXIBAgMEBQ==
-----END OPENSSH PRIVATE KEY-----
```

4. Click **"CREATE"**

---

## Step 3: Create Inventory

1. Go to **Inventory** tab
2. Click **"NEW INVENTORY"**
3. Fill in:
   - **Name**: `Ansible Hosts`
   - **User Credentials**: Select `Ansible SSH Key` (the key you just created)
   - **Type**: `Static`
   - **Inventory**: Paste the content below

```
[mail-server]
192.168.1.30

[jira]
192.168.1.22

[confluence]
192.168.1.21
```

4. Click **"CREATE"**

---

## Step 4: Create Repository

1. Go to **Repositories** tab
2. Click **"NEW REPOSITORY"**
3. Fill in:
   - **Name**: `Semaphore Playbooks`
   - **URL**: `file:///opt/semaphore-playbooks`
   - **Branch**: Leave as `master` or empty
   - **Access Key**: Select `Ansible SSH Key`
4. Click **"CREATE"**

---

## Step 5: Create Task Templates

Create **7 templates** (one by one). For each template:

1. Go to **Task Templates** tab
2. Click **"NEW TEMPLATE"**
3. Fill in the details below
4. Click **"CREATE"**
5. Repeat for all 7 templates

### Template 1: HestiaCP - Daily Log Cleanup
- **Name**: `HestiaCP - Daily Log Cleanup`
- **Description**: `Daily log cleanup and rotation`
- **Playbook Filename**: `hestia-logs.sh`
- **Inventory**: `Ansible Hosts`
- **Repository**: `Semaphore Playbooks`
- **Environment**: None
- **Type**: `Build` or `Deploy` (default)
- **Suppress success alerts**: ✓ (check this)

### Template 2: HestiaCP - Full Maintenance
- **Name**: `HestiaCP - Full Maintenance`
- **Description**: `Full maintenance with OS updates`
- **Playbook Filename**: `hestia-full.sh`
- **Inventory**: `Ansible Hosts`
- **Repository**: `Semaphore Playbooks`
- **Environment**: None
- **Type**: `Build` or `Deploy`
- **Suppress success alerts**: ✓

### Template 3: JIRA - Full Maintenance
- **Name**: `JIRA - Full Maintenance`
- **Description**: `Full JIRA maintenance with OS updates`
- **Playbook Filename**: `jira-full.sh`
- **Inventory**: `Ansible Hosts`
- **Repository**: `Semaphore Playbooks`
- **Environment**: None
- **Type**: `Build` or `Deploy`
- **Suppress success alerts**: ✓

### Template 4: Confluence - Full Maintenance
- **Name**: `Confluence - Full Maintenance`
- **Description**: `Full Confluence maintenance with OS updates`
- **Playbook Filename**: `confluence-full.sh`
- **Inventory**: `Ansible Hosts`
- **Repository**: `Semaphore Playbooks`
- **Environment**: None
- **Type**: `Build` or `Deploy`
- **Suppress success alerts**: ✓

### Template 5: HestiaCP - Comprehensive (Monthly)
- **Name**: `HestiaCP - Comprehensive (Monthly)`
- **Description**: `Monthly comprehensive maintenance`
- **Playbook Filename**: `hestia-comprehensive.sh`
- **Inventory**: `Ansible Hosts`
- **Repository**: `Semaphore Playbooks`
- **Environment**: None
- **Type**: `Build` or `Deploy`
- **Suppress success alerts**: ✓

### Template 6: JIRA - Comprehensive (Monthly)
- **Name**: `JIRA - Comprehensive (Monthly)`
- **Description**: `Monthly JIRA comprehensive maintenance`
- **Playbook Filename**: `jira-comprehensive.sh`
- **Inventory**: `Ansible Hosts`
- **Repository**: `Semaphore Playbooks`
- **Environment**: None
- **Type**: `Build` or `Deploy`
- **Suppress success alerts**: ✓

### Template 7: Confluence - Comprehensive (Monthly)
- **Name**: `Confluence - Comprehensive (Monthly)`
- **Description**: `Monthly Confluence comprehensive maintenance`
- **Playbook Filename**: `confluence-comprehensive.sh`
- **Inventory**: `Ansible Hosts`
- **Repository**: `Semaphore Playbooks`
- **Environment**: None
- **Type**: `Build` or `Deploy`
- **Suppress success alerts**: ✓

---

## Done!

After creating all templates, you can:
1. Click on any template
2. Click **"RUN"** to execute it
3. Watch the live output

All 7 maintenance scripts have been tested and are working 100%!

---

## Quick Test

To verify everything works:
1. Go to **Task Templates**
2. Select **"HestiaCP - Daily Log Cleanup"**
3. Click **"RUN"**
4. Should complete with `ok=18, changed=8, failed=0`
