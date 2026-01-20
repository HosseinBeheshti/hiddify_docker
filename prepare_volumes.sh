#!/bin/bash

# Script to prepare necessary directories for Hiddify Docker

set -e

echo "Creating necessary directories..."

# Create base directories (only the ones we actually mount as volumes)
mkdir -p docker-data/{hiddify,logs,tmp,mariadb,redis}

# Set proper permissions
chmod -R 755 docker-data/
chmod -R 777 docker-data/tmp
chmod 700 docker-data/mariadb
chmod 700 docker-data/redis

echo "Directories created successfully!"
echo ""
echo "Directory structure:"
tree -L 3 docker-data/ 2>/dev/null || find docker-data/ -type d
echo ""
echo "You can now run: docker-compose up -d"
