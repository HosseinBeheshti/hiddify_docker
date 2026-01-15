# Hiddify Manager - Secure Docker Installation

This is a secure, self-contained Docker setup for Hiddify Manager with strict isolation from your host system.

## Features

- **Security Hardened**: No privileged mode, limited capabilities, no new privileges
- **Resource Limited**: CPU and memory limits to prevent resource exhaustion
- **Isolated Storage**: All data contained in `docker-data/` directory
- **No Host Access**: Container cannot access your host files outside designated volumes
- **Health Monitoring**: Built-in health checks for all services
- **Easy Backup**: Simple backup by copying `docker-data/` directory

## Quick Installation on Fresh Ubuntu Server

```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/HosseinBeheshti/private_scripts/main/hiddify_docker/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

## Manual Installation

### Prerequisites

- Ubuntu 20.04, 22.04, or 24.04
- Minimum 2GB RAM, 2 CPU cores
- 20GB free disk space
- Root or sudo access

### Step 1: Install Docker

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install dependencies
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
```

### Step 2: Clone or Download Configuration

```bash
# Create directory
mkdir -p ~/hiddify-docker
cd ~/hiddify-docker

# Download files (or use the files in this directory)
# - Dockerfile
# - docker-compose.yml
# - docker-entrypoint.sh
# - docker.env
```

### Step 3: Configure Environment

Edit `docker.env` and change the passwords:

```bash
vim docker.env
```

Change:
```
REDIS_PASSWORD=your_strong_redis_password_here
MYSQL_PASSWORD=your_strong_mysql_password_here
```

### Step 4: Build and Start

```bash
# Make entrypoint executable
chmod +x docker-entrypoint.sh

# Build the image
docker compose build

# Start services
docker compose up -d
```

### Step 5: Access

Open your browser and navigate to:
- `http://YOUR_SERVER_IP`

## Management Commands

```bash
# View logs
docker compose logs -f

# View logs for specific service
docker compose logs -f hiddify

# Stop services
docker compose stop

# Start services
docker compose start

# Restart services
docker compose restart

# Check status
docker compose ps

# Access shell in hiddify container
docker compose exec hiddify bash

# Stop and remove containers (keeps data)
docker compose down

# Stop and remove everything including volumes (DELETES ALL DATA)
docker compose down -v
```

## Backup and Restore

### Backup

```bash
# Stop containers
docker compose stop

# Backup all data
tar -czf hiddify-backup-$(date +%Y%m%d).tar.gz docker-data/ docker.env

# Start containers
docker compose start
```

### Restore

```bash
# Stop and remove containers
docker compose down

# Extract backup
tar -xzf hiddify-backup-YYYYMMDD.tar.gz

# Start containers
docker compose up -d
```

## Security Features

1. **No Privileged Mode**: Container runs with limited capabilities
2. **Capability Restrictions**: Only NET_ADMIN and NET_RAW allowed (needed for VPN)
3. **No New Privileges**: Prevents privilege escalation
4. **Resource Limits**: CPU and memory capped
5. **Isolated Network**: Custom bridge network
6. **Volume Restrictions**: Only specific directories mounted
7. **Read-only Root Filesystem**: (Optional, may be enabled in production)

## Troubleshooting

### Container fails to start

```bash
# Check logs
docker compose logs hiddify

# Check if ports are in use
sudo netstat -tulpn | grep -E ':(80|443)'

# Restart with fresh state
docker compose down
docker compose up -d
```

### Cannot connect to web interface

```bash
# Check if services are running
docker compose ps

# Check firewall
sudo ufw status

# Allow ports if needed
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Database connection errors

```bash
# Check MariaDB logs
docker compose logs mariadb

# Restart database
docker compose restart mariadb

# Verify environment variables
docker compose exec hiddify env | grep -E '(MYSQL|REDIS)'
```

### Reset everything

```bash
# Stop and remove all containers and volumes
docker compose down -v

# Remove data directory
rm -rf docker-data/

# Start fresh
docker compose up -d
```

## Updating

```bash
# Pull latest changes (if using git)
git pull

# Rebuild image
docker compose build --no-cache

# Restart with new image
docker compose up -d
```

## Directory Structure

```
hiddify_docker/
├── Dockerfile                 # Container image definition
├── docker-compose.yml         # Service orchestration
├── docker-entrypoint.sh       # Container startup script
├── docker.env                 # Environment configuration (PASSWORDS!)
├── install.sh                 # Automated installation script
├── README.md                  # This file
└── docker-data/              # Persistent data (AUTO-CREATED)
    ├── hiddify/              # Hiddify configuration and SSL
    ├── mariadb/              # Database files
    ├── redis/                # Redis data
    ├── logs/                 # Application logs
    └── tmp/                  # Temporary files
```

## Support

- Official Hiddify: https://github.com/hiddify/Hiddify-Manager
- Telegram: https://t.me/hiddify
- Documentation: https://hiddify.com/manager/

## License

This Docker configuration follows the same license as Hiddify Manager (GPL-3.0).

## Security Note

⚠️ **IMPORTANT**: This setup is designed to limit container access to your host system. However:

1. The container still needs NET_ADMIN capability for VPN functionality
2. Always change default passwords in `docker.env`
3. Keep Docker and the host system updated
4. Use firewall rules to limit access
5. Regular backups are your responsibility
6. Monitor logs for suspicious activity

## Contributing

Feel free to submit issues or pull requests for improvements!
