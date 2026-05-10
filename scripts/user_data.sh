#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg git awscli

# Install Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

# Clone & deploy app
APP_DIR="/opt/${project_name}"
git clone ${git_repo_url} "$APP_DIR" || (cd "$APP_DIR" && git pull)
cd "$APP_DIR"
docker compose pull
docker compose up -d

# Notify
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
aws sns publish --region ${aws_region} --topic-arn ${sns_topic} \
  --subject "✅ App deployed: ${project_name}" \
  --message "App running on $PUBLIC_IP"