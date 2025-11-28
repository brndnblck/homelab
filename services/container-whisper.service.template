[Unit]
Description=Whisper
After=podman.service task-networks.service
Requires=podman.service task-networks.service

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
ExecStartPre=/usr/bin/podman pull onerahmet/openai-whisper-asr-webservice:latest
ExecStart=/usr/bin/podman run --replace --rm --name %n --cgroups=split \
  --network internal-net \
  --user 1000:1000 \
  --read-only-tmpfs \
  --security-opt no-new-privileges \
  --health-cmd="curl -f http://localhost:9000/health || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --health-start-period=120s \
  -e TZ=America/Los_Angeles \
  -e ASR_MODEL=small \
  -e ASR_ENGINE=faster_whisper \
  onerahmet/openai-whisper-asr-webservice:latest

[Install]
WantedBy=multi-user.target
