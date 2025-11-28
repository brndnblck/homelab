[Unit]
Description=Radarr
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
ExecStartPre=/usr/bin/podman pull lscr.io/linuxserver/radarr:latest
ExecStart=/usr/bin/podman run --replace --rm --name %n --cgroups=split \
  --user 1000:1000 \
  --read-only \
  --cap-drop=ALL \
  --tmpfs /tmp \
  --network internal-net \
  --health-cmd="curl -f http://localhost:7878 || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=120s \
  -e TZ=America/Los_Angeles \
  -v /var/services/radarr:/config:z \
  -v /var/downloads:/downloads:z \
  -v /mnt/movies:/movies:z \
  lscr.io/linuxserver/radarr:latest

[Install]
WantedBy=multi-user.target
