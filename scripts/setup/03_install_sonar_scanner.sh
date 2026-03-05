#!/bin/bash
set -euo pipefail

INSTALL_DIR="/var/lib/jenkins/sonarqube"
SCANNER_VERSION="3.3.0.1492"
SCANNER_ZIP="sonar-scanner-cli-${SCANNER_VERSION}-linux.zip"
SCANNER_DIR="sonar-scanner-${SCANNER_VERSION}-linux"
DOWNLOAD_URL="https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/${SCANNER_ZIP}"

# Detect Java dynamically — works regardless of Java version or install path
JAVA_BIN=$(readlink -f "$(which java)")
echo "==> Detected Java binary: ${JAVA_BIN}"

if [ ! -f "${JAVA_BIN}" ]; then
  echo "ERROR: Java binary not found at ${JAVA_BIN}"
  echo "       Make sure Java is installed before running this script."
  exit 1
fi

echo "==> Creating directory..."
sudo mkdir -p "$INSTALL_DIR"

# Skip download if already present
if [ -f "${INSTALL_DIR}/${SCANNER_ZIP}" ]; then
  echo "==> Scanner zip already present, skipping download."
else
  echo "==> Downloading sonar-scanner..."
  sudo wget -q --show-progress -P "$INSTALL_DIR" "$DOWNLOAD_URL"
fi

echo "==> Installing unzip..."
sudo apt-get install -y unzip

echo "==> Unzipping..."
sudo unzip -q "${INSTALL_DIR}/${SCANNER_ZIP}" -d "$INSTALL_DIR"

echo "==> Linking Java..."
sudo rm -f "${INSTALL_DIR}/${SCANNER_DIR}/jre/bin/java"
sudo ln -s "$JAVA_BIN" "${INSTALL_DIR}/${SCANNER_DIR}/jre/bin/java"

# Verify the symlink works
echo "==> Verifying symlink..."
ls -la "${INSTALL_DIR}/${SCANNER_DIR}/jre/bin/java"
"${INSTALL_DIR}/${SCANNER_DIR}/jre/bin/java" -version 2>&1 | head -1

echo "==> Setting ownership..."
sudo chown -R jenkins:jenkins "$INSTALL_DIR"

echo "==> Sonar scanner installed."