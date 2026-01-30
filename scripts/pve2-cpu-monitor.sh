#!/bin/bash
# pve2 CPU Usage Monitor
# Alerts when CPU usage exceeds threshold for sustained period

THRESHOLD=80  # CPU percentage threshold
DURATION=60   # Sustained duration in seconds
CHECK_INTERVAL=10  # Check every 10 seconds
ALERT_EMAIL="${ALERT_EMAIL:-}"
LOG_FILE="/var/log/pve2-cpu-monitor.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_cpu() {
    local cpu_usage=$(top -b -n 1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo "${cpu_usage%.*}"
}

get_top_processes() {
    ps aux --sort=-%cpu | head -10
}

# Main monitoring loop
sustained_count=0
required_checks=$((DURATION / CHECK_INTERVAL))

while true; do
    cpu=$(check_cpu)
    log "CPU Usage: ${cpu}%"
    
    if [ "$cpu" -gt "$THRESHOLD" ]; then
        sustained_count=$((sustained_count + 1))
        log "HIGH CPU DETECTED: ${cpu}% (${sustained_count}/${required_checks})"
        
        if [ "$sustained_count" -ge "$required_checks" ]; then
            log "!!! ALERT: Sustained high CPU usage (${cpu}% for ${DURATION}s) !!!"
            log "Top processes:"
            get_top_processes | tee -a "$LOG_FILE"
            
            # Send email if configured
            if [ -n "$ALERT_EMAIL" ]; then
                get_top_processes | mail -s "ALERT: High CPU on pve2 (${cpu}%)" "$ALERT_EMAIL"
            fi
            
            # Reset counter after alert
            sustained_count=0
        fi
    else
        sustained_count=0
    fi
    
    sleep "$CHECK_INTERVAL"
done
