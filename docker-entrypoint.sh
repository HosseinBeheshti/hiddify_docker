#!/bin/bash
# Docker entrypoint for Hiddify Manager

set -e

echo "==============================================="
echo "    Hiddify Manager Docker Container"
echo "==============================================="

# Validate environment variables
if [ -z "$REDIS_PASSWORD" ]; then
    echo "ERROR: REDIS_PASSWORD environment variable is required"
    exit 1
fi

if [ -z "$MYSQL_PASSWORD" ]; then
    echo "ERROR: MYSQL_PASSWORD environment variable is required"
    exit 1
fi

# Setup environment
export REDIS_URI_MAIN="redis://:${REDIS_PASSWORD}@redis:6379/0"
export REDIS_URI_SSH="redis://:${REDIS_PASSWORD}@redis:6379/1"
export SQLALCHEMY_DATABASE_URI="mysql+mysqldb://hiddifypanel:${MYSQL_PASSWORD}@mariadb/hiddifypanel?charset=utf8mb4"

cd /opt/hiddify-manager

# Create necessary directories
mkdir -p /hiddify-data/ssl/ /opt/hiddify-manager/log/system/
rm -rf /opt/hiddify-manager/log/*.lock 2>/dev/null || true

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

# Configure Hiddify Panel
echo "Configuring Hiddify Panel..."
if [ -d "hiddify-panel" ]; then
    cat > hiddify-panel/app.cfg <<EOF
REDIS_URI_MAIN='${REDIS_URI_MAIN}'
REDIS_URI_SSH='${REDIS_URI_SSH}'
SQLALCHEMY_DATABASE_URI='${SQLALCHEMY_DATABASE_URI}'
EOF

    # Try to initialize database
    if [ -f "hiddify-panel/hiddifypanel/__init__.py" ]; then
        echo "Initializing database..."
        cd hiddify-panel
        python3 -m hiddifypanel init-db 2>/dev/null || echo "Database initialization completed"
        cd ..
    fi
fi

# Try to run install.sh if it exists and is executable
if [ -f "install.sh" ] && [ -x "install.sh" ]; then
    echo "Running Hiddify configuration..."
    DO_NOT_INSTALL=true bash ./install.sh docker --no-gui 2>&1 | tee log/system/docker-init.log || {
        echo "Warning: install.sh had issues, but continuing..."
    }
fi

# Start services
echo ""
echo "==============================================="
echo "    Hiddify Manager Started Successfully!"
echo "==============================================="
echo ""
echo "Services are running. Check logs below:"
echo ""

# Keep container running and show logs
if [ -d "log/system" ]; then
    tail -f log/system/* 2>/dev/null &
fi

# Keep container alive
while true; do
    sleep 3600
done
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
