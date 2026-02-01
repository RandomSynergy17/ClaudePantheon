# macOS Connectivity Guide for ClaudePantheon

Complete guide for connecting your Mac to ClaudePantheon with multiple methods.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Method 1: WebDAV (Recommended)](#method-1-webdav-recommended)
- [Method 2: SMB/CIFS (Native Finder)](#method-2-smbcifs-native-finder)
- [Method 3: Docker Volume Mounts](#method-3-docker-volume-mounts)
- [Method 4: SFTP](#method-4-sftp)
- [Method 5: FileBrowser Web UI](#method-5-filebrowser-web-ui)
- [Comparison Matrix](#comparison-matrix)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

**Fastest setup:** WebDAV via Finder (5 minutes)

```bash
# 1. Enable WebDAV in ClaudePantheon
cd ClaudePantheon/docker
nano .env
# Set: ENABLE_WEBDAV=true
make restart

# 2. On Mac: Finder → Go → Connect to Server (⌘K)
# Enter: http://localhost:7681/webdav/workspace/
```

---

## Method 1: WebDAV (Recommended)

### Overview

- **Best for:** General file access, editing files
- **Setup time:** 5 minutes
- **Performance:** Good
- **macOS native:** Yes (built into Finder)

### Setup Steps

#### 1. Enable WebDAV in ClaudePantheon

```bash
cd ClaudePantheon/docker
nano .env
```

Set:
```bash
ENABLE_WEBDAV=true
```

Restart container:
```bash
make restart
```

#### 2. Connect from macOS Finder

**Option A: GUI Method**

1. Open Finder
2. Press `⌘K` (or Go → Connect to Server)
3. Enter server address:
   ```
   http://localhost:7681/webdav/workspace/
   ```
4. Click `Connect`
5. If prompted for credentials:
   - Use `INTERNAL_CREDENTIAL` from your `.env` file
   - Format: `username` and `password` (split on the `:`)
6. The drive will mount as `workspace on localhost`

**Option B: Command Line**

```bash
# Mount via command line
mount_webdav -i http://localhost:7681/webdav/workspace/ ~/ClaudePantheon

# Unmount
umount ~/ClaudePantheon
```

#### 3. Available WebDAV Endpoints

| Endpoint | Maps to | Purpose |
|----------|---------|---------|
| `/webdav/workspace/` | `data/workspace/` | Your projects and code |
| `/webdav/webroot/` | `data/webroot/` | Landing page files |
| `/webdav/scripts/` | `data/scripts/` | Container scripts |
| `/webdav/logs/` | `data/logs/` | Log files |

**Security Note:** Sensitive directories (`claude/`, `mcp/`, `ssh/`) are NOT accessible via WebDAV.

#### 4. Add to Finder Sidebar

1. Connect to WebDAV share
2. Drag the mounted volume to Finder sidebar under "Favorites"
3. Auto-reconnect on next Finder restart

### WebDAV Performance Tuning

For better performance with large files:

```nginx
# In docker/defaults/nginx/nginx.conf (or data/nginx/nginx.conf)
client_max_body_size 0;           # No upload limit
client_body_buffer_size 128k;     # Larger buffer
```

---

## Method 2: SMB/CIFS (Native Finder)

### Overview

- **Best for:** Native macOS integration, fast performance
- **Setup time:** 10 minutes
- **Performance:** Excellent
- **macOS native:** Yes (SMB is the default macOS file sharing protocol)

### Setup Steps

#### 1. Enable SMB Server in ClaudePantheon

Add Samba to custom packages:

```bash
# Add to docker/data/custom-packages.txt
samba
samba-common-tools
```

Restart container:
```bash
cd ClaudePantheon/docker
make restart
```

#### 2. Configure Samba

Create SMB configuration inside container:

```bash
# Enter container
make shell

# Create Samba config
cat > /etc/samba/smb.conf << 'EOF'
[global]
    workgroup = WORKGROUP
    server string = ClaudePantheon
    security = user
    map to guest = Never
    log file = /tmp/samba-%m.log
    max log size = 50

[workspace]
    path = /app/data/workspace
    browseable = yes
    writable = yes
    valid users = claude
    create mask = 0664
    directory mask = 0775
    force user = claude
    force group = claude

[webroot]
    path = /app/data/webroot
    browseable = yes
    writable = yes
    valid users = claude
    create mask = 0664
    directory mask = 0775

[scripts]
    path = /app/data/scripts
    browseable = yes
    writable = yes
    valid users = claude
    create mask = 0775
    directory mask = 0775
EOF

# Set Samba password (same as your system password)
smbpasswd -a claude
# Enter password twice

# Start Samba
smbd -D
nmbd -D
```

#### 3. Expose SMB Port

Update `docker-compose.yml`:

```yaml
ports:
  - "7681:7681"     # nginx (existing)
  - "2222:22"       # SSH (existing)
  - "445:445"       # SMB (new)
  - "139:139"       # NetBIOS (new)
```

Rebuild:
```bash
make rebuild
```

#### 4. Connect from macOS

**Option A: Finder GUI**

1. Open Finder
2. Press `⌘K` (or Go → Connect to Server)
3. Enter:
   ```
   smb://localhost/workspace
   ```
4. Click `Connect`
5. When prompted:
   - Username: `claude`
   - Password: (password you set with `smbpasswd`)
6. Select share: `workspace`, `webroot`, or `scripts`

**Option B: Command Line**

```bash
# Mount via command line
mkdir -p ~/ClaudePantheon
mount -t smbfs //claude@localhost/workspace ~/ClaudePantheon

# Unmount
umount ~/ClaudePantheon
```

### Auto-Start SMB on Container Boot

Add to `data/scripts/entrypoint.sh` or create a startup script:

```bash
# In entrypoint.sh, after service startup section
if [ -f /etc/samba/smb.conf ]; then
    log "Starting Samba (SMB/CIFS) server..."
    smbd -D
    nmbd -D
fi
```

---

## Method 3: Docker Volume Mounts

### Overview

- **Best for:** Direct filesystem access, development, no latency
- **Setup time:** 2 minutes
- **Performance:** Native (best possible)
- **macOS native:** No (requires Docker Desktop)

### Setup Steps

#### 1. Add Volume Mount to docker-compose.yml

```yaml
volumes:
  - ${CLAUDE_DATA_PATH:-/docker/appdata/claudepantheon}:/app/data

  # ADD THIS: Mount Mac directory into container
  - /Users/yourname/Documents:/mounts/mac-docs
  - /Users/yourname/Projects:/mounts/mac-projects
```

#### 2. Restart Container

```bash
cd ClaudePantheon/docker
make restart
```

#### 3. Access from Container

Inside ClaudePantheon terminal:

```bash
# Navigate to Mac directories
ls /mounts/mac-docs
cd /mounts/mac-projects

# Files are bidirectionally synced
```

#### 4. Access from Mac

Mac directories remain at their original location. Changes made in either location are immediately visible in both.

### Reverse Access (Container → Mac)

To access container workspace from Mac:

```yaml
volumes:
  # Expose container workspace to Mac
  - ${CLAUDE_DATA_PATH}/workspace:/app/data/workspace
```

Then access via Docker Desktop:
1. Open Docker Desktop
2. Navigate to Containers → ClaudePantheon
3. Files tab → `/app/data/workspace`
4. Or set `CLAUDE_DATA_PATH` to a Mac directory:
   ```bash
   # In .env
   CLAUDE_DATA_PATH=/Users/yourname/ClaudePantheon
   ```

---

## Method 4: SFTP

### Overview

- **Best for:** Secure file transfer, automated scripts
- **Setup time:** 5 minutes
- **Performance:** Good
- **macOS native:** Via third-party apps (Cyberduck, FileZilla, Transmit)

### Setup Steps

#### 1. Enable SSH in ClaudePantheon

```bash
cd ClaudePantheon/docker
nano .env
```

Set:
```bash
ENABLE_SSH=true
```

Restart:
```bash
make restart
```

#### 2. Connect via SFTP Client

**Cyberduck (Recommended Free App):**

1. Download: https://cyberduck.io
2. New Connection
3. Protocol: SFTP
4. Server: `localhost`
5. Port: `2222`
6. Username: `claude`
7. SSH Private Key: Browse to your SSH key (or use password auth)
8. Connect

**FileZilla:**

1. Download: https://filezilla-project.org
2. File → Site Manager → New Site
3. Protocol: SFTP
4. Host: `localhost`
5. Port: `2222`
6. User: `claude`
7. Connect

**Transmit (Commercial):**

1. Download: https://panic.com/transmit
2. New Server → SFTP
3. Address: `localhost`
4. Port: `2222`
5. User: `claude`

#### 3. Command Line SFTP

```bash
# Connect
sftp -P 2222 claude@localhost

# Navigate
cd /app/data/workspace

# Upload
put myfile.txt

# Download
get remotefile.txt

# Quit
quit
```

#### 4. Mount via sshfs (macOS)

Install macFUSE and sshfs:

```bash
brew install --cask macfuse
brew install gromgit/fuse/sshfs-mac

# Mount
mkdir -p ~/ClaudePantheon
sshfs claude@localhost:/app/data/workspace ~/ClaudePantheon -p 2222

# Unmount
umount ~/ClaudePantheon
```

---

## Method 5: FileBrowser Web UI

### Overview

- **Best for:** Quick file access, mobile devices, no setup
- **Setup time:** 0 minutes (enabled by default)
- **Performance:** Good
- **macOS native:** Web browser only

### Access

1. Open browser: `http://localhost:7681/files/`
2. Login with `INTERNAL_CREDENTIAL` if auth is enabled
3. Drag & drop files to upload
4. Click files to download
5. Built-in text editor for code files

---

## Comparison Matrix

| Method | Speed | Setup | Native | Bidirectional | Best For |
|--------|-------|-------|--------|---------------|----------|
| **WebDAV** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ | ✅ | General use |
| **SMB/CIFS** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ | ✅ | Power users |
| **Docker Volumes** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ❌ | ✅ | Development |
| **SFTP** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ❌* | ✅ | Secure transfer |
| **FileBrowser** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ | ✅ | Quick access |

*SFTP requires third-party app

---

## Troubleshooting

### WebDAV Issues

**"Connection Failed" error:**

```bash
# Check WebDAV is enabled
grep ENABLE_WEBDAV docker/.env

# Check nginx is running
docker exec claudepantheon ps aux | grep nginx

# Test WebDAV endpoint
curl -I http://localhost:7681/webdav/workspace/
```

**"401 Unauthorized" error:**

- Check `INTERNAL_AUTH` and `INTERNAL_CREDENTIAL` in `.env`
- Username/password format: `username:password`
- Split on `:` when entering in Finder

**Slow performance:**

- Increase nginx buffer sizes in `nginx.conf`
- Use SMB/CIFS instead for better macOS performance

### SMB Issues

**"Connection refused":**

```bash
# Check Samba is running
docker exec claudepantheon ps aux | grep smbd

# Check ports are exposed
docker port claudepantheon
```

**"Permission denied":**

```bash
# Reset Samba password
docker exec -it claudepantheon smbpasswd -a claude
```

### Docker Volume Mount Issues

**"Permission denied" on Mac:**

```bash
# Check Docker Desktop permissions
# Docker Desktop → Preferences → Resources → File Sharing
# Add your directory to allowed paths
```

**Files not syncing:**

- Docker Desktop caches files - restart Docker Desktop
- Check `docker-compose.yml` volume paths are absolute
- Verify `PUID`/`PGID` match your Mac user: `id -u` and `id -g`

### SFTP Issues

**"Connection refused":**

```bash
# Check SSH is enabled
grep ENABLE_SSH docker/.env

# Check SSH is running
docker exec claudepantheon ps aux | grep sshd

# Test connection
ssh -p 2222 claude@localhost
```

**"Permission denied (publickey)":**

- Use password authentication instead
- Or copy your SSH public key to container's `~/.ssh/authorized_keys`

---

## Performance Tips

### For Best Performance

1. **Local development:** Use Docker volume mounts
2. **File browsing:** Use SMB/CIFS
3. **Web access:** Use FileBrowser or WebDAV
4. **Automated scripts:** Use SFTP

### Network Optimization

For **remote access** (Mac on different network):

1. Set up Tailscale or Wireguard VPN
2. Connect both Mac and server to VPN
3. Use VPN IP address instead of `localhost`
4. All methods work over VPN

Example:
```
# Instead of: smb://localhost/workspace
# Use: smb://100.64.1.2/workspace (Tailscale IP)
```

---

## Advanced: Multiple Methods Combined

You can use multiple methods simultaneously:

```yaml
# docker-compose.yml
ports:
  - "7681:7681"   # WebDAV + FileBrowser
  - "445:445"     # SMB
  - "2222:22"     # SFTP

volumes:
  - ${CLAUDE_DATA_PATH}:/app/data
  - /Users/yourname/Projects:/mounts/mac-projects  # Docker volume
```

This gives you:
- ✅ Finder access via WebDAV/SMB
- ✅ Direct filesystem via Docker volumes
- ✅ Secure transfer via SFTP
- ✅ Web access via FileBrowser

---

## Security Checklist

When exposing file access:

- [ ] Use strong passwords for WebDAV/SMB/SFTP
- [ ] Enable `INTERNAL_AUTH=true` in `.env`
- [ ] Only expose needed ports (not all methods)
- [ ] Use VPN for remote access (Tailscale recommended)
- [ ] Regularly update ClaudePantheon
- [ ] Monitor access logs in `data/logs/`

---

## Quick Reference

```bash
# WebDAV
⌘K → http://localhost:7681/webdav/workspace/

# SMB
⌘K → smb://localhost/workspace

# SFTP
sftp -P 2222 claude@localhost

# FileBrowser
http://localhost:7681/files/

# Docker Volume (in .env)
CLAUDE_DATA_PATH=/Users/yourname/ClaudePantheon
```

---

**Last Updated:** 2026-01-31
**Version:** 1.0

For issues or questions, see [ClaudePantheon Issues](https://github.com/RandomSynergy17/ClaudePantheon/issues)
