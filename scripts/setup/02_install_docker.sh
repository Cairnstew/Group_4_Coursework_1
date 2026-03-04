#!/bin/bash
set -euo pipefail

echo "==> Removing any existing Docker installations..."
sudo apt-get -y remove --purge \
  docker docker-engine docker.io containerd runc \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin 2>/dev/null || true

sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

echo "==> Updating package list..."
sudo apt-get update

echo "==> Removing unscd..."
sudo apt-get -y remove unscd 2>/dev/null || true

echo "==> Installing prerequisites..."
sudo apt-get -y install \
  apt-transport-https ca-certificates curl \
  gnupg-agent software-properties-common

echo "==> Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

echo "==> Verifying Docker GPG key fingerprint..."
sudo apt-key fingerprint 0EBFCD88

echo "==> Adding Docker repository..."
sudo add-apt-repository -y \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "==> Updating package list..."
sudo apt-get update

echo "==> Installing Docker..."
sudo apt-get -y install docker-ce docker-ce-cli containerd.io

echo "==> Configuring Docker group..."
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"