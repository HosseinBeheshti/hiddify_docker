#!/bin/bash

set -e

echo "==========================================="
echo "   Ubuntu 24.04 TigerVNC Docker Setup"
echo "==========================================="

# Deep clean Docker
echo "Cleaning up old containers and images..."
docker compose down 2>/dev/null || true
docker rm -f hiddify-docker 2>/dev/null || true
docker rmi -f hiddify_docker-hiddify 2>/dev/null || true
docker system prune -f

echo ""
# Build the image
echo "Building Ubuntu VNC image..."
docker compose build

# Start the container
echo "Starting VNC container with host networking..."
docker compose up -d

echo ""
echo "==========================================="
echo "   VNC Server Started Successfully!"
echo "==========================================="
echo ""
echo "Connection Details:"
echo "  VNC Server: $(hostname -I | awk '{print $1}'):5905"
echo "  Default Password: vncpass"
echo ""
echo "Connect from your TigerVNC client:"
echo "  vncviewer $(hostname -I | awk '{print $1}'):5905"
echo ""
echo "Note: Using display :5 (port 5905) to avoid conflict with existing displays 1-4"
echo ""
echo "Useful Commands:"
echo "  View logs:    docker compose logs -f"
echo "  Stop:         docker compose stop"
echo "  Start:        docker compose start"
echo "  Restart:      docker compose restart"
echo "  Shell access: docker exec -it hiddify-docker bash"
echo ""
echo "To change VNC password:"
echo "  docker exec -it hiddify-docker vncpasswd"
echo ""
