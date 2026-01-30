# Dinero Cash Website - Backup Log

**Backup Date**: 2026-01-16
**Backup Time**: 15:34 UTC
**Purpose**: Pre-deployment backup before applying SEO/accessibility fixes

---

## Backup Summary

Two complete backups have been created:

### 1. Remote Backup (Hestia Server)

| Property | Value |
|----------|-------|
| **Location** | `/home/dinero/web/dinero.cash/` |
| **Filename** | `public_html.backup.20260116_153431.tar.gz` |
| **Size** | 4.6 MB (compressed) |
| **Files** | 172 files and directories |
| **Owner** | root:root |
| **Uncompressed Size** | ~5.7 MB |

**Restore Command**:
```bash
ssh root@192.168.1.30
cd /home/dinero/web/dinero.cash
tar -xzf public_html.backup.20260116_153431.tar.gz
chown -R dinero:dinero public_html/
```

### 2. Local Backup (Repository)

| Property | Value |
|----------|-------|
| **Location** | `/Users/jm/Codebase/internet-control/websites/www.dinero.cash/backups/` |
| **Directory** | `live-20260116_153450/` |
| **Size** | 5.8 MB |
| **Method** | rsync copy |

**Restore Command**:
```bash
rsync -avz --delete \
  /Users/jm/Codebase/internet-control/websites/www.dinero.cash/backups/live-20260116_153450/ \
  root@192.168.1.30:/home/dinero/web/dinero.cash/public_html/
```

---

## Backup Contents

### Files Backed Up

**HTML Pages**:
- index.html (58KB, 968 lines)
- agents.html (37KB, 626 lines)
- users.html (39KB, 667 lines)
- contact-us.html (3.2KB, 44 lines)
- privacy-policy.html (6.1KB, 61 lines)
- redirect.html (2.1KB, 29 lines)

**Assets**:
- css/ (normalize.css, webflow.css, dinerocash.webflow.css)
- js/ (webflow.js - 590KB)
- images/ (100+ hero images, icons, screenshots)
- documents/ (lottie animations, JSON configs)
- user/ (status pages for en/fr locales)

### Directory Structure (Original Live Site)

```
public_html/
├── css/
│   ├── normalize.css (7.6KB)
│   ├── webflow.css (38KB)
│   └── dinerocash.webflow.css (46KB)
├── js/
│   └── webflow.js (590KB)
├── images/
│   ├── Hero-Image-*.jpg (4 hero slides)
│   ├── f*.png (feature screenshots)
│   ├── Tabs-i*.png (tab screenshots)
│   ├── *.svg (icons and graphics)
│   └── ... (100+ files total)
├── documents/
│   └── lottieflow-menu-nav-*.json
├── user/
│   ├── en/status.html
│   └── fr/status.html
├── index.html
├── agents.html
├── users.html
├── contact-us.html
├── privacy-policy.html
├── redirect.html
└── robots.txt
```

---

## Verification

### Remote Backup Integrity
```bash
# File count verification
tar -tzf public_html.backup.20260116_153431.tar.gz | wc -l
# Result: 172 files/directories

# Size verification
ls -lh public_html.backup.20260116_153431.tar.gz
# Result: -rw-r--r-- 1 root root 4.6M Jan 16 14:34
```

### Local Backup Integrity
```bash
# Size verification
du -sh live-20260116_153450/
# Result: 5.8M

# File count
find live-20260116_153450/ -type f | wc -l
# Result: 172 files
```

---

## Deployment Plan

After backup completion, the following steps will be taken:

1. ✅ **Backup completed** - Two redundant backups created
2. ⏳ **Apply fixes to local files** - Implement SEO/accessibility improvements
3. ⏳ **Test locally** - Verify changes work correctly
4. ⏳ **Deploy to staging** - Optional staging test
5. ⏳ **Deploy to production** - Sync to Hestia
6. ⏳ **Verify deployment** - Test live site functionality
7. ⏳ **Monitor** - Check logs and performance

---

## Rollback Procedure

If deployment causes issues, immediate rollback is available:

### Option 1: Quick Restore from Remote Backup
```bash
ssh root@192.168.1.30
cd /home/dinero/web/dinero.cash
rm -rf public_html/
tar -xzf public_html.backup.20260116_153431.tar.gz
chown -R dinero:dinero public_html/
systemctl reload nginx
```

### Option 2: Restore from Local Backup
```bash
rsync -avz --delete \
  /Users/jm/Codebase/internet-control/websites/www.dinero.cash/backups/live-20260116_153450/ \
  root@192.168.1.30:/home/dinero/web/dinero.cash/public_html/
```

---

## Backup Retention

**Recommended**: Keep this backup until the next deployment is verified working (minimum 7 days).

**Archive Location**: Backups will remain in both locations until manually removed.

**Clean-up Command** (when safe):
```bash
# Remote (after 7 days of successful operation)
ssh root@192.168.1.30 "rm /home/dinero/web/dinero.cash/public_html.backup.20260116_153431.tar.gz"

# Local (optional - keep for historical record)
# Can be moved to cold storage or deleted
```

---

## Next Steps

1. Apply improvements from `QUICK-FIXES.md` to local files
2. Test all changes locally
3. Deploy to production with monitoring
4. Verify all functionality post-deployment
5. Keep backup available for 7 days

---

**Backup Status**: ✅ COMPLETE
**Ready for Deployment**: ✅ YES
**Rollback Available**: ✅ YES (two methods)
