#!/bin/bash
set -euo pipefail

echo "==> Starting SonarQube container..."
sg docker -c "docker run -d --rm --name sonarqube-container -p 9000:9000 sonarqube"

PUBLIC_IP=$(curl -sf http://checkip.amazonaws.com || echo "localhost")

echo "SonarQube running at: http://${PUBLIC_IP}:9000"