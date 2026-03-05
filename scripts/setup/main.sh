#!/bin/bash
set -euo pipefail

chmod +x *.sh

echo "===== STEP 1: Install Jenkins ====="
./01_install_jenkins.sh

echo "===== STEP 2: Install Docker ====="
./02_install_docker.sh

echo "===== STEP 3: Install Sonar Scanner ====="
./03_install_sonar_scanner.sh

echo "===== STEP 4: Start SonarQube ====="
./04_start_sonarqube.sh

echo "===== STEP 5: Configure SonarQube ====="
./05_configure_sonarqube.sh

echo "===== STEP 6: Configure Jenkins ====="
./06_configure_jenkins.sh

PUBLIC_IP=$(curl -sf http://checkip.amazonaws.com || echo "localhost")

echo ""
echo "======================================================"
echo "✅ ALL SETUP COMPLETE"
echo ""
echo "SonarQube: http://${PUBLIC_IP}:9000"
echo "Jenkins:   http://${PUBLIC_IP}:8080"
echo ""
echo "Default SonarQube credentials: admin / admin"
echo "======================================================"

echo "===== ALL DONE ====="