#!/bin/sh
set -eu

for share; do
	case "$share" in
	tv | movies | music | books | software | games | services) ;;
	*)
		echo "Unknown NAS share: $share" >&2
		exit 1
		;;
	esac
	actual=$(findmnt --noheadings --raw --mountpoint "/var/mnt/$share" --output FSTYPE,SOURCE)
	if [ "$actual" != "cifs //nas.lan/$share" ]; then
		echo "Expected //nas.lan/$share mounted as CIFS at /var/mnt/$share" >&2
		exit 1
	fi
done
