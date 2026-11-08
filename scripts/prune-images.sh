#!/bin/sh
set -eu

exec 9>/run/homelab-state.lock
flock --nonblock 9
case "$IMAGE_RETENTION_HOURS" in
'' | *[!0-9]* | 0)
	echo "Invalid IMAGE_RETENTION_HOURS" >&2
	exit 1
	;;
esac
# Rootful service: only unused images created before the configured cutoff.
exec /usr/bin/podman image prune --all --force --filter "until=${IMAGE_RETENTION_HOURS}h"
