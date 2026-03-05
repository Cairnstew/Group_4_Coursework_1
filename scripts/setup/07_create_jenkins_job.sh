#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
#  07_create_jenkins_job.sh
#
#  Reads config from .env in the same directory.
#  Run after 01–06 scripts have completed.
#
#  Usage:
#    sudo bash 07_create_jenkins_job.sh
# ══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# ── Load .env ─────────────────────────────────────────────────────────────────
if [ ! -f "${ENV_FILE}" ]; then
  echo "ERROR: .env file not found at ${ENV_FILE}"
  echo "       Copy .env.example to .env and fill in your details."
  exit 1
fi

set -o allexport
# shellcheck source=/dev/null
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

# ── Sonar token (written by 05_configure_sonarqube.sh) ───────────────────────
if [ ! -f /tmp/sonar_token.txt ]; then
  echo "ERROR: /tmp/sonar_token.txt not found — run 05_configure_sonarqube.sh first"
  exit 1
fi
SONAR_TOKEN=$(cat /tmp/sonar_token.txt)
PUBLIC_IP=$(curl -sf --max-time 5 http://checkip.amazonaws.com 2>/dev/null || echo "localhost")
BRANCH="${GITHUB_BRANCH:-*/main}"
SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-group4-dec2hex}"
SONAR_PROJECT_NAME="${SONAR_PROJECT_NAME:-Group4 Dec2Hex}"

# ── Helper: fetch crumb + session ─────────────────────────────────────────────
COOKIE_JAR="/tmp/jenkins-cookies.txt"

fetch_crumb() {
  rm -f "${COOKIE_JAR}"
  CRUMB_JSON=$(curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
    --cookie "${COOKIE_JAR}" --cookie-jar "${COOKIE_JAR}" \
    "${JENKINS_URL}/crumbIssuer/api/json")
  CRUMB_FIELD=$(echo "$CRUMB_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['crumbRequestField'])")
  CRUMB_VALUE=$(echo "$CRUMB_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['crumb'])")
}

# Jenkins CLI helper
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

curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
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
  }" > /dev/null

echo "==> GitHub credentials added (id: github)."

# ── 2. Add SonarQube token credential ────────────────────────────────────────
echo "==> Adding SonarQube token credential to Jenkins..."
fetch_crumb

curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
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
  }" > /dev/null

echo "==> SonarQube credential added (id: sonarqube-token)."

# ── 3. Configure SonarQube server + scanner via Groovy ───────────────────────
echo "==> Configuring SonarQube server and scanner in Jenkins..."
fetch_crumb

GROOVY_SCRIPT=$(cat <<GROOVY
import jenkins.model.*
import hudson.plugins.sonar.*
import hudson.plugins.sonar.model.*
import hudson.tools.*

def jenkins = Jenkins.getInstance()

// Configure SonarQube server
def sonarConfig = jenkins.getDescriptor(SonarGlobalConfiguration.class)
def installation = new SonarInstallation(
  "SonarQube",
  "${SONAR_URL}",
  "sonarqube-token",
  null, null, null, null, null, null
)
sonarConfig.setInstallations(installation)
sonarConfig.setBuildWrapperEnabled(true)
sonarConfig.save()

// Configure SonarQube Scanner tool
def scannerDesc = jenkins.getDescriptor(SonarRunnerInstallation.class)
def scannerProps = new InstallSourceProperty([new SonarRunnerInstaller("latest")])
def scanner = new SonarRunnerInstallation("SonarScanner", "", [scannerProps])
scannerDesc.setInstallations(scanner)
scannerDesc.save()

jenkins.save()
println "SonarQube configured successfully."
GROOVY
)

curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
  --cookie "${COOKIE_JAR}" --cookie-jar "${COOKIE_JAR}" \
  -H "${CRUMB_FIELD}:${CRUMB_VALUE}" \
  -X POST "${JENKINS_URL}/scriptText" \
  --data-urlencode "script=${GROOVY_SCRIPT}" \
  | grep -v "^$" || true

echo "==> SonarQube server and scanner configured."

# ── 4. Create job-01 ──────────────────────────────────────────────────────────
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
        <n>${BRANCH}</n>
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

  <buildWrappers>
    <hudson.plugins.sonar.SonarBuildWrapper plugin="sonar"/>
  </buildWrappers>

  <builders>
    <hudson.plugins.sonar.SonarRunnerBuilder plugin="sonar">
      <installationName>SonarScanner</installationName>
      <project>sonar-project.properties</project>
      <properties>
sonar.projectKey=${SONAR_PROJECT_KEY}
sonar.projectName=${SONAR_PROJECT_NAME}
sonar.sources=.
sonar.language=py
      </properties>
      <javaOpts/>
      <additionalArguments/>
      <jdk>(Inherit From Job)</jdk>
    </hudson.plugins.sonar.SonarRunnerBuilder>

    <hudson.tasks.Shell>
      <command>
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

cli create-job "${JOB_NAME}" < /tmp/job-config.xml
echo "==> Job '${JOB_NAME}' created."

# ── 5. Write sonar-project.properties to workspace ───────────────────────────
echo "==> Writing sonar-project.properties..."
REPO_DIR="/var/lib/jenkins/workspace/${JOB_NAME}"
mkdir -p "${REPO_DIR}"
cat > "${REPO_DIR}/sonar-project.properties" <<EOF
sonar.projectKey=${SONAR_PROJECT_KEY}
sonar.projectName=${SONAR_PROJECT_NAME}
sonar.sources=.
sonar.language=py
sonar.host.url=${SONAR_URL}
sonar.token=${SONAR_TOKEN}
EOF
chown -R jenkins:jenkins "${REPO_DIR}" 2>/dev/null || true

# ── 6. Trigger initial build ──────────────────────────────────────────────────
echo "==> Triggering initial build..."
cli build "${JOB_NAME}" -s
echo "==> Build complete."

# ── Done ──────────────────────────────────────────────────────────────────────
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