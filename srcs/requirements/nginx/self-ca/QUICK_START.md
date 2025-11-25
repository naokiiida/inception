# Quick Start Guide

## TL;DR - 3 Simple Steps

### Step 1: Create Your CA (One Time)
```bash
./create-ca.sh
```
- Enter a strong passphrase when prompted
- Fill in your organization details
- This creates `ca-cert.pem` (your CA certificate)

### Step 2: Import CA into Firefox (One Time)
1. Open Firefox
2. Go to: **Settings** → **Privacy & Security** → **Certificates** → **View Certificates**
3. Click the **Authorities** tab
4. Click **Import**
5. Select `ca-cert.pem`
6. ✅ Check "Trust this CA to identify websites"
7. Click OK

### Step 3: Generate Server Certificates (As Needed)
```bash
# Simple usage
./sign-server-cert.sh -d yourdomain.com

# With alternative names
./sign-server-cert.sh -d yourdomain.com -a "*.yourdomain.com,localhost,127.0.0.1"
```

## Common Examples

### For Nginx with a Local Domain
```bash
# Generate certificate
./sign-server-cert.sh -d mysite.local -a "*.mysite.local,127.0.0.1"

# Use in nginx.conf
ssl_certificate     /path/to/certs/mysite.local-cert.pem;
ssl_certificate_key /path/to/certs/mysite.local-key.pem;
```

### For WordPress/Inception Project
```bash
# Generate for your domain
./sign-server-cert.sh -d niida.42.fr -a "*.niida.42.fr,localhost"

# Copy to nginx ssl directory
cp certs/niida.42.fr-cert.pem ../conf/
cp certs/niida.42.fr-key.pem ../conf/
```

### For Multiple Domains
```bash
./sign-server-cert.sh -d example.com -a "*.example.com,example.org,*.example.org,localhost,127.0.0.1,::1"
```

## Verify It Works

### Check Certificate Details
```bash
# View what domains are in the certificate
openssl x509 -noout -text -in certs/yourdomain.com-cert.pem | grep -A1 "Subject Alternative Name"
```

### Verify Certificate Chain
```bash
# Should output: "OK"
openssl verify -CAfile ca-cert.pem certs/yourdomain.com-cert.pem
```

### Test in Browser
1. Configure your web server with the certificate
2. Visit your HTTPS site in Firefox
3. Click the padlock icon
4. Should show "Connection Secure" ✅

## Troubleshooting

### Browser Still Shows Warning
- ❌ Did you import `ca-cert.pem` (not the server cert)?
- ❌ Did you import to **Authorities** tab?
- ❌ Did you check "Trust this CA to identify websites"?
- ❌ Did you restart Firefox after importing?

### "Common Name Invalid" Error
- The domain in the URL doesn't match the certificate
- Regenerate with the correct domain and alternative names

### "Certificate Not Trusted"
```bash
# Verify the cert was signed by your CA
openssl verify -CAfile ca-cert.pem certs/yourdomain.com-cert.pem
# Should output: "OK"
```

## Files You Need to Know

| File | What It Is | Where It Goes |
|------|-----------|---------------|
| `ca-cert.pem` | CA certificate | Import into Firefox |
| `ca-key.pem` | CA private key | **Keep secret!** |
| `{domain}-cert.pem` | Server certificate | Web server config |
| `{domain}-key.pem` | Server private key | Web server config |

## Important Notes

⚠️ **Security**:
- The `ca-key.pem` is protected by a passphrase
- Never share it or commit to git
- If lost, you'll need to recreate the CA and re-import to browsers

✅ **Validity**:
- CA certificate: 10 years
- Server certificates: 375 days (reissue yearly)

🔄 **Renewal**:
- To renew a server cert, just run `sign-server-cert.sh` again
- No need to re-import the CA

## Need More Help?

See `README.md` for detailed documentation.
