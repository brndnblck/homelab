#!/bin/sh
set -e

echo "[$(date)] Syncing service configuration from backup..."

# Check if backup source is available
if ! mountpoint -q /mnt/services; then
    echo "[$(date)] WARNING: /mnt/services not mounted, creating fresh directories"
    mkdir -p /var/services/plex /var/services/sonarr /var/services/radarr /var/services/lidarr /var/services/readarr /var/services/prowlarr /var/services/bazarr /var/services/sabnzbd /var/services/nginx /var/services/homebridge /var/services/n8n
else
    # Restore configurations from backup
    setenforce 0
    rsync -avh --progress \
      --exclude='/plex/config/Library/Application Support/Plex Media Server/Cache/**' \
      --exclude='/plex/config/Library/Application Support/Plex Media Server/Metadata/**' \
      --exclude='/plex/config/Library/Application Support/Plex Media Server/Logs/**' \
      --exclude='/plex/config/Library/Application Support/Plex Media Server/Crash Reports/**' \
      /mnt/services/ /var/services/
    setenforce 1
fi

echo "[$(date)] Setting ownership and permissions..."
chown -R core:core /var/services
chmod -R 775 /var/services

echo "[$(date)] Enabling and starting container services..."
for service in nginx bazarr homebridge lidarr plex prowlarr radarr readarr sabnzbd sonarr n8n; do
    echo "[$(date)] Starting container-$service.service"
    systemctl enable "container-$service.service"
    systemctl start "container-$service.service"
done

echo "[$(date)] Service initialization completed"

# Disable this service after successful run (run once only)
systemctl disable task-services.service
