# Hiddify Manager Docker Setup

Complete Docker setup for Hiddify Manager with external MariaDB and Redis.

## Quick Start

1. **Clone and prepare:**
   ```bash
   git clone <your-repo-url>
   cd hiddify_docker
   ```

2. **Configure passwords:**
   Edit `docker.env` and set strong passwords:
   ```bash
   REDIS_PASSWORD=your_strong_redis_password_here
   MYSQL_PASSWORD=your_strong_mysql_password_here
   MYSQL_ROOT_PASSWORD=your_strong_root_password_here
   MYSQL_DATABASE=hiddifypanel
   MYSQL_USER=hiddifypanel
   ```

3. **Build and start:**
   ```bash
   docker compose build --no-cache
   docker compose up -d
   ```

4. **Check logs:**
   ```bash
   docker compose logs -f hiddify
   ```

5. **Access panel:**
   Wait 2-3 minutes for initialization, then access via:
   - `http://YOUR_SERVER_IP/`
   - Check logs for admin URL with credentials

## Management Commands

**View logs:**
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f hiddify
docker compose logs -f mariadb
docker compose logs -f redis
```

**Restart services:**
```bash
# All services
docker compose restart

# Specific service
docker compose restart hiddify
```

**Stop everything:**
```bash
docker compose down
```

**Complete reset (WARNING: deletes all data):**
```bash
docker compose down -v
rm -rf docker-data
docker compose up -d
```

**Check service status:**
```bash
docker compose ps
```

**Execute commands in container:**
```bash
docker compose exec hiddify bash
```

## Troubleshooting

**Container exits immediately:**
```bash
docker compose logs hiddify
```
Check for database connection errors or missing environment variables.

**Database errors:**
```bash
# Check MariaDB logs
docker compose logs mariadb

# Recreate database
docker compose down
docker volume rm hiddify_docker_mariadb_data
docker compose up -d
```

**Can't access panel:**
- Wait 2-3 minutes for full initialization
- Check firewall: ports 80 and 443 must be open
- Check logs: `docker compose logs hiddify`

**Need to change passwords:**
1. Stop containers: `docker compose down`
2. Edit `docker.env`
3. Remove volumes: `docker volume rm hiddify_docker_mariadb_data hiddify_docker_redis_data`
4. Start fresh: `docker compose up -d`

## Architecture

- **hiddify**: Main Hiddify Manager container (Nginx, HAProxy, Xray/Singbox, Panel)
- **mariadb**: MySQL database (persistent data in volume)
- **redis**: Cache and session storage (persistent data in volume)

All containers are isolated on custom bridge network `172.28.0.0/16`.

## Security Notes

- Change default passwords in `docker.env` before deployment
- Only ports 80 and 443 are exposed
- Containers run with minimal required capabilities
- All data stored in Docker volumes (backed up automatically)
