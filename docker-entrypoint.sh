#!/bin/bash
set -e

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

# Create SSL directory if it doesn't exist
mkdir -p /hiddify-data/ssl/

# Check systemctl
systemctl is-active --quiet hiddify-panel 2>/dev/null || {
  echo "Starting hiddify-panel service..."
  systemctl restart hiddify-panel 2>/dev/null || true
}

# Run installation/update
cd /opt/hiddify-manager
DO_NOT_INSTALL=true ./install.sh docker --no-gui "$@" || true

# Show status
./status.sh --no-gui || true

echo "========================================"
echo "Hiddify Manager is starting..."
echo "========================================"
sleep 5

# Tail logs
exec tail -f /opt/hiddify-manager/log/system/* 2>/dev/null || tail -f /opt/hiddify-manager/log/*.log 2>/dev/null || sleep infinity
