#!/bin/bash

# Script to create and sign a server certificate with the CA
# This generates a server certificate with subjectAltName extension
# Uses defaults from server-cert.cnf

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 -d DOMAIN [-a ALT_NAMES] [-o OUTPUT_DIR]"
    echo ""
    echo "Options:"
    echo "  -d DOMAIN       Primary domain name (required)"
    echo "  -a ALT_NAMES    Comma-separated alternative names (optional)"
    echo "                  Example: '*.example.com,example.org,192.168.1.1'"
    echo "  -o OUTPUT_DIR   Output directory for certificates (default: ./certs)"
    echo ""
    echo "Examples:"
    echo "  $0 -d localhost"
    echo "  $0 -d niida.42.fr -a '*.niida.42.fr,www.niida.42.fr'"
    echo "  $0 -d mysite.local -a '*.mysite.local,127.0.0.1' -o /etc/nginx/ssl"
    echo ""
    echo "Note: Subject defaults (Country, City, Org) are read from server-cert.cnf"
    exit 1
}

# Parse command line arguments
DOMAIN=""
ALT_NAMES=""
OUTPUT_DIR="./certs"

while getopts "d:a:o:h" opt; do
    case $opt in
        d) DOMAIN="$OPTARG" ;;
        a) ALT_NAMES="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Error: Domain name is required${NC}"
    usage
fi

# Check if CA exists
if [ ! -f ca-cert.pem ] || [ ! -f ca-key.pem ]; then
    echo -e "${RED}Error: CA certificate or key not found${NC}"
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

# Remove the existing alt_names section and rebuild it
sed -i.bak '/^\[ alt_names \]/,$d' "$TEMP_CONFIG"
rm -f "${TEMP_CONFIG}.bak"

# Build the alt_names section dynamically
cat >> "$TEMP_CONFIG" << EOF

[ alt_names ]
EOF

echo "DNS.1 = ${DOMAIN}" >> "$TEMP_CONFIG"

DNS_COUNT=2
IP_COUNT=1

# Add alternative names if provided
if [ -n "$ALT_NAMES" ]; then
    IFS=',' read -ra NAMES <<< "$ALT_NAMES"
    for name in "${NAMES[@]}"; do
        name=$(echo "$name" | xargs)  # Trim whitespace

        # Check if it's an IP address
        if [[ $name =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ $name =~ ^[0-9a-fA-F:]+$ ]]; then
            echo "IP.${IP_COUNT} = ${name}" >> "$TEMP_CONFIG"
            ((IP_COUNT++))
        else
            echo "DNS.${DNS_COUNT} = ${name}" >> "$TEMP_CONFIG"
            ((DNS_COUNT++))
        fi
    done
fi

# Add localhost by default
echo "DNS.${DNS_COUNT} = localhost" >> "$TEMP_CONFIG"
echo "IP.${IP_COUNT} = 127.0.0.1" >> "$TEMP_CONFIG"
((IP_COUNT++))
echo "IP.${IP_COUNT} = ::1" >> "$TEMP_CONFIG"

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

# Create extension file for signing
# CRITICAL: Must include subjectAltName for SAN to be in the certificate
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

# Copy the alt_names we built into the extension file
grep "^DNS\." "$TEMP_CONFIG" >> "$EXT_FILE"
grep "^IP\." "$TEMP_CONFIG" >> "$EXT_FILE"

# Sign the certificate with the CA
echo -e "${YELLOW}Signing certificate with CA...${NC}"
openssl x509 -req -in "$CSR_FILE" \
    -CA ca-cert.pem \
    -CAkey ca-key.pem \
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
echo "  openssl verify -CAfile ca-cert.pem ${CERT_FILE}"
