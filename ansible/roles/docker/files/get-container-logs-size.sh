#!/bin/bash
# Get Docker container logs size
for container in $(docker ps -q); do
    log_file=$(docker inspect --format='{{ .LogPath }}' "$container")
    if [ -f "$log_file" ]; then
        du -sh "$log_file"
    fi
done
