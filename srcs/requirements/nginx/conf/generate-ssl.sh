#!/bin/bash

# Create SSL directory if it doesn't exist
mkdir -p /etc/nginx/ssl

# Use LOGIN from environment or whoami as fallback
LOGIN=${LOGIN:-$(whoami)}
DOMAIN="${LOGIN}.42.fr"

echo "Generating SSL certificate for domain: $DOMAIN"

# Generate SSL certificate and private key
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# Generate DH parameters for enhanced security
openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048

# Set proper permissions
chmod 600 /etc/nginx/ssl/key.pem
chmod 644 /etc/nginx/ssl/cert.pem
chmod 644 /etc/nginx/ssl/dhparam.pem

echo "SSL certificate generated successfully for $DOMAIN" 