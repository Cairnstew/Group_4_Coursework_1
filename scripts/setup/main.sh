#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: .env file not found at ${ENV_FILE}"
  echo "       Add a .env file to the repo root and fill in your GitHub details."
  exit 1
fi

source "${ENV_FILE}"

if [ "${GITHUB_TOKEN:-your_personal_access_token_here}" = "your_personal_access_token_here" ]; then
  echo "ERROR: GITHUB_TOKEN is still the placeholder value in .env — update it first."
  exit 1
fi

run_step() {
  local step="$1"
  local label="$2"
  echo ""
  echo "===== ${label} ====="
  bash "${SCRIPT_DIR}/${step}"
}

run_step 01_install_jenkins.sh       "STEP 1: Install Jenkins"
run_step 02_install_docker.sh        "STEP 2: Install Docker"
run_step 03_install_sonar_scanner.sh "STEP 3: Install Sonar Scanner"
run_step 04_start_sonarqube.sh       "STEP 4: Start SonarQube"
run_step 05_configure_sonarqube.sh   "STEP 5: Configure SonarQube"
run_step 06_configure_jenkins.sh     "STEP 6: Configure Jenkins"
run_step 07_create_jenkins_job.sh    "STEP 7: Create Jenkins Job"

PUBLIC_IP=$(curl -sf --max-time 5 http://checkip.amazonaws.com 2>/dev/null || echo "localhost")

echo ""
echo "══════════════════════════════════════════════════════"
echo "✅  ALL SETUP COMPLETE"
echo ""
echo "  Jenkins:    http://${PUBLIC_IP}:8080  (admin / admin)"
echo "  SonarQube:  http://${PUBLIC_IP}:9000  (admin / admin)"
echo "══════════════════════════════════════════════════════"