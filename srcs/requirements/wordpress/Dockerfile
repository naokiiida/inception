FROM debian:bookworm-slim

# WordPress version configuration
ARG WORDPRESS_VERSION=6.8
ARG WORDPRESS_SHA1=c4d8b210decd86dc1bf5deecb3a4a2e1b70024f6

# Default environment variables for WordPress configuration (non-sensitive only)
ENV WORDPRESS_DB_HOST=mariadb
ENV WORDPRESS_DB_NAME=wordpress
ENV WORDPRESS_URL=https://${LOGIN}.42.fr
ENV WORDPRESS_TITLE="My WordPress Site"
ENV WORDPRESS_ADMIN_EMAIL=admin@example.com
ENV WORDPRESS_THEME=""
ENV WORDPRESS_PLUGINS=""

# Install required tools and PHP with extensions
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg2 \
    lsb-release \
    mariadb-client \
    && curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/php.gpg \
    && echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php8.2-fpm \
        php8.2-mysql \
        php8.2-curl \
        php8.2-gd \
        php8.2-mbstring \
        php8.2-xml \
        php8.2-zip \
        php8.2-intl \
        php8.2-opcache \
        php8.2-common \
        php8.2-soap \
        php8.2-redis \
        php8.2-imagick \
        php8.2-bcmath \
        php8.2-imap \
        php8.2-xmlrpc \
        php8.2-readline \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/www/html \
    && chown -R www-data:www-data /var/www/html \
    && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# Configure PHP-FPM
RUN mkdir -p /var/run/php \
    && chown -R www-data:www-data /var/run/php \
    && echo '\n\n; Custom PHP settings\n\
; Maximum execution time\nmax_execution_time = 300\n\
; Maximum input variables\nmax_input_vars = 3000\n\
; Memory limit\nmemory_limit = 256M\n\
; Post max size\npost_max_size = 64M\n\
; Upload max filesize\nupload_max_filesize = 64M\n\
; Max file uploads\nmax_file_uploads = 20\n' \
    >> /etc/php/8.2/fpm/php.ini

# Configure PHP-FPM pool
RUN echo '[www]\n\
user = www-data\n\
group = www-data\n\
listen = 9000\n\
; Use TCP socket for better compatibility\nlisten = 0.0.0.0:9000\n\
; Process manager settings\npm = dynamic\n\
pm.max_children = 5\n\
pm.start_servers = 2\n\
pm.min_spare_servers = 1\n\
pm.max_spare_servers = 3\n\
; Security\nchdir = /\n' > /etc/php/8.2/fpm/pool.d/www.conf

# Download and prepare WordPress
RUN set -eux; \
    curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"; \
    echo "${WORDPRESS_SHA1} *wordpress.tar.gz" | sha1sum -c -; \
    tar -xzf wordpress.tar.gz; \
    cp -a wordpress/* /var/www/html/; \
    cp -a wordpress /usr/src/wordpress; \
    rm -rf wordpress wordpress.tar.gz; \
    chown -R www-data:www-data /var/www/html; \
    chmod -R 755 /var/www/html

COPY ./docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

COPY ./conf/wp-setup.sh /conf/wp-setup.sh
RUN chmod +x /conf/wp-setup.sh

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD pgrep -f "php-fpm.*master" > /dev/null || exit 1

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["php-fpm8.2", "-F"]
