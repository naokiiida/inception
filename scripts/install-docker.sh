#!/bin/bash
# Docker installation script for Debian
# Run with: sudo bash install-docker.sh <username>

set -e

# Check if username is provided
if [ -z "$1" ]; then
    echo "Error: Username not provided"
    echo "Usage: sudo bash install-docker.sh <username>"
    exit 1
fi

LOGIN="$1"

echo "Installing Docker on Debian..."

# Install prerequisites
echo "Installing prerequisites..."
apt-get update
apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
echo "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list

# Install Docker
echo "Installing Docker packages..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker service
echo "Enabling Docker service..."
systemctl enable docker
systemctl start docker

# Add user to docker group
echo "Adding $LOGIN to docker group..."
usermod -aG docker "$LOGIN"

echo "Docker installation complete!"
echo "You may need to log out and back in for group changes to take effect."
echo "Or run: newgrp docker"

# Verify installation
docker --version
docker compose version
