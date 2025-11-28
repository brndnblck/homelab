[Unit]
Description=Lidarr
After=podman.service task-shared.service task-networks.service
Requires=podman.service task-shared.service task-networks.service

[Service]
TimeoutStopSec=30
TimeoutStartSec=120
Type=simple
Restart=on-failure
RestartSec=10s
StartLimitBurst=3
StartLimitInterval=300s
StandardOutput=journal
StandardError=journal
ExecStartPre=/usr/bin/podman pull lscr.io/linuxserver/lidarr:latest
ExecStart=/usr/bin/podman run --replace --rm --name %n --cgroups=split \
  --user 1000:1000 \
  --network internal-net \
  --health-cmd="curl -f http://localhost:8686 || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=120s \
  -e TZ=America/Los_Angeles \
  -v /var/services/lidarr:/config:z \
  -v /var/downloads:/downloads:z \
  -v /mnt/music:/music \
  lscr.io/linuxserver/lidarr:latest

[Install]
WantedBy=multi-user.target
