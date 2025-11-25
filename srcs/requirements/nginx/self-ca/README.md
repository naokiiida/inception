# Certificate Authority (CA) Setup

This directory contains scripts and configuration to create a private Certificate Authority (CA) and sign server certificates that will be trusted by browsers like Firefox.

## Overview

This CA setup allows you to:
- Create a trusted root CA certificate with the `CA:TRUE` extension
- Sign server certificates with `subjectAltName` (SAN) extensions
- Import the CA into Firefox to trust all certificates signed by this CA
- Avoid browser security warnings for your development/internal servers

## Quick Start

### 1. Create the Certificate Authority

```bash
# Make the script executable
chmod +x create-ca.sh

# Run the CA creation script
./create-ca.sh
```

You'll be prompted for:
- A passphrase for the CA private key (choose a strong one!)
- Certificate details (Country, State, Organization, etc.)
- Common Name (e.g., "My Development CA")

This creates:
- `ca-key.pem` - CA private key (keep this secure!)
- `ca-cert.pem` - CA certificate (import this into browsers)

### 2. Generate and Sign a Server Certificate

```bash
# Make the script executable
chmod +x sign-server-cert.sh

# Generate a certificate for a single domain
./sign-server-cert.sh -d example.com

# Generate a certificate with alternative names
./sign-server-cert.sh -d example.com -a "*.example.com,www.example.com"

# Generate with custom output directory
./sign-server-cert.sh -d mysite.local -a "*.mysite.local,127.0.0.1" -o ../conf
```

This creates:
- `{domain}-key.pem` - Server private key
- `{domain}-cert.pem` - Signed server certificate
- `{domain}-csr.pem` - Certificate signing request

### 3. Import CA Certificate into Firefox

#### Method 1: Firefox Preferences (Recommended)

1. Open Firefox and navigate to: `about:preferences#privacy`
2. Scroll down to **Certificates** section
3. Click **View Certificates** button
4. Go to the **Authorities** tab
5. Click **Import** button
6. Select the `ca-cert.pem` file from this directory
7. Check the box: **"Trust this CA to identify websites"**
8. Click **OK**

#### Method 2: Direct URL

1. Open Firefox
2. Navigate to: `about:preferences#privacy`
3. Search for "certificates"
4. Click "View Certificates"
5. Click the "Authorities" tab
6. Click "Import..."
7. Browse to and select `ca-cert.pem`
8. Check "Trust this CA to identify websites"
9. Click OK

#### Method 3: Command Line (macOS/Linux)

```bash
# For Firefox using certutil (if installed)
certutil -A -n "My Development CA" -t "C,," -i ca-cert.pem -d ~/.mozilla/firefox/*.default-release
```

### 4. Verify the Import

1. In Firefox, go to: `about:preferences#privacy`
2. Click **View Certificates** → **Authorities** tab
3. Look for your CA name in the list
4. You should see it listed under the organization name you specified

## File Structure

```
self-ca/
├── README.md                 # This file
├── ca-config.cnf            # OpenSSL CA configuration
├── server-cert.cnf          # Server certificate template
├── create-ca.sh             # Script to create the CA
├── sign-server-cert.sh      # Script to sign server certificates
├── ca-key.pem               # CA private key (generated)
├── ca-cert.pem              # CA certificate (generated)
├── certs/                   # Directory for server certificates
├── private/                 # Directory for private keys
├── newcerts/                # Directory for issued certificates
├── index.txt                # Certificate database
├── serial                   # Serial number tracker
└── crlnumber                # CRL number tracker
```

## Using Certificates with Nginx

