[Unit]
Description=Daily Backup
After=task-shared.service
Requires=task-shared.service

[Service]
Type=oneshot
ExecStart=/usr/bin/sh /var/scripts/backup.sh
User=root
StandardOutput=journal
StandardError=journal
