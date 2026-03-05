#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

# ── Load .env ─────────────────────────────────────────────────────────────────
if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: .env file not found at ${ENV_FILE}"
  exit 1
fi

set -o allexport
source "${ENV_FILE}"
set +o allexport

# ── Validate required values ──────────────────────────────────────────────────
for var in GITHUB_REPO GITHUB_USER GITHUB_TOKEN JENKINS_URL JENKINS_USER JENKINS_PASS SONAR_URL JOB_NAME; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: ${var} is not set in .env"
    exit 1
  fi
done

if [ "${GITHUB_TOKEN}" = "your_personal_access_token_here" ]; then
  echo "ERROR: GITHUB_TOKEN is still the placeholder value — update your .env file"
  exit 1
fi

# ── Sonar token ───────────────────────────────────────────────────────────────
if [ ! -f /tmp/sonar_token.txt ]; then
  echo "ERROR: /tmp/sonar_token.txt not found — run 05_configure_sonarqube.sh first"
  exit 1
fi
SONAR_TOKEN=$(cat /tmp/sonar_token.txt)
PUBLIC_IP=$(curl -sf --max-time 5 http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
BRANCH="${GITHUB_BRANCH:-*/main}"
SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-group4-dec2hex}"
SONAR_PROJECT_NAME="${SONAR_PROJECT_NAME:-Group4 Dec2Hex}"
SCANNER_BIN="/var/lib/jenkins/sonarqube/sonar-scanner-3.3.0.1492-linux/bin/sonar-scanner"

# ── Debug: print resolved config ──────────────────────────────────────────────
echo ""
echo "==> Config:"
echo "    JENKINS_URL:        ${JENKINS_URL}"
echo "    SONAR_URL:          ${SONAR_URL}"
echo "    GITHUB_REPO:        ${GITHUB_REPO}"
echo "    BRANCH:             ${BRANCH}"
echo "    JOB_NAME:           ${JOB_NAME}"
echo "    SONAR_PROJECT_KEY:  ${SONAR_PROJECT_KEY}"
echo "    SONAR_TOKEN:        ${SONAR_TOKEN:0:8}... (truncated)"
echo "    SCANNER_BIN:        ${SCANNER_BIN}"
echo ""

# ── Debug: verify sonar-scanner exists ────────────────────────────────────────
echo "==> Checking sonar-scanner binary..."
if [ -f "${SCANNER_BIN}" ]; then
  echo "    Found: ${SCANNER_BIN}"
else
  echo "    WARNING: sonar-scanner not found at ${SCANNER_BIN}"
  echo "    Searching for it..."
  find /var/lib/jenkins -name "sonar-scanner" -type f 2>/dev/null || echo "    Not found anywhere under /var/lib/jenkins"
fi

# ── Debug: verify SonarQube is reachable ──────────────────────────────────────
echo "==> Checking SonarQube is reachable..."
SONAR_STATUS=$(curl -sf --max-time 10 "${SONAR_URL}/api/system/status" 2>/dev/null || echo "UNREACHABLE")
echo "    SonarQube status: ${SONAR_STATUS}"

# ── Helpers ───────────────────────────────────────────────────────────────────
COOKIE_JAR="/tmp/jenkins-cookies.txt"

fetch_crumb() {
  rm -f "${COOKIE_JAR}"
  CRUMB_JSON=$(curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
    --cookie "${COOKIE_JAR}" --cookie-jar "${COOKIE_JAR}" \
    "${JENKINS_URL}/crumbIssuer/api/json")
  CRUMB_FIELD=$(echo "$CRUMB_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['crumbRequestField'])")
  CRUMB_VALUE=$(echo "$CRUMB_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['crumb'])")
}

cli() {
  java -jar /tmp/jenkins-cli.jar \
    -s "${JENKINS_URL}" \
    -auth "${JENKINS_USER}:${JENKINS_PASS}" \
    "$@"
}

