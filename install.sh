#!/bin/bash

#############################################
# Hiddify Manager Docker Installation Script
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
    ufw

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

# Create installation directory
INSTALL_DIR="/opt/hiddify-docker"
print_message "Creating installation directory: $INSTALL_DIR"
sudo mkdir -p $INSTALL_DIR
sudo chown -R $USER:$USER $INSTALL_DIR 2>/dev/null || sudo chown -R $SUDO_USER:$SUDO_USER $INSTALL_DIR

cd $INSTALL_DIR

# Download Hiddify Docker files
print_message "Downloading Hiddify Docker configuration files..."

# Download Dockerfile
curl -fsSL -o Dockerfile https://raw.githubusercontent.com/HosseinBeheshti/private_scripts/main/hiddify_docker/Dockerfile || {
    print_warning "Could not download from repository, creating files manually..."
    
    # If download fails, ask user to provide files
    print_error "Please copy the following files to $INSTALL_DIR:"
    print_error "  - Dockerfile"
    print_error "  - docker-compose.yml"
    print_error "  - docker-entrypoint.sh"
    print_error "  - docker.env"
    exit 1
}

curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/HosseinBeheshti/private_scripts/main/hiddify_docker/docker-compose.yml
curl -fsSL -o docker-entrypoint.sh https://raw.githubusercontent.com/HosseinBeheshti/private_scripts/main/hiddify_docker/docker-entrypoint.sh
curl -fsSL -o docker.env https://raw.githubusercontent.com/HosseinBeheshti/private_scripts/main/hiddify_docker/docker.env

chmod +x docker-entrypoint.sh

# Generate strong passwords
print_message "Generating secure passwords..."
REDIS_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
MYSQL_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Update docker.env with generated passwords
sed -i "s/CHANGE_THIS_TO_STRONG_REDIS_PASSWORD/$REDIS_PASS/" docker.env
sed -i "s/CHANGE_THIS_TO_STRONG_MYSQL_PASSWORD/$MYSQL_PASS/" docker.env

print_message "Generated passwords saved in docker.env"

# Create data directories
print_message "Creating data directories..."
mkdir -p docker-data/{hiddify,mariadb,redis,logs,tmp}

# Set proper permissions
chmod 700 docker-data/mariadb
chmod 700 docker-data/redis

# Configure firewall
print_message "Configuring firewall..."
sudo ufw --force enable
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw reload

# Build and start containers
print_message "Building Docker image (this may take several minutes)..."
docker compose build

print_message "Starting Hiddify Manager..."
docker compose up -d

# Wait for services to be healthy
print_message "Waiting for services to start..."
sleep 10

# Show status
print_message "Checking container status..."
docker compose ps

# Show logs
print_message "Recent logs:"
docker compose logs --tail=50

# Get server IP
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || hostname -I | awk '{print $1}')

echo ""
echo "========================================"
echo -e "${GREEN}Installation Complete!${NC}"
echo "========================================"
echo ""
echo "Access Hiddify Manager at:"
echo "  http://$SERVER_IP"
echo "  or"
echo "  https://$SERVER_IP"
echo ""
echo "Installation directory: $INSTALL_DIR"
echo "Configuration file: $INSTALL_DIR/docker.env"
echo ""
echo "Useful commands:"
echo "  View logs:    docker compose logs -f"
echo "  Stop:         docker compose stop"
echo "  Start:        docker compose start"
echo "  Restart:      docker compose restart"
echo "  Status:       docker compose ps"
echo "  Uninstall:    docker compose down -v"
echo ""
echo "IMPORTANT: Save your passwords from: $INSTALL_DIR/docker.env"
echo ""
echo "For security, consider:"
echo "  1. Changing the default admin password in web interface"
echo "  2. Enabling HTTPS with valid SSL certificate"
echo "  3. Regular backups: docker-data/ directory"
echo ""
print_warning "If you were added to the docker group, log out and back in for permissions to take effect."
echo "========================================"
