# Ubuntu 24.04 TigerVNC Docker

Simple Ubuntu 24.04 desktop with TigerVNC using **host networking** (same IP as server).

## Quick Start

```bash
# Build and start VNC
./setup_vnc.sh
```

## Connect to VNC

From your TigerVNC client on the server:
```bash
vncviewer YOUR_SERVER_IP:5901
```

Default password: `vncpass`

## Configuration

- **Network Mode:** `host` - Container uses the same IP as your server
- **VNC Port:** 5901 (accessible on server's IP)
- **Desktop:** XFCE4
- **Resolution:** 1920x1080 (can be changed in Dockerfile.vnc)

## Management

```bash
# View logs
docker compose -f docker-compose.vnc.yml logs -f

# Stop VNC
docker compose -f docker-compose.vnc.yml stop

# Start VNC
docker compose -f docker-compose.vnc.yml start

# Restart VNC
docker compose -f docker-compose.vnc.yml restart

# Access container shell
docker exec -it ubuntu-vnc bash

# Change VNC password
docker exec -it ubuntu-vnc vncpasswd
```

## Files

- `Dockerfile.vnc` - Ubuntu 24.04 with TigerVNC
- `docker-compose.vnc.yml` - Docker Compose with host networking
- `setup_vnc.sh` - Build and start script
- `vnc-home/` - Persistent home directory

## Change Resolution

Edit [Dockerfile.vnc](Dockerfile.vnc#L45) and change:
```dockerfile
CMD ["vncserver", ":1", "-geometry", "1920x1080", "-depth", "24", "-localhost", "no", "-fg"]
```

Then rebuild:
```bash
docker compose -f docker-compose.vnc.yml down
docker compose -f docker-compose.vnc.yml build
docker compose -f docker-compose.vnc.yml up -d
```

## Install Additional Software

```bash
# Access container
docker exec -it ubuntu-vnc bash

# Install packages (as root)
sudo apt update
sudo apt install PACKAGE_NAME
```

## Host Networking

The container uses `network_mode: host`, which means:
- ✅ Container shares the same IP as your server
- ✅ VNC accessible at `SERVER_IP:5901`
- ✅ No port mapping needed
- ✅ Full network access

---

**Old Hiddify files** are still in the repository if you need them later.
