#!/bin/sh
set -e

echo "[$(date)] Initializing Podman networks..."

# Create external network (only nginx proxy)
if ! podman network exists external-net 2>/dev/null; then
    echo "[$(date)] Creating external-net for public-facing services"
    podman network create external-net
else
    echo "[$(date)] Network external-net already exists"
fi

# Create internal network (all other services)
if ! podman network exists internal-net 2>/dev/null; then
    echo "[$(date)] Creating internal-net for private services"
    podman network create internal-net
else
    echo "[$(date)] Network internal-net already exists"
fi

# List created networks for verification
echo "[$(date)] Available Podman networks:"
podman network ls

echo "[$(date)] Network initialization completed"