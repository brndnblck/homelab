# Storage, services, and backups

## Managed settings

`config/storage.env` is provisioned to `/etc/homelab/storage.env` (root-only).

| Setting | Default | Reason |
| --- | --- | --- |
| `SAB_DOWNLOAD_FREE` | `150G` | Observed 72 GiB downloads can need another similarly sized unpack, plus working space. |
| `DISK_ALERT_GIB` | `175` | Warn before the SAB reserve is reached. |
| `BACKLOG_HOURS` | `24` | Report old completed music folders after an import grace period. |
| `IMAGE_RETENTION_HOURS` | `168` | Weekly cleanup of unused images created more than seven days ago. |
| `BACKUP_KEEP` | `7` | Keep seven completed application-state snapshots. |
| `ALERT_WEBHOOK` | empty | Optional HTTPS endpoint accepting `{"text": "..."}`. |

These are initial policies based on the disk incident. Review the reserve if larger
jobs or overlapping downloads/post-processing become normal. SAB pauses downloads
at the reserve; this does not limit the space consumed by an unpack already running.
Do not enable the policy until the local filesystem has enough headroom.

The SAB pre-start script changes only the `[misc]` free-space reserve and port,
preserves other configuration, and refuses to edit a running SAB container.

## Monitoring and cleanup

- `task-storage-report.timer`: every 15 minutes, starting 10 minutes after boot.
  Reads the Lidarr queue, local completed music folders, disk space, and SAB reserve.
  Reports old tracked folders as awaiting import and old untracked folders separately.
  It never imports, deletes, or changes matching thresholds.
- The latest report is `/var/lib/homelab/storage-report.json`. Folder age uses its
  directory modification time, not a guaranteed download-completion timestamp.
  Incomplete or unavailable API checks fail the service rather than reporting healthy.
- Alerts are written to the journal and make the service fail. Set `ALERT_WEBHOOK`
  to receive external notifications; an empty webhook provides local reporting only.
- `task-image-prune.timer`: Sundays around 03:00. Runs rootful image-only pruning,
  with no volume or container pruning. The age filter uses image creation time,
  not last use or pull time. Backups and pruning share a lock.
- Journald is bounded to 1 GiB, with 10 GiB kept free and a 14-day age limit.

```sh
sudo systemctl start task-storage-report.service
sudo journalctl -u task-storage-report.service
sudo systemctl list-timers 'task-*'
```

## NAS and service compatibility

Seven native mount units manage `/var/mnt/{tv,movies,music,books,software,games,services}`.
CoreOS exposes these through `/mnt`. Each media consumer requires its own mounts,
checks the CIFS source before starting, and stops if those mounts are deactivated.
An unavailable CIFS server can still leave a mounted filesystem blocked on I/O;
mount presence alone is not a network-health check.

`task-shared.service` configures SELinux CIFS access. Startup no longer recursively
changes ownership of application state or downloads. Fresh staging directories use
911:911, and the Plex transcode directory uses 1000:1000.

| Service | Host port | Container port | Application identity |
| --- | --- | --- | --- |
| Sonarr | 8080 | 8989 | 911:911 |
| Lidarr | 8082 | 8686 | 911:911 |
| Radarr | 8083 | 7878 | 911:911 |
| Prowlarr | 8084 | 9696 | 911:911 |
| SABnzbd | 8085 | 8085 | 911:911 |
| Bookshelf (`readarr`) | 8086 | 8787 | 911:911 |
| Bazarr | 8087 | 6767 | 911:911 |
| Nginx Proxy Manager | 80, 81, 443 | same | Vendor-managed initialization |
| Plex | host network | native ports | Plex 1000:1000 |
| Homebridge | host network | native ports | Vendor-managed initialization |

LinuxServer images start their vendor init as root and drop the application to
`PUID=911`, `PGID=911`, matching the observed configuration ownership. Plex and
Homebridge retain host networking for discovery. Other applications use the named
Podman bridges. These bridges permit egress; `internal-net` is a name, not a firewall.
The published host ports preserve existing LAN clients and proxy upstreams.

Images are pulled only when missing. Updates are explicit: record the current
image digest, pull the reviewed new image, restart one service, and verify it.
To roll back, pull/run the recorded digest and restore its previous unit definition.
An unused local rollback image can be removed by scheduled pruning, so retain
the digest and registry access. Bookshelf remains pinned to its existing digest.

## Backup and restore

