#!/bin/bash
# Get Docker daemon driver status info
docker info --format '{{ .DriverStatus }}'
