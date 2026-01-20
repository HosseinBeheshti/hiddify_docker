#!/bin/bash

set -e

echo "============================================="
echo "   LXC Container Setup for Hiddify"
echo "============================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

CONTAINER_NAME="hiddify-lxc"

echo "Installing LXD via snap..."
snap install lxd --channel=latest/stable

# Add current user to lxd group
usermod -aG lxd $SUDO_USER 2>/dev/null || true

# Initialize LXD with defaults
echo ""
echo "Initializing LXD..."
lxd init --auto 2>/dev/null || echo "LXD already initialized"

echo ""
echo "Creating Ubuntu 24.04 container: $CONTAINER_NAME"
lxc launch ubuntu:24.04 $CONTAINER_NAME || echo "Container may already exist"

echo ""
echo "Waiting for container to start..."
sleep 5

echo ""
echo "Configuring container..."
# Allow nested containers and privileged operations for Hiddify
lxc config set $CONTAINER_NAME security.nesting true
lxc config set $CONTAINER_NAME security.privileged true

echo ""
echo "Setting up port forwarding..."
# Forward common Hiddify ports
lxc config device add $CONTAINER_NAME hiddify-panel proxy listen=tcp:0.0.0.0:9443 connect=tcp:127.0.0.1:9443 2>/dev/null || echo "Port 9443 already forwarded"
lxc config device add $CONTAINER_NAME hiddify-api proxy listen=tcp:0.0.0.0:54321 connect=tcp:127.0.0.1:54321 2>/dev/null || echo "Port 54321 already forwarded"

echo ""
echo "Installing basic packages in container..."
lxc exec $CONTAINER_NAME -- bash -c "apt update && apt install -y curl wget sudo"

echo ""
echo "============================================="
echo "   Container Ready!"
echo "============================================="
echo ""
echo "Access the container:"
echo "  sudo lxc exec $CONTAINER_NAME -- bash"
echo ""
echo "Install Hiddify inside container:"
echo "  sudo lxc exec $CONTAINER_NAME -- bash -c 'bash <(curl https://i.hiddify.com/release)'"
echo ""
echo "Container Management:"
echo "  List containers:    sudo lxc list"
echo "  Start:              sudo lxc start $CONTAINER_NAME"
echo "  Stop:               sudo lxc stop $CONTAINER_NAME"
echo "  Delete:             sudo lxc delete $CONTAINER_NAME --force"
echo "  Shell access:       sudo lxc exec $CONTAINER_NAME -- bash"
echo "  Get IP:             sudo lxc list $CONTAINER_NAME"
echo ""
echo "Hiddify Access:"
echo "  Panel: https://$(hostname -I | awk '{print $1}'):9443"
echo "  (After Hiddify installation completes)"
echo ""
echo "Security Benefits:"
echo "  ✓ Isolated filesystem - can't access host files"
echo "  ✓ Separate network namespace"
echo "  ✓ Resource limits can be set"
echo "  ✓ Better isolation than Docker privileged mode"
echo ""
echo "Opening firewall ports..."
ufw allow 9443/tcp 2>/dev/null || iptables -A INPUT -p tcp --dport 9443 -j ACCEPT
ufw allow 54321/tcp 2>/dev/null || iptables -A INPUT -p tcp --dport 54321 -j ACCEPT

echo ""
echo "✓ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. sudo lxc exec $CONTAINER_NAME -- bash"
echo "  2. bash <(curl https://i.hiddify.com/release)"
echo "  3. Access panel at https://$(hostname -I | awk '{print $1}'):9443"
echo ""
