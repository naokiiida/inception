# SSL Certificate Authority Tools

This directory contains tools to create and manage a self-signed Certificate Authority (CA) and server certificates for development purposes.

## Directory Structure

```
ssl-ca/
├── create-ca.sh           # Script to create Certificate Authority
├── sign-server-cert.sh    # Script to sign server certificates
├── ca-config.cnf          # OpenSSL CA configuration
├── server-cert.cnf        # OpenSSL server certificate configuration
└── generated/             # All generated files (gitignored)
    ├── ca-cert.pem        # CA certificate (public)
    ├── ca-key.pem         # CA private key (NEVER COMMIT!)
    ├── index.txt          # Certificate database
    ├── serial             # Serial number tracker
    ├── crlnumber          # CRL number tracker
    └── certs/             # Generated server certificates
        ├── *.42.fr-cert.pem
        ├── *.42.fr-key.pem
        └── *.42.fr-csr.pem
```

## Usage

### 1. Create Certificate Authority

```bash
./create-ca.sh
```

This creates a CA certificate that can be imported into your browser to trust all certificates signed by it.

### 2. Generate Server Certificate

```bash
./sign-server-cert.sh -d your-domain.42.fr -a "*.your-domain.42.fr,localhost,127.0.0.1"
```

Options:
- `-d DOMAIN`: Primary domain name (required)
- `-a ALT_NAMES`: Comma-separated alternative names (optional)
- `-o OUTPUT_DIR`: Output directory (default: ./generated/certs)

### 3. Clean Up Generated Files

To remove all generated certificates and start fresh:

```bash
rm -rf generated/
```

All generated files are stored in the `generated/` directory, making cleanup simple and safe.

## From Project Root

Use the Makefile targets:

```bash
make ca-create      # Create CA
make cert-create    # Generate server certificate
make ssl-setup      # Complete SSL setup
```

## Notes

- All generated files are stored in `generated/` directory
- The `generated/` directory is gitignored to prevent committing secrets
- CA private key is encrypted with a passphrase for security
- Server certificates are valid for 375 days
- Certificates include Subject Alternative Names (SAN) for modern browser compatibility
