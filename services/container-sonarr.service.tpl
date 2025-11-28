[Unit]
Description=Sonarr
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
StandardError=journal
StandardOutput=journal
ExecStartPre=/usr/bin/podman pull lscr.io/linuxserver/sonarr:latest
ExecStart=/usr/bin/podman run --replace --rm --name %n --cgroups=split \
  --user 1000:1000 \
  --network internal-net \
  --health-cmd="curl -f http://localhost:8989 || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=120s \
  -e TZ=America/Los_Angeles \
  -v /var/services/sonarr:/config:z \
  -v /var/downloads:/downloads:z \
  -v /mnt/tv:/tv:z \
  lscr.io/linuxserver/sonarr:latest

[Install]
WantedBy=multi-user.target
