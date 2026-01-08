#!/bin/bash
# Exim Queue Monitoring Script
# Deployed by Ansible - Hestia Mail Server Maintenance
# Purpose: Monitor Exim queue size and alert on threshold breaches
# Based on: /docs/hestia/hestia-mail-server-maintenance-intervention-2026-01-08.md
# Scheduled: Every 15 minutes via cron

QUEUE_COUNT=$(exim4 -bpc 2>/dev/null | grep -oE '[0-9]+' || echo 0)
THRESHOLD=50

if [ "$QUEUE_COUNT" -gt "$THRESHOLD" ]; then
    logger -t exim-queue-monitor -p mail.warning "Exim queue alert: $QUEUE_COUNT messages pending (threshold: $THRESHOLD)"
fi
