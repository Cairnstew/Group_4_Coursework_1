#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [ -f "${ENV_FILE}" ]; then
  set -o allexport
  source "${ENV_FILE}"
  set +o allexport
fi

JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASS="${JENKINS_PASS:-admin}"
JOB_NAME="${JOB_NAME:-job-01}"
SONAR_URL="${SONAR_URL:-http://localhost:9000}"
SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-group4-dec2hex}"
SONAR_PROJECT_NAME="${SONAR_PROJECT_NAME:-Group4 Dec2Hex}"
PUBLIC_IP=$(curl -sf --max-time 5 http://checkip.amazonaws.com 2>/dev/null || echo "localhost")

# ── Sonar token ────────────────────────────────────────────────────────────────
if [ ! -f /tmp/sonar_token.txt ]; then
  echo "ERROR: /tmp/sonar_token.txt not found — run 05_configure_sonarqube.sh first"
  exit 1
fi
SONAR_TOKEN=$(cat /tmp/sonar_token.txt)

# ── Wait for Jenkins ───────────────────────────────────────────────────────────
echo "==> Waiting for Jenkins..."
MAX_WAIT=120; WAITED=0
until curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
    "${JENKINS_URL}/api/json" > /dev/null; do
  sleep 5; WAITED=$((WAITED + 5))
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "ERROR: Jenkins did not respond after ${MAX_WAIT}s"
    exit 1
  fi
done
echo "==> Jenkins is up."

# ── Download Jenkins CLI ───────────────────────────────────────────────────────
if [ ! -f /tmp/jenkins-cli.jar ]; then
  echo "==> Downloading Jenkins CLI..."
  curl -fL -u "${JENKINS_USER}:${JENKINS_PASS}" \
    "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" \
    --output /tmp/jenkins-cli.jar
else
  echo "==> CLI jar already present, skipping download."
fi
echo "==> Jenkins CLI ready."

# ── Install SonarQube plugin ───────────────────────────────────────────────────
echo "==> Installing SonarQube plugin..."
set +e
java -jar /tmp/jenkins-cli.jar \
  -s "${JENKINS_URL}" \
  -auth "${JENKINS_USER}:${JENKINS_PASS}" \
  install-plugin sonar -deploy
PLUGIN_EXIT=$?
set -e
if [ "$PLUGIN_EXIT" -ne 0 ]; then
  echo "ERROR: Plugin install failed with exit code ${PLUGIN_EXIT}"
  exit 1
fi
echo "==> Plugin installation complete."

# ── sonar-project.properties is written by the Jenkins build step itself ──────
echo "==> sonar-project.properties will be written by the Jenkins build step."

echo ""
echo "======================================================"
echo "✅ Jenkins configured."
echo "   Jenkins:   http://${PUBLIC_IP}:8080"
echo "   SonarQube: http://${PUBLIC_IP}:9000"
echo "======================================================"