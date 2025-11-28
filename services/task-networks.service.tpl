[Unit]
Description=Initialize Podman Networks
After=podman.service
Requires=podman.service
Before=container-nginx.service container-radarr.service container-plex.service

[Service]
User=root
Type=oneshot
ExecStart=/usr/bin/sh /var/scripts/init-networks.sh
RemainAfterExit=yes
Restart=on-failure

[Install]
WantedBy=multi-user.target