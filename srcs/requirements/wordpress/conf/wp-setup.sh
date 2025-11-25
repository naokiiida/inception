#!/bin/bash
set -euo pipefail

# Only run if WordPress is not already installed
if [ ! -f /var/www/html/wp-config.php ]; then
    # If /var/www/html is empty, copy core files from /usr/src/wordpress (where Dockerfile puts them)
    if [ ! -f /var/www/html/index.php ]; then
        echo "Copying WordPress core files to /var/www/html..."
        cp -a /usr/src/wordpress/* /var/www/html/
        chown -R www-data:www-data /var/www/html
    fi
    cd /var/www/html

    # Create wp-config.php
    wp config create \
        --dbname="${WORDPRESS_DB_NAME}" \
        --dbuser="${WORDPRESS_DB_USER}" \
        --dbpass="${WORDPRESS_DB_PASSWORD}" \
        --dbhost="${WORDPRESS_DB_HOST}" \
        --dbcharset="utf8mb4" \
        --dbcollate="utf8mb4_unicode_ci" \
        --allow-root \
        --force

    # Set authentication keys and salts
    SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
    printf "\n/* Authentication Keys and Salts */\n%s\n" "$SALT" >> wp-config.php

    # Set security keys
    sed -i "/^define( 'DB_COLLATE', '' );/a \
define('FORCE_SSL_ADMIN', true);" wp-config.php
    sed -i "/^define( 'DB_COLLATE', '' );/a \
define('WP_DEBUG', false);" wp-config.php

    # Set file permissions
    chmod 644 wp-config.php

    # Install WordPress if not already installed
    if ! wp core is-installed --allow-root; then
        wp core install \
            --url="${WORDPRESS_URL:-https://${LOGIN}.42.fr}" \
            --title="${WORDPRESS_TITLE:-WordPress}" \
            --admin_user="${WORDPRESS_ADMIN_USER}" \
            --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
            --admin_email="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}" \
            --skip-email \
            --allow-root

        # Install and activate theme
        if [ -n "${WORDPRESS_THEME:-}" ]; then
            wp theme install ${WORDPRESS_THEME} --activate --allow-root
        fi

        # Install and activate plugins
        if [ -n "${WORDPRESS_PLUGINS:-}" ]; then
            for plugin in ${WORDPRESS_PLUGINS//,/ }; do
                wp plugin install $plugin --activate --allow-root
            done
        fi

        # Update permalink structure
        wp rewrite structure '/%postname%/' --allow-root
        wp rewrite flush --hard --allow-root
    else
        # WordPress is already installed, update the site URL if needed
        CURRENT_URL=$(wp option get siteurl --allow-root)
        EXPECTED_URL="${WORDPRESS_URL:-https://${LOGIN}.42.fr}"
        
        if [ "$CURRENT_URL" != "$EXPECTED_URL" ]; then
            echo "Updating WordPress site URL from $CURRENT_URL to $EXPECTED_URL"
            wp option update siteurl "$EXPECTED_URL" --allow-root
            wp option update home "$EXPECTED_URL" --allow-root
            wp cache flush --allow-root
        fi
    fi

    echo "WordPress setup complete!"
else
    echo "WordPress is already installed."
fi

# Set proper permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
