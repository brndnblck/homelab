[Unit]
Description=Setup Dependencies
After=syslog.target network-online.target rpm-ostreed.service
Requires=network-online.target rpm-ostreed.service

[Service]
User=root
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/sh /var/scripts/init-deps.sh

[Install]
WantedBy=multi-user.target
