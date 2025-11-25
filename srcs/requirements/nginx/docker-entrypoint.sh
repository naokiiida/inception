#!/bin/bash
set -euo pipefail

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