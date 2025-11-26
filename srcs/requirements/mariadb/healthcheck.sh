#!/bin/bash

mariadb-admin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" --silent

if [ $? -eq 0 ]; then
    exit 0
else
    exit 1
fi
