#!/bin/bash
set -euo pipefail

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin"
JOB_NAME="job-01"
REPO_DIR="/var/lib/jenkins/workspace/${JOB_NAME}"
SONAR_TOKEN=$(cat /tmp/sonar_token.txt)
PUBLIC_IP=$(curl -sf http://checkip.amazonaws.com || echo "localhost")

echo "==> Waiting for Jenkins..."
until curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
    "${JENKINS_URL}/api/json" > /dev/null; do
  sleep 5
done

CRUMB=$(curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
  "${JENKINS_URL}/crumbIssuer/api/json" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['crumbRequestField']+':'+d['crumb'])")

echo "==> Installing Sonar plugin..."
curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
  -H "${CRUMB}" \
  -X POST "${JENKINS_URL}/pluginManager/installNecessaryPlugins" \
  -d '<install plugin="sonar@latest" />'

sleep 30

echo "==> Writing sonar-project.properties..."
cat > "${REPO_DIR}/sonar-project.properties" <<EOF
sonar.projectKey=java-jenkins-sonar
sonar.sources=.
EOF

echo "Jenkins configured."