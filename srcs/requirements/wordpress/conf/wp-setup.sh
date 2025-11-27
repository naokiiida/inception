#!/bin/bash
set -euo pipefail

cd /var/www/html

# ----------------------------------------------------------------
# PHASE 1: URL MISMATCH CHECK (The Warning)
# ----------------------------------------------------------------
# If wp-config exists, we check if the requested URL matches the DB URL.
if [ -f wp-config.php ] && wp core is-installed --allow-root; then
    CURRENT_URL=$(wp option get siteurl --allow-root)
    # Remove trailing slash if present for comparison
    CURRENT_URL=${CURRENT_URL%/}
    TARGET_URL=${WORDPRESS_URL%/}

    if [ "$CURRENT_URL" != "$TARGET_URL" ]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "⚠️  WARNING: URL MISMATCH DETECTED ⚠️"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Current Database URL: $CURRENT_URL"
        echo "Requested URL (YAML): $TARGET_URL"
        echo ""
        echo "Changing WORDPRESS_URL in docker-compose is NOT enough."
        echo "WordPress stores the URL in the database."
        echo ""
        echo "To fix this, either:"
        echo "1. Revert WORDPRESS_URL to match the database."
        echo "2. Delete the database volume to reinstall: docker compose down -v"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        # We continue execution so the site runs (on the old URL), 
        # allowing the user to backup or export data if needed.
    fi
fi

# ----------------------------------------------------------------
# PHASE 2: INITIAL INSTALLATION (Run Once)
# ----------------------------------------------------------------
if [ ! -f wp-config.php ]; then
    echo "--- First time setup detected. Installing... ---"
    
    # Copy core files if directory is empty
    if [ ! -f index.php ]; then
        cp -a /usr/src/wordpress/* .
        chown -R www-data:www-data .
    fi

    # Create standard wp-config.php (Static, no dynamic PHP)
    wp config create \
        --dbname="${WORDPRESS_DB_NAME}" \
        --dbuser="${WORDPRESS_DB_USER}" \
        --dbpass="${WORDPRESS_DB_PASSWORD}" \
        --dbhost="${WORDPRESS_DB_HOST}" \
        --dbcharset="utf8mb4" \
        --dbcollate="utf8mb4_unicode_ci" \
        --allow-root \
        --force

    # Security settings
    sed -i "/^define( 'DB_COLLATE', '' );/a define('FORCE_SSL_ADMIN', true);" wp-config.php
    
    # Core Install
    wp core install \
        --url="${WORDPRESS_URL}" \
        --title="${WORDPRESS_TITLE}" \
        --admin_user="${WORDPRESS_ADMIN_USER}" \
        --admin_password="${WORDPRESS_ADMIN_PASSWORD}" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root

    # Install Theme/Plugins (Optional)
    if [ -n "${WORDPRESS_THEME:-}" ]; then
        wp theme install ${WORDPRESS_THEME} --activate --allow-root
    fi

    # Create author user
    if [ -n "${WORDPRESS_USER:-}" ]; then
        wp user create "${WORDPRESS_USER}" "${WORDPRESS_USER_EMAIL}" \
            --role=author \
            --user_pass="${WORDPRESS_USER_PASSWORD}" \
            --allow-root
        echo "Author user created: ${WORDPRESS_USER}"
    fi

    echo "--- Installation Complete ---"
fi

# ----------------------------------------------------------------
# PHASE 3: RECURRING CONFIGURATION (Run Every Time)
# ----------------------------------------------------------------
# This ensures that if you change the Title or Admin Password in YAML,
# it actually updates the running site.

if wp core is-installed --allow-root; then
    echo "--- Checking for configuration updates... ---"
    
    # 1. Update Blog Title (Safe to change)
    wp option update blogname "${WORDPRESS_TITLE}" --allow-root

    # 2. Update Admin User (Password/Email sync)
    if wp user get "${WORDPRESS_ADMIN_USER}" --allow-root > /dev/null 2>&1; then
        wp user update "${WORDPRESS_ADMIN_USER}" \
            --user_pass="${WORDPRESS_ADMIN_PASSWORD}" \
            --user_email="${WORDPRESS_ADMIN_EMAIL}" \
            --allow-root
    fi

    # 3. Update Author User (Password/Email sync)
    if [ -n "${WORDPRESS_USER:-}" ] && wp user get "${WORDPRESS_USER}" --allow-root > /dev/null 2>&1; then
        wp user update "${WORDPRESS_USER}" \
            --user_pass="${WORDPRESS_USER_PASSWORD}" \
            --user_email="${WORDPRESS_USER_EMAIL}" \
            --allow-root
    fi

    # 4. Flush Cache (Good practice on restart)
    wp cache flush --allow-root
fi

# Final Permissions Fix
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "WordPress setup finished."
