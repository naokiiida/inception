#!/bin/bash

# Read password from secrets at runtime
MYSQL_ROOT_PASSWORD=$(cat /run/secrets/mysql_root_password 2>/dev/null)

mariadb-admin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" --silent

if [ $? -eq 0 ]; then
    exit 0
else
    exit 1
fi
