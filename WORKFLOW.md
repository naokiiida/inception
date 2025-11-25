# Inception Project Workflow with Custom CA

This document describes the complete workflow for using custom CA-signed certificates with the Inception project.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [One-Time Setup](#one-time-setup)
- [Daily Workflow](#daily-workflow)
- [Certificate Management](#certificate-management)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### Certificate Structure

```
inception/
├── srcs/
│   └── requirements/
│       └── nginx/
│           ├── self-ca/                      # Custom CA directory
│           │   ├── ca-cert.pem              # Root CA certificate (import to Firefox)
│           │   ├── ca-key.pem               # CA private key (keep secure!)
│           │   └── certs/
│           │       ├── niida.42.fr-cert.pem # Server certificate (mounted to container)
│           │       └── niida.42.fr-key.pem  # Server private key (mounted to container)
│           ├── conf/
│           │   └── default.conf             # Nginx config (uses /etc/nginx/ssl/cert.pem)
│           ├── Dockerfile                   # Generates dhparam.pem at build time
│           └── docker-entrypoint.sh         # Templates config and starts nginx
└── data/
    └── wordpress_files/                     # WordPress files (mounted to both containers)
```

### How It Works

1. **Build Time:**
   - Nginx Docker image is built
   - `dhparam.pem` is generated inside the image (one-time, ~2 minutes)

2. **Runtime:**
   - CA-signed certificates are mounted from `self-ca/certs/` into `/etc/nginx/ssl/`
   - `cert.pem` → `niida.42.fr-cert.pem`
   - `key.pem` → `niida.42.fr-key.pem`
   - Nginx uses these certificates to serve HTTPS

3. **Browser Trust:**
   - Firefox has `ca-cert.pem` imported in Authorities
   - Browser trusts any certificate signed by this CA
   - No certificate warnings! ✅

---

## One-Time Setup

### Step 1: Create Your Certificate Authority (Once Per System)

```bash
cd srcs/requirements/nginx/self-ca/

# Create the CA (you'll be prompted for a passphrase)
./create-ca.sh

# This creates:
# - ca-key.pem (private key - keep secure!)
# - ca-cert.pem (public cert - import to browser)
```

**Important:**
- Choose a strong passphrase and remember it
- The CA is valid for 10 years
- You only need to do this once per development machine

### Step 2: Generate Server Certificate for Your Domain

```bash
# Still in self-ca/ directory
# Replace 'niida' with your LOGIN

./sign-server-cert.sh -d niida.42.fr -a "*.niida.42.fr,localhost,127.0.0.1"

# This creates in certs/:
# - niida.42.fr-cert.pem (server certificate)
# - niida.42.fr-key.pem (server private key)
# - niida.42.fr-csr.pem (certificate signing request)
```

**Certificate Details:**
- Valid for 375 days (must renew yearly)
- Includes alternative names for flexibility
- Signed by your CA

### Step 3: Import CA Certificate into Firefox

1. Open Firefox
2. Go to: `about:preferences#privacy`
3. Scroll to **Certificates** → Click **View Certificates**
4. Go to **Authorities** tab
5. Click **Import**
6. Select `srcs/requirements/nginx/self-ca/ca-cert.pem`
7. ✅ Check **"Trust this CA to identify websites"**
8. Click **OK**

**Verify Import:**
- Go back to Authorities tab
- Search for "42 cursus" or your CA organization name
- You should see "42 cursus Inception CA" listed

### Step 4: Configure Environment

```bash
# Edit srcs/.env
cd ../../../  # Back to inception/srcs/
vim .env

# Ensure LOGIN is set correctly:
LOGIN=niida
```

### Step 5: Add Domain to /etc/hosts

```bash
# Add your domain to hosts file
sudo vim /etc/hosts

# Add this line:
127.0.0.1    niida.42.fr
```

---

## Daily Workflow

### Starting the Project

```bash
# From inception/srcs/ directory

# Build all containers (first time or after changes)
docker-compose build

# Start the stack
docker-compose up -d

# Check logs
docker-compose logs -f nginx
docker-compose logs -f wordpress
docker-compose logs -f mariadb
```

**Note:** The first build will take ~2 minutes longer due to dhparam.pem generation.

### Accessing Your Site

1. Open Firefox
2. Navigate to: `https://niida.42.fr`
3. You should see:
   - ✅ Green padlock (secure connection)
   - ✅ No certificate warnings
   - ✅ WordPress installation or your site

### Stopping the Project

```bash
# Stop all containers
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

### Rebuilding After Changes

```bash
# Rebuild specific service
docker-compose build nginx
docker-compose up -d nginx

# Or rebuild everything
docker-compose build
docker-compose up -d
```

---

## Certificate Management

### Checking Certificate Expiration

```bash
cd srcs/requirements/nginx/self-ca/

# Check server certificate expiration
openssl x509 -noout -dates -in certs/niida.42.fr-cert.pem

# Output shows:
# notBefore: Nov 25 09:16:31 2025 GMT
# notAfter : Dec  5 09:16:31 2026 GMT  ← Expiration date
```

### Renewing Server Certificate

Server certificates expire after 375 days. To renew:

```bash
cd srcs/requirements/nginx/self-ca/

# Regenerate the server certificate (you'll need CA passphrase)
./sign-server-cert.sh -d niida.42.fr -a "*.niida.42.fr,localhost,127.0.0.1"

# Restart nginx to pick up new certificate
cd ../../..
docker-compose restart nginx
```

**No rebuild needed!** Certificates are mounted, so just restart nginx.

### Updating for a Different User/Domain

```bash
# Generate certificate for new domain
cd srcs/requirements/nginx/self-ca/
./sign-server-cert.sh -d newuser.42.fr -a "*.newuser.42.fr,localhost"

# Update .env
cd ../../
vim .env
# Change: LOGIN=newuser

# Restart stack
docker-compose down
docker-compose up -d
```

---

## Troubleshooting

### Issue: Certificate Not Trusted in Firefox

**Symptoms:**
- Red warning page: "Your connection is not secure"
- Error code: `SEC_ERROR_UNKNOWN_ISSUER`

**Solutions:**

1. **Verify CA is imported:**
   ```
   about:preferences#privacy → Certificates → View Certificates → Authorities
   Look for "42 cursus Inception CA"
   ```

2. **Re-import CA certificate:**
   - Delete old CA entry if it exists
   - Import `ca-cert.pem` again
   - Ensure "Trust this CA to identify websites" is checked

3. **Verify certificate chain:**
   ```bash
   cd srcs/requirements/nginx/self-ca/
   openssl verify -CAfile ca-cert.pem certs/niida.42.fr-cert.pem
   # Should output: certs/niida.42.fr-cert.pem: OK
   ```

4. **Check certificate was signed by your CA:**
   ```bash
   openssl x509 -noout -text -in certs/niida.42.fr-cert.pem | grep Issuer
   # Should show: Issuer: ... CN=42 cursus Inception CA
   ```

### Issue: "Common Name Invalid" Error

**Symptoms:**
- Error: `NET::ERR_CERT_COMMON_NAME_INVALID`
- Certificate is trusted, but domain doesn't match

**Solutions:**

1. **Check domain in certificate:**
   ```bash
   openssl x509 -noout -text -in certs/niida.42.fr-cert.pem | grep -A1 "Subject Alternative Name"
   # Should show: DNS:niida.42.fr, DNS:*.niida.42.fr, ...
   ```

2. **Verify /etc/hosts entry:**
   ```bash
   cat /etc/hosts | grep niida.42.fr
   # Should show: 127.0.0.1    niida.42.fr
   ```

3. **Regenerate certificate with correct domain:**
   ```bash
   cd srcs/requirements/nginx/self-ca/
   ./sign-server-cert.sh -d niida.42.fr -a "*.niida.42.fr,localhost,127.0.0.1"
   docker-compose restart nginx
   ```

### Issue: Nginx Won't Start

**Symptoms:**
- Container exits immediately
- Logs show certificate errors

**Solutions:**

1. **Check certificate files exist:**
   ```bash
   ls -la srcs/requirements/nginx/self-ca/certs/
   # Should see: niida.42.fr-cert.pem and niida.42.fr-key.pem
   ```

2. **Check file permissions:**
   ```bash
   # Certificate should be readable
   chmod 644 srcs/requirements/nginx/self-ca/certs/niida.42.fr-cert.pem
   # Key should be readable (chmod 600 is safer but Docker needs 644)
   chmod 644 srcs/requirements/nginx/self-ca/certs/niida.42.fr-key.pem
   ```

3. **Test nginx config:**
   ```bash
   docker-compose run --rm nginx nginx -t
   ```

4. **Check certificate paths in docker-compose.yml:**
   ```yaml
   volumes:
     - ./requirements/nginx/self-ca/certs/${LOGIN}.42.fr-cert.pem:/etc/nginx/ssl/cert.pem:ro
     - ./requirements/nginx/self-ca/certs/${LOGIN}.42.fr-key.pem:/etc/nginx/ssl/key.pem:ro
   ```

### Issue: dhparam.pem Generation Takes Too Long

**Symptoms:**
- Docker build hangs during dhparam generation
- Takes more than 5 minutes

**Solutions:**

1. **Use 2048 bits (current default):**
   - 2048 bits: ~2 minutes ✅
   - 4096 bits: ~10-30 minutes ❌

2. **Pre-generate and copy instead:**
   ```bash
   # Generate once on host
   openssl dhparam -out dhparam.pem 2048

   # Then in Dockerfile, replace RUN with:
   COPY dhparam.pem /etc/nginx/ssl/dhparam.pem
   ```

### Issue: Changes Not Reflected

**Symptoms:**
- Made changes but site looks the same
- Certificate not updated

**Solutions:**

1. **For configuration changes:**
   ```bash
   docker-compose restart nginx
   ```

2. **For Dockerfile changes:**
   ```bash
   docker-compose build nginx
   docker-compose up -d nginx
   ```

3. **For certificate changes:**
   ```bash
   docker-compose restart nginx  # No rebuild needed!
   ```

4. **Nuclear option (clean slate):**
   ```bash
   docker-compose down -v
   docker-compose build
   docker-compose up -d
   ```

---

## Verification Checklist

Use this checklist to verify everything is working correctly:

### ✅ CA Setup
- [ ] `ca-cert.pem` and `ca-key.pem` exist in `self-ca/`
- [ ] CA certificate has `CA:TRUE` extension
  ```bash
  openssl x509 -noout -text -in self-ca/ca-cert.pem | grep "CA:TRUE"
  ```
- [ ] CA is imported in Firefox (Authorities tab)

### ✅ Server Certificate
- [ ] Server cert and key exist in `self-ca/certs/`
- [ ] Certificate matches your LOGIN
- [ ] Certificate is signed by your CA
  ```bash
  openssl verify -CAfile self-ca/ca-cert.pem self-ca/certs/niida.42.fr-cert.pem
  ```
- [ ] Certificate includes required domains
  ```bash
  openssl x509 -noout -text -in self-ca/certs/niida.42.fr-cert.pem | grep DNS
  ```

### ✅ Docker Setup
- [ ] `docker-compose.yml` mounts correct certificate files
- [ ] `.env` file has correct LOGIN value
- [ ] All containers start successfully
  ```bash
  docker-compose ps
  ```

### ✅ Browser Access
- [ ] `/etc/hosts` has domain entry
- [ ] Site accessible at `https://niida.42.fr`
- [ ] Green padlock shown (trusted connection)
- [ ] No certificate warnings
- [ ] Certificate details show your CA as issuer

---

## Additional Resources

- **Custom CA Documentation:** `srcs/requirements/nginx/self-ca/README.md`
- **Quick Start Guide:** `srcs/requirements/nginx/self-ca/QUICK_START.md`
- **Configuration Details:** `srcs/requirements/nginx/self-ca/CONFIGURATION.md`
- **Nginx SSL Config:** `srcs/requirements/nginx/conf/default.conf`

---

## Quick Reference Commands

```bash
# Generate new server certificate
cd srcs/requirements/nginx/self-ca/
./sign-server-cert.sh -d ${LOGIN}.42.fr -a "*.${LOGIN}.42.fr,localhost"

# Build and start
cd ../../../
docker-compose build
docker-compose up -d

# View logs
docker-compose logs -f nginx

# Restart after certificate update
docker-compose restart nginx

# Stop everything
docker-compose down

# Clean slate (removes volumes)
docker-compose down -v

# Check certificate expiration
openssl x509 -noout -dates -in srcs/requirements/nginx/self-ca/certs/niida.42.fr-cert.pem

# Verify certificate chain
openssl verify -CAfile srcs/requirements/nginx/self-ca/ca-cert.pem \
  srcs/requirements/nginx/self-ca/certs/niida.42.fr-cert.pem
```

---

## Security Notes

### ⚠️ Important Security Considerations

1. **CA Private Key (`ca-key.pem`):**
   - Protected by passphrase
   - Never commit to git (in `.gitignore`)
   - Never share or expose
   - If compromised: recreate entire CA and all certificates

2. **Server Private Key (`niida.42.fr-key.pem`):**
   - Never commit to git (in `.gitignore`)
   - Mounted read-only in container
   - If compromised: regenerate server certificate only

3. **This Setup is for Development Only:**
   - NOT for production use
   - Only trusted on machines where CA is imported
   - Production should use Let's Encrypt or commercial CA

4. **Passphrase Storage:**
   - Never store CA passphrase in plain text
   - Use a password manager
   - Don't share the passphrase

---

## License

This workflow is part of the 42 Inception project.
