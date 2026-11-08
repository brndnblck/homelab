#!/bin/sh
set -eu

# shellcheck source=state-common.sh
. /var/scripts/state-common.sh
exec 9>/run/homelab-state.lock
flock --nonblock 9
check_backup_mount
mkdir -p /var/lib/homelab
prepared=/var/lib/homelab/services-prepared

# Preparing state and starting units are separate, so a failed start never restores again.
if [ ! -e "$prepared" ]; then
	if [ -n "$(find "$SERVICES" -mindepth 1 -print -quit)" ]; then
		echo "Existing service data found. Review it and explicitly adopt it before initialization." >&2
		exit 1
	fi
	if [ -f "$BACKUPS/latest" ]; then
		check_snapshot "$(cat "$BACKUPS/latest")"
		restore_snapshot
	else
		while IFS= read -r service; do
			if [ -n "$service" ] && [ -d "/mnt/services/$service" ]; then
				echo 'Legacy NAS backup found. Create a verified snapshot before provisioning.' >&2
				exit 1
			fi
		done </etc/homelab/services
	fi
	while IFS= read -r service; do
		[ -n "$service" ] || continue
		if [ ! -d "$SERVICES/$service" ]; then
			case "$service" in
			bazarr | lidarr | prowlarr | radarr | readarr | sabnzbd | sonarr)
				uid=911
				gid=911
				;;
			nginx)
				uid=0
				gid=0
				;;
			*)
				uid=1000
				gid=1000
				;;
			esac
			install -d -m 0755 -o "$uid" -g "$gid" "$SERVICES/$service"
		fi
	done </etc/homelab/services
	touch "$prepared"
fi

while IFS= read -r service; do
	[ -n "$service" ] || continue
	systemctl enable "container-$service.service"
	systemctl start "container-$service.service"
done </etc/homelab/services
systemctl disable task-services.service
echo 'Service initialization completed'
