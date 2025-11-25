# Configuration Summary for niida@42 Tokyo

## Your Certificate Configuration

### Location Information
- **Country**: JP (Japan)
- **State/Province**: Tokyo
- **City**: Tokyo
- **Organization**: 42 Tokyo
- **Organizational Unit**: Cadet
- **Email**: niida@student.42tokyo.jp

### Domain Configuration
- **Primary Domain**: niida.42.fr
- **Wildcard**: *.niida.42.fr
- **Subdomain**: www.niida.42.fr
- **Local**: localhost, *.localhost
- **IP Addresses**: 127.0.0.1, ::1

## What This Means

### ca-config.cnf
This file controls your **Certificate Authority (CA)** settings. When you run `./create-ca.sh`, it will:

1. Prompt you to create your CA certificate with these defaults:
   ```
   Country Name: JP
   State: Tokyo
   Locality: Tokyo
   Organization: 42 Tokyo
   Organizational Unit: Cadet
   Common Name: [You'll enter this - e.g., "42 Tokyo Development CA"]
   Email: niida@student.42tokyo.jp
   ```

2. You can accept defaults by pressing Enter or change any value

3. The most important field is **Common Name** - this is your CA's name
   - Good examples: "42 Tokyo Development CA", "niida's CA", "Inception CA"
   - This name will appear in Firefox's Authorities list

### server-cert.cnf
This file has default values for **server certificates**. However, the `sign-server-cert.sh` script will:

1. Override the alt_names section based on the domain you specify
2. Use these Tokyo defaults for the certificate subject
3. Automatically include your domain + wildcards + localhost

## Usage Examples

### Example 1: Create Your CA
```bash
./create-ca.sh
```

**You'll see:**
```
Country Name (2 letter code) [JP]: ← Press Enter (uses default)
State or Province Name [Tokyo]: ← Press Enter
Locality Name [Tokyo]: ← Press Enter
Organization Name [42 Tokyo]: ← Press Enter
Organizational Unit Name [Cadet]: ← Press Enter
Common Name []: 42 Tokyo Development CA ← Type this (or your preferred CA name)
Email Address [niida@student.42tokyo.jp]: ← Press Enter
```

### Example 2: Generate Certificate for Your Domain
```bash
./sign-server-cert.sh -d niida.42.fr
```

This automatically creates a certificate with:
- ✅ niida.42.fr
- ✅ *.niida.42.fr (wildcard for subdomains)
- ✅ localhost
- ✅ 127.0.0.1

### Example 3: Add Extra Domains/IPs
```bash
./sign-server-cert.sh -d niida.42.fr -a "blog.niida.42.fr,api.niida.42.fr,192.168.1.100"
```

## Certificate Structure Preview

When you create your CA certificate, it will look like this:

```
Subject:
    C=JP
    ST=Tokyo
    L=Tokyo
    O=42 Tokyo
    OU=Cadet
    CN=42 Tokyo Development CA
    emailAddress=niida@student.42tokyo.jp

Extensions:
    X509v3 Basic Constraints: critical
        CA:TRUE  ← This makes it a valid Certificate Authority
    X509v3 Key Usage: critical
        Certificate Sign, CRL Sign
```

When you create server certificates, they will look like this:

```
Subject:
    C=JP
    ST=Tokyo
    L=Tokyo
    O=42 Tokyo
    OU=Cadet
    CN=niida.42.fr
    emailAddress=niida@student.42tokyo.jp

Extensions:
    X509v3 Subject Alternative Name:
        DNS:niida.42.fr
        DNS:*.niida.42.fr
        DNS:www.niida.42.fr
        DNS:localhost
        IP Address:127.0.0.1
        IP Address:::1
    X509v3 Extended Key Usage:
        TLS Web Server Authentication
```

## Modifying Domains Later

If you need different domains, you have two options:

### Option 1: Use command-line arguments (Recommended)
```bash
./sign-server-cert.sh -d yourdomain.com -a "*.yourdomain.com,other.com"
```

### Option 2: Edit server-cert.cnf
Edit the `[ alt_names ]` section in `server-cert.cnf`:
```ini
[ alt_names ]
DNS.1 = newdomain.com
DNS.2 = *.newdomain.com
DNS.3 = localhost
IP.1 = 127.0.0.1
IP.2 = ::1
```

Then run: `./sign-server-cert.sh -d newdomain.com`

## File Locations

- **ca-config.cnf** (line 75-80): Tokyo defaults for CA
- **server-cert.cnf** (line 22-26): Tokyo defaults for servers
- **server-cert.cnf** (line 37-44): Domain configuration

## Next Steps

1. **Create your CA:**
   ```bash
   ./create-ca.sh
   ```

2. **Import CA into Firefox:**
   - Settings → Privacy & Security → View Certificates → Authorities → Import
   - Select `ca-cert.pem`
   - Check "Trust this CA to identify websites"

3. **Generate server certificate:**
   ```bash
   ./sign-server-cert.sh -d niida.42.fr
   ```

4. **Use in your Inception project:**
   ```bash
   # Copy certificates to nginx
   cp certs/niida.42.fr-cert.pem ../conf/
   cp certs/niida.42.fr-key.pem ../conf/
   ```

## Configuration Files Reference

### ca-config.cnf
- Controls CA certificate generation
- Sets defaults for Tokyo location
- Defines CA policies and extensions
- **Key setting**: `basicConstraints = critical, CA:true` (line 86)

### server-cert.cnf
- Template for server certificate requests
- Includes subjectAltName configuration
- Used by `sign-server-cert.sh` (but script overrides domains)
- **Key setting**: `subjectAltName = @alt_names` (line 32)

## Troubleshooting

### "Wrong location in certificate"
The script uses the configured defaults, but you can override when running:
```bash
openssl req ... -subj "/C=JP/ST=Tokyo/L=Tokyo/O=42 Tokyo/OU=Cadet/CN=niida.42.fr"
```

### "Domain not in certificate"
Check what domains are actually in the certificate:
```bash
openssl x509 -noout -text -in certs/niida.42.fr-cert.pem | grep -A10 "Subject Alternative Name"
```

### "Need different defaults"
Just edit the `*_default` values in the config files - they're clearly marked.