The daily 04:00 backup stops the currently running `container-*.service` units,
archives `/var/services` with numeric ownership, ACLs and xattrs, and restarts that
same set of units. This includes nightly application and reverse-proxy downtime.
Large Plex state can extend the downtime. Plex caches, logs and crash reports are
excluded; metadata and databases are included. Downloads and NAS media are excluded.

Snapshots live at `/mnt/services/homelab-backups/<UTC timestamp>-<pid>/` and contain:

- `services.tar`, `services.tar.sha256`;
- `active-units`, the services running before the backup;
- `complete`, written only after archiving, hashing and archive-read validation.

Only complete snapshots are published through `latest` and considered for retention.
An interrupted backup leaves a `.partial-*` directory for inspection. A normal error
or termination attempts to restart the original units. After a hard kill, power
loss, or restart failure, inspect `active-units` and explicitly restore those services.
Partials and legacy rsync backups are not automatically deleted.

The NAS share credentials must restrict access to these archives: they contain API
keys and application credentials. CIFS mode bits alone do not enforce NAS ACLs.

```sh
# Manual consistent backup (uses the same lock as the scheduled task).
sudo env BACKUP_KEEP=7 /usr/bin/sh /var/scripts/backup.sh

# Restore latest, or supply an explicit snapshot ID.
sudo /usr/bin/sh /var/scripts/restore.sh
```

Restore verifies the marker, checksum, and archive readability before stopping
anything. It asks for confirmation, moves the current state to
`/var/services.before-<timestamp>-<pid>`, then restores ownership and SELinux labels.
If extraction fails, containers remain stopped and the previous tree is retained.
Allow enough local disk for both trees. Review and remove old trees manually after
verification; restore does not automatically discard them.

Before relying on the backup, perform a restore in an isolated disposable host:
verify SQLite integrity and application startup against the restored configuration,
without connecting duplicate applications to the production download clients.
Automated tests cover archive round trips and SQLite contents, corrupt checksums,
wrong mounts, archive failure, restart behavior, and retention. They do not replace
an actual restore drill with the installed application versions.

## Existing-host rollout

Ignition is for first boot. `make build` does not update an installed host. Use a
maintenance window for the following sequence, reviewing rendered changes first:

1. Check `/var` free space, current mounts, application owners, published ports, and
   active services. Confirm 150 GiB is an appropriate reserve and configure the alert
   destination. Save the current unit files, scripts, and SAB configuration securely.
2. Stage the new backup, shared-state, and mount-check scripts. Create and verify a
   consistent snapshot of the current running installation before changing its units.
   Existing CIFS mounts are sufficient for the backup script's mount check.
3. Render with `make generate`. Treat `build/` as secret material. Validate with
   `make lint` on Fedora/Linux with the required tools. Native systemd verification
   runs against properly named rendered units, not `.template` files.
4. Stop the affected application units. Install the reviewed scripts, service list,
   storage environment file, journald drop-in, mount units and container/task units
   at their paths in `storage.yaml.template`. Keep existing state and credentials.
5. Run `systemctl daemon-reload`. Verify/adopt the existing CIFS mounts through the
   matching `var-mnt-*.mount` units; compare their options before any remount. Start
   `task-shared.service` and `task-networks.service`. Do not remount under running apps.
6. Leave `task-deps.service` and `task-services.service` disabled on this existing
   installation. The dependency initializer installs packages and reboots. Service
   initialization is for fresh provisioning, not a live-state migration.
7. Restart applications individually. Verify SAB's port, reserve and health check;
   the *arr client and Nginx upstream connections; service UIDs; and actual CIFS
   access. A small controlled import should land on the NAS before broader use.
8. Restart journald to load its drop-in. Enable/start `task-backup.timer`,
   `task-storage-report.timer`, and `task-image-prune.timer`; confirm their next runs.
   Persistent timers can run missed work immediately. Run a report and verify alert
   delivery, then inspect the first scheduled backup and recovery behavior.

If validation fails, stop the changed services, restore the saved unit/script files,
reload systemd, and restart the recorded original units/images. Keep mounts in place
until consumers are stopped. A configuration/data rollback uses a verified snapshot
and the restore procedure above.

Fresh initialization uses `config/services` as its service list, avoiding stale
references such as `n8n`. It never repeatedly restores over prepared state after a
failed service start. Existing local state requires explicit adoption via the
root-owned `/var/lib/homelab/services-prepared` marker after review. A legacy NAS
rsync backup without a new snapshot blocks automatic initialization rather than
silently starting with empty configuration.
