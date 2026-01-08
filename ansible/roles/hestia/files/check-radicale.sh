#!/bin/bash
# Check Radicale container status
docker ps --filter name=radicale --format '{{ .Status }}'
