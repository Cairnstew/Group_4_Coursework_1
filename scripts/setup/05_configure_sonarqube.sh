#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "${ENV_FILE}" ]; then
  set -o allexport
  source "${ENV_FILE}"
  set +o allexport
fi

SONAR_URL="${SONAR_URL:-http://localhost:9000}"
SONAR_USER="${SONAR_USER:-admin}"
SONAR_PASS="${SONAR_PASS:-admin}"

echo "==> Waiting for SonarQube..."
until curl -sf -u "${SONAR_USER}:${SONAR_PASS}" \
    "${SONAR_URL}/api/system/status" | grep -q '"status":"UP"'; do
  sleep 5
done

echo "==> Generating token..."
SONAR_TOKEN=$(curl -sf -u "${SONAR_USER}:${SONAR_PASS}" \
  -X POST "${SONAR_URL}/api/user_tokens/generate" \
  --data-urlencode "name=Jenkins" \
  --data-urlencode "type=USER_TOKEN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

echo "$SONAR_TOKEN" > /tmp/sonar_token.txt

echo "==> Creating webhook..."
PUBLIC_IP=$(curl -sf --max-time 5 http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
JENKINS_PORT="${JENKINS_URL:-http://localhost:8080}"
JENKINS_PORT="${JENKINS_PORT##*:}"

curl -sf -u "${SONAR_USER}:${SONAR_PASS}" \
  -X POST "${SONAR_URL}/api/webhooks/create" \
  --data-urlencode "name=Jenkins" \
  --data-urlencode "url=http://${PUBLIC_IP}:8080" \
  > /dev/null

echo "SonarQube configured."