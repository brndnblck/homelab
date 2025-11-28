[Unit]
Description=Prowlarr
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
ExecStartPre=/usr/bin/podman pull lscr.io/linuxserver/prowlarr:latest
ExecStart=/usr/bin/podman run --replace --rm --name %n --cgroups=split \
  --network internal-net \
  --user 1000:1000 \
  --read-only-tmpfs \
  --security-opt no-new-privileges \
  --health-cmd="curl -f http://localhost:9696 || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=120s \
  -e TZ=America/Los_Angeles \
  -v /var/services/prowlarr:/config:z \
  lscr.io/linuxserver/prowlarr:latest

[Install]
WantedBy=multi-user.target
