#!/bin/sh
set -e

echo "[$(date)] Starting homelab restore..."

# Check if backup source is mounted
if ! mountpoint -q /mnt/services; then
    echo "[$(date)] ERROR: Backup source /mnt/services not mounted"
    exit 1
fi

# Confirmation prompt
echo "WARNING: This will overwrite current service data with backup data."
echo "Current services will be stopped during restore."
echo ""
printf "Continue with restore? (yes/no): "
read -r confirm
if [ "$confirm" != "yes" ]; then
    echo "[$(date)] Restore cancelled by user"
    exit 0
fi

# Store current SELinux state and temporarily disable for NAS restore
SELINUX_STATE=$(getenforce)
echo "[$(date)] Current SELinux state: $SELINUX_STATE"

if [ "$SELINUX_STATE" = "Enforcing" ]; then
    echo "[$(date)] Temporarily disabling SELinux for NAS restore..."
    setenforce 0
    
    # Set trap to restore SELinux on any exit (success, failure, or signal)
    trap 'echo "[$(date)] Restoring SELinux to: $SELINUX_STATE"; setenforce 1' EXIT INT TERM
fi

# Stop all container services before restore
echo "[$(date)] Stopping container services..."
systemctl stop container-*.service || true

# Perform restore with same optimizations as backup
echo "[$(date)] Starting rsync restore..."
rsync -avh --progress --stats \
  --delete \
  --partial \
  --partial-dir=.rsync-partial \
  /mnt/services/ /var/services/

# Start container services after restore
echo "[$(date)] Starting container services..."
systemctl start container-*.service || true

echo "[$(date)] Restore completed successfully"
echo "[$(date)] All container services have been restarted"
