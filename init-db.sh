#!/bin/bash
set -e

echo "Initializing Hiddify Panel database..."

# MariaDB official image will create the database automatically from MYSQL_DATABASE env var
# We just need to grant proper privileges to the user

# Wait a moment for MariaDB to be fully ready
sleep 2

# Grant all privileges to the user
mysql -u root -p"${MARIADB_ROOT_PASSWORD}" <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL

echo "Database initialized successfully!"
echo "Database: ${MYSQL_DATABASE}"
echo "User: ${MYSQL_USER}"
