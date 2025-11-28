[Unit]
Description=Plex
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
ExecStartPre=-/usr/bin/podman pull docker.io/plexinc/pms-docker
ExecStart=/usr/bin/podman run -h Black --replace --rm --name %n \
  --network external-net \
  --cgroups=split \
  --user 1000:1000 \
  --read-only \
  --cap-drop=ALL \
  --tmpfs /tmp \
  --health-cmd="curl -f http://localhost:32400/web || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=120s \
  -e TZ=America/Los_Angeles \
   -e PLEX_CLAIM=$PLEX_CLAIM \
  -p 32400:32400/tcp -p 8324:8324/tcp -p 32469:32469/tcp \
  -p 1900:1900/udp -p 32410:32410/udp -p 32412:32412/udp \
  -p 32413:32413/udp -p 32414:32414/udp \
  -v /var/services/plex/config:/config:z \
  -v /var/downloads/transcode:/transcode:z \
  -v /mnt/tv:/data/TV:z \
  -v /mnt/music:/data/Music:z \
  -v /mnt/movies:/data/Movies \
  docker.io/plexinc/pms-docker

[Install]
WantedBy=multi-user.target

