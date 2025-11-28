FROM debian:bookworm-slim

# Version arguments for easy bumping
ARG MARIADB_VERSION=10.11
# $(apt-cache madison mariadb-server | awk '{print $3}')
ARG MARIADB_PACKAGE_VERSION=1:10.11.11-0+deb12u1

# Install required tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg2 \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Add MariaDB repository
RUN mkdir -p /usr/share/keyrings \
    && curl -fsSL https://mariadb.org/mariadb_release_signing_key.asc | gpg --dearmor -o /usr/share/keyrings/mariadb-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/mariadb-keyring.gpg] https://mirror.mariadb.org/repo/${MARIADB_VERSION}/debian/ $(lsb_release -cs) main" \
       > /etc/apt/sources.list.d/mariadb.list

# Install MariaDB server
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/*

# Configure MariaDB
RUN set -ex \
    && mkdir -p /var/lib/mysql /var/run/mysqld /etc/mysql /var/log/mysql \
    && chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql \
    && chmod 755 /var/run/mysqld

# Copy configuration
COPY ./conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Copy entrypoint and healthcheck scripts
COPY ./docker-entrypoint.sh /usr/local/bin/
COPY ./healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Set up health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=1m --retries=3 \
    CMD healthcheck.sh || exit 1

# Expose port
EXPOSE 3306

# Set entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]

# Start MariaDB
CMD ["mariadbd", "-u", "mysql"]
