#!/bin/bash

set -e

echo "==========================================="
echo "   Ubuntu 24.04 TigerVNC Docker Setup"
echo "==========================================="

# Build the image
echo "Building Ubuntu VNC image..."
docker compose -f docker-compose.vnc.yml build

# Start the container
echo "Starting VNC container with host networking..."
docker compose -f docker-compose.vnc.yml up -d

echo ""
echo "==========================================="
echo "   VNC Server Started Successfully!"
echo "==========================================="
echo ""
echo "Connection Details:"
echo "  VNC Server: $(hostname -I | awk '{print $1}'):5901"
echo "  Default Password: vncpass"
echo ""
echo "Connect from your TigerVNC client:"
echo "  vncviewer $(hostname -I | awk '{print $1}'):5901"
echo ""
echo "Useful Commands:"
echo "  View logs:    docker compose -f docker-compose.vnc.yml logs -f"
echo "  Stop:         docker compose -f docker-compose.vnc.yml stop"
echo "  Start:        docker compose -f docker-compose.vnc.yml start"
echo "  Restart:      docker compose -f docker-compose.vnc.yml restart"
echo "  Shell access: docker exec -it ubuntu-vnc bash"
echo ""
echo "To change VNC password:"
echo "  docker exec -it ubuntu-vnc vncpasswd"
echo ""