# ── Wait for Jenkins ──────────────────────────────────────────────────────────
echo "==> Waiting for Jenkins..."
MAX_WAIT=120; WAITED=0
until curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" "${JENKINS_URL}/api/json" > /dev/null; do
  sleep 5; WAITED=$((WAITED+5))
  [ "$WAITED" -ge "$MAX_WAIT" ] && echo "ERROR: Jenkins timeout" && exit 1
done
echo "==> Jenkins is up."

# ── Ensure CLI jar is available ───────────────────────────────────────────────
if [ ! -f /tmp/jenkins-cli.jar ]; then
  echo "==> Downloading Jenkins CLI..."
  curl -fL -u "${JENKINS_USER}:${JENKINS_PASS}" \
    "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" \
    --output /tmp/jenkins-cli.jar
fi

# ── Ensure SonarQube plugin is installed ─────────────────────────────────────
echo "==> Ensuring SonarQube plugin is installed..."
set +e
cli install-plugin sonar -deploy 2>/dev/null
set -e
echo "==> SonarQube plugin ready."

# ── 1. Add GitHub credentials ────────────────────────────────────────────────
echo "==> Adding GitHub credentials to Jenkins..."
fetch_crumb

CRED_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
  -u "${JENKINS_USER}:${JENKINS_PASS}" \
  --cookie "${COOKIE_JAR}" --cookie-jar "${COOKIE_JAR}" \
  -H "${CRUMB_FIELD}:${CRUMB_VALUE}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -X POST "${JENKINS_URL}/credentials/store/system/domain/_/createCredentials" \
  --data-urlencode "json={
    \"\": \"0\",
    \"credentials\": {
      \"scope\": \"GLOBAL\",
      \"id\": \"github\",
      \"description\": \"GitHub Access Token\",
      \"username\": \"${GITHUB_USER}\",
      \"password\": \"${GITHUB_TOKEN}\",
      \"\$class\": \"com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl\"
    }
  }")
echo "==> GitHub credentials HTTP response: ${CRED_RESULT}"

# ── 2. Add SonarQube token credential ────────────────────────────────────────
echo "==> Adding SonarQube token credential to Jenkins..."
fetch_crumb

SONAR_CRED_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
  -u "${JENKINS_USER}:${JENKINS_PASS}" \
  --cookie "${COOKIE_JAR}" --cookie-jar "${COOKIE_JAR}" \
  -H "${CRUMB_FIELD}:${CRUMB_VALUE}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -X POST "${JENKINS_URL}/credentials/store/system/domain/_/createCredentials" \
  --data-urlencode "json={
    \"\": \"0\",
    \"credentials\": {
      \"scope\": \"GLOBAL\",
      \"id\": \"sonarqube-token\",
      \"description\": \"SonarQube Auth Token\",
      \"secret\": \"${SONAR_TOKEN}\",
      \"\$class\": \"org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl\"
    }
  }")
echo "==> SonarQube credential HTTP response: ${SONAR_CRED_RESULT}"

# ── 3. Create job ─────────────────────────────────────────────────────────────
echo "==> Creating Jenkins job: ${JOB_NAME}..."

set +e
cli get-job "${JOB_NAME}" > /dev/null 2>&1
JOB_EXISTS=$?
set -e
if [ "$JOB_EXISTS" -eq 0 ]; then
  echo "==> Job '${JOB_NAME}' already exists — recreating..."
  cli delete-job "${JOB_NAME}"
fi

cat > /tmp/job-config.xml <<XML
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <description>CI pipeline for Dec2Hex Python project — GCU SE &amp; DevOps CW1</description>
  <keepDependencies>false</keepDependencies>
  <properties/>

  <scm class="hudson.plugins.git.GitSCM" plugin="git">
    <configVersion>2</configVersion>
    <userRemoteConfigs>
      <hudson.plugins.git.UserRemoteConfig>
        <url>${GITHUB_REPO}</url>
        <credentialsId>github</credentialsId>
      </hudson.plugins.git.UserRemoteConfig>
    </userRemoteConfigs>
    <branches>
      <hudson.plugins.git.BranchSpec>
        <name>${BRANCH}</name>
      </hudson.plugins.git.BranchSpec>
    </branches>
    <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
    <submoduleCfg class="empty-list"/>
    <extensions/>
  </scm>

  <triggers>
    <hudson.triggers.SCMTrigger>
      <spec>* * * * *</spec>
      <ignorePostCommitHooks>false</ignorePostCommitHooks>
    </hudson.triggers.SCMTrigger>
  </triggers>

  <buildWrappers/>

  <builders>
    <hudson.tasks.Shell>
      <command>
