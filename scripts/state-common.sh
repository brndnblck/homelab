#!/bin/sh

BACKUPS=/mnt/services/homelab-backups
SERVICES=/var/services

check_backup_mount() {
	/usr/bin/sh /var/scripts/check-shares.sh services || return
	[ ! -L "$BACKUPS" ] && [ ! -L "$SERVICES" ]
}

running_services() {
	listing=$(systemctl list-units --type=service --state=running --no-legend --plain 'container-*.service') || return
	printf '%s\n' "$listing" | awk '{print $1}'
}

stop_services() {
	[ -n "$units" ] || return 0
	# Legacy units can exit while their containers remain in a separate cgroup.
	# shellcheck disable=SC2086
	systemctl stop $units
	# shellcheck disable=SC2086
	podman stop --ignore --time 60 $units
}

check_snapshot() {
	case "$1" in
	'' | *[!0-9TZ-]*)
		echo "Invalid snapshot ID" >&2
		return 1
		;;
	esac
	snapshot="$BACKUPS/$1"
	[ ! -L "$snapshot" ] && [ -d "$snapshot" ]
	[ "$(cat "$snapshot/complete")" = "homelab-backup-v1" ]
	(cd "$snapshot" && sha256sum --check services.tar.sha256)
	tar --list --file "$snapshot/services.tar" >/dev/null
}

restore_snapshot() {
	tar --extract --file "$snapshot/services.tar" --directory "$SERVICES" \
		--numeric-owner --same-owner --acls --xattrs || return
	restorecon -RF "$SERVICES"
}
