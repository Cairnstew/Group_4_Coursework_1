#!/bin/bash
set -euo pipefail

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

echo "===== ALL DONE ====="