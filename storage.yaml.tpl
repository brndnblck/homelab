---
storage:
  directories:
    - path: /etc/smb
      mode: 0700
      user:
        name: root
      group:
        name: root
    - path: /var/scripts
      mode: 0700
      user:
        name: root
      group:
        name: root
    - path: /var/downloads
      mode: 0777
      user:
        name: core
      group:
        name: core
    - path: /var/services
      mode: 0777
      user:
        name: core
      group:
        name: core
    - path: /var/home/core/.config
      mode: 0777
      user:
        name: core
      group:
        name: core
  files:
    - path: /etc/smb/credentials
      mode: 0600
      overwrite: true
      contents:
        local: security/credentials
      user:
        name: root
      group:
        name: root
    - path: /var/home/core/.config/starship.toml
      mode: 0755
      overwrite: true
      contents:
        local: profile/starship.toml
      user:
        name: core
      group:
        name: core
    - path: /var/home/core/.zshrc
      mode: 0755
      overwrite: true
      contents:
        local: profile/.zshrc
      user:
        name: core
      group:
        name: core
    - path: /var/scripts/backup.sh
      mode: 0755
      overwrite: true
      contents:
        local: scripts/backup.sh
      user:
        name: root
      group:
        name: root
    - path: /var/scripts/init-deps.sh
      mode: 0755
      overwrite: true
      contents:
        local: scripts/init-deps.sh
      user:
        name: root
      group:
        name: root
    - path: /var/scripts/init-shared.sh
      mode: 0755
      overwrite: true
      contents:
        local: scripts/init-shared.sh
      user:
        name: root
      group:
        name: root
    - path: /var/scripts/init-services.sh
      mode: 0755
      overwrite: true
      contents:
        local: scripts/init-services.sh
      user:
        name: root
      group:
        name: root
    - path: /var/scripts/init-networks.sh
      mode: 0755
      overwrite: true
      contents:
        local: scripts/init-networks.sh
      user:
        name: root
      group:
        name: root
    - path: /var/scripts/restore.sh
      mode: 0755
      overwrite: true
      contents:
        local: scripts/restore.sh
      user:
        name: root
      group:
        name: root
    - path: /etc/systemd/system/task-deps.service
      mode: 0644
      contents:
        local: services/task-deps.service
    - path: /etc/systemd/system/task-shared.service
      mode: 0644
      contents:
        local: services/task-shared.service
    - path: /etc/systemd/system/task-backup.service
      mode: 0644
      contents:
        local: services/task-backup.service
    - path: /etc/systemd/system/task-backup.timer
      mode: 0644
      contents:
        local: services/task-backup.timer
    - path: /etc/systemd/system/container-homebridge.service
      mode: 0644
      contents:
        local: services/container-homebridge.service
    - path: /etc/systemd/system/container-nginx.service
      mode: 0644
      contents:
        local: services/container-nginx.service
    - path: /etc/systemd/system/container-bazarr.service
      mode: 0644
      contents:
        local: services/container-bazarr.service
    - path: /etc/systemd/system/container-lidarr.service
      mode: 0644
      contents:
        local: services/container-lidarr.service
    - path: /etc/systemd/system/container-plex.service
      mode: 0644
      contents:
        local: services/container-plex.service
    - path: /etc/systemd/system/container-prowlarr.service
      mode: 0644
      contents:
        local: services/container-prowlarr.service
    - path: /etc/systemd/system/container-radarr.service
      mode: 0644
      contents:
        local: services/container-radarr.service
    - path: /etc/systemd/system/container-readarr.service
      mode: 0644
      contents:
        local: services/container-readarr.service
    - path: /etc/systemd/system/container-sabnzbd.service
      mode: 0644
      contents:
        local: services/container-sabnzbd.service
    - path: /etc/systemd/system/container-sonarr.service
      mode: 0644
      contents:
        local: services/container-sonarr.service

    - path: /etc/systemd/system/task-networks.service
      mode: 0644
      contents:
        local: services/task-networks.service
    - path: /etc/systemd/system/task-services.service
      mode: 0644
      contents:
        local: services/task-services.service
    - path: /etc/systemd/system/container-whisper.service
      mode: 0644
      contents:
        local: services/container-whisper.service
