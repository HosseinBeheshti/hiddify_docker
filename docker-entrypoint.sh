#!/bin/bash
set -e

echo "========================================"
echo "Starting Hiddify Manager Docker Container"
echo "========================================"

# Remove any lock files
rm -rf /opt/hiddify-manager/log/*.lock
mkdir -p /opt/hiddify-manager/log/system/

# Change to Hiddify directory
cd /opt/hiddify-manager

# Activate Python virtual environment
source /opt/hiddify-manager/.venv313/bin/activate

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
cd /opt/hiddify-manager/hiddify-panel

echo "Configuring hiddify-panel..."

# Fix ownership if needed (app.cfg might be owned by hiddify-panel user)
if [ -f app.cfg ]; then
    chmod 600 app.cfg 2>/dev/null || true
else
    touch app.cfg 2>/dev/null || echo "" > app.cfg
    chmod 600 app.cfg 2>/dev/null || true
fi

# Remove old config lines
sed -i '/^SQLALCHEMY_DATABASE_URI/d' app.cfg
sed -i '/^REDIS_URI/d' app.cfg

# Add new config
echo "SQLALCHEMY_DATABASE_URI ='${SQLALCHEMY_DATABASE_URI}'" >> app.cfg
echo "REDIS_URI_MAIN = '${REDIS_URI_MAIN}'" >> app.cfg
echo "REDIS_URI_SSH = '${REDIS_URI_SSH}'" >> app.cfg

# Initialize database (requires hiddify-panel-cli to be available)
echo "Initializing database..."
cd /opt/hiddify-manager/hiddify-panel
if command -v hiddify-panel-cli &> /dev/null; then
    hiddify-panel-cli init-db 2>&1 || true
fi

# Start Nginx
echo "Starting Nginx..."
cd /opt/hiddify-manager/nginx
if [ -f "pre-start.sh" ]; then
    bash pre-start.sh 2>&1 || true
fi
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
