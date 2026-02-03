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
| 🌐 **Remote Mounts** | rclone: S3, Google Drive, SFTP, SMB, WebDAV, FTP, 50+ backends |

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
│     workspace/   webroot/   scripts/   logs/                 │
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
| `ENABLE_RCLONE` | `false` | rclone remote mounts (requires FUSE in docker-compose.yml) |
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
| `cc` | Continue last session (most recent) |
| `cc-new` | Start a fresh session |
| `cc-resume` | Resume a session (interactive picker) |
| `cc-list` | Resume a session (interactive picker, same as cc-resume) |
| `cc-setup` | Re-run the CLAUDE.md setup wizard |
| `cc-mcp` | Manage MCP server configurations |
| `cc-bypass` | Toggle bypass permissions `[on\|off]` |
| `cc-settings` | Show current settings |
| `cc-info` | Show environment information |
| `cc-community` | Install community skills, commands & rules |
| `cc-rmount` | Manage rclone remote mounts (S3, SFTP, Google Drive, etc.) |
| `cc-factory-reset` | Factory reset — wipe all data, fresh install |
| `cc-help` | Show all available commands |

### Navigation Aliases

| Command | Description |
|---------|-------------|
| `ccw` | Go to workspace directory |
| `ccd` | Go to data directory |
| `ccmnt` | Go to host mounts directory |
| `ccr` | Go to rclone mounts directory |
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
│   ├── commands/           # Community slash commands (via cc-community)
│   └── rules/              # Community rules (via cc-community)
├── mcp/
│   └── mcp.json            # MCP server configuration
├── nginx/
│   └── nginx.conf          # nginx config (customizable)
├── webroot/
│   └── public_html/
│       └── index.php       # Landing page (customizable)
├── filebrowser/            # FileBrowser database
├── ssh/                    # SSH keys (auto 700/600 permissions)
├── ssh-host-keys/          # Persistent SSH host keys (root-owned)
├── logs/                   # Container logs (when LOG_TO_FILE=true)
├── zsh-history/            # Shell history
├── npm-cache/              # npm cache
├── python-venvs/           # Python virtual environments
├── rclone/                 # rclone config & auto-mount settings
│   ├── rclone.conf         # Remote configurations
│   └── automount.conf      # Auto-mount on startup
├── scripts/                # Runtime scripts (all customizable)
│   ├── entrypoint.sh       # Container bootstrap
│   ├── start-services.sh   # Service supervisor
│   ├── shell-wrapper.sh    # First-run wizard
│   └── .zshrc              # Shell configuration
├── gitconfig               # Git configuration
└── custom-packages.txt     # Alpine packages to install on start
```

**Key point:** Scripts in `scripts/` and `nginx/` are updated from image defaults on every container start. To preserve your customizations, create a `.keep` marker file (e.g., `touch $CLAUDE_DATA_PATH/scripts/.keep`). Webroot files are only copied if they don't exist yet.

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

WebDAV allows mounting ClaudePantheon directories as a network drive. Enable with `ENABLE_WEBDAV=true` in `.env`.

**Available directories:**

| Path | Maps to | Purpose |
|------|---------|---------|
| `/webdav/workspace/` | `data/workspace/` | User projects |
| `/webdav/webroot/` | `data/webroot/` | Landing page and web content |
| `/webdav/scripts/` | `data/scripts/` | Runtime scripts |
| `/webdav/logs/` | `data/logs/` | Container logs |

> Sensitive directories (`claude/`, `mcp/`, `ssh/`, `filebrowser/`) are not accessible via WebDAV.

**macOS Finder:**
1. Go → Connect to Server (⌘K)
2. Enter: `http://localhost:7681/webdav/workspace/`

**Windows Explorer:**
1. This PC → Map Network Drive
2. Enter: `http://localhost:7681/webdav/workspace/`

**Linux:**
```bash
sudo mount -t davfs http://localhost:7681/webdav/workspace/ /mnt/claudepantheon
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

## 🌐 Remote Filesystems (rclone)

Mount cloud storage and remote filesystems directly into the container using [rclone](https://rclone.org/). Supports **50+ backends** including S3, Google Drive, SFTP, SMB/CIFS, WebDAV, FTP, Azure Blob, Dropbox, OneDrive, Backblaze B2, and more.

### Enabling Remote Mounts

Remote mounts require FUSE support, which needs three changes to `docker-compose.yml`:

**Step 1:** Uncomment FUSE sections in `docker/docker-compose.yml`:
```yaml
    # FUSE SUPPORT
    devices:
      - /dev/fuse
    cap_add:
      - SYS_ADMIN

    security_opt:
      - no-new-privileges:true
      - apparmor:unconfined       # uncomment this line
```

**Step 2:** Set `ENABLE_RCLONE=true` in `docker/.env`

**Step 3:** Rebuild: `make rebuild`

### Managing Remotes (cc-rmount)

Once enabled, use the `cc-rmount` command inside the container:

```
╔═══════════════════════════════════════════════════════════╗
║        ClaudePantheon - Remote Mount Manager             ║
╚═══════════════════════════════════════════════════════════╝

  1. Refresh mounts & remotes
  2. Add remote
  3. Mount remote
  4. Unmount remote
  5. Test remote connection
  6. Edit rclone config (rclone config)
  7. Auto-mount setup
  q. Exit
```

**Quick-setup wizards** are available for common providers:

| Provider | Type | Notes |
|----------|------|-------|
| S3 / S3-compatible | Cloud storage | AWS, Minio, Wasabi, DigitalOcean, Cloudflare |
| Google Drive | Cloud storage | Requires OAuth token (headless auth) |
| SFTP | Remote server | Password or SSH key auth |
| SMB / CIFS | Network share | Windows shares, NAS devices |
| WebDAV | Remote server | Nextcloud, Owncloud, SharePoint |
| FTP | Remote server | Plain or FTPS |

For all other providers, use the full `rclone config` interactive wizard (option 1).

### Auto-Mount on Startup

Configure remotes to mount automatically when the container starts. Edit `$CLAUDE_DATA_PATH/rclone/automount.conf`:

```bash
# Format: remote_name:/path  [rclone mount flags]
gdrive:/Documents  --vfs-cache-mode=writes
s3bucket:/data     --vfs-cache-mode=minimal
mysftp:/home       --vfs-cache-mode=off
```

Or use `cc-rmount` → Auto-mount setup → "Add active mounts to auto-mount" to populate from current mounts.

### VFS Cache Modes

| Mode | Description | Best For |
|------|-------------|----------|
| `off` | No caching, streaming only | Large read-only files |
| `minimal` | Metadata cache only | Read-heavy workloads |
| `writes` | Cache writes locally (**recommended**) | General use |
| `full` | Full read/write cache | Frequent read + write |

### Accessing Remote Mounts

```bash
ccr                    # Navigate to /mounts/rclone/
ls /mounts/rclone/     # List all mounted remotes
cd /mounts/rclone/nas  # Access a specific mount
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| `cc-rmount` says "FUSE device not available" | Uncomment `devices`, `cap_add`, and `apparmor:unconfined` in docker-compose.yml, then `make rebuild` |
| "Transport endpoint is not connected" | Stale mount — run `cc-rmount` → Unmount, or restart the container (auto-cleaned on start) |
| Google Drive auth fails | Run `rclone authorize "drive"` on a machine with a browser, paste the token in the quick-setup wizard |
| Mount fails silently | Check `rclone ls <remote>:` to verify the remote config works before mounting |

### Files

| Path | Purpose |
|------|---------|
| `$CLAUDE_DATA_PATH/rclone/rclone.conf` | rclone remote configuration (persisted) |
| `$CLAUDE_DATA_PATH/rclone/automount.conf` | Auto-mount configuration |
| `/mounts/rclone/<name>/` | Mountpoints for active remotes |

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

## 🧩 Community Content

ClaudePantheon includes a built-in installer for curated Claude Code commands and rules from the open-source community. Content is downloaded on demand from GitHub — no extra image bloat.

### Installing

During the initial setup wizard (questions 11-12), or anytime with:

```bash
cc-community    # Install community commands & rules
cc-mcp          # Option 3: auto-configure MCP servers
```

