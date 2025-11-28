#!/bin/sh
set -e

echo "[$(date)] Mounting shared folders from nas.lan..."

# Mount shared folders
for path in tv movies music books software games services; do
    echo "[$(date)] Mounting $path"
    mkdir -p "/mnt/$path"
    mount -t cifs "//nas.lan/$path" "/mnt/$path" -o vers=3.0,credentials=/etc/smb/credentials,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,noperm,noserverino
done

echo "[$(date)] All shares mounted successfully"

echo "[$(date)] Standardizing ownership to 1000:1000..."
# Ensure local service directories match mount UID
chown -R 1000:1000 /var/services/ 2>/dev/null || true
chown -R 1000:1000 /var/downloads/ 2>/dev/null || true

echo "[$(date)] Ownership standardization completed"
