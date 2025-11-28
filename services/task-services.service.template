[Unit]
Description=Initialize Service Configuration
After=task-shared.service task-deps.service
Requires=task-shared.service
# Only run after deps has completed (fresh install) or if deps is disabled (existing install)
ConditionPathExists=!/var/run/task-deps.lock

[Service]
User=root
Type=oneshot
ExecStart=/usr/bin/sh /var/scripts/init-services.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