After generating a server certificate, configure Nginx:

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate     /path/to/certs/example.com-cert.pem;
    ssl_certificate_key /path/to/certs/example.com-key.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # ... rest of your configuration
}
```

## Security Notes

### CA Private Key Protection

The `ca-key.pem` file is **extremely sensitive**:
- It's encrypted with a passphrase
- Keep it secure and backed up
- Never share it or commit it to version control
- If compromised, all certificates signed by this CA are compromised

### Best Practices

1. **Passphrase**: Use a strong passphrase for the CA private key
2. **Permissions**: The scripts set restrictive permissions automatically
3. **Backup**: Backup `ca-key.pem` and `ca-cert.pem` securely
4. **Validity**: CA is valid for 10 years, server certs for 375 days
5. **Storage**: Keep the CA files in a secure location

### For Production

**WARNING**: This CA setup is designed for:
- Development environments
- Internal networks
- Testing purposes

For production websites, use certificates from trusted public CAs like:
- Let's Encrypt (free)
- DigiCert
- GlobalSign

## Troubleshooting

### "CA:TRUE not found" in Firefox

Make sure the CA certificate was generated with the `v3_ca` extension:

```bash
openssl x509 -noout -text -in ca-cert.pem | grep "CA:TRUE"
```

You should see: `CA:TRUE`

### Certificate Not Trusted After Import

1. Verify you imported to the **Authorities** tab (not Personal or Servers)
2. Verify you checked **"Trust this CA to identify websites"**
3. Restart Firefox
4. Check that the server certificate was signed by this CA:
   ```bash
   openssl verify -CAfile ca-cert.pem certs/example.com-cert.pem
   ```

### "NET::ERR_CERT_COMMON_NAME_INVALID"

The domain doesn't match the certificate. Check:

```bash
openssl x509 -noout -text -in certs/example.com-cert.pem | grep -A1 "Subject Alternative Name"
```

Make sure your domain is listed in the DNS entries.

### Regenerating Everything

If you need to start over:

```bash
# Backup if needed
mkdir backup
mv ca-*.pem backup/

# Clean up
rm -rf certs/* newcerts/* private/*
rm -f index.txt* serial* crlnumber*

# Start fresh
./create-ca.sh
```

## Advanced Usage

### Viewing Certificate Information

```bash
# View CA certificate details
openssl x509 -noout -text -in ca-cert.pem

# View server certificate details
openssl x509 -noout -text -in certs/example.com-cert.pem

# Verify certificate chain
openssl verify -CAfile ca-cert.pem certs/example.com-cert.pem
```

### Creating Wildcard Certificates

```bash
./sign-server-cert.sh -d "*.example.com" -a "example.com"
```

### Multiple Domains in One Certificate

```bash
./sign-server-cert.sh -d example.com -a "*.example.com,example.org,*.example.org,localhost,127.0.0.1"
```

### Custom Certificate Validity

Edit `sign-server-cert.sh` and change the `-days 375` parameter in the `openssl x509` command.

## Additional Browser Instructions

### Chrome/Chromium (macOS)

1. Open **Keychain Access**
2. Select **System** keychain
3. Drag and drop `ca-cert.pem` into the keychain
4. Double-click the certificate
5. Expand **Trust** section
6. Set **When using this certificate** to **Always Trust**

### Chrome/Chromium (Linux)

```bash
# Install ca-certificates package if not already installed
sudo apt-get install ca-certificates

# Copy CA certificate
sudo cp ca-cert.pem /usr/local/share/ca-certificates/my-ca.crt

# Update certificate store
sudo update-ca-certificates
```

### Chrome/Chromium (Windows)

1. Open Chrome Settings
2. Search for "certificates"
3. Click "Manage certificates"
4. Go to "Trusted Root Certification Authorities" tab
5. Click "Import"
6. Select `ca-cert.pem`
7. Complete the wizard

### Safari (macOS)

1. Double-click `ca-cert.pem` to open Keychain Access
2. Select **System** keychain when prompted
3. Enter your password
4. Find the certificate in the list
5. Double-click it
6. Expand **Trust**
7. Set **When using this certificate** to **Always Trust**
8. Close the window and enter your password again

## References

- [OpenSSL Certificate Authority](https://jamielinux.com/docs/openssl-certificate-authority/)
- [Firefox Certificate Management](https://support.mozilla.org/en-US/kb/setting-certificate-authorities-firefox)
- [Subject Alternative Name](https://en.wikipedia.org/wiki/Subject_Alternative_Name)
- [X.509 Certificates](https://en.wikipedia.org/wiki/X.509)

## License

This is free and unencumbered software released into the public domain.
