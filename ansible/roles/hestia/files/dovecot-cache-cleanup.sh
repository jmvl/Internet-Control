#!/bin/bash
# Dovecot Cache Cleanup Script
# Deployed by Ansible - Hestia Mail Server Maintenance
# Purpose: Automated cleanup of large Dovecot index cache files
# Based on: /docs/hestia/hestia-mail-server-maintenance-intervention-2026-01-08.md
# Scheduled: Weekly (Sundays at 3 AM) via cron

LOG_FILE="/var/log/dovecot-cache-cleanup.log"
MAX_SIZE_MB=100

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Starting Dovecot cache cleanup..."

# Find and remove large cache files (>100MB)
find /home -name "dovecot.index.cache" -size +${MAX_SIZE_MB}M -type f 2>/dev/null | while read -r cache_file; do
    if [ -f "$cache_file" ]; then
        SIZE=$(stat -c%s "$cache_file" 2>/dev/null || echo 0)
        SIZE_MB=$((SIZE / 1048576))
        log "Found large cache: $cache_file (${SIZE_MB}MB)"
        rm -f "$cache_file"
        log "Removed: $cache_file"

        # Also remove associated .log files
        CACHE_DIR=$(dirname "$cache_file")
        rm -f "$CACHE_DIR"/dovecot.index.log 2>/dev/null

        log "Cache will be rebuilt on next mailbox access"
    fi
done

log "Dovecot cache cleanup completed"
