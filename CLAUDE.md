# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClaudePantheon is a minimal Alpine-based Docker environment for persistent Claude Code sessions. Features web terminal access via ttyd, session continuity, MCP integrations, and runtime package installation. All persistent data lives in a single volume mount.

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
make health         # Check ttyd web terminal health
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
docker/
├── Dockerfile              # Alpine image (Node.js 22, ttyd, zsh, rsync, ssh)
├── docker-compose.yml      # Volume mount: $CLAUDE_DATA_PATH:/app/data
├── Makefile                # Management commands
├── .env.example            # Host config template (CLAUDE_DATA_PATH, PUID, etc.)
├── scripts/                # Default scripts (copied to data/ on first run)
│   ├── entrypoint.sh       # Container bootstrap
│   ├── shell-wrapper.sh    # First-run wizard
│   └── .zshrc              # Shell config
│
# Data directory (default: /docker/appdata/claudepantheon)
$CLAUDE_DATA_PATH/          # ALL PERSISTENT DATA (auto-created)
├── workspace/              # User projects
├── claude/                 # Session history
├── mcp/                    # MCP configuration
│   └── mcp.json
├── ssh/                    # SSH keys (auto 700/600 permissions)
├── logs/                   # Container logs (enable with LOG_TO_FILE=true)
├── zsh-history/
├── npm-cache/
├── python-venvs/
├── scripts/                # Runtime scripts (all customizable!)
│   ├── entrypoint.sh       # Container bootstrap
│   ├── shell-wrapper.sh    # First-run wizard
│   └── .zshrc              # Shell config (symlinked to ~/.zshrc)
├── gitconfig               # Git configuration
├── custom-packages.txt
└── .env
```

**Flow:** Docker start → `defaults/entrypoint.sh` checks for custom → `data/scripts/entrypoint.sh` (if exists) → ttyd → `data/scripts/shell-wrapper.sh` → zsh → Claude Code CLI

**Customization:** All scripts in `$CLAUDE_DATA_PATH/scripts/` can be customized without rebuilding the image.

## Key Files

| File | Purpose |
|------|---------|
| `docker/Dockerfile` | Alpine image with Node.js 22, ttyd, zsh, oh-my-zsh, rsync, ssh |
| `docker/docker-compose.yml` | Volume mount: `$CLAUDE_DATA_PATH:/app/data` |
| `docker/Makefile` | All management commands |
| `docker/scripts/entrypoint.sh` | Bootstrap: user mapping, data init, script copying |
| `docker/scripts/shell-wrapper.sh` | Default first-run wizard (copied to data/) |
| `docker/scripts/.zshrc` | Default shell config (copied to data/) |

## Data Directory (created on first run)

| Path | Purpose |
|------|---------|
| `data/workspace/` | Your projects (symlinked to ~/workspace) |
| `data/claude/` | Claude Code session history (symlinked to ~/.claude) |
| `data/mcp/mcp.json` | MCP server configuration |
| `data/ssh/` | SSH keys (symlinked to ~/.ssh, auto 700/600 perms) |
| `data/logs/` | Container logs (enable with LOG_TO_FILE=true) |
| `data/gitconfig` | Git configuration |
| `data/zsh-history/` | Shell history (symlinked to ~/.zsh_history_dir) |
| `data/npm-cache/` | NPM cache (symlinked to ~/.npm) |
| `data/python-venvs/` | Python virtual environments (symlinked to ~/.venvs) |
| `data/scripts/entrypoint.sh` | Container bootstrap (customizable) |
| `data/scripts/shell-wrapper.sh` | First-run wizard (customizable) |
| `data/scripts/.zshrc` | Shell config (symlinked to ~/.zshrc, customizable) |
| `data/custom-packages.txt` | Alpine packages to install on boot |
| `data/.env` | Environment configuration (API keys, etc.) |

## Configuration

Host-level settings go in `docker/.env` (copy from `.env.example`):
- `CLAUDE_DATA_PATH` - Where to store data (default: `/docker/appdata/claudepantheon`)
- `PUID` / `PGID` - User/group IDs for file permissions
- `ANTHROPIC_API_KEY` - Claude API key
- `TTYD_CREDENTIAL` - Web terminal auth (`user:pass`)
- `LOG_TO_FILE` - Enable logging to data/logs/ (default: false)
- `MEMORY_LIMIT` - Container memory limit (default: 4G)
- `CLAUDE_BYPASS_PERMISSIONS` - Skip permission prompts (default: false)

Claude Code is configured to use zsh as its shell (`CLAUDE_CODE_SHELL=/bin/zsh`).

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

## Startup Validation

The entrypoint performs these checks before starting:
1. **Data directory exists and is writable** - Fails fast if volume mount is broken
2. **Disk space check** - Requires 100MB free minimum
3. **Loop detection** - Prevents infinite redirect if custom entrypoint misconfigured
4. **Package name validation** - Only allows alphanumeric, dash, underscore, dot in custom-packages.txt
