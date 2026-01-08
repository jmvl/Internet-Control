#!/bin/bash
# Check critical containers status
CONTAINERS="$@"

for container in $CONTAINERS; do
    if docker ps | grep -q "$container"; then
        echo "$container: running"
    else
        echo "$container: NOT RUNNING"
    fi
done
