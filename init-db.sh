#!/bin/bash
set -e

echo "Initializing Hiddify Panel database and user..."

# This script runs automatically when MariaDB container starts for the first time
# All environment variables from docker.env are available here

# The MariaDB official image automatically:
# - Sets root password to MYSQL_PASSWORD (we'll use it as both root and user password)
# - Creates MYSQL_DATABASE if set
# - Creates MYSQL_USER with MYSQL_PASSWORD if both are set

# Since we're setting all these variables in docker.env, MariaDB will handle the setup
# This script just confirms the setup

echo "Database: ${MYSQL_DATABASE:-hiddifypanel}"
echo "User: ${MYSQL_USER:-hiddifypanel}"
echo "Database initialization complete!"
