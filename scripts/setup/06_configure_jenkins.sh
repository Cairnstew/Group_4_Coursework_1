#!/bin/bash
set -euo pipefail

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin"
JOB_NAME="job-01"
REPO_DIR="/var/lib/jenkins/workspace/${JOB_NAME}"
PUBLIC_IP=$(curl -sf --max-time 5 http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
# ── Sonar token ────────────────────────────────────────────────────────────────
if [ ! -f /tmp/sonar_token.txt ]; then
  echo "ERROR: /tmp/sonar_token.txt not found — run 05_configure_sonarqube.sh first"
  exit 1
fi
SONAR_TOKEN=$(cat /tmp/sonar_token.txt)

# ── Wait for Jenkins ───────────────────────────────────────────────────────────
echo "==> Waiting for Jenkins..."
MAX_WAIT=120
WAITED=0
until curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
    "${JENKINS_URL}/api/json" > /dev/null; do
  sleep 5
  WAITED=$((WAITED + 5))
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "ERROR: Jenkins did not respond after ${MAX_WAIT}s"
    exit 1
  fi
done
echo "==> Jenkins is up."

# ── Download Jenkins CLI ───────────────────────────────────────────────────────
echo "==> Downloading Jenkins CLI..."
if [ ! -f /tmp/jenkins-cli.jar ]; then
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

# ── Write sonar-project.properties ────────────────────────────────────────────
echo "==> Writing sonar-project.properties..."
mkdir -p "${REPO_DIR}"
cat > "${REPO_DIR}/sonar-project.properties" <<EOF
sonar.projectKey=java-jenkins-sonar
sonar.sources=.
sonar.host.url=http://localhost:9000
sonar.token=${SONAR_TOKEN}
EOF
chown -R jenkins:jenkins "${REPO_DIR}" 2>/dev/null || true