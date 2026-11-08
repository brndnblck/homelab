#!/bin/sh
set -eu

# shellcheck source=state-common.sh
. /var/scripts/state-common.sh
exec 9>/run/homelab-state.lock
flock --nonblock 9
check_backup_mount
case "$BACKUP_KEEP" in
'' | *[!0-9]* | 0)
	echo "BACKUP_KEEP must be positive" >&2
	exit 1
	;;
esac
umask 077
mkdir -p "$BACKUPS"
id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
stage="$BACKUPS/.partial-$id"
mkdir "$stage"
units=$(running_services)
printf '%s\n' "$units" >"$stage/active-units"
restart() {
	status=$?
	trap - EXIT
	if [ -n "$units" ]; then
		# Units come only from systemctl, with no whitespace in unit names.
		# shellcheck disable=SC2086
		systemctl start $units || status=1
	fi
	exit "$status"
}
trap restart EXIT
trap 'exit 1' HUP INT TERM
if [ -n "$units" ]; then
	# shellcheck disable=SC2086
	systemctl stop $units
fi

echo "Creating consistent snapshot $id (application containers are stopped)"
tar --create --file "$stage/services.tar" --directory "$SERVICES" \
	--numeric-owner --acls --xattrs \
	--exclude='./plex/config/Library/Application Support/Plex Media Server/Cache' \
	--exclude='./plex/config/Library/Application Support/Plex Media Server/Logs' \
	--exclude='./plex/config/Library/Application Support/Plex Media Server/Crash Reports' .
(cd "$stage" && sha256sum services.tar >services.tar.sha256)
tar --list --file "$stage/services.tar" >/dev/null
printf '%s\n' 'homelab-backup-v1' >"$stage/complete"
mv "$stage" "$BACKUPS/$id"
printf '%s\n' "$id" >"$BACKUPS/latest.tmp"
mv "$BACKUPS/latest.tmp" "$BACKUPS/latest"
echo "Published snapshot $id"

# Only this script's completed, timestamped snapshots are eligible for retention.
count=0
for directory in $(printf '%s\n' "$BACKUPS"/20*T*Z-* | sort -r); do
	case "${directory##*/}" in *[!0-9TZ-]*) continue ;; esac
	[ -d "$directory" ] && [ ! -L "$directory" ] || continue
	[ -f "$directory/complete" ] || continue
	[ "$(cat "$directory/complete")" = 'homelab-backup-v1' ] || continue
	count=$((count + 1))
	if [ "$count" -gt "$BACKUP_KEEP" ]; then
		rm -rf -- "$directory"
	fi
done
