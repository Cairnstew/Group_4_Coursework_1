#!/bin/bash
set -euo pipefail

INSTALL_DIR="/var/lib/jenkins/sonarqube"
SCANNER_VERSION="3.3.0.1492"
SCANNER_ZIP="sonar-scanner-cli-${SCANNER_VERSION}-linux.zip"
SCANNER_DIR="sonar-scanner-${SCANNER_VERSION}-linux"
DOWNLOAD_URL="https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/${SCANNER_ZIP}"
JAVA_BIN="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"

echo "==> Creating directory..."
sudo mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "==> Downloading sonar-scanner..."
sudo wget -q --show-progress "$DOWNLOAD_URL"

echo "==> Installing unzip..."
sudo apt-get install -y unzip

echo "==> Unzipping..."
sudo unzip -q "$SCANNER_ZIP"

echo "==> Linking Java 17..."
sudo rm -f "${INSTALL_DIR}/${SCANNER_DIR}/jre/bin/java"
sudo ln -s "$JAVA_BIN" "${INSTALL_DIR}/${SCANNER_DIR}/jre/bin/java"

echo "==> Setting ownership..."
sudo chown -R jenkins:jenkins "$INSTALL_DIR"

echo "==> Sonar scanner installed."