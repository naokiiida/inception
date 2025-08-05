FROM debian:bookworm-slim

# Install required tools and NGINX
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg2 \
    lsb-release \
    debian-archive-keyring \
    openssl \
    && curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/debian $(lsb_release -cs) nginx" \
       > /etc/apt/sources.list.d/nginx.list \
    && apt-get update \
     && apt-get install -y --no-install-recommends nginx gettext-base \
     && rm -rf /var/lib/apt/lists/*
# Configure NGINX
RUN rm -f /etc/nginx/conf.d/default.conf \
    && mkdir -p /etc/nginx/ssl \
    && mkdir -p /var/www/html \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Copy configuration files
COPY ./conf/nginx.conf /etc/nginx/nginx.conf
COPY ./conf/default.conf /etc/nginx/conf.d/default.conf
COPY ./conf/generate-ssl.sh /usr/local/bin/
COPY ./docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/generate-ssl.sh /usr/local/bin/docker-entrypoint.sh

# Set up health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -k -f https://localhost:443/ || exit 1

# Expose ports
EXPOSE 443

# Set entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]
