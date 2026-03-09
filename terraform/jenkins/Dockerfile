FROM jenkins/jenkins:lts-jdk21

ENV JAVA_OPTS=-Djenkins.install.runSetupWizard=false
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs

USER root
RUN apt-get update && apt-get install -y python3 python3-pip && rm -rf /var/lib/apt/lists/*
USER jenkins

RUN jenkins-plugin-cli --plugins \
  sonar:latest \
  git:latest \
  maven-plugin:latest \
  credentials:latest \
  job-dsl:latest \
  workflow-aggregator:latest \
  configuration-as-code:latest \
  matrix-auth:latest \
  groovy:latest \
  docker-workflow:latest \
  ssh-agent:latest \
  ssh-steps:latest

COPY casc.yaml /var/jenkins_home/casc_configs/jenkins.yaml