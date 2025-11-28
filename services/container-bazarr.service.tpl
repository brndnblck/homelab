[Unit]
Description=Bazarr
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
ExecStartPre=/usr/bin/podman pull lscr.io/linuxserver/bazarr:latest
ExecStart=/usr/bin/podman run --rm --replace --name %n --cgroups=split \
  --user 1000:1000 \
  --network internal-net \
  --health-cmd="curl -f http://localhost:6767 || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=120s \
  -e TZ=America/Los_Angeles \
  -v /var/services/bazarr:/config:z \
  -v /mnt/movies:/movies:z \
  -v /mnt/tv:/tv:z \
  lscr.io/linuxserver/bazarr:latest

[Install]
WantedBy=multi-user.target
