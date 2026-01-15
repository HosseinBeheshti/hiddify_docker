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

# Get the directory where the script is located (before changing directories)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
print_message "Source directory: $SCRIPT_DIR"

# Create installation directory
INSTALL_DIR="/opt/hiddify-docker"
print_message "Creating installation directory: $INSTALL_DIR"
sudo mkdir -p $INSTALL_DIR
sudo chown -R $USER:$USER $INSTALL_DIR 2>/dev/null || sudo chown -R $SUDO_USER:$SUDO_USER $INSTALL_DIR

# Copy Hiddify Docker files from source directory
print_message "Copying Hiddify Docker configuration files..."

# Copy required files to installation directory
if [ -f "$SCRIPT_DIR/Dockerfile" ]; then
    sudo cp "$SCRIPT_DIR/Dockerfile" "$INSTALL_DIR/"
else
    print_error "Dockerfile not found in $SCRIPT_DIR"
    exit 1
fi

if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    sudo cp "$SCRIPT_DIR/docker-compose.yml" "$INSTALL_DIR/"
else
    print_error "docker-compose.yml not found in $SCRIPT_DIR"
    exit 1
fi

if [ -f "$SCRIPT_DIR/docker-entrypoint.sh" ]; then
    sudo cp "$SCRIPT_DIR/docker-entrypoint.sh" "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/docker-entrypoint.sh"
else
    print_error "docker-entrypoint.sh not found in $SCRIPT_DIR"
    exit 1
fi

if [ -f "$SCRIPT_DIR/docker.env" ]; then
    sudo cp "$SCRIPT_DIR/docker.env" "$INSTALL_DIR/"
else
    print_error "docker.env not found in $SCRIPT_DIR"
    exit 1
fi

# Set ownership of copied files
sudo chown -R $USER:$USER $INSTALL_DIR 2>/dev/null || sudo chown -R $SUDO_USER:$SUDO_USER $INSTALL_DIR

print_message "All configuration files copied successfully"

# Now change to installation directory
cd $INSTALL_DIR

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
sleep 15

# Wait for hiddify-manager container to be running
print_message "Waiting for Hiddify Manager to be ready..."
MAX_WAIT=120
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
    if docker compose ps hiddify | grep -q "Up"; then
        print_message "Hiddify Manager container is running!"
        break
    fi
    sleep 2
    COUNTER=$((COUNTER+2))
done

if [ $COUNTER -ge $MAX_WAIT ]; then
    print_warning "Hiddify Manager took longer than expected to start"
fi

# Wait for panel to generate the current.json file with panel links
print_message "Waiting for Hiddify Panel to initialize..."
MAX_WAIT=60
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
    if docker compose exec -T hiddify test -f /opt/hiddify-manager/current.json 2>/dev/null; then
        print_message "Panel configuration ready!"
        break
    fi
    sleep 3
    COUNTER=$((COUNTER+3))
done

# Show status
print_message "Checking container status..."
docker compose ps

# Get panel links from current.json
PANEL_LINKS=""
if docker compose exec -T hiddify test -f /opt/hiddify-manager/current.json 2>/dev/null; then
    PANEL_LINKS=$(docker compose exec -T hiddify cat /opt/hiddify-manager/current.json 2>/dev/null | jq -r '.panel_links[]' 2>/dev/null | grep -v "^\[" || true)
fi

# Get server public IP as fallback
SERVER_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || curl -s --max-time 5 api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "========================================"
echo -e "${GREEN}Installation Complete!${NC}"
echo "========================================"
echo ""

if [ ! -z "$PANEL_LINKS" ]; then
    echo -e "${GREEN}Access Hiddify Panel at:${NC}"
    echo "$PANEL_LINKS" | while read -r link; do
        if [ ! -z "$link" ]; then
            # Ensure the link uses the correct public IP
            # If the link doesn't contain a valid public IP (e.g. localhost or internal IP), try to construct one
            if [[ "$link" == *"localhost"* ]] || [[ "$link" == *"127.0.0.1"* ]]; then
                 UPDATED_LINK="${link/localhost/$SERVER_IP}"
                 UPDATED_LINK="${UPDATED_LINK/127.0.0.1/$SERVER_IP}"
                 echo -e "  ${GREEN}${UPDATED_LINK}${NC}"
            else
                 echo -e "  ${GREEN}${link}${NC}"
            fi
        fi
    done
    echo ""
else
    echo -e "${GREEN}Access Hiddify Panel at:${NC}"
    # Construct a link that is more likely to work for remote access
    echo -e "  ${GREEN}http://${SERVER_IP}/${NC}"
    echo ""
    print_warning "Panel links not yet available. Check logs: cd /opt/hiddify-docker && docker compose logs hiddify"
fi

echo "Internal/Private Network Access:"
# Show all detected IPs
hostname -I | tr ' ' '\n' | while read ip; do
    if [ ! -z "$ip" ]; then
         echo "  http://$ip/"
    fi
done
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
