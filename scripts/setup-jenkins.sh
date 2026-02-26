#!/usr/bin/env bash

# Exit on error, unset vars, or failed pipes
set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Must run as root / sudo ────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  error "Please run with sudo: sudo ./setup-jenkins.sh"
  exit 1
fi

# ── Check OS ───────────────────────────────────────────────────────────────────
if ! grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
  error "This script only supports Ubuntu/Debian systems."
  exit 1
fi

# ── 1. Java ────────────────────────────────────────────────────────────────────
if java -version &>/dev/null; then
  info "Java already installed: $(java -version 2>&1 | head -1)"
else
  info "Installing Java 17 and dependencies..."
  apt-get update -qq
  apt-get install -y ca-certificates fontconfig openjdk-17-jre default-jdk
  info "Java installed: $(java -version 2>&1 | head -1)"
fi

# ── 2. Jenkins apt repo & keyring ─────────────────────────────────────────────
# Jenkins rotated signing keys in Dec 2025 — must use jenkins.io-2026.key
# Modern apt handles armored .asc keys directly; no gpg --dearmor needed
KEYRING="/usr/share/keyrings/jenkins-keyring.asc"
SOURCES="/etc/apt/sources.list.d/jenkins.list"

# Clean up any previously broken key files from old installs
rm -f /usr/share/keyrings/jenkins-keyring.gpg

info "Downloading Jenkins GPG key (2026)..."
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2026.key \
  | tee "$KEYRING" > /dev/null
info "Jenkins GPG key saved ✔"

info "Adding Jenkins apt repository..."
echo "deb [signed-by=${KEYRING}] https://pkg.jenkins.io/debian binary/" \
  | tee "$SOURCES" > /dev/null

# ── 3. Install Jenkins ─────────────────────────────────────────────────────────
info "Running apt-get update..."
apt-get update -qq

if dpkg -s jenkins &>/dev/null; then
  info "Jenkins already installed — ensuring it is up to date..."
  apt-get install -y --only-upgrade jenkins
else
  info "Installing Jenkins..."
  apt-get install -y jenkins
fi

# ── 4. Start & enable service ──────────────────────────────────────────────────
info "Starting Jenkins service..."
systemctl start jenkins
systemctl enable jenkins

# ── 5. Status check ────────────────────────────────────────────────────────────
if systemctl is-active --quiet jenkins; then
  info "Jenkins is running ✔"
else
  error "Jenkins failed to start. Check logs: sudo journalctl -u jenkins -n 50"
  exit 1
fi

# ── 6. Helpful next-steps ──────────────────────────────────────────────────────
PUBLIC_IP=$(curl -sf http://checkip.amazonaws.com || echo "<your-ec2-ip>")

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN} Jenkins setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Open in browser:  http://${PUBLIC_IP}:8080"
echo ""
echo "  Unlock password:"
echo "    sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo ""
echo "  Useful commands:"
echo "    sudo systemctl status jenkins"
echo "    sudo journalctl -u jenkins -f"
echo ""