set -x

echo "=== Environment ==="
echo "Working dir: \$(pwd)"
echo "Jenkins workspace: \${WORKSPACE:-not set}"
echo "Python: \$(python3 --version)"
echo "Files in workspace:"
ls -la

echo ""
echo "=== Checking SonarQube reachability ==="
curl -sf --max-time 10 "${SONAR_URL}/api/system/status" || echo "WARNING: SonarQube unreachable"

echo ""
echo "=== Running SonarQube Analysis ==="
${SCANNER_BIN} \
  -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
  -Dsonar.projectName="${SONAR_PROJECT_NAME}" \
  -Dsonar.sources=. \
  -Dsonar.language=py \
  -Dsonar.host.url=${SONAR_URL} \
  -Dsonar.token=${SONAR_TOKEN}

echo ""
echo "=== Running Dec2Hex with test values ==="
echo "--- Test: valid integer (255) ---"
python3 Dec2Hex.py 255

echo "--- Test: valid integer (16) ---"
python3 Dec2Hex.py 16

echo "--- Test: no argument (should show usage message) ---"
python3 Dec2Hex.py || true

echo "--- Test: non-integer input (should handle gracefully) ---"
python3 Dec2Hex.py hello || true

echo ""
echo "=== Running Unit Tests ==="
python3 -m pytest test_Dec2Hex.py -v || true
      </command>
    </hudson.tasks.Shell>
  </builders>

  <publishers/>
  <concurrentBuild>false</concurrentBuild>
</project>
XML

echo "==> Job XML written to /tmp/job-config.xml"
echo "==> Branch in XML: $(grep -o '<name>[^<]*</name>' /tmp/job-config.xml | head -1)"

cli create-job "${JOB_NAME}" < /tmp/job-config.xml
echo "==> Job '${JOB_NAME}' created."

# ── 5. Write sonar-project.properties to workspace ───────────────────────────
echo "==> Writing sonar-project.properties..."
WORKSPACE="/var/lib/jenkins/workspace/${JOB_NAME}"
mkdir -p "${WORKSPACE}"
cat > "${WORKSPACE}/sonar-project.properties" <<EOF
sonar.projectKey=${SONAR_PROJECT_KEY}
sonar.projectName=${SONAR_PROJECT_NAME}
sonar.sources=.
sonar.language=py
sonar.host.url=${SONAR_URL}
sonar.token=${SONAR_TOKEN}
EOF
chown -R jenkins:jenkins "${WORKSPACE}" 2>/dev/null || true
echo "==> sonar-project.properties written."

# ── 6. Trigger initial build and show output ──────────────────────────────────
echo "==> Triggering initial build..."
set +e
cli build "${JOB_NAME}" -s
BUILD_STATUS=$?
set -e

echo ""
echo "==> Build finished with status: ${BUILD_STATUS}. Fetching console output..."
echo "────────────────────────────────────────────────"
cli console "${JOB_NAME}" 1 || true
echo "────────────────────────────────────────────────"

if [ "$BUILD_STATUS" -ne 0 ]; then
  echo "❌ Build FAILED — see console output above"
  exit 1
fi

echo ""
echo "══════════════════════════════════════════════════════"
echo "✅  Pipeline is live!"
echo ""
echo "  Jenkins:   http://${PUBLIC_IP}:8080"
echo "  job-01:    http://${PUBLIC_IP}:8080/job/${JOB_NAME}/"
echo "  SonarQube: http://${PUBLIC_IP}:9000"
echo ""
echo "  Push a change to GitHub to trigger an automatic build."
echo "══════════════════════════════════════════════════════"