#!/bin/bash
set -euo pipefail

# Generate secure random passwords if not provided
if [ -z "${WORDPRESS_DB_USER:-}" ]; then
    export WORDPRESS_DB_USER="wordpress_user"
    echo "Using default database user: $WORDPRESS_DB_USER"
fi

if [ -z "${WORDPRESS_DB_PASSWORD:-}" ]; then
    export WORDPRESS_DB_PASSWORD=$(php -r "echo base64_encode(random_bytes(24));")
    echo "Generated secure random database password"
fi

if [ -z "${WORDPRESS_ADMIN_USER:-}" ]; then
    export WORDPRESS_ADMIN_USER="admin"
    echo "Using default admin user: $WORDPRESS_ADMIN_USER"
fi

if [ -z "${WORDPRESS_ADMIN_PASSWORD:-}" ]; then
    export WORDPRESS_ADMIN_PASSWORD=$(php -r "echo base64_encode(random_bytes(16));")
    echo "Generated secure random admin password"
fi

# Wait for database to be ready
until mysql -h${WORDPRESS_DB_HOST} -uroot -p${DB_ROOT_PASSWORD} -e 'SELECT 1' &> /dev/null; do
    echo "Waiting for database connection as root..."
    sleep 2
done

# Set up WordPress database and user (idempotent)
echo "Setting up WordPress database and user..."
mysql -h${WORDPRESS_DB_HOST} -uroot -p${DB_ROOT_PASSWORD} <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${WORDPRESS_DB_NAME}\`;
    CREATE USER IF NOT EXISTS '${WORDPRESS_DB_USER}'@'%' IDENTIFIED BY '${WORDPRESS_DB_PASSWORD}';
    GRANT ALL ON \`${WORDPRESS_DB_NAME}\`.* TO '${WORDPRESS_DB_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL

# Set up WordPress if it's not already installed
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Running WordPress setup script..."
    /bin/bash /conf/wp-setup.sh
else
    echo "WordPress is already installed."
fi

        
# Execute the CMD
exec "$@"
