#!/bin/bash
set -euo pipefail

# Load database credentials from Docker secrets
export WORDPRESS_DB_PASSWORD=$(cat /run/secrets/mysql_password)
export WORDPRESS_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_pass)
export WORDPRESS_USER_PASSWORD=$(cat /run/secrets/wp_user_pass)

# Wait for MariaDB to be ready
echo "Waiting for MariaDB connection..."
until mariadb-admin ping -h"${WORDPRESS_DB_HOST}" --silent; do
    echo "Waiting for database..."
    sleep 2
done
echo "MariaDB is online."

# Run WordPress setup (installation/configuration)
/bin/bash /conf/wp-setup.sh

# Start PHP-FPM
echo "Starting PHP-FPM..."
exec "$@"
