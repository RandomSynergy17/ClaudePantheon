# Docker Secrets Directory

This directory is for storing sensitive credentials using Docker secrets, which is more secure than environment variables.

## Why Use Docker Secrets?

**Environment variables** (in `.env` file) have security issues:
- ✗ Visible in `docker inspect` output
- ✗ Visible in `/proc/*/environ` on host
- ✗ May appear in logs
- ✗ Stored in plaintext in `.env` file

**Docker secrets** (this directory) are more secure:
- ✓ Not visible in `docker inspect`
- ✓ Not accessible from host processes
- ✓ Mounted in-memory only (tmpfs)
- ✓ Separate file permissions per secret

## Quick Setup

### Option 1: Use the Setup Script (Recommended)

```bash
cd docker
./setup-secrets.sh
```

This script will:
1. Create the `secrets/` directory
2. Generate strong random passwords
3. Prompt for your Anthropic API key
4. Set proper permissions (600)
5. Update docker-compose.yml to enable secrets

### Option 2: Manual Setup

```bash
# Create secrets directory
mkdir -p docker/secrets

# Create API key secret (if you have one)
echo "sk-ant-api03-your-key-here" > docker/secrets/anthropic_api_key.txt

# Create authentication credentials with strong passwords
# Format: username:password
echo "admin:$(openssl rand -base64 32)" > docker/secrets/internal_credential.txt
echo "guest:$(openssl rand -base64 24)" > docker/secrets/webroot_credential.txt

# Set restrictive permissions (owner read-only)
chmod 600 docker/secrets/*.txt

# Enable secrets in docker-compose.yml
# Uncomment the 'secrets:' sections at the top and in the service definition
```

## File Structure

```
docker/secrets/
├── README.md                    # This file
├── anthropic_api_key.txt       # Claude API key (optional)
├── internal_credential.txt     # Credentials for /terminal/, /files/, /webdav/
└── webroot_credential.txt      # Credentials for landing page (optional)
```

## File Formats

### anthropic_api_key.txt
```
sk-ant-api03-your-actual-key-here
```

### internal_credential.txt
```
username:password
```
Example: `admin:mySecurePassword123`

### webroot_credential.txt
```
username:password
```
Example: `guest:guestPassword456`

## Security Best Practices

1. **Never commit secrets to git**
   - `.gitignore` already excludes `*.txt` files in this directory
   - Double-check before committing

2. **Use strong passwords**
   - Minimum 16 characters
   - Use `openssl rand -base64 32` for strong random passwords
   - Avoid dictionary words

3. **Restrict file permissions**
   ```bash
   chmod 600 docker/secrets/*.txt
   ```

4. **Rotate credentials regularly**
   - Update secret files
   - Run `docker compose restart` to apply

5. **Backup securely**
   - Encrypt backups containing secrets
   - Store in secure location (password manager, encrypted vault)

## Testing Your Setup

After creating secrets and restarting:

```bash
# Restart container to load secrets
docker compose restart

# Check logs for "Loaded X from Docker secret"
docker compose logs | grep "Loaded.*from Docker secret"

# Verify secrets are not in environment
docker compose exec claudepantheon env | grep -i credential
# Should show nothing (good!)

# Test authentication
curl -u admin:yourpassword http://localhost:7681/terminal/
```

## Troubleshooting

### "Permission denied" errors
```bash
# Fix permissions
chmod 600 docker/secrets/*.txt
```

### Secrets not loading
```bash
# Check docker-compose.yml has secrets uncommented
grep -A 5 "^secrets:" docker-compose.yml

# Check container can access /run/secrets/
docker compose exec claudepantheon ls -la /run/secrets/
```

### Still using environment variables
```bash
# Remove from .env to force using secrets
sed -i 's/^ANTHROPIC_API_KEY=.*$/ANTHROPIC_API_KEY=/' .env
sed -i 's/^INTERNAL_CREDENTIAL=.*$/INTERNAL_CREDENTIAL=/' .env
```

## Migration from Environment Variables

If you're currently using `.env` for secrets:

1. Copy current values to secret files:
   ```bash
   # Extract from .env
   grep "^ANTHROPIC_API_KEY=" .env | cut -d= -f2 > docker/secrets/anthropic_api_key.txt
   grep "^INTERNAL_CREDENTIAL=" .env | cut -d= -f2 > docker/secrets/internal_credential.txt

   # Set permissions
   chmod 600 docker/secrets/*.txt
   ```

2. Clear sensitive values from `.env`:
   ```bash
   sed -i 's/^ANTHROPIC_API_KEY=.*$/ANTHROPIC_API_KEY=/' .env
   sed -i 's/^INTERNAL_CREDENTIAL=.*$/INTERNAL_CREDENTIAL=/' .env
   ```

3. Enable secrets in docker-compose.yml (uncomment sections)

4. Restart:
   ```bash
   docker compose restart
   ```

## Additional Resources

- [Docker Secrets Documentation](https://docs.docker.com/engine/swarm/secrets/)
- [ClaudePantheon Security Best Practices](../SECURITY.md)
