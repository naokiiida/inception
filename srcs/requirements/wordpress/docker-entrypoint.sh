#!/bin/bash
set -euo pipefail

# 1. GENERATE SECRETS (If not provided in Docker Compose)
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

# 2. WAIT FOR DATABASE
# We use mariadb-admin (or mysqladmin) to ping until the server answers.
echo "Waiting for MariaDB connection..."
until mariadb-admin ping -h"${WORDPRESS_DB_HOST}" --silent; do
    echo "Waiting for database..."
    sleep 2
done
echo "MariaDB is online."

# 3. CREATE DB USER (Idempotent)
# This ensures the WP user exists even if the DB volume was persisted but the user wasn't.
echo "Setting up WordPress database and user..."
mysql -h"${WORDPRESS_DB_HOST}" -u root -p"${DB_ROOT_PASSWORD}" <<-EOSQL
    CREATE DATABASE IF NOT EXISTS \`${WORDPRESS_DB_NAME}\`;
    CREATE USER IF NOT EXISTS '${WORDPRESS_DB_USER}'@'%' IDENTIFIED BY '${WORDPRESS_DB_PASSWORD}';
    GRANT ALL ON \`${WORDPRESS_DB_NAME}\`.* TO '${WORDPRESS_DB_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL

# 4. HANDOFF TO SETUP SCRIPT
# We run this unconditionally. The script itself checks if it needs to install or update.
/bin/bash /conf/wp-setup.sh

# 5. EXECUTE CMD (php-fpm)
echo "Entrypoint setup done. Executing CMD..."
exec "$@"
