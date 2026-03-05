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
PUBLIC_IP=$(curl -sf --max-time 5 http://checkip.amazonaws.com 2>/dev/null || echo "localhost")

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

# ── Plugin installation and job creation are handled by 07 ───────────────────
echo ""
echo "======================================================"
echo "✅ Jenkins is up and CLI is ready."
echo "   Jenkins:   http://${PUBLIC_IP}:8080"
echo "   Run 07_create_jenkins_job.sh to create the pipeline."
echo "======================================================"