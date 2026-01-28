<div align="center">

# 🏛️ ClaudePantheon

### *A temple for your persistent Claude Code sessions*

[![GHCR](https://img.shields.io/badge/GHCR-Package-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://github.com/RandomSynergy17/ClaudePantheon/pkgs/container/claudepantheon)
[![Alpine](https://img.shields.io/badge/Alpine-Linux-0D597F?style=for-the-badge&logo=alpinelinux&logoColor=white)](https://alpinelinux.org/)
[![Claude](https://img.shields.io/badge/Claude-Code-D97757?style=for-the-badge&logo=anthropic&logoColor=white)](https://claude.ai/)

**Run Claude Code anywhere. Remember everything. Access from any browser.**

[Quick Start](#-quick-start) • [Configuration](#%EF%B8%8F-configuration) • [Architecture](#-architecture) • [Commands](#-commands) • [Troubleshooting](#-troubleshooting)

</div>

---

## 🎯 What is ClaudePantheon?

ClaudePantheon gives you a **persistent, always-on Claude Code environment** that you can access from any device with a web browser. Unlike running Claude Code locally, your sessions, context, and workspace persist across restarts — Claude remembers your projects, preferences, and ongoing work.

The name is inspired by the show [*Pantheon*](https://en.wikipedia.org/wiki/Pantheon_(TV_series)) (based on Ken Liu's short stories), where consciousness is uploaded into a persistent digital environment. ClaudePantheon applies that concept to Claude Code — a temple where your AI assistant lives permanently, remembers everything, and is always available.

```
╔═══════════════════════════════════════════════════════════╗
║                    ClaudePantheon                         ║
║              A RandomSynergy Production                   ║
╚═══════════════════════════════════════════════════════════╝
```

---

## 💡 Use Cases

<table>
<tr>
<td width="50%">

### 🏠 Home Server / NAS
Run Claude Code on your home server and access it from your laptop, tablet, or phone. Your AI assistant is always available on your local network.

### 🖥️ Remote Development
SSH tunnel or reverse proxy to your ClaudePantheon instance from anywhere. Perfect for developers who work across multiple machines.

### 🏢 Team Workstation
Deploy shared instances for your team. Each developer gets their own persistent Claude environment without local setup.

</td>
<td width="50%">

### 🔧 DevOps & Automation
Let Claude manage your infrastructure. Connect MCP servers for GitHub, databases, Home Assistant, and more — all persisted between sessions.

### 📱 Mobile Access
Access your AI coding assistant from a tablet or phone browser when you're away from your main workstation.

### 🧪 Experimentation
Spin up isolated environments to test new workflows, MCP integrations, or Claude configurations without affecting your main setup.

</td>
</tr>
</table>

---

## ✨ Features

<table>
<tr>
<td>

### 🔄 Persistent Everything
- **Session continuity** — Claude remembers your conversations
- **Workspace files** — Your code stays between restarts
- **MCP connections** — Integrations persist across sessions
- **Shell history** — Command history saved permanently

</td>
<td>

### 🌐 Access Anywhere
- **Web terminal** — Full terminal via any browser
- **No client install** — Just open a URL
- **Mobile friendly** — Works on tablets and phones
- **Landing page** — Professional entry point with quick access

</td>
</tr>
<tr>
<td>

### ⚡ Developer Experience
- **Oh My Zsh** — Beautiful shell with plugins
- **Simple aliases** — `cc` to start, `cc-new` for fresh session
- **Custom packages** — Add tools without rebuilding
- **User mapping** — Seamless host file permissions

</td>
<td>

### 🔌 Extensible
- **MCP ready** — GitHub, Postgres, Home Assistant, more
- **Host mounts** — Access any directory on the host
- **Customizable webroot** — Add custom PHP apps
- **WebDAV support** — Mount as network drive

</td>
</tr>
</table>

### At a Glance

| Feature | Description |
|---------|-------------|
| 🏔️ **Alpine-Based** | Minimal base image, fast startup |
| 🔄 **Persistent Sessions** | All conversations continue where you left off |
| 🌐 **Single Port** | All services via one port (nginx reverse proxy) |
| 🏠 **Landing Page** | Customizable PHP landing page with quick access buttons |
| 📁 **FileBrowser** | Web-based file management built-in |
| 🔗 **WebDAV** | Mount workspace as network drive (optional) |
| 🐚 **Oh My Zsh** | Beautiful shell with syntax highlighting & autosuggestions |
| 🔌 **MCP Ready** | Pre-configured for Model Context Protocol integrations |
| 📦 **Custom Packages** | Install Alpine packages without rebuilding |
| 👤 **User Mapping** | Configurable UID/GID for permission-free bind mounts |
| 🔐 **Two-Zone Auth** | Separate credentials for landing page vs services |

---

## 📋 Prerequisites

- **Docker** (20.10+) and **Docker Compose** (v2)
- An **Anthropic API key** or the ability to run `claude auth login` for browser-based auth
- ~500MB disk space for the image, plus space for your data

---

## 🚀 Quick Start

### Option 1: Pull from GHCR (recommended)

```bash
git clone https://github.com/RandomSynergy17/ClaudePantheon.git
cd ClaudePantheon/docker

cp .env.example .env
# Edit .env — at minimum set CLAUDE_DATA_PATH and PUID/PGID

docker compose pull
docker compose up -d
```

### Option 2: Build from source

```bash
cd ClaudePantheon/docker

cp .env.example .env
# Edit .env — at minimum set CLAUDE_DATA_PATH and PUID/PGID

make build
make up
```

Open **http://localhost:7681** — you'll see the landing page with Terminal, Files, and PHP Info buttons. Click Terminal, complete the setup wizard, then type `cc` to start.

---

## 🏗️ Architecture

All services accessible via a single port through an nginx reverse proxy:

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

### Ports

| Port | Service | Notes |
|------|---------|-------|
| **7681** | nginx reverse proxy | All web services (`/`, `/terminal/`, `/files/`, `/webdav/`) |
| **2222** | SSH server | Optional, requires `ENABLE_SSH=true` in `.env` |

### Startup Flow

On container start, the entrypoint script runs through this sequence:

1. **Validate** data directory exists and is writable, check disk space (100MB minimum)
2. **Map user** — adjusts container UID/GID to match `PUID`/`PGID` from `.env`
3. **Initialize data** — creates directory structure under `$CLAUDE_DATA_PATH` on first run
4. **Copy defaults** — scripts, nginx config, and webroot are copied from the image into the data volume *only if they don't already exist* (preserves your customizations)
5. **Install packages** — reads `custom-packages.txt` and installs via `apk`
6. **Fix permissions** — sets ownership and SSH key permissions
7. **Start services** — launches nginx, php-fpm, FileBrowser (if enabled), and ttyd

### Startup Validation

The entrypoint performs safety checks before proceeding:

- **Data directory writable** — fails fast if the volume mount is broken
- **Disk space** — requires 100MB free minimum
- **Loop detection** — prevents infinite redirect if custom entrypoint is misconfigured
- **Package name validation** — only alphanumeric, dash, underscore, dot allowed in `custom-packages.txt`

---

## ⚙️ Configuration

All configuration is done through `docker/.env` (copy from `.env.example`). Changes require `make restart` unless noted otherwise.

### .env Variable Reference

#### Data & User

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_DATA_PATH` | `/docker/appdata/claudepantheon` | Host path for all persistent data |
| `PUID` | `1000` | Container user ID (run `id -u` on host) |
| `PGID` | `1000` | Container group ID (run `id -g` on host) |

#### Claude Code

| Variable | Default | Description |
|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | *(empty)* | Claude API key. Alternatively, run `claude auth login` inside the container |
| `CLAUDE_BYPASS_PERMISSIONS` | `false` | Skip permission prompts. Also toggleable at runtime with `cc-bypass on\|off` |

#### Authentication (Two-Zone System)

| Variable | Default | Description |
|----------|---------|-------------|
| `INTERNAL_AUTH` | `false` | Enable auth for `/terminal/`, `/files/`, `/webdav/` |
| `INTERNAL_CREDENTIAL` | *(empty)* | Credentials as `user:password` |
| `WEBROOT_AUTH` | `false` | Enable auth for `/` (landing page) |
| `WEBROOT_CREDENTIAL` | *(empty)* | Webroot credentials. Falls back to `INTERNAL_CREDENTIAL` if unset |
| `TTYD_CREDENTIAL` | *(empty)* | **Deprecated.** Backward compatibility alias for `INTERNAL_CREDENTIAL` |

#### Feature Toggles

| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_FILEBROWSER` | `true` | Web file manager at `/files/` |
| `ENABLE_WEBDAV` | `false` | WebDAV endpoint at `/webdav/` |
| `ENABLE_SSH` | *(empty)* | Set to any value (e.g., `true`) to enable SSH on port 2222 |
| `LOG_TO_FILE` | `false` | Write logs to `$CLAUDE_DATA_PATH/logs/claudepantheon.log`. Auto-rotates at 10MB |

#### System

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Timezone ([list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)) |
| `MEMORY_LIMIT` | `4G` | Container memory limit. Increase for large codebases or many MCP servers |

---

## 🔐 Authentication

ClaudePantheon uses a two-zone authentication system:

| Zone | Endpoints | Use Case |
|------|-----------|----------|
| **Internal** | `/terminal/`, `/files/`, `/webdav/` | Core services |
| **Webroot** | `/` (landing page, custom apps) | Public-facing content |

### Common Configurations

**1. No authentication (development/trusted networks):**
```bash
INTERNAL_AUTH=false
WEBROOT_AUTH=false
```

**2. Protect everything with same credentials:**
```bash
INTERNAL_AUTH=true
INTERNAL_CREDENTIAL=admin:secretpassword
WEBROOT_AUTH=true
# WEBROOT_CREDENTIAL not set = uses INTERNAL_CREDENTIAL
```

**3. Public landing page, protected services:**
```bash
INTERNAL_AUTH=true
INTERNAL_CREDENTIAL=admin:secretpassword
WEBROOT_AUTH=false
```

**4. Different credentials for each zone:**
```bash
INTERNAL_AUTH=true
INTERNAL_CREDENTIAL=admin:secretpassword
WEBROOT_AUTH=true
WEBROOT_CREDENTIAL=guest:guestpassword
```

---

## 📜 Commands

### Claude Code Aliases

| Command | Description |
|---------|-------------|
| `cc` | Continue last Claude conversation |
| `cc-new` | Start a fresh session |
| `cc-resume` | Resume last session (same as cc) |
| `cc-list` | Interactive session picker |
| `cc-setup` | Re-run the CLAUDE.md setup wizard |
| `cc-mcp` | Manage MCP server configurations |
| `cc-bypass` | Toggle bypass permissions `[on\|off]` |
| `cc-settings` | Show current settings |
| `cc-info` | Show environment information |
| `cc-help` | Show all available commands |

### Navigation Aliases

| Command | Description |
|---------|-------------|
| `ccw` | Go to workspace directory |
| `ccd` | Go to data directory |
| `ccmnt` | Go to host mounts directory |
| `cce` | Edit workspace CLAUDE.md |
| `ccm` | Edit MCP configuration |
| `ccp` | Edit custom packages list |

---

## 📁 File Structure

### Source (in the repository)

```
docker/
├── Dockerfile              # Alpine image definition
├── docker-compose.yml      # Container configuration
├── Makefile                # Management commands
├── .env.example            # Configuration template (copy to .env)
├── .dockerignore           # Files excluded from build context
├── defaults/               # Default configs baked into the image
│   ├── nginx/
│   │   └── nginx.conf      # Reverse proxy configuration
│   └── webroot/
│       └── public_html/
│           └── index.php   # Landing page
└── scripts/
    ├── entrypoint.sh       # Container bootstrap
    ├── start-services.sh   # Service supervisor (nginx, php-fpm, filebrowser, ttyd)
    ├── shell-wrapper.sh    # First-run wizard
    └── .zshrc              # Shell configuration
```

### Data Volume (auto-created on first run)

All persistent data lives in `$CLAUDE_DATA_PATH`. On first run, defaults from the image are copied here. Your edits are preserved across container rebuilds and image updates.

```
$CLAUDE_DATA_PATH/
├── workspace/              # Your projects
├── claude/                 # Session history and Claude state
├── mcp/
│   └── mcp.json            # MCP server configuration
├── nginx/
│   └── nginx.conf          # nginx config (customizable)
├── webroot/
│   └── public_html/
│       └── index.php       # Landing page (customizable)
├── filebrowser/            # FileBrowser database
├── ssh/                    # SSH keys (auto 700/600 permissions)
├── logs/                   # Container logs (when LOG_TO_FILE=true)
├── zsh-history/            # Shell history
├── npm-cache/              # npm cache
├── python-venvs/           # Python virtual environments
├── scripts/                # Runtime scripts (all customizable)
│   ├── entrypoint.sh       # Container bootstrap
│   ├── start-services.sh   # Service supervisor
│   ├── shell-wrapper.sh    # First-run wizard
│   └── .zshrc              # Shell configuration
├── gitconfig               # Git configuration
└── custom-packages.txt     # Alpine packages to install on start
```

**Key point:** Defaults are only copied if the file doesn't exist yet. To reset a file to its default, delete it and restart the container.

---

## 🛠️ Makefile Commands

Run from the `docker/` directory.

```bash
# Container Lifecycle
make build      # Build the Docker image from source
make up         # Start ClaudePantheon (detached)
make down       # Stop the container
make restart    # Restart the container
make rebuild    # Stop, rebuild, and start (down + build + up)

# Development & Access
make shell      # Open zsh shell in running container
make logs       # Follow container logs (Ctrl+C to exit)
make dev        # Run in foreground with logs

# Status & Health
make status     # Show container status, data dir, and resource usage
make health     # Check if nginx is responding
make version    # Show Claude Code version
make tree       # Show data directory structure

# Maintenance
make backup     # Backup data directory to timestamped tarball
make update     # Update Claude Code to latest inside container
make clean      # Remove container and images (keeps data)
make purge      # Remove everything including data (DESTRUCTIVE)

# Registry (GHCR)
make login      # Log in to GitHub Container Registry
make push       # Build and push image to GHCR (:latest)
make push-all   # Push with :latest + :SHA tags
```

---

## 🌐 Landing Page

The landing page is a PHP file at `$CLAUDE_DATA_PATH/webroot/public_html/index.php`.

- **Three quick-access buttons**: Terminal, Files, PHP Info
- **Inline PHP info**: Accordion that expands without leaving the page
- **Catppuccin Mocha theme**: Dark mode, easy on the eyes
- **Mobile responsive**: Buttons stack on smaller screens
- **Customizable**: Edit the file to add branding, links, or features

Edit `$CLAUDE_DATA_PATH/webroot/public_html/index.php` to add custom branding, links, status widgets, or PHP applications.

---

## 📁 FileBrowser

[FileBrowser Quantum](https://github.com/gtsteffaniak/filebrowser) is embedded in the container at `/files/`.

- Browse all workspace files visually
- Upload files via drag & drop
- Download files and folders
- Edit text files in browser
- Fast indexed search
- Mobile-friendly interface

Disable with `ENABLE_FILEBROWSER=false` in `.env`.

---

## 🔗 WebDAV

WebDAV allows mounting the ClaudePantheon workspace as a network drive. Enable with `ENABLE_WEBDAV=true` in `.env`.

**macOS Finder:**
1. Go → Connect to Server (⌘K)
2. Enter: `http://localhost:7681/webdav/`

**Windows Explorer:**
1. This PC → Map Network Drive
2. Enter: `http://localhost:7681/webdav/`

**Linux:**
```bash
sudo mount -t davfs http://localhost:7681/webdav/ /mnt/claudepantheon
```

---

## 🖥️ SSH Server

An optional SSH server can be enabled for direct shell access without the web terminal.

```bash
# In docker/.env
ENABLE_SSH=true
```

Connect via:
```bash
ssh -p 2222 claude@localhost
```

SSH host keys are persisted in `$CLAUDE_DATA_PATH/ssh-host-keys/` so they survive container rebuilds. User SSH keys go in `$CLAUDE_DATA_PATH/ssh/` with permissions auto-fixed (directories 700, private keys 600, public keys 644).

---

## 📝 Logging

ClaudePantheon has two separate logging systems:

**1. Docker container logs** (always active):
```bash
make logs              # Follow logs
docker compose logs    # View logs
```
Container logs use `json-file` driver with 10MB rotation (3 files kept).

**2. Application log file** (opt-in):
```bash
# In docker/.env
LOG_TO_FILE=true
```
Writes to `$CLAUDE_DATA_PATH/logs/claudepantheon.log`. Auto-rotates at 10MB.

---

## 📦 Custom Packages

Add Alpine packages to `$CLAUDE_DATA_PATH/custom-packages.txt` (one per line). Packages install on every container start — no rebuild required.

```bash
# Example custom-packages.txt
docker-cli
postgresql-client
go
rust
```

Only alphanumeric characters, dashes, underscores, and dots are allowed in package names. Find packages at: https://pkgs.alpinelinux.org/packages

---

## 👤 User Mapping

Configure UID/GID in `docker/.env` to match your host user:

```bash
PUID=1000  # Run `id -u` on host
PGID=1000  # Run `id -g` on host
```

The entrypoint adjusts the container user at runtime — no rebuild needed. This ensures files created inside the container have the correct ownership on the host.

---

## Host Directory Mounts

Mount host directories into the container at `/mounts/<name>` so Claude can access files outside the data directory. Edit `docker/docker-compose.yml`:

```yaml
volumes:
  - ${CLAUDE_DATA_PATH:-/docker/appdata/claudepantheon}:/app/data

  # Add your host mounts here:
  - /home/user:/mounts/home
  - /media/storage:/mounts/storage
  - /var/www:/mounts/www:ro  # read-only
```

Inside the container:
```bash
ls /mounts/home/projects
cd /mounts/storage/code
```

**Security note:** Mounted directories are accessible to Claude with full read/write permissions unless `:ro` is specified. Only mount directories you want Claude to access.

---

## 🔌 MCP Configuration

Edit `$CLAUDE_DATA_PATH/mcp/mcp.json` to add MCP servers. The default config includes filesystem access to the workspace.

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your-token"
      }
    }
  }
}
```

### Available MCP Servers

| Server | Package | Use Case |
|--------|---------|----------|
| Filesystem | `@modelcontextprotocol/server-filesystem` | Extended file access |
| GitHub | `@modelcontextprotocol/server-github` | Repos, issues, PRs |
| PostgreSQL | `@modelcontextprotocol/server-postgres` | Database queries |
| Brave Search | `@modelcontextprotocol/server-brave-search` | Web search |
| Memory | `@modelcontextprotocol/server-memory` | Persistent memory |
| Puppeteer | `@modelcontextprotocol/server-puppeteer` | Browser automation |
| Home Assistant | `mcp-server-home-assistant` | Smart home |
| Notion | `mcp-notion` | Workspace |

---

## Claude Code Settings

### API Authentication

**Option 1: API key** (set once, works immediately):
```bash
# In docker/.env
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
```

**Option 2: Browser auth** (interactive login):
```bash
make shell
claude auth login
```

### Bypass Permissions

Skip all permission prompts (Claude executes without asking):

**Environment variable** (requires restart):
```bash
# In docker/.env
CLAUDE_BYPASS_PERMISSIONS=true
```

**Runtime toggle** (instant, no restart):
```bash
cc-bypass on      # Enable
cc-bypass off     # Disable
cc-bypass         # Toggle
cc-settings       # View current settings
```

**Warning:** Only enable if you trust Claude to run commands autonomously. This adds `--dangerously-skip-permissions` to all claude commands.

### Default Shell

Claude Code uses zsh by default (`CLAUDE_CODE_SHELL=/bin/zsh`), ensuring Claude's shell commands use the same environment as your interactive terminal.

---

## 🔒 Security

### Built-in Protections

- **`no-new-privileges`** — Docker security option prevents privilege escalation
- **Non-root runtime** — Services run as the `claude` user (UID/GID mapped to host)
- **Two-zone auth** — Separate credentials for landing page vs internal services
- **SSH key permissions** — Auto-fixed on every start (700 directories, 600 private keys)
- **Package validation** — Custom package names are validated before installation

### Essential Configuration

1. **Set authentication** in `docker/.env` — use `INTERNAL_AUTH=true` with strong credentials
2. **Use a reverse proxy** — add HTTPS with nginx, Caddy, or Traefik
3. **Limit port exposure** — only expose ports you need

### Remote Access Options

- **Tailscale** — add to your tailnet for secure access
- **Cloudflare Tunnel** — zero-trust access without port forwarding
- **VPN** — access via your network VPN

---

## 🚀 CI/CD

The repository includes a GitHub Actions workflow (`.github/workflows/docker-publish.yml`) that automatically builds and pushes the Docker image to GHCR:

- **On push to `main`**: publishes `ghcr.io/randomsynergy17/claudepantheon:latest` and `:SHA`
- **On version tags** (`v*`): publishes semver tags (e.g., `:1.0.0`, `:1.0`)
- **On pull requests**: builds the image without pushing (validation only)

The image is available at: `ghcr.io/randomsynergy17/claudepantheon`

---

## 🔧 Troubleshooting

### Session Not Persisting

Check the data volume:
```bash
ls -la ./data/
ls -la ./data/claude/
```

### Claude Not Authenticated

For API key auth, add to `docker/.env`:
```bash
ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
```

For browser auth:
```bash
make shell
claude auth login
```

### MCP Servers Not Working

1. Check config: `cat ./data/mcp/mcp.json | jq .`
2. Test manually: `npx -y @modelcontextprotocol/server-github`
3. Check status in Claude: `claude mcp`

### Container Won't Start

**Disk space error:** Requires at least 100MB free on the data volume.
```bash
df -h /path/to/data
```

**Data directory not writable:**
```bash
sudo chown -R $(id -u):$(id -g) /path/to/data
```

**Entrypoint loop error:** If you customized `data/scripts/entrypoint.sh` incorrectly, it may loop. Delete it to restore the default:
```bash
rm data/scripts/entrypoint.sh
make restart
```

---

## 💾 Backup & Restore

```bash
# Quick backup (creates timestamped tarball in docker/backups/)
make backup

# Manual backup
tar -czf claudepantheon-backup.tar.gz -C docker data/

# Restore from backup
make down
tar -xzf claudepantheon-backup.tar.gz -C docker/
make up
```

---

## 📄 License

MIT — Do whatever you want with it!

---

<p align="center">
Built with ❤️ for persistent Claude Code workflows.<br>
A RandomSynergy Production
</p>
