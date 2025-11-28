[Unit]
Description=Nginx
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
ExecStartPre=/usr/bin/podman pull docker.io/jc21/nginx-proxy-manager:latest
ExecStart=/usr/bin/podman run --replace --rm --name %n --cgroups=split \
  --user 101:101 \
  --read-only \
  --cap-drop=ALL --cap-add=NET_BIND_SERVICE \
  --tmpfs /tmp \
  --tmpfs /var/run \
  --tmpfs /var/cache/nginx \
  --network external-net,internal-net \
  --health-cmd="curl -f http://localhost:81 || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=120s \
  -p 80:80 -p 81:81 -p 443:443 \
  -v /var/services/nginx:/data:z \
  -v /var/services/nginx/letsencrypt:/etc/letsencrypt:z \
  docker.io/jc21/nginx-proxy-manager:latest

[Install]
WantedBy=multi-user.target
