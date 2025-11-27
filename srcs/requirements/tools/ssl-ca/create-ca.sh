#!/bin/bash

# Script to create a Certificate Authority (CA)
# This CA can be used to sign server certificates that will be trusted by browsers

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Certificate Authority Setup ===${NC}"

# Check if OpenSSL is installed
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: OpenSSL is not installed${NC}"
    exit 1
fi

# Create generated directory for all generated files
echo -e "${YELLOW}Creating generated directory structure...${NC}"
mkdir -p generated/certs

# Create CA database files if they don't exist
if [ ! -f generated/index.txt ]; then
    touch generated/index.txt
    echo -e "${GREEN}Created generated/index.txt${NC}"
fi

if [ ! -f generated/serial ]; then
    echo 1000 > generated/serial
    echo -e "${GREEN}Created generated/serial${NC}"
fi

if [ ! -f generated/crlnumber ]; then
    echo 1000 > generated/crlnumber
    echo -e "${GREEN}Created generated/crlnumber${NC}"
fi

# Generate CA private key
echo -e "${YELLOW}Generating CA private key...${NC}"
if [ -f generated/ca-key.pem ]; then
    echo -e "${YELLOW}Warning: ca-key.pem already exists. Skipping key generation.${NC}"
    echo -e "${YELLOW}If you want to regenerate, delete generated/ca-key.pem first.${NC}"
else
    openssl genrsa -aes256 -out generated/ca-key.pem 4096
    chmod 400 generated/ca-key.pem
    echo -e "${GREEN}CA private key generated: generated/ca-key.pem${NC}"
fi

# Generate CA certificate
echo -e "${YELLOW}Generating CA certificate...${NC}"
if [ -f generated/ca-cert.pem ]; then
    echo -e "${YELLOW}Warning: ca-cert.pem already exists. Skipping certificate generation.${NC}"
    echo -e "${YELLOW}If you want to regenerate, delete generated/ca-cert.pem first.${NC}"
else
    openssl req -config ca-config.cnf \
        -key generated/ca-key.pem \
        -new -x509 -days 3650 -sha256 \
        -extensions v3_ca \
        -out generated/ca-cert.pem

    chmod 444 generated/ca-cert.pem
    echo -e "${GREEN}CA certificate generated: generated/ca-cert.pem${NC}"
fi

# Display certificate information
echo -e "${GREEN}=== CA Certificate Information ===${NC}"
openssl x509 -noout -text -in generated/ca-cert.pem | grep -A 2 "Subject:"
openssl x509 -noout -text -in generated/ca-cert.pem | grep -A 2 "CA:"

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Import generated/ca-cert.pem into Firefox (Authorities tab)"
echo "2. Use sign-server-cert.sh to create and sign server certificates"
echo ""
echo -e "${YELLOW}CA Certificate location: $(pwd)/generated/ca-cert.pem${NC}"
