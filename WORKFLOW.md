# Inception Project Workflow

Quick reference guide for the Inception project with custom CA-signed certificates.

## Table of Contents
- [Quick Start](#quick-start)
- [One-Time Setup](#one-time-setup)
- [Daily Workflow](#daily-workflow)
- [Certificate Management](#certificate-management)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

```bash
# First time setup
make ssl-setup        # Creates CA, server certificates, and data directories
make browser-setup    # Shows Firefox configuration instructions

# Daily usage
make up              # Start all services
make down            # Stop all services
make logs            # View logs
make help            # Show all available commands
```

**Access your site:** `https://niida.42.fr:8443` (or your LOGIN instead of niida)

---

## One-Time Setup

### Step 1: SSL Setup

```bash
# Automated setup (creates CA + server certificate + data dirs)
make ssl-setup

# Or manual steps:
make ca-create       # Create Certificate Authority (prompts for passphrase)
make cert-create     # Generate server certificate for your domain
make data-setup      # Create data directories
```

### Step 2: Import CA into Firefox

```bash
make browser-setup   # Shows detailed instructions
```

**Quick steps:**
1. Firefox → Settings → Privacy & Security → Certificates → View Certificates
2. Authorities tab → Import
3. Select: `/home/$(LOGIN)/data/nginx_ssl/ca-cert.pem`
4. ✅ Check "Trust this CA to identify websites"

### Step 3: Configure Domain Resolution

**Option A: Firefox DNS (Recommended for port 8443)**
1. Type `about:config` in Firefox
2. Search for `network.dns.localDomains`
3. Add `niida.42.fr` (or your LOGIN)

**Option B: System hosts (if using port 443)**
```bash
sudo vim /etc/hosts
# Add: 127.0.0.1    niida.42.fr
```

---

## Daily Workflow

### Starting Services

```bash
make up              # Runs ssl-setup automatically, then starts containers
```

⚠️ **IMPORTANT: MariaDB Initialization**
- First startup takes 2-5 minutes to initialize the database
- MariaDB has a HEALTHCHECK with 5-minute start period configured
- Even with this safeguard, health checks can occasionally fail during heavy load
- **If MariaDB shows as "unhealthy":**
  ```bash
  make down          # Stop all services
  make up            # Restart - database is already initialized, will be faster
  ```

### Monitoring

```bash
make ps              # Check container status
make logs            # Follow all logs
make test-nginx-host # Test nginx connectivity (skips SSL verification)
make test-nginx-host-ssl  # Test with SSL verification
```

### Stopping Services

```bash
make down            # Stop containers (keeps data)
make clean           # Stop + remove containers and images
make fclean          # Full clean including data directories
make re              # Rebuild everything from scratch
```

---

## Certificate Management

### Verify Certificates

```bash
make cert-check      # View certificate details and SANs
make cert-verify     # Verify certificate chain (should show "OK")
```

### Renew Server Certificate

Server certificates expire after 375 days:

```bash
cd srcs/requirements/nginx/self-ca/
./sign-server-cert.sh -d niida.42.fr -a "*.niida.42.fr,localhost,127.0.0.1"

# Copy to data directory
cp certs/niida.42.fr-cert.pem /home/$(LOGIN)/data/nginx_ssl/cert.pem
cp certs/niida.42.fr-key.pem /home/$(LOGIN)/data/nginx_ssl/key.pem

# Restart nginx
docker compose -f srcs/docker-compose.yml restart nginx
```

---

## Troubleshooting

### MariaDB Health Check Failures

**Symptoms:** Container shows as "unhealthy" or WordPress can't connect to database

**Solution:**
```bash
make down
make up              # Database already initialized, faster restart
```

The MariaDB container has a health check configured in `srcs/requirements/mariadb/Dockerfile`:
```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=5m --retries=3
```
Despite the 5-minute grace period, initialization can still occasionally fail under load.

### Certificate Not Trusted

**Symptoms:** Firefox shows "Your connection is not secure" (SEC_ERROR_UNKNOWN_ISSUER)

**Solutions:**
1. Verify CA is imported:
   ```bash
   # Firefox: about:preferences#privacy → Certificates → Authorities
   # Search for "42 cursus Inception CA"
   ```

2. Re-import CA:
   ```bash
   make browser-setup  # Shows import instructions
   ```

3. Verify certificate chain:
   ```bash
   make cert-verify    # Should show "OK"
   ```

### Common Name Invalid

**Symptoms:** NET::ERR_CERT_COMMON_NAME_INVALID

**Solutions:**
1. Check certificate SANs:
   ```bash
   make cert-check     # Shows Subject Alternative Names
   ```

2. Verify domain configuration:
   ```bash
   make test-wp-url    # Shows configured vs actual WordPress URLs
   ```

3. Check Firefox DNS config:
   - `about:config` → `network.dns.localDomains` → add `niida.42.fr`

### Nginx Won't Start

**Symptoms:** Container exits immediately

**Solutions:**
```bash
# Check logs
make logs

# Verify certificate files exist
ls -la /home/$(LOGIN)/data/nginx_ssl/

# Test nginx config
docker compose -f srcs/docker-compose.yml run --rm nginx nginx -t

# Nuclear option
make fclean && make up
```

### Changes Not Reflected

```bash
# For config changes:
docker compose -f srcs/docker-compose.yml restart nginx

# For Dockerfile changes:
make build && make up

# For certificate changes (no rebuild needed):
docker compose -f srcs/docker-compose.yml restart nginx

# Clean slate:
make re
```

---

## Security Notes

### ⚠️ Important Security Considerations

1. **CA Private Key (`ca-key.pem`):**
   - Protected by passphrase
   - Never commit to git (in `.gitignore`)
   - If compromised: recreate entire CA and all certificates

2. **Server Private Key:**
   - Never commit to git (in `.gitignore`)
   - Mounted read-only in container
   - If compromised: regenerate server certificate only

3. **Development Only:**
   - NOT for production use
   - Only trusted on machines where CA is imported
   - Production should use Let's Encrypt or commercial CA

---

## Quick Reference

```bash
# All common tasks use Makefile
make help            # Show all available commands
make ssl-setup       # One-time SSL setup
make up              # Start services
make down            # Stop services
make logs            # View logs
make ps              # Container status
make cert-verify     # Verify certificates
make test-nginx-host-ssl  # Test HTTPS connection
```

**WordPress URL:** `https://niida.42.fr:8443` (or your LOGIN)

---

## Additional Resources

- Makefile targets: `make help`
- Custom CA docs: `srcs/requirements/nginx/self-ca/README.md`
- Nginx SSL config: `srcs/requirements/nginx/conf/default.conf`
