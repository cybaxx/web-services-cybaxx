#!/usr/bin/env bash

set -euo pipefail
set -x

# Root check
if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root. Try: sudo bash $0"
  exit 1
fi

# OS check
if [[ -x "$(command -v apt)" ]]; then
  OS_ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
  if [[ "$OS_ID" != "debian" && "$OS_ID" != "ubuntu" ]]; then
    echo "Unsupported OS: $OS_ID. This script only supports Debian or Ubuntu."
    exit 1
  fi
else
  echo "This script requires apt. Are you on a Debian/Ubuntu system?"
  exit 1
fi

# Install essential dependencies
apt-get update

REQUIRED_PACKAGES=(figlet curl git gnupg lsb-release ca-certificates)
for pkg in "${REQUIRED_PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    echo "Installing missing package: $pkg"
    apt-get install -y "$pkg"
  fi
done

# Banner
figlet "Wetfish Web Services"
echo "Starting setup for Wetfish production environment"

# Install Docker if missing
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/$OS_ID/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "Docker is already installed."
fi

# Create traefik-backend network if missing
if ! docker network inspect traefik-backend &> /dev/null; then
  docker network create traefik-backend
else
  echo "Docker network traefik-backend already exists."
fi

# Clone repo
cd /opt
REPO_DIR="/opt/production-manifests"

if [[ ! -d "$REPO_DIR" ]]; then
  git clone \
    --branch prod-2023 \
    --single-branch \
    --recursive \
    --recurse-submodules \
    https://github.com/wetfish/production-manifests.git \
    "$REPO_DIR"
else
  echo "Repo already exists at $REPO_DIR"
fi

# Fix permissions
cd "$REPO_DIR"
bash ./fix-subproject-permissions.sh

# Start Traefik stack
cd "$REPO_DIR/traefik"
docker compose up -d

echo "Waiting 60 seconds for Traefik to acquire certificates..."
sleep 60

# Start all services
cd "$REPO_DIR"
bash ./init-servivces.sh
bash ./all-services up
