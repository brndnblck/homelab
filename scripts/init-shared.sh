#!/bin/sh
set -e

echo "[$(date)] Ensuring SELinux allows container CIFS access..."
setsebool -P virt_use_samba on

# Each consumer depends on and verifies its own systemd-managed NAS mounts.
echo "[$(date)] Container CIFS access configured"
