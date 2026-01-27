# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClaudePantheon is a minimal Alpine-based Docker environment for persistent Claude Code sessions. Features:
- **Single-port architecture**: nginx reverse proxy routes to all services via port 7681
- **Landing page**: PHP-based with Terminal, Files, and PHP Info buttons
- **Web terminal**: ttyd at /terminal/
- **File browser**: FileBrowser Quantum at /files/
- **WebDAV**: Optional at /webdav/
- **Two-zone authentication**: Separate auth for internal services vs webroot
- **Session continuity**: Claude remembers your conversations
- **MCP integrations**: Persisted configuration
- **Runtime customization**: All scripts editable without rebuild

## Development Commands

All commands run from the `docker/` directory:

```bash
# Container lifecycle
make build          # Build Docker image
make up             # Start container (background)
make down           # Stop container
make restart        # Restart container
make rebuild        # down → build → up

# Development
make shell          # Enter container shell
make logs           # View container logs (follow mode)
make dev            # Run in foreground with logs

# Status & Health
make status         # Show container status and data directory
make health         # Check web interface health
make version        # Show Claude Code version
make tree           # Show data directory structure

# Maintenance
make backup         # Backup data directory to tarball
make update         # Update Claude Code to latest version
make clean          # Remove container and images (keeps data)
make purge          # Full cleanup including data (DESTRUCTIVE)
```

### Shell Aliases (inside container)

```bash
# Claude Code
cc              # Continue last Claude session
cc-new          # Start fresh session
cc-resume       # Resume last session (same as cc)
cc-list         # Interactive session picker
cc-setup        # Run CLAUDE.md setup wizard
cc-mcp          # Manage MCP servers
cc-bypass       # Toggle bypass permissions [on|off]
cc-settings     # Show current settings
cc-info         # Show environment info

# Navigation
ccw             # Go to workspace
ccd             # Go to data directory
ccmnt           # Go to host mounts (/mounts/)

# Quick Edit
cce             # Edit workspace CLAUDE.md
ccm             # Edit MCP configuration
ccp             # Edit custom packages list
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Browser (Port 7681)                       │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                       nginx                                  │
│                  (Reverse Proxy)                             │
│                                                              │
│   /              → Landing Page (PHP)                        │
│   /terminal/     → ttyd (Claude Code)                        │
│   /files/        → FileBrowser Quantum                       │
│   /webdav/       → nginx WebDAV (optional)                   │
└─────────────────────────────────────────────────────────────┘
```

### File Structure

```
docker/
├── Dockerfile              # Alpine image definition
├── docker-compose.yml      # Container configuration
├── Makefile                # Management commands
├── .env.example            # Configuration template
├── defaults/               # Default configs (copied on first run)
│   ├── nginx/
│   │   └── nginx.conf      # Reverse proxy configuration
│   └── webroot/
│       └── public_html/
│           └── index.php   # Landing page
├── scripts/
│   ├── entrypoint.sh       # Container bootstrap
│   ├── start-services.sh   # Service supervisor (nginx, php-fpm, filebrowser, ttyd)
│   ├── shell-wrapper.sh    # First-run wizard
│   └── .zshrc              # Shell configuration

# Data directory (default: /docker/appdata/claudepantheon)
$CLAUDE_DATA_PATH/          # ALL PERSISTENT DATA (auto-created)
├── workspace/              # User projects
├── claude/                 # Session history
├── mcp/mcp.json            # MCP server configuration
├── nginx/nginx.conf        # nginx config (customizable)
├── webroot/public_html/    # Web content (customizable)
│   └── index.php           # Landing page
├── filebrowser/            # FileBrowser database
├── ssh/                    # SSH keys (auto 700/600 permissions)
├── logs/                   # Container logs (enable with LOG_TO_FILE=true)
├── zsh-history/
├── npm-cache/
├── python-venvs/
├── scripts/                # Runtime scripts (all customizable!)
│   ├── entrypoint.sh       # Container bootstrap
│   ├── start-services.sh   # Service supervisor
│   ├── shell-wrapper.sh    # First-run wizard
│   └── .zshrc              # Shell config
├── gitconfig               # Git configuration
├── custom-packages.txt     # Alpine packages to install
└── .env                    # Environment configuration
```

**Flow:** Docker start → `entrypoint.sh` (user mapping, data init) → `start-services.sh` (nginx, php-fpm, filebrowser, ttyd) → `shell-wrapper.sh` → zsh → Claude Code CLI

## Key Files

