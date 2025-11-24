#!/bin/bash

# Create SSL directory if it doesn't exist
mkdir -p /etc/nginx/ssl

# Use LOGIN from environment or whoami as fallback
LOGIN=${LOGIN:-$(whoami)}
DOMAIN="${LOGIN}.42.fr"

echo "Generating SSL certificate for domain: $DOMAIN"

# Create OpenSSL config file with proper extensions
cat > /tmp/openssl.cnf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_ca

[dn]
C = US
ST = State
L = City
O = Organization
CN = $DOMAIN

[v3_ca]
subjectAltName = @alt_names
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

# Generate SSL certificate and private key with proper extensions
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -config /tmp/openssl.cnf \
    -extensions v3_ca

# Generate DH parameters for enhanced security
openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048

# Set proper permissions
chmod 600 /etc/nginx/ssl/key.pem
chmod 644 /etc/nginx/ssl/cert.pem
chmod 644 /etc/nginx/ssl/dhparam.pem

echo "SSL certificate generated successfully for $DOMAIN" 