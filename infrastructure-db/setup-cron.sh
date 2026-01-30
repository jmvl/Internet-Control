#!/bin/bash
#
# setup-cron.sh
# Install cron job for automated infrastructure database updates
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update-infrastructure.sh"
CRON_FILE="$SCRIPT_DIR/infrastructure-update.cron"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "================================================"
echo "  Infrastructure Update Cron Job Setup"
echo "================================================"
echo ""

# Verify update script exists
if [ ! -x "$UPDATE_SCRIPT" ]; then
    log_error "Update script not found or not executable: $UPDATE_SCRIPT"
    exit 1
fi

# Create crontab entry (every 5 minutes)
log_info "Creating cron job configuration..."
cat > "$CRON_FILE" << EOF
# Infrastructure database auto-update
# Runs every 5 minutes to scrape PVE2 for changes
*/5 * * * * $UPDATE_SCRIPT >/dev/null 2>&1
EOF

log_success "Cron configuration created: $CRON_FILE"
echo ""

# Display cron entry
log_info "Cron entry (runs every 5 minutes):"
echo "  */5 * * * * $UPDATE_SCRIPT"
echo ""

# Ask for installation method
echo "Installation options:"
echo "  1. Install to current user's crontab"
echo "  2. Install to root's crontab (requires sudo)"
echo "  3. Skip installation (manual setup)"
echo ""
read -p "Choose option [1-3]: " -n 1 choice
echo ""

case $choice in
    1)
        log_info "Installing to current user's crontab..."
        # Check if entry already exists
        if crontab -l 2>/dev/null | grep -q "$UPDATE_SCRIPT"; then
            log_info "Cron entry already exists in current user's crontab"
        else
            # Append to existing crontab or create new one
            (crontab -l 2>/dev/null; cat "$CRON_FILE") | crontab -
            log_success "Cron job installed to current user's crontab"
        fi
        ;;
    2)
        log_info "Installing to root's crontab..."
        if sudo crontab -l 2>/dev/null | grep -q "$UPDATE_SCRIPT"; then
            log_info "Cron entry already exists in root's crontab"
        else
            (sudo crontab -l 2>/dev/null; cat "$CRON_FILE") | sudo crontab -
            log_success "Cron job installed to root's crontab"
        fi
        ;;
    3)
        log_info "Skipping installation. Manual setup required."
        echo ""
        echo "To install manually, add the following line to your crontab:"
        echo "  */5 * * * * $UPDATE_SCRIPT"
        echo ""
        echo "Edit crontab with: crontab -e"
        ;;
    *)
        log_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "================================================"
echo "  Setup Complete!"
echo "================================================"
echo ""
log_info "Cron job will run every 5 minutes"
echo ""
log_info "Log files will be created in: $SCRIPT_DIR/logs/"
log_info "Old logs (>30 days) will be automatically cleaned up"
echo ""
echo "To view logs:"
echo "  ls -la $SCRIPT_DIR/logs/"
echo ""
echo "To manually trigger an update:"
echo "  $UPDATE_SCRIPT"
echo ""
echo "To uninstall cron job:"
echo "  crontab -e    # and delete the infrastructure-update line"
echo ""
