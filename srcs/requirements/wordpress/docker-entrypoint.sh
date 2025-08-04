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
until mysql -h${WORDPRESS_DB_HOST} -u${WORDPRESS_DB_USER} -p${WORDPRESS_DB_PASSWORD} -e 'SELECT 1' &> /dev/null; do
    echo "Waiting for database connection..."
    sleep 2
done

# Set up WordPress if it's not already installed
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Setting up WordPress configuration..."
    
    # Check if WordPress files exist, if not download them (fallback only)
    if [ ! -f /var/www/html/wp-settings.php ]; then
        echo "WordPress files not found, downloading as fallback..."
        cd /tmp
        curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-6.8.tar.gz"
        echo "c4d8b210decd86dc1bf5deecb3a4a2e1b70024f6 *wordpress.tar.gz" | sha1sum -c -
        tar -xzf wordpress.tar.gz
        cp -a wordpress/* /var/www/html/
        rm -rf wordpress wordpress.tar.gz
        chown -R www-data:www-data /var/www/html
    fi
    
    cd /var/www/html
    
    # Create wp-config.php if it doesn't exist
    if [ ! -f wp-config.php ]; then
        echo "Creating wp-config.php..."
        # Create wp-config.php with the database connection details
        wp config create \
            --dbname=${WORDPRESS_DB_NAME} \
            --dbuser=${WORDPRESS_DB_USER} \
            --dbpass=${WORDPRESS_DB_PASSWORD} \
            --dbhost=${WORDPRESS_DB_HOST} \
            --dbcharset="utf8mb4" \
            --dbcollate="utf8mb4_unicode_ci" \
            --allow-root \
            --force
            
        # Set authentication keys and salts
        echo "Setting up authentication keys and salts..."
        SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
        printf "\n/* Authentication Keys and Salts */\n%s\n" "$SALT" >> wp-config.php
        
        # Set security keys
        echo "Setting up security keys..."
        sed -i "/^define( 'DB_COLLATE', '' );/a \\ndefine('FORCE_SSL_ADMIN', true);" wp-config.php
        sed -i "/^define( 'DB_COLLATE', '' );/a \\ndefine('WP_DEBUG', false);" wp-config.php
        
        # Set file permissions for wp-config.php
        chmod 644 wp-config.php
        
        # Install WordPress if not already installed
        if ! wp core is-installed --allow-root; then
            echo "Installing WordPress..."
            wp core install \
                --url=${WORDPRESS_URL:-http://localhost} \
                --title="${WORDPRESS_TITLE:-WordPress}" \
                --admin_user=${WORDPRESS_ADMIN_USER:-admin} \
                --admin_password=${WORDPRESS_ADMIN_PASSWORD:-password} \
                --admin_email=${WORDPRESS_ADMIN_EMAIL:-admin@example.com} \
                --skip-email \
                --allow-root
            
            # Install and activate theme
            if [ -n "${WORDPRESS_THEME}" ]; then
                wp theme install ${WORDPRESS_THEME} --activate --allow-root
            fi
            
            # Install and activate plugins
            if [ -n "${WORDPRESS_PLUGINS}" ]; then
                for plugin in ${WORDPRESS_PLUGINS//,/ }; do
                    wp plugin install $plugin --activate --allow-root
                done
            fi
            
            # Update permalink structure
            wp rewrite structure '/%postname%/' --allow-root
            wp rewrite flush --hard --allow-root
        fi
    fi
    
    echo "WordPress setup complete!"
else
    echo "WordPress is already installed."
fi

# Execute the CMD
exec "$@"