### Available Commands

Downloaded to `~/.claude/commands/` and usable as slash commands in Claude Code:

| Command | Description |
|---------|-------------|
| `/plan` | Plan implementation before coding |
| `/code-review` | Structured code review with severity levels |
| `/tdd` | Test-driven development workflow |
| `/build-fix` | Fix build errors iteratively |
| `/refactor-clean` | Clean up and remove dead code |
| `/verify` | Verify changes before committing |
| `/checkpoint` | Save verification state |

### Available Rules

Downloaded to `~/.claude/rules/` and always active during Claude sessions:

| Rule | Description |
|------|-------------|
| Security | Prevent credential leaks, injection flaws |
| Coding Style | Clean code standards |
| Testing | Test coverage requirements |
| Git Workflow | Clean commit practices |

### MCP Auto-Configuration

The setup wizard and `cc-mcp` now auto-configure MCP servers by prompting for tokens and writing directly to `mcp.json`. Supported servers: GitHub, Brave Search, Memory, PostgreSQL, Filesystem, Puppeteer, and Context7.

### Attribution

Community content is sourced from these open-source projects — all credit to the original authors:

- **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** by Affaan M — Commands, rules, skills, and agents for Claude Code workflows
- **[claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice)** by Shan Raisshan — Architecture patterns, CLAUDE.md best practices, and workflow guidance

Attribution is also stored in `~/.claude/COMMUNITY_CREDITS.md` inside the container.

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

## 🐚 Shell Customization

The shell environment is fully customizable by editing `$CLAUDE_DATA_PATH/scripts/.zshrc`. Changes persist across container rebuilds. After editing, start a new terminal session (or run `source ~/.zshrc`) to apply.

### Default Editor

The `EDITOR` environment variable controls which editor is used by `cce`, `ccm`, `ccp`, and `cc-mcp`:

```bash
# In $CLAUDE_DATA_PATH/scripts/.zshrc
export EDITOR='nano'      # default
export EDITOR='vim'       # for vim users
export EDITOR='micro'     # modern terminal editor
```

### Oh My Zsh Theme

Change the shell prompt theme by editing `ZSH_THEME`:

```bash
ZSH_THEME="robbyrussell"   # default
ZSH_THEME="agnoster"       # powerline-style
ZSH_THEME="dst"            # minimal with git info
```

Browse all themes: https://github.com/ohmyzsh/ohmyzsh/wiki/Themes

### Plugins

The following Oh My Zsh plugins are enabled by default:

| Plugin | What it provides |
|--------|-----------------|
| `git` | Git aliases and functions (`gst`, `gco`, `gb`, etc.) |
| `docker` | Docker command completions |
| `npm` | npm command completions and aliases |
| `python` | Python/pip aliases and virtualenv helpers |
| `history` | History search aliases (`h`, `hs`) |
| `sudo` | Press <kbd>Esc</kbd> twice to prepend `sudo` to last command |
| `web-search` | Search from terminal (`google`, `ddg`, `github` commands) |
| `copypath` | Copy current directory path to clipboard |
| `copyfile` | Copy file contents to clipboard |
| `jsontools` | JSON formatting tools (`pp_json`, `is_json`, `urlencode_json`) |
| `zsh-autosuggestions` | Fish-like inline command suggestions |
| `zsh-syntax-highlighting` | Real-time syntax coloring as you type |

Add or remove plugins by editing the `plugins=()` array in `.zshrc`.

### History

| Setting | Default | Description |
|---------|---------|-------------|
| `HISTSIZE` | `50000` | Max entries kept in memory |
| `SAVEHIST` | `50000` | Max entries saved to disk |
| `SHARE_HISTORY` | enabled | Share history across concurrent sessions |
| `HIST_IGNORE_DUPS` | enabled | Skip duplicate consecutive commands |

History is stored in `$CLAUDE_DATA_PATH/zsh-history/` and persists across restarts.

### Additional Aliases

Beyond the Claude Code aliases documented above, `.zshrc` includes:

**Utility:**
`ll` (ls -la), `la` (ls -A), `l` (ls -CF), `..` (cd ..), `...` (cd ../..)

