#!/bin/sh
set -eu

# shellcheck source=state-common.sh
. /var/scripts/state-common.sh
exec 9>/run/homelab-state.lock
flock --nonblock 9
check_backup_mount
id=${1:-$(cat "$BACKUPS/latest")}
check_snapshot "$id"
echo "Restore snapshot $id? Current state will be retained alongside /var/services."
printf 'Type yes to stop containers and restore: '
read -r confirm
[ "$confirm" = yes ] || exit 0

units=$(running_services)
if [ -n "$units" ]; then
	# shellcheck disable=SC2086
	systemctl stop $units
fi
previous="/var/services.before-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mv "$SERVICES" "$previous"
mkdir -m 0755 "$SERVICES"
if ! restore_snapshot; then
	echo "Restore failed. Containers remain stopped. Previous state: $previous" >&2
	exit 1
fi
if [ -n "$units" ]; then
	# shellcheck disable=SC2086
	systemctl start $units
fi
echo "Restored $id; previous state retained at $previous"
