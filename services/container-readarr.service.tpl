[Unit]
Description=Readarr
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
ExecStartPre=/usr/bin/podman pull lscr.io/linuxserver/readarr:develop
ExecStart=/usr/bin/podman run --replace --rm --name %n --cgroups=split \
  --network internal-net \
  --user 1000:1000 \
  --read-only-tmpfs \
  --security-opt no-new-privileges \
  --health-cmd="curl -f http://localhost:8787 || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=120s \
  -e TZ=America/Los_Angeles \
  -v /var/services/readarr:/config:z \
  -v /var/downloads:/downloads:z \
  -v /mnt/books:/books:z \
  ghcr.io/pennydreadful/bookshelf:hardcover-v0.4.20.91@sha256:eb2cb4a291e5f755e76d68c2be7e1da11f23724d6b9a5934b00388bd2e4212c6

[Install]
WantedBy=multi-user.target
