# Ubuntu 24.04 TigerVNC Docker

Ubuntu 24.04 desktop with TigerVNC using **host networking** (same IP as server).

## Quick Start

```bash
./setup_docker.sh
```

## Connect to VNC

From your TigerVNC client:
```bash
vncviewer YOUR_SERVER_IP:5905
```

Default password: `vncpass`

**Note:** Uses display :5 (port 5905) to avoid conflict with existing displays 1-4 on your VPS.

## Configuration

- **Network Mode:** `host` - Container uses the same IP as your server
- **VNC Display:** :5 (port 5905) - Won't conflict with existing displays 1-4
- **Desktop:** XFCE4
- **Resolution:** 1920x1080

## Management

```bash
# View logs
docker compose logs -f

# Stop VNC
docker compose stop

# Start VNC
docker compose start

# Restart VNC
docker compose restart

# Access container shell
docker exec -it hiddify-docker bash

# Change VNC password
docker exec -it hiddify-docker vncpasswd
```

## Files

- `Dockerfile` - Ubuntu 24.04 with TigerVNC
- `docker-compose.yml` - Docker Compose with host networking
- `setup_docker.sh` - Build and start script
- `hiddify-home/` - Persistent home directory

## Change Resolution

Edit Dockerfile line 47 and rebuild:
```bash
docker compose down
docker compose build
docker compose up -d
```

## Install Additional Software

```bash
docker exec -it hiddify-docker bash
sudo apt update
sudo apt install PACKAGE_NAME
```
