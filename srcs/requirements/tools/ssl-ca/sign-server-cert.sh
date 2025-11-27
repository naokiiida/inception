#!/bin/bash

# Script to create and sign a server certificate with the CA
# Simplified version - uses server-cert.cnf for configuration
# Only requires domain name as argument

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 DOMAIN"
    echo ""
    echo "Arguments:"
    echo "  DOMAIN       Domain name (e.g., niida.42.fr)"
    echo ""
    echo "Examples:"
    echo "  $0 niida.42.fr"
    echo "  $0 localhost"
    echo ""
    echo "Note: Subject details are read from server-cert.cnf"
    exit 1
}

# Get domain from first argument
DOMAIN="$1"

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Domain name is required${NC}"
    usage
fi

# Fixed output directory
OUTPUT_DIR="./generated/certs"

# Check if CA exists
if [ ! -f generated/ca-cert.pem ] || [ ! -f generated/ca-key.pem ]; then
    echo -e "${RED}Error: CA certificate or key not found in generated/ directory${NC}"
    echo "Please run create-ca.sh first to set up the Certificate Authority"
    exit 1
fi

# Check if server-cert.cnf exists
if [ ! -f server-cert.cnf ]; then
    echo -e "${RED}Error: server-cert.cnf not found${NC}"
    exit 1
fi

echo -e "${GREEN}=== Generating Server Certificate for: ${DOMAIN} ===${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# File names based on domain
KEY_FILE="${OUTPUT_DIR}/${DOMAIN}-key.pem"
CSR_FILE="${OUTPUT_DIR}/${DOMAIN}-csr.pem"
CERT_FILE="${OUTPUT_DIR}/${DOMAIN}-cert.pem"

# Create a temporary config file by copying server-cert.cnf and modifying it
TEMP_CONFIG=$(mktemp)
cp server-cert.cnf "$TEMP_CONFIG"

# Update the Common Name to use the domain
sed -i.bak "s/^CN[[:space:]]*=.*/CN = ${DOMAIN}/" "$TEMP_CONFIG"
rm -f "${TEMP_CONFIG}.bak"

# Update the DNS.1 entry in alt_names to match the domain
sed -i.bak "s/^DNS\.1[[:space:]]*=.*/DNS.1 = ${DOMAIN}/" "$TEMP_CONFIG"
rm -f "${TEMP_CONFIG}.bak"

# Generate server private key
echo -e "${YELLOW}Generating server private key...${NC}"
openssl genrsa -out "$KEY_FILE" 2048
chmod 400 "$KEY_FILE"
echo -e "${GREEN}Server key created: ${KEY_FILE}${NC}"

# Generate certificate signing request (CSR)
# This uses the defaults from server-cert.cnf (via TEMP_CONFIG)
echo -e "${YELLOW}Generating certificate signing request...${NC}"

openssl req -config "$TEMP_CONFIG" \
    -key "$KEY_FILE" \
    -new -sha256 \
    -out "$CSR_FILE"

echo -e "${GREEN}CSR created: ${CSR_FILE}${NC}"

# Create extension file for signing using v3_req from the config
EXT_FILE=$(mktemp)
cat > "$EXT_FILE" << EOF
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
EOF

# Copy the alt_names section from the temporary config
grep "^DNS\." "$TEMP_CONFIG" >> "$EXT_FILE"
grep "^IP\." "$TEMP_CONFIG" >> "$EXT_FILE"

# Sign the certificate with the CA
echo -e "${YELLOW}Signing certificate with CA...${NC}"
openssl x509 -req -in "$CSR_FILE" \
    -CA generated/ca-cert.pem \
    -CAkey generated/ca-key.pem \
    -CAcreateserial \
    -out "$CERT_FILE" \
    -days 375 -sha256 \
    -extfile "$EXT_FILE"

chmod 444 "$CERT_FILE"
echo -e "${GREEN}Certificate signed: ${CERT_FILE}${NC}"

# Clean up temporary files
rm -f "$TEMP_CONFIG" "$EXT_FILE"

# Display certificate information
echo -e "${BLUE}=== Certificate Information ===${NC}"
echo -e "${YELLOW}Subject:${NC}"
openssl x509 -noout -subject -in "$CERT_FILE"

echo -e ""
echo -e "${YELLOW}Subject Alternative Names:${NC}"
openssl x509 -noout -text -in "$CERT_FILE" | grep -A1 "Subject Alternative Name" || echo "  (No SAN found - this is a problem!)"

echo -e ""
echo -e "${GREEN}=== Certificate Generation Complete! ===${NC}"
echo ""
echo -e "${YELLOW}Generated files:${NC}"
echo "  Private Key: ${KEY_FILE}"
echo "  Certificate: ${CERT_FILE}"
echo "  CSR: ${CSR_FILE}"
echo ""
echo -e "${YELLOW}For Nginx configuration, use:${NC}"
echo "  ssl_certificate     ${CERT_FILE};"
echo "  ssl_certificate_key ${KEY_FILE};"
echo ""
echo -e "${YELLOW}Verify the certificate:${NC}"
echo "  openssl x509 -noout -text -in ${CERT_FILE} | grep -A10 'X509v3 Subject Alternative Name'"
echo "  openssl verify -CAfile generated/ca-cert.pem ${CERT_FILE}"
