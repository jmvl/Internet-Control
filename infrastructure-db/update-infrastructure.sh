#!/bin/bash
#
# update-infrastructure.sh
# Master script to update infrastructure database from all sources
# Can be run manually or via cron
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_PATH="$SCRIPT_DIR/infrastructure.db"
LOG_DIR="$SCRIPT_DIR/logs"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/update-$(date +%Y%m%d-%H%M%S).log"

# Logging functions
log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" | tee -a "$LOG_FILE"; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE"; }
log_success() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" | tee -a "$LOG_FILE"; }

log_info "Starting infrastructure database update..."

# Update PVE2 data via SSH scraper
if [ -x "$SCRIPT_DIR/scrape_pve2.sh" ]; then
    log_info "Updating PVE2 data via SSH..."
    bash "$SCRIPT_DIR/scrape_pve2.sh" >> "$LOG_FILE" 2>&1
    log_success "PVE2 data updated"
else
    log_error "scrape_pve2.sh not found or not executable"
    exit 1
fi

# TODO: Add other data sources here
# - Docker hosts via SSH
# - Network devices via SNMP
# - OPNsense API for firewall rules

log_success "Infrastructure database update completed!"
log_info "Log file: $LOG_FILE"

# Cleanup old logs (keep last 30 days)
find "$LOG_DIR" -name "update-*.log" -mtime +30 -delete 2>/dev/null || true
