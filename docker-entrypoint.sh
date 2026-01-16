#!/bin/bash
# Docker entrypoint for Hiddify Manager
# Based on official docker-init.sh

set -e

echo "==============================================="
echo "    Hiddify Manager Docker Container"
echo "==============================================="

# Validate environment variables
if [ -z "$REDIS_PASSWORD" ]; then
    echo "ERROR: REDIS_PASSWORD environment variable is required"
    exit 1
fi

# Setup database URI - support both MYSQL_PASSWORD and SQLALCHEMY_DATABASE_URI
if [ -z "$SQLALCHEMY_DATABASE_URI" ]; then
  if [ -z "$MYSQL_PASSWORD" ]; then
    echo "ERROR: One of MYSQL_PASSWORD or SQLALCHEMY_DATABASE_URI must be set"
    exit 1
  fi
  export SQLALCHEMY_DATABASE_URI="mysql+mysqldb://hiddifypanel:${MYSQL_PASSWORD}@mariadb/hiddifypanel?charset=utf8mb4"
fi

cd /opt/hiddify-manager

# Setup environment with proper Redis and Database URIs
export REDIS_URI_MAIN="redis://:${REDIS_PASSWORD}@redis:6379/0"
export REDIS_URI_SSH="redis://:${REDIS_PASSWORD}@redis:6379/1"

# Create necessary directories
mkdir -p /hiddify-data/ssl/ /opt/hiddify-manager/log/system/ /opt/hiddify-manager/hiddify-panel
rm -rf /opt/hiddify-manager/log/*.lock 2>/dev/null || true

# Create app.cfg with database configuration BEFORE anything else
echo "Creating app.cfg configuration..."
cat > /opt/hiddify-manager/hiddify-panel/app.cfg <<EOF
# Redis Configuration
REDIS_URI_MAIN='${REDIS_URI_MAIN}'
REDIS_URI_SSH='${REDIS_URI_SSH}'

# Database Configuration
SQLALCHEMY_DATABASE_URI='${SQLALCHEMY_DATABASE_URI}'

# Logging Configuration
STDOUT_LOG_LEVEL='INFO'
FILE_LOG_LEVEL='DEBUG'

# Flask Configuration
SECRET_KEY='$(openssl rand -hex 32)'
DEBUG=False

# Hiddify Configuration
MODE='docker'
COMMIT_SHA='docker-build'
EOF

chmod 644 /opt/hiddify-manager/hiddify-panel/app.cfg || true

# Check if systemctl wrapper is working properly
systemctl is-active --quiet hiddify-panel 2>/dev/null || {
  echo "Ensuring systemctl wrapper is properly installed..."
  if [ -f "other/docker/systemctl" ]; then
    cp other/docker/systemctl /usr/bin/systemctl 2>/dev/null || true
    chmod +x /usr/bin/systemctl 2>/dev/null || true
  fi
  if [ -f "other/docker/systemd-cat" ]; then
    cp other/docker/systemd-cat /usr/bin/systemd-cat 2>/dev/null || true
    chmod +x /usr/bin/systemd-cat 2>/dev/null || true
  fi
  systemctl restart hiddify-panel 2>/dev/null || true
}

# Wait for MariaDB
echo "Waiting for MariaDB..."
for i in $(seq 1 30); do
    if mysqladmin ping -h mariadb -u hiddifypanel -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; then
        echo "✓ MariaDB is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: MariaDB not ready after 60 seconds"
        exit 1
    fi
    sleep 2
done

# Wait for Redis
echo "Waiting for Redis..."
for i in $(seq 1 30); do
    if redis-cli -h redis -a "${REDIS_PASSWORD}" ping 2>/dev/null | grep -q PONG; then
        echo "✓ Redis is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: Redis not ready after 60 seconds"
        exit 1
    fi
    sleep 2
done

# Run the official install script in apply mode (following official docker-init.sh)
echo "Applying Hiddify configuration..."
DO_NOT_INSTALL=true ./install.sh docker --no-gui $@ 2>&1 | tee log/system/docker-init.log || true

# Show status
if [ -f "status.sh" ]; then
    ./status.sh --no-gui 2>/dev/null || true
fi

# Start services
echo ""
echo "==============================================="
echo "    Hiddify Manager Started Successfully!"
echo "==============================================="
echo ""
echo "Hiddify services are running."
echo ""

# Follow logs
echo "Following system logs..."
sleep 5
tail -f /opt/hiddify-manager/log/system/* 2>/dev/null || {
    echo "No logs available yet. Container is running."
    # Keep container alive
    while true; do
        sleep 3600
    done
}
echo "====================================="
echo ""

# Show running services
if command -v systemctl >/dev/null 2>&1; then
    echo "Service Status:"
    for service in hiddify-nginx hiddify-haproxy hiddify-xray hiddify-singbox hiddify-panel; do
        if systemctl list-unit-files | grep -q "$service"; then
            status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
            echo "  $service: $status"
        fi
    done
    echo ""
fi

# Display panel URLs if available
if [ -f current.json ]; then
    echo "Panel URLs:"
    jq -r '.panel_links[]' current.json 2>/dev/null | sed 's/^/  /' || true
    echo ""
fi

echo "Tailing logs (press Ctrl+C to stop)..."
sleep 3

# Tail logs, fallback to keeping container alive
tail -f log/system/*.log 2>/dev/null || sleep infinity