**Git:**
`gs` (status), `ga` (add), `gc` (commit), `gp` (push), `gl` (log --oneline -10), `gd` (diff)

**Docker:**
`dps` (ps), `dpa` (ps -a), `di` (images)

### Color Fix

The `.zshrc` includes `precmd` and `preexec` hooks that reset terminal colors before and after each command. This prevents color bleeding from Claude Code's colored error output into your prompt.

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

Check the data volume (use your configured `CLAUDE_DATA_PATH`):
```bash
ls -la $CLAUDE_DATA_PATH/
ls -la $CLAUDE_DATA_PATH/claude/
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

1. Check config: `jq . $CLAUDE_DATA_PATH/mcp/mcp.json`
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

## 🔄 Factory Reset

Reset ClaudePantheon to a fresh install state from inside the container:

```bash
cc-factory-reset
```

This command has a **three-stage confirmation process** to prevent accidental data loss:

1. **Step 1:** Type `yes` to confirm intent
2. **Step 2:** Type `YES` (uppercase) to double-confirm
3. **Step 3:** Retype a randomly generated three-word challenge phrase

### What Gets Deleted

Everything under `$CLAUDE_DATA_PATH` except SSH keys:

- Workspace files and projects
- Claude session history and conversations
- MCP server configuration
- Community commands, rules, and skills
- Custom packages list, nginx config, webroot
- Shell configuration (.zshrc customizations)
- FileBrowser database, git config, logs, caches

### What Gets Preserved

- **SSH keys** (`$CLAUDE_DATA_PATH/ssh/`) — preserved by default, with an optional double-confirmation prompt to delete them too
- **Host volume mounts** (`/mounts/`) — completely untouched (separate Docker volumes)

After the reset completes, the container automatically restarts and re-initializes from image defaults, presenting the first-run setup wizard.

**Tip:** Run `make backup` before resetting if you want the option to restore later.

---

## 📋 Changelog

### 2026-02-03
- **Changelog directive** — Added commit guidelines to CLAUDE.md requiring changelog updates with every commit
- **SSH key authentication fix** — Unlock user account on startup to allow SSH public key authentication (previously blocked by locked account status)

### 2026-01-31
- **404 page improvements** — Global 404 handling with themed error page
- **WebDAV security** — Added subdirectory restrictions for sensitive paths
- **Security hardening** — Multiple security fixes and documentation alignment

### 2026-01-30
- **Community content installer** — `cc-community` command for installing slash commands and rules
- **MCP auto-configuration** — Interactive setup for GitHub, Brave Search, PostgreSQL, and more
- **Factory reset** — `cc-factory-reset` with three-stage confirmation

### 2026-01-29
- **Default editor** — Changed from vim to nano for better accessibility
- **Health endpoint** — Added `/health` for Docker healthchecks with auth
- **Pantheon TV show reference** — Added name inspiration to README
- **Multiple bug fixes:**
  - Claude Code binary detection path
  - nginx permission warnings and dav_ext module loading
  - Service log color rendering
  - False "no authentication" warning
  - Script update race condition
  - Auth config special character handling
  - Always update scripts from image defaults on container start

### 2026-01-28
- **GHCR deployment** — GitHub Actions CI/CD for automatic image builds
- **Comprehensive documentation** — Full configuration reference in README

### 2026-01-27
- **Multi-service architecture** — nginx reverse proxy routing all services via single port
- **FileBrowser Quantum** — Optional web file manager at `/files/`

### 2026-01-26
- **Native Claude Code installer** — Switched from npm to official installer
- **PATH fixes** — Use `~/.local/bin` for Claude Code binary
- **Build fixes** — Resolve macOS UID/GID conflicts, node:alpine conflicts
- **ttyd terminal** — Fixed terminal issues, updated branding
- **README enhancements** — Use cases, benefits, better formatting

### 2026-01-25
- **Initial release** — First public version
- **DevOps review fixes** — Runtime settings, major refactoring

---

## 📄 License

MIT — Do whatever you want with it!

---

<p align="center">
Built with ❤️ for persistent Claude Code workflows.<br>
A RandomSynergy Production
</p>