| File | Purpose |
|------|---------|
| `docker/Dockerfile` | Alpine image with Node.js 22, nginx, php-fpm, ttyd, filebrowser |
| `docker/docker-compose.yml` | Container config, volume mount, environment variables |
| `docker/Makefile` | All management commands |
| `docker/scripts/entrypoint.sh` | Bootstrap: user mapping, data init, script copying |
| `docker/scripts/start-services.sh` | Service supervisor: nginx, php-fpm, filebrowser, ttyd |
| `docker/defaults/nginx/nginx.conf` | Default reverse proxy config |
| `docker/defaults/webroot/public_html/index.php` | Default landing page |

## Configuration

Host-level settings go in `docker/.env` (copy from `.env.example`):

### Data & User
- `CLAUDE_DATA_PATH` - Where to store data (default: `/docker/appdata/claudepantheon`)
- `PUID` / `PGID` - User/group IDs for file permissions
- `TZ` - Timezone (default: UTC)
- `MEMORY_LIMIT` - Container memory limit (default: 4G)

### Authentication (Two-Zone System)

| Zone | Endpoints | Variables |
|------|-----------|-----------|
| **Internal** | /terminal/, /files/, /webdav/ | `INTERNAL_AUTH`, `INTERNAL_CREDENTIAL` |
| **Webroot** | / (landing page, custom apps) | `WEBROOT_AUTH`, `WEBROOT_CREDENTIAL` |

```bash
# Protect everything with same credentials
INTERNAL_AUTH=true
INTERNAL_CREDENTIAL=admin:secretpassword
WEBROOT_AUTH=true  # Uses INTERNAL_CREDENTIAL if WEBROOT_CREDENTIAL not set

# Public landing, protected services
INTERNAL_AUTH=true
INTERNAL_CREDENTIAL=admin:secretpassword
WEBROOT_AUTH=false
```

`TTYD_CREDENTIAL` still works for backward compatibility (maps to `INTERNAL_CREDENTIAL`).

### Feature Toggles
- `ENABLE_FILEBROWSER` - Enable /files/ endpoint (default: true)
- `ENABLE_WEBDAV` - Enable /webdav/ endpoint (default: false)

### Claude Settings
- `ANTHROPIC_API_KEY` - Claude API key
- `CLAUDE_BYPASS_PERMISSIONS` - Skip permission prompts (default: false)
- `CLAUDE_CODE_SHELL` - Shell for Claude commands (set to /bin/zsh)

### Other
- `ENABLE_SSH` - Enable SSH server on port 2222
- `LOG_TO_FILE` - Enable logging to data/logs/ (default: false)

**Runtime settings:** Bypass permissions can be toggled at runtime with `cc-bypass [on|off]` - no restart needed.

## User Mapping

Set in `docker/.env`:

```bash
PUID=1000  # Your user ID (run `id -u` on host)
PGID=1000  # Your group ID (run `id -g` on host)
```

Entrypoint adjusts container user at runtime—no rebuild needed.

## Custom Packages

Edit `data/custom-packages.txt` (one package per line). Installed on every container start.

```bash
# Example
docker-cli
postgresql-client
go
```

Find packages: https://pkgs.alpinelinux.org/packages

## MCP Configuration

Edit `data/mcp/mcp.json`. Default includes filesystem access to workspace.

## Host Directory Mounts

Mount host directories to `/mounts/<name>` in `docker-compose.yml`:
```yaml
volumes:
  - /home/user:/mounts/user
  - /media/drive:/mounts/drive:ro  # read-only
```

Access at `/mounts/` inside container.

## Customization

All configs in `$CLAUDE_DATA_PATH/` can be customized without rebuilding:

| Path | Purpose |
|------|---------|
| `nginx/nginx.conf` | Reverse proxy configuration |
| `webroot/public_html/index.php` | Landing page (add branding, links, PHP apps) |
| `scripts/entrypoint.sh` | Container bootstrap |
| `scripts/start-services.sh` | Service supervisor |
| `scripts/shell-wrapper.sh` | First-run wizard |
| `scripts/.zshrc` | Shell configuration |

## Startup Validation

The entrypoint performs these checks before starting:
1. **Data directory exists and is writable** - Fails fast if volume mount is broken
2. **Disk space check** - Requires 100MB free minimum
3. **Loop detection** - Prevents infinite redirect if custom entrypoint misconfigured
4. **Package name validation** - Only allows alphanumeric, dash, underscore, dot in custom-packages.txt
