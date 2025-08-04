#!/bin/bash

# Wait for MariaDB to be ready
until mysql -h mariadb -u $WORDPRESS_DB_USER -p$WORDPRESS_DB_PASSWORD -e "SELECT 1" >/dev/null 2>&1; do
    echo "Waiting for MariaDB to be ready..."
    sleep 1
done

# Configure WordPress
wp config create \
    --dbname=$WORDPRESS_DB_NAME \
    --dbuser=$WORDPRESS_DB_USER \
    --dbpass=$WORDPRESS_DB_PASSWORD \
    --dbhost=mariadb \
    --allow-root \
    --path=/var/www/html

# Install WordPress
wp core install \
    --url=https://localhost \
    --title="$WORDPRESS_TITLE" \
    --admin_user="$WORDPRESS_ADMIN_USER" \
    --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
    --admin_email="$WORDPRESS_ADMIN_EMAIL" \
    --allow-root \
    --path=/var/www/html

# Create second user
wp user create \
    editor editor@example.com \
    --role=editor \
    --user_pass=editor_password \
    --allow-root \
    --path=/var/www/html

# Set proper permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html 