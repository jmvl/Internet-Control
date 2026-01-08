#!/bin/bash
# Truncate large Docker container logs
MAX_SIZE=104857600  # 100MB in bytes
TRUNCATE_SIZE="${1:-100M}"

for container in $(docker ps -q); do
    log_file=$(docker inspect --format='{{ .LogPath }}' "$container")
    if [ -f "$log_file" ]; then
        size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
        if [ "$size" -gt "$MAX_SIZE" ]; then
            truncate -s "$TRUNCATE_SIZE" "$log_file"
            echo "Truncated $log_file"
        fi
    fi
done
