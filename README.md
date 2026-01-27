<div align="center">

# 🏛️ ClaudePantheon

### *A temple for your persistent Claude Code sessions*

[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://ghcr.io/randomsynergy17/claudepantheon)
[![Alpine](https://img.shields.io/badge/Alpine-Linux-0D597F?style=for-the-badge&logo=alpinelinux&logoColor=white)](https://alpinelinux.org/)
[![Claude](https://img.shields.io/badge/Claude-Code-D97757?style=for-the-badge&logo=anthropic&logoColor=white)](https://claude.ai/)

**Run Claude Code anywhere. Remember everything. Access from any browser.**

[Quick Start](#-quick-start) • [Features](#-features) • [Use Cases](#-use-cases) • [Commands](#-commands) • [Configuration](#️-makefile-commands)

</div>

---

## 🎯 What is ClaudePantheon?

ClaudePantheon gives you a **persistent, always-on Claude Code environment** that you can access from any device with a web browser. Unlike running Claude Code locally, your sessions, context, and workspace persist across restarts—Claude remembers your projects, preferences, and ongoing work.

Think of it as your personal AI development workstation in the cloud (or on your server), ready whenever you need it.

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
Let Claude manage your infrastructure. Connect MCP servers for GitHub, databases, Home Assistant, and more—all persisted between sessions.

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

## 🚀 Quick Start

```bash
cd ClaudePantheon/docker

# Optional: Configure data path and settings
cp .env.example .env
# Edit .env to set CLAUDE_DATA_PATH, PUID, PGID, etc.

# Build and start
make build
make up

# Open http://localhost:7681
# You'll see the landing page with Terminal, Files, and PHP Info buttons
# Click Terminal and complete the setup wizard, then type 'cc' to start!
```

## 🏗️ Architecture

All services accessible via a single port:

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

## 📁 Data Structure

All persistent data lives in a single mounted directory (configurable via `CLAUDE_DATA_PATH`).

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
│   ├── start-services.sh   # Service supervisor
│   ├── shell-wrapper.sh    # First-run wizard
│   └── .zshrc              # Shell configuration

# Data directory (default: /docker/appdata/claudepantheon)
$CLAUDE_DATA_PATH/          # ALL PERSISTENT DATA (auto-created)
├── workspace/              # Your projects
├── claude/                 # Session history
├── mcp/                    # MCP configuration
│   └── mcp.json            # MCP server configuration
├── nginx/                  # nginx config (customizable)
│   └── nginx.conf
├── webroot/                # Web content (customizable)
│   └── public_html/
│       └── index.php       # Landing page
├── filebrowser/            # FileBrowser database
├── ssh/                    # SSH keys (auto 700/600 permissions)
├── logs/                   # Container logs (optional)
├── zsh-history/            # Shell history
├── npm-cache/              # npm cache
├── python-venvs/           # Python virtual environments
├── scripts/                # Runtime scripts (all customizable!)
│   ├── entrypoint.sh       # Container bootstrap
│   ├── start-services.sh   # Service supervisor
│   ├── shell-wrapper.sh    # First-run wizard
│   └── .zshrc              # Shell configuration
├── gitconfig               # Git configuration
├── custom-packages.txt     # Alpine packages to install
└── .env                    # Container environment
```

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

## 🛠️ Makefile Commands

```bash
# Container Lifecycle
make build    # Build the Docker image
make up       # Start ClaudePantheon (detached)
make down     # Stop the container
make restart  # Restart the container
make rebuild  # Quick rebuild (down + build + up)

# Development & Access
make shell    # Get a shell in the container
make logs     # View logs (follow mode)
make dev      # Run in foreground with logs

# Status & Health
make status   # Show container status and resources
make health   # Check web interface health
make version  # Show Claude Code version
make tree     # Show data directory structure

# Maintenance
make backup   # Backup entire data directory
make update   # Update Claude Code to latest
make clean    # Remove container and images (keeps data)
make purge    # Remove everything including data
```

## 🌐 Landing Page

The landing page is a PHP file at `data/webroot/public_html/index.php`. Features:

- **Three quick-access buttons**: Terminal, Files, PHP Info
- **Inline PHP info**: Accordion that expands without leaving the page
- **Catppuccin Mocha theme**: Dark mode, easy on the eyes
- **Mobile responsive**: Buttons stack on smaller screens
- **Customizable**: Edit the file to add branding, links, or features

### Customizing the Landing Page

Edit `$CLAUDE_DATA_PATH/webroot/public_html/index.php` to:
- Change branding/logo
- Add custom links or buttons
- Include system status widgets
- Add your own PHP applications

## 📁 FileBrowser

FileBrowser Quantum is embedded in the container and accessible at `/files/`.

### Features

- 📂 Browse all workspace files visually
- ⬆️ Upload files via drag & drop
- ⬇️ Download files and folders
- ✏️ Edit text files in browser
- 🔍 Fast indexed search across all files
- 🔗 Generate shareable links
- 📱 Mobile-friendly interface

### Disable FileBrowser

```bash
# In docker/.env
ENABLE_FILEBROWSER=false
```

## 🔗 WebDAV

WebDAV allows you to mount your ClaudePantheon workspace as a network drive.

### Enable WebDAV

```bash
# In docker/.env
ENABLE_WEBDAV=true
```

### Connect

**macOS Finder:**
1. Go → Connect to Server (⌘K)
2. Enter: `http://localhost:7681/webdav/`
3. Enter credentials if auth is enabled

**Windows Explorer:**
1. This PC → Map Network Drive
2. Enter: `http://localhost:7681/webdav/`
3. Enter credentials if auth is enabled

**Linux:**
```bash
# Using davfs2
sudo mount -t davfs http://localhost:7681/webdav/ /mnt/claudepantheon
```

## 📦 Custom Packages

Add Alpine packages to `./data/custom-packages.txt` (one per line). Packages install on every container start—no rebuild required.

```bash
# Example custom-packages.txt
docker-cli
postgresql-client
go
rust
```

Find packages at: https://pkgs.alpinelinux.org/packages

## 👤 User Mapping

Configure UID/GID in `docker/.env` to match your host user:

```bash
PUID=1000  # Run `id -u` on host
PGID=1000  # Run `id -g` on host
```

The entrypoint adjusts container user at runtime—no rebuild needed.

## Memory Limits

Configure container memory in `docker/.env`:

```bash
MEMORY_LIMIT=4G  # Default
```

Increase for heavy usage (large codebases, many MCP servers).

## Claude Code Settings

### Bypass Permissions

Skip all permission prompts (Claude executes without asking). Can be configured two ways:

**Option 1: Environment variable** (requires restart)
```bash
# In docker/.env
CLAUDE_BYPASS_PERMISSIONS=true  # Default: false
```

**Option 2: Runtime toggle** (instant, no restart)
```bash
cc-bypass on      # Enable bypass
cc-bypass off     # Disable bypass
cc-bypass         # Toggle current setting
cc-settings       # View current settings
```

**Warning:** Only enable if you trust Claude to run commands autonomously. This adds `--dangerously-skip-permissions` to all claude commands.

### Default Shell

Claude Code uses zsh by default in this container (set via `CLAUDE_CODE_SHELL=/bin/zsh`). This ensures Claude's shell commands use the same environment as your terminal.

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

Inside the container, access mounted directories at `/mounts/`:
```bash
ls /mounts/home/projects
cd /mounts/storage/code
```

**Security note:** Mounted directories are accessible to Claude with full read/write permissions (unless `:ro` is specified). Only mount directories you want Claude to access.

## 🔌 MCP Configuration

Edit `./data/mcp/mcp.json` to add MCP servers:

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

## 🔒 Security

### Essential Configuration

1. **Set authentication** in `docker/.env` - Use `INTERNAL_AUTH=true` with credentials
2. **Use a reverse proxy** - Add HTTPS with nginx/Caddy
3. **Limit port exposure** - Only expose ports you need

### Remote Access Options

- **Tailscale** - Add to your tailnet for secure access
- **Cloudflare Tunnel** - Zero-trust access without port forwarding
- **VPN** - Access via your network VPN

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

## 💾 Backup

```bash
# Quick backup of all data
make backup

# Manual backup
tar -czf claudepantheon-backup.tar.gz -C docker data/
```

## 📄 License

MIT - Do whatever you want with it!

---

<p align="center">
Built with ❤️ for persistent Claude Code workflows.<br>
A RandomSynergy Production
</p>
