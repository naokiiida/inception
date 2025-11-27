#!/bin/bash

# Check 1: Is PHP-FPM process running?
if ! pgrep -f "php-fpm.*master" > /dev/null; then
    exit 1
fi

# Check 2: Can PHP-FPM accept connections?
# Use cgi-fcgi to ping PHP-FPM on port 9000
if ! command -v cgi-fcgi > /dev/null 2>&1; then
    # Fallback: Just check if the socket/port is listening
    if ! nc -z localhost 9000 2>/dev/null; then
        exit 1
    fi
else
    # Use cgi-fcgi to properly test FastCGI connection
    if ! SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect localhost:9000 > /dev/null 2>&1; then
        exit 1
    fi
fi

# Check 3: Is WordPress installed?
if [ -f /var/www/html/wp-config.php ]; then
    # WordPress is configured, check if it's actually working
    if ! wp core is-installed --allow-root --path=/var/www/html 2>/dev/null; then
        # wp-config exists but WordPress not installed yet - still setting up
        exit 1
    fi
fi

exit 0
