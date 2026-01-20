# Hiddify Manager Docker

Dockerized deployment of Hiddify Manager with MariaDB and Redis.

## ✅ Status: Working

The container successfully runs Hiddify Manager with:
- ✅ Database initialization and migrations
- ✅ SSL certificate generation (Let's Encrypt)
- ✅ Core services: Nginx, HAProxy, Xray, Singbox
- ✅ Admin panel and background tasks
- ⚠️ Minor expected warnings (systemctl, IPv6 - safe to ignore)

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

# Get admin panel links (note: mysql.service not found error is expected and safe to ignore)
docker compose exec hiddify hiddify admin
```

## Troubleshooting

### Expected Warnings (Safe to Ignore)

These warnings are normal in Docker environments:
- `sudo: unable to send audit message: Operation not permitted` - Audit system not available in containers
- `ip6tables-restore: line 35 failed` - IPv6 firewall rule (harmless if IPv6 not needed)
- `sysctl: setting key "net.ipv6...", ignoring: Read-only file system` - IPv6 sysctl in container
- `ERROR:systemctl:Unit hiddify-cli.service not found` - Optional service
- `ERROR:systemctl:Unit sshd.service not found` - SSH handled differently in Docker
- `ERROR:systemctl:Unit mysql.service not found` - MariaDB runs in separate container (this is correct)
- `hiddify-ss-faketls failed` - Optional feature, can be enabled in panel if needed

### Real Issues

**Panel not accessible:**
- Wait 2-3 minutes for initialization
- Check logs: `docker compose logs -f hiddify`
- Verify ports 80/443 are open: `sudo ufw allow 80/tcp && sudo ufw allow 443/tcp`
- Check service status: All should show `active` except `hiddify-ss-faketls` (optional)
  ```bash
  docker compose exec hiddify systemctl status hiddify-panel
  docker compose exec hiddify systemctl status hiddify-nginx
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

## Security Features

- Limited container capabilities (NET_ADMIN, SYS_ADMIN, DAC_OVERRIDE, etc.)
- Isolated network with custom bridge
- Resource limits (CPU: 1.5 cores, Memory: 2GB)
- Health checks for all services
- Automatic SSL certificate generation and renewal
- Secure password generation

## Files

- `setup_server.sh`: Installs Docker and system dependencies
- `setup_docker.sh`: Builds and deploys containers (generates passwords)
- `prepare_volumes.sh`: Creates necessary directory structure
- `docker-compose.yml`: Service orchestration with security settings
- `Dockerfile`: Hiddify Manager image build
- `docker-entrypoint.sh`: Container initialization script
- `docker.env`: Environment variables (passwords auto-generated)
- `init-db.sh`: Database initialization script

## Known Limitations

- IPv6 may require host network mode (currently uses IPv4)
- Some sysctl settings read-only in containers (handled via sysctls in docker-compose)
- Container requires extended capabilities for iptables/networking
- Log audit messages disabled (normal for containers)

## Contributing

Issues and pull requests welcome at: https://github.com/HosseinBeheshti/hiddify_docker
