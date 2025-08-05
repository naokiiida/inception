#!/bin/bash
set -euo pipefail

# Set default values for environment variables
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-root_password}
MYSQL_DATABASE=${MYSQL_DATABASE:-wordpress}
MYSQL_USER=${MYSQL_USER:-wordpress_user}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-wordpress_password}

# Initialize database if it doesn't exist
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql --rpm
    
    # Start temporary server for initialization
    mysqld --skip-networking --socket=/var/run/mysqld/mysqld.sock &
    MYSQL_PID=$!
    
    # Wait for server to start
    for i in {30..0}; do
        if mysql --protocol=socket -uroot -hlocalhost --socket=/var/run/mysqld/mysqld.sock -e 'SELECT 1' &> /dev/null; then
            break
        fi
        echo 'Waiting for server startup...'
        sleep 1
    done
    
    # Set root access
    echo "Setting up database and users..."
    mysql --protocol=socket -uroot -hlocalhost --socket=/var/run/mysqld/mysqld.sock <<-EOSQL
        SET @@SESSION.SQL_LOG_BIN=0;
        DELETE FROM mysql.user WHERE user='root' AND host NOT IN ('localhost', '127.0.0.1', '::1');
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
        GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
        DROP DATABASE IF EXISTS test;
        FLUSH PRIVILEGES;

EOSQL
    
    # Shutdown temporary server
    if ! kill -s TERM "$MYSQL_PID" || ! wait "$MYSQL_PID"; then
        echo >&2 'Failed to stop temporary MySQL server'
        exit 1
    fi
    
    echo 'MySQL init process done. Ready for start up.'
fi

# Execute the CMD
echo "Starting MariaDB server..."
exec "$@"
