# Hiddify Manager Docker

Dockerized deployment of Hiddify Manager with MariaDB and Redis.

## Installation

### Method 1: Automated Setup (Recommended)

**On a fresh Ubuntu/Debian VPS:**

```bash
# Clone repository
git clone https://github.com/HosseinBeheshti/hiddify_docker.git
cd hiddify_docker

# Install Docker and dependencies
sudo bash setup_server.sh

# Build and deploy (generates passwords automatically)
sudo bash setup_docker.sh
```

**Access your panel at the URL shown after installation completes (typically http://YOUR_SERVER_IP/)**

### Method 2: Manual Setup

```bash
# 1. Clone repository
git clone https://github.com/HosseinBeheshti/hiddify_docker.git
cd hiddify_docker

# 2. Build and start (passwords will be generated automatically)
docker compose build --no-cache
docker compose up -d

# 3. Access panel at http://YOUR_SERVER_IP/
```

**Note:** Setup scripts automatically generate secure passwords. Check `docker.env` for generated credentials if needed.

## Management

```bash
# View logs
docker compose logs -f hiddify

# Restart services
docker compose restart

# Stop/start
docker compose stop
docker compose start

# Access container shell
docker compose exec hiddify bash

# Check service status inside container
docker compose exec hiddify systemctl status hiddify-panel
docker compose exec hiddify systemctl status hiddify-nginx
```

## Troubleshooting

**Panel not accessible:**
- Wait 2-3 minutes for initialization
- Check logs: `docker compose logs hiddify`
- Verify ports 80/443 are open: `sudo ufw status`

**Services failing:**
```bash
# Check service status
docker compose exec hiddify systemctl status hiddify-panel
docker compose exec hiddify systemctl status hiddify-nginx

# View error logs
docker compose exec hiddify tail -f /opt/hiddify-manager/log/system/hiddify_panel.err.log
```

**Database connection issues:**
```bash
# Check MariaDB status
docker compose logs mariadb

# Test connection inside container
docker compose exec hiddify mysql -h mariadb -u hiddifypanel -p
```

**Complete reinstall (deletes all data):**
```bash
# Run setup script again - it will clean everything
sudo bash setup_docker.sh
```

## Components

- **hiddify-manager**: Main application (Nginx, HAProxy, Xray, Singbox, Flask Panel)
- **mariadb**: Database server (MariaDB 11.2)
- **redis**: Cache and session store (Redis 7.2)

Network: `172.28.0.0/16` bridge
Data: Stored in `./docker-data/` directory

## Files

- `setup_server.sh`: Installs Docker and system dependencies
- `setup_docker.sh`: Builds and deploys containers (generates passwords)
- `docker-compose.yml`: Service orchestration
- `Dockerfile`: Hiddify Manager image build
- `docker-entrypoint.sh`: Container initialization script
- `docker.env`: Environment variables (passwords auto-generated)
- `init-db.sh`: Database initialization script
