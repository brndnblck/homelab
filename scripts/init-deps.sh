#!/bin/sh
set -e

echo "[$(date)] Starting dependency setup..."

# Install packages
PACKAGES="tree vim htop tmux zsh eza podman-compose wget2"
echo "[$(date)] Installing packages: $PACKAGES"
rpm-ostree install -y --apply-live "$PACKAGES"

# Set system time zone to Pacific
echo "[$(date)] Setting timezone to America/Los_Angeles"
timedatectl set-timezone America/Los_Angeles

# Install starship prompt
echo "[$(date)] Installing starship prompt"
curl -fsSL https://starship.rs/install.sh | sh -s -- -y

# Create download folder structure
echo "[$(date)] Setting up download directories"
mkdir -p /var/downloads/complete /var/downloads/incomplete /var/downloads/nzb /var/downloads/transcode
mkdir -p /var/downloads/complete/tv /var/downloads/complete/movies /var/downloads/complete/music /var/downloads/complete/books /var/downloads/complete/games /var/downloads/complete/software /var/downloads/complete/other
chown -R core:core /var/downloads
chmod -R 775 /var/downloads

# Allow unprivileged port binding (persist across reboots)
echo "[$(date)] Configuring unprivileged port access"
echo 'net.ipv4.ip_unprivileged_port_start=80' > /etc/sysctl.d/99-unprivileged-ports.conf
sysctl net.ipv4.ip_unprivileged_port_start=80

# Create lock file and disable this service (run once only)
touch /var/run/task-deps.lock
systemctl disable task-deps.service
echo "[$(date)] Setup completed successfully. Rebooting..."

reboot
