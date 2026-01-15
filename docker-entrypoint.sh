#!/bin/bash
set -e

echo "========================================"
echo "Starting Hiddify Manager Docker Container"
echo "========================================"

# Remove any lock files
rm -rf /opt/hiddify-manager/log/*.lock

# Check and set REDIS_URI_MAIN
if [ -z "$REDIS_URI_MAIN" ]; then
  if [ -z "$REDIS_PASSWORD" ]; then
    echo "ERROR: REDIS_PASSWORD must be set"
    exit 1
  fi
  export REDIS_URI_MAIN="redis://:${REDIS_PASSWORD}@redis:6379/0"
fi

# Check and set REDIS_URI_SSH
if [ -z "$REDIS_URI_SSH" ]; then
  if [ -z "$REDIS_PASSWORD" ]; then
    echo "ERROR: REDIS_PASSWORD must be set"
    exit 1
  fi
  export REDIS_URI_SSH="redis://:${REDIS_PASSWORD}@redis:6379/1"
fi

# Check and set SQLALCHEMY_DATABASE_URI
if [ -z "$SQLALCHEMY_DATABASE_URI" ]; then
  if [ -z "$MYSQL_PASSWORD" ]; then
    echo "ERROR: MYSQL_PASSWORD must be set"
    exit 1
  fi
  export SQLALCHEMY_DATABASE_URI="mysql+mysqldb://hiddifypanel:${MYSQL_PASSWORD}@mariadb/hiddifypanel?charset=utf8mb4"
fi

# Create necessary directories
mkdir -p /hiddify-data/ssl/
mkdir -p /opt/hiddify-manager/log/system/

# Wait for services to be available
echo "Waiting for database and redis..."
sleep 10

# Change to Hiddify directory
cd /opt/hiddify-manager

# Export database environment variables for Hiddify
export MYSQL_DATABASE="${MYSQL_DATABASE:-hiddifypanel}"
export MYSQL_USER="${MYSQL_USER:-hiddifypanel}"

# Run database migrations if needed
if [ -f "manage.py" ]; then
  echo "Running database migrations..."
  python3 manage.py db upgrade 2>/dev/null || true
fi

# Start Hiddify panel in background
echo "Starting Hiddify Panel..."
if [ -f "hiddifypanel/panel/__main__.py" ]; then
  python3 -m hiddifypanel.panel > /opt/hiddify-manager/log/system/panel.log 2>&1 &
  PANEL_PID=$!
elif [ -f "hiddifypanel/__main__.py" ]; then
  python3 -m hiddifypanel > /opt/hiddify-manager/log/system/panel.log 2>&1 &
  PANEL_PID=$!
fi

# Start background tasks
echo "Starting background tasks..."
if [ -f "hiddifypanel/background_tasks.py" ]; then
  python3 hiddifypanel/background_tasks.py > /opt/hiddify-manager/log/system/background.log 2>&1 &
  BACKGROUND_PID=$!
fi

# Wait a bit for services to start
sleep 5

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}' || echo "YOUR_SERVER_IP")

echo "========================================"
echo "Hiddify Manager Started Successfully!"
echo "========================================"
echo ""
echo "Access Panel at:"
echo "  http://${SERVER_IP}/"
echo "  or"
echo "  http://localhost/ (from host)"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "IMPORTANT: Change default password immediately!"
echo "========================================"

# Monitor processes and show logs
if [ ! -z "$PANEL_PID" ] && [ ! -z "$BACKGROUND_PID" ]; then
  # Both processes started, monitor them
  while kill -0 $PANEL_PID 2>/dev/null && kill -0 $BACKGROUND_PID 2>/dev/null; do
    sleep 10
  done
  echo "ERROR: One or more services stopped unexpectedly"
  exit 1
else
  # Fallback: just keep container alive and show logs
  echo "Monitoring logs..."
  exec tail -f /opt/hiddify-manager/log/system/*.log 2>/dev/null || \
       tail -f /opt/hiddify-manager/log/*.log 2>/dev/null || \
       sleep infinity
fi
