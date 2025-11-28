#!/bin/sh
set -e

echo "[$(date)] Starting backup..."

# Check if backup destination is mounted
if ! mountpoint -q /mnt/services; then
    echo "[$(date)] ERROR: Backup destination /mnt/services not mounted"
    exit 1
fi

# Store current SELinux state and temporarily disable for NAS backup
SELINUX_STATE=$(getenforce)
echo "[$(date)] Current SELinux state: $SELINUX_STATE"

if [ "$SELINUX_STATE" = "Enforcing" ]; then
    echo "[$(date)] Temporarily disabling SELinux for NAS backup..."
    setenforce 0
    
    # Set trap to restore SELinux on any exit (success, failure, or signal)
    trap 'echo "[$(date)] Restoring SELinux to: $SELINUX_STATE"; setenforce 1' EXIT INT TERM
fi

# Perform incremental backup with optimizations
echo "[$(date)] Starting incremental rsync backup..."
rsync -avh --progress --stats \
  --delete \
  --delete-excluded \
  --partial \
  --partial-dir=.rsync-partial \
  --exclude='/plex/config/Library/Application Support/Plex Media Server/Cache/**' \
  --exclude='/plex/config/Library/Application Support/Plex Media Server/Metadata/**' \
  --exclude='/plex/config/Library/Application Support/Plex Media Server/Logs/**' \
  --exclude='/plex/config/Library/Application Support/Plex Media Server/Crash Reports/**' \
  --exclude='**/.DS_Store' \
  --exclude='**/Thumbs.db' \
  /var/services/ /mnt/services/

echo "[$(date)] Incremental backup completed successfully"
echo "[$(date)] To restore, run: rsync -avh --progress /mnt/services/ /var/services/"
