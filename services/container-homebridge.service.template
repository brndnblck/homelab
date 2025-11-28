[Unit]
Description=Homebridge
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
ExecStartPre=/usr/bin/podman pull docker.io/homebridge/homebridge:latest
ExecStart=/usr/bin/podman run --replace --rm --name %n \
  --network external-net \
  --cgroups=split \
  --user 1000:1000 \
  --read-only-tmpfs \
  --security-opt no-new-privileges \
  --health-cmd="curl -f http://localhost:8581 || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=120s \
  -e TZ=America/Los_Angeles \
  -p 8581:8581 \
  -v /var/services/homebridge:/homebridge:z \
  docker.io/homebridge/homebridge:latest

[Install]
WantedBy=multi-user.target


