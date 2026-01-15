#!/bin/bash
# Don't exit on error - we need to handle permissions gracefully
set +e

echo "========================================"
echo "Starting Hiddify Manager Docker Container"
echo "========================================"

# Remove any lock files
rm -rf /opt/hiddify-manager/log/*.lock
mkdir -p /opt/hiddify-manager/log/system/
mkdir -p /var/log/nginx

# Ensure proper permissions for all directories
chown -R root:root /opt/hiddify-manager
chmod -R 755 /opt/hiddify-manager
mkdir -p /opt/hiddify-manager/hiddify-panel
chmod 755 /opt/hiddify-manager/hiddify-panel

# Change to Hiddify directory
cd /opt/hiddify-manager

# Activate Python virtual environment if it exists
if [ -f "/opt/hiddify-manager/.venv313/bin/activate" ]; then
    source /opt/hiddify-manager/.venv313/bin/activate
elif [ -f "/opt/hiddify-manager/.venv/bin/activate" ]; then
    source /opt/hiddify-manager/.venv/bin/activate
fi

# Export environment variables
export LANG=C.UTF-8
export MYSQL_PASS="${MYSQL_PASSWORD}"
export REDIS_PASS="${REDIS_PASSWORD}"

# Set database URI for Docker (using container names)
if [ -z "$SQLALCHEMY_DATABASE_URI" ]; then
  export SQLALCHEMY_DATABASE_URI="mysql+mysqldb://hiddifypanel:${MYSQL_PASSWORD}@mariadb/hiddifypanel?charset=utf8mb4"
fi

# Set Redis URIs for Docker
if [ -z "$REDIS_URI_MAIN" ]; then
  export REDIS_URI_MAIN="redis://:${REDIS_PASSWORD}@redis:6379/0"
  export REDIS_URI_SSH="redis://:${REDIS_PASSWORD}@redis:6379/1"
fi

echo "Waiting for database and redis to be ready..."
sleep 15

# Configure hiddify-panel app.cfg
echo "Configuring hiddify-panel..."

# Create config file
cat > /opt/hiddify-manager/hiddify-panel/app.cfg <<EOF
SQLALCHEMY_DATABASE_URI ='${SQLALCHEMY_DATABASE_URI}'
REDIS_URI_MAIN = '${REDIS_URI_MAIN}'
REDIS_URI_SSH = '${REDIS_URI_SSH}'
EOF

chmod 644 /opt/hiddify-manager/hiddify-panel/app.cfg

# Initialize database - Run the actual Hiddify initialization script
echo "Running Hiddify initialization..."
cd /opt/hiddify-manager
if [ -f "install.sh" ]; then
    bash install.sh --no-gui --docker 2>&1 || true
elif [ -f "common/hiddify_installer.sh" ]; then
    bash common/hiddify_installer.sh docker --no-gui 2>&1 || true
fi

# Check if nginx config exists now
if [ ! -f "/opt/hiddify-manager/nginx/nginx.conf" ]; then
    echo "ERROR: Nginx config not found after initialization!"
    echo "Listing /opt/hiddify-manager/nginx directory:"
    ls -la /opt/hiddify-manager/nginx/ 2>&1 || echo "nginx directory does not exist"
    exit 1
fi

# Start Nginx
echo "Starting Nginx..."
/usr/sbin/nginx -c /opt/hiddify-manager/nginx/nginx.conf 2>&1 &
NGINX_PID=$!

# Start Hiddify Panel
echo "Starting Hiddify Panel..."
cd /opt/hiddify-manager/hiddify-panel
/opt/hiddify-manager/.venv313/bin/python /opt/hiddify-manager/hiddify-panel/app.py \
    > /opt/hiddify-manager/log/system/hiddify_panel.out.log \
    2> /opt/hiddify-manager/log/system/hiddify_panel.err.log &
PANEL_PID=$!

# Start Background Tasks
echo "Starting Background Tasks..."
cd /opt/hiddify-manager/hiddify-panel
/opt/hiddify-manager/.venv313/bin/python -m celery \
    -A hiddifypanel.apps.celery_app:celery_app \
    worker --beat --loglevel debug --concurrency 1 --pool=solo \
    > /opt/hiddify-manager/log/system/hiddify_panel_background_tasks.out.log \
    2> /opt/hiddify-manager/log/system/hiddify_panel_background_tasks.err.log &
BACKGROUND_PID=$!

# Wait for services to start
sleep 5

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}' || echo "localhost")

echo "========================================"
echo "Hiddify Manager Started!"
echo "========================================"
echo ""
echo "Access Panel at:"
echo "  http://${SERVER_IP}/"
echo ""
echo "Panel PID: $PANEL_PID"
echo "Background PID: $BACKGROUND_PID"
echo "Nginx PID: $NGINX_PID"
echo ""
echo "Logs:"
echo "  Panel: /opt/hiddify-manager/log/system/hiddify_panel.*.log"
echo "  Background: /opt/hiddify-manager/log/system/hiddify_panel_background_tasks.*.log"
echo "========================================"

# Monitor all processes
while true; do
    if ! kill -0 $PANEL_PID 2>/dev/null; then
        echo "ERROR: Panel process died"
        exit 1
    fi
    if ! kill -0 $BACKGROUND_PID 2>/dev/null; then
        echo "ERROR: Background tasks process died"
        exit 1
    fi
    if ! kill -0 $NGINX_PID 2>/dev/null; then
        echo "ERROR: Nginx process died"
        exit 1
    fi
    sleep 10
done
