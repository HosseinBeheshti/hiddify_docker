#!/bin/bash

#############################################
# Hiddify Manager Server Setup Script
# Installs Docker and system dependencies
# For Fresh Ubuntu Server (20.04/22.04/24.04)
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_warning "Running as root. Consider running as a regular user with sudo."
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    print_error "Cannot detect OS. This script is for Ubuntu only."
    exit 1
fi

if [[ ! "$OS" =~ "Ubuntu" ]]; then
    print_error "This script is designed for Ubuntu. Detected: $OS"
    exit 1
fi

print_message "Detected: $OS $VER"

# Update system
print_message "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
print_message "Installing required packages..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    ufw \
    jq

# Install Docker
print_message "Installing Docker..."

# Remove old Docker installations
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
if [ "$SUDO_USER" ]; then
    sudo usermod -aG docker $SUDO_USER
    print_message "Added $SUDO_USER to docker group. You may need to log out and back in."
elif [ "$USER" != "root" ]; then
    sudo usermod -aG docker $USER
    print_message "Added $USER to docker group. You may need to log out and back in."
fi

# Verify Docker installation
print_message "Verifying Docker installation..."
docker --version
docker compose version

# Configure firewall
print_message "Configuring firewall..."
sudo ufw --force enable
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw reload

echo ""
echo "========================================"
echo -e "${GREEN}Server Setup Complete!${NC}"
echo "========================================"
echo ""
echo "Docker and required packages are installed."
echo ""
print_warning "If you were added to the docker group, log out and back in for permissions to take effect."
echo ""
echo "Next step: Run ./setup_docker.sh to build and deploy Hiddify Manager"
echo "========================================"
