#!/bin/bash
set -euo pipefail

# Check if certificates need generation/regeneration
CERT_FILE="/etc/nginx/ssl/cert.pem"
KEY_FILE="/etc/nginx/ssl/key.pem"
DHPARAM_FILE="/etc/nginx/ssl/dhparam.pem"
CERT_DOMAIN_FILE="/etc/nginx/ssl/.domain"

# Get current domain (let generate-ssl.sh handle LOGIN logic)
CURRENT_DOMAIN="${LOGIN:-$(whoami)}.42.fr"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ] || [ ! -f "$DHPARAM_FILE" ] || [ ! -f "$CERT_DOMAIN_FILE" ] || [ "$(cat $CERT_DOMAIN_FILE 2>/dev/null)" != "$CURRENT_DOMAIN" ]; then
    echo "Generating SSL certificates..."
    /usr/local/bin/generate-ssl.sh
    echo "$CURRENT_DOMAIN" > "$CERT_DOMAIN_FILE"
else
    echo "SSL certificates exist for $CURRENT_DOMAIN"
fi

# Template nginx config with environment variables
export BACKEND_SERVICE="${BACKEND_SERVICE:-wordpress}"
export BACKEND_PORT="${BACKEND_PORT:-9000}"
export BACKEND_PROTOCOL="${BACKEND_PROTOCOL:-fastcgi}"
export APP_ROOT="${APP_ROOT:-/var/www/html}"
export DOMAIN="${LOGIN:-$(whoami)}.42.fr"

# Use envsubst to substitute variables in config
for conf in /etc/nginx/conf.d/*.conf; do
    envsubst '${BACKEND_SERVICE} ${BACKEND_PORT} ${BACKEND_PROTOCOL} ${APP_ROOT} ${DOMAIN}' < "$conf" > "/tmp/$(basename $conf)"
    mv "/tmp/$(basename $conf)" "$conf"
done

# Test and start nginx
nginx -t
exec "$@"