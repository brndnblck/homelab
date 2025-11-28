[Unit]
Description=Mount Shared Drives
After=syslog.target network-online.target
Requires=network-online.target
BindsTo=network-online.target

[Service]
User=root
Type=oneshot
ExecStart=/usr/bin/sh /var/scripts/init-shared.sh
RemainAfterExit=yes
Restart=on-failure

[Install]
WantedBy=multi-user.target
