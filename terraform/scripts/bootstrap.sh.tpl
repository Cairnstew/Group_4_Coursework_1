#!/bin/bash
set -e

echo "=== Updating system ==="
apt-get update -y
apt-get upgrade -y

echo "=== Installing Docker ==="
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

echo "=== Installing Docker Compose plugin ==="
apt-get install -y docker-compose-plugin

echo "=== Setting kernel params for SonarQube ==="
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sysctl -w vm.max_map_count=262144

echo "=== Creating app directory ==="
mkdir -p /opt/app/jenkins/jobs

cat > /opt/app/docker-compose.yaml <<'COMPOSE'
${docker_compose}
COMPOSE

cat > /opt/app/jenkins/Dockerfile <<'DOCKERFILE'
${dockerfile}
DOCKERFILE

cat > /opt/app/jenkins/casc.yaml <<'CASC'
${jenkins_casc}
CASC


echo "=== Starting SonarQube ==="
docker compose -f /opt/app/docker-compose.yaml up -d sonarqube sonarqube_db

echo "=== Waiting for SonarQube to be ready (this may take a few minutes) ==="
until curl -sf http://localhost:9000/api/system/status | grep -q '"status":"UP"'; do
  echo "SonarQube not ready yet, retrying in 10s..."
  sleep 10
done

echo "=== Generating SonarQube token ==="
# Retry token generation in case admin setup isn't complete
for i in {1..5}; do
  SONAR_TOKEN=$(curl -sf -u admin:admin -X POST \
    "http://localhost:9000/api/user_tokens/generate" \
    -d "name=jenkins-token" | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])" 2>/dev/null) && break
  echo "Token generation failed, retrying in 10s..."
  sleep 10
done

if [ -z "$SONAR_TOKEN" ]; then
  echo "ERROR: Failed to generate SonarQube token after 5 attempts"
  exit 1
fi

echo "=== Starting Jenkins ==="
# Remove any pre-existing jenkins_home volume so CasC starts fresh
# (prevents the initial-admin-password from blocking CasC login)
docker volume rm app_jenkins_home 2>/dev/null || true
SONAR_TOKEN=$SONAR_TOKEN docker compose -f /opt/app/docker-compose.yaml up -d jenkins

echo "=== Done ==="