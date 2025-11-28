---
systemd:
  units:
    - name: task-deps.service
      enabled: true
    - name: task-shared.service
      enabled: true
    - name: task-networks.service
      enabled: true
    - name: task-services.service
      enabled: true
    - name: task-backup.timer
      enabled: true
    - name: container-homebridge.service
      enabled: false
    - name: container-nginx.service
      enabled: false
    - name: container-bazarr.service
      enabled: false
    - name: container-lidarr.service
      enabled: false
    - name: container-plex.service
      enabled: false
    - name: container-prowlarr.service
      enabled: false
    - name: container-radarr.service
      enabled: false
    - name: container-readarr.service
      enabled: false
    - name: container-sabnzbd.service
      enabled: false
    - name: container-sonarr.service
      enabled: false
    - name: container-whisper.service
      enabled: false
