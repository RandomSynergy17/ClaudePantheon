# 🏛️ ClaudePantheon

> *A temple for your persistent Claude Code sessions*

A minimal Alpine-based Docker environment for persistent Claude Code sessions with web terminal access, oh-my-zsh, MCP integrations, and runtime package installation.

```
╔═══════════════════════════════════════════════════════════╗
║                    ClaudePantheon                         ║
║     Project Hospitality - We implement. Not just advise.  ║
╚═══════════════════════════════════════════════════════════╝
```

## ✨ Features

- 🏔️ **Alpine-Based** - Minimal footprint, fast startup
- 🔄 **Persistent Sessions** - All conversations continue from where you left off
- 🌐 **Web Terminal Access** - Connect via browser using ttyd
- 🐚 **Oh My Zsh** - Beautiful, functional shell with plugins
- 🔌 **MCP Ready** - Pre-configured for Model Context Protocol integrations
- 📦 **Custom Packages** - Install Alpine packages without rebuilding
- 👤 **User Mapping** - Configurable UID/GID for permission-free bind mounts
- 📁 **Single Volume** - All data in one directory for easy backup
- 🔐 **Secure** - Optional authentication for web terminal
- 🚀 **Auto-Setup** - Interactive wizard builds your CLAUDE.md on first run

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
# Complete the setup wizard, then type 'cc' to start!
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
├── docker-compose.yml      # Volume mount configuration
├── Makefile                # Management commands
├── .env.example            # Host configuration template
├── scripts/                # Default scripts (copied to data/ on first run)
│   ├── entrypoint.sh       # Container bootstrap
│   ├── shell-wrapper.sh    # First-run wizard
│   └── .zshrc              # Shell configuration
│
# Data directory (default: /docker/appdata/claudepantheon)
$CLAUDE_DATA_PATH/          # ALL PERSISTENT DATA (auto-created)
├── workspace/              # Your projects
├── claude/                 # Session history
├── mcp/                    # MCP configuration
│   └── mcp.json            # MCP server configuration
├── ssh/                    # SSH keys (auto 700/600 permissions)
├── logs/                   # Container logs (optional)
├── zsh-history/            # Shell history
├── npm-cache/              # npm cache
├── python-venvs/           # Python virtual environments
├── scripts/                # Runtime scripts (all customizable!)
│   ├── entrypoint.sh       # Container bootstrap
│   ├── shell-wrapper.sh    # First-run wizard
│   └── .zshrc              # Shell configuration
├── gitconfig               # Git configuration
├── custom-packages.txt     # Alpine packages to install
└── .env                    # Container environment
```

**Note:** All scripts in `$CLAUDE_DATA_PATH/scripts/` are copied from defaults on first run. You can customize `entrypoint.sh`, `shell-wrapper.sh`, and `.zshrc` without rebuilding the image.

### Data Path Configuration

Set `CLAUDE_DATA_PATH` in `docker/.env` to customize where data is stored:

```bash
# Default location
CLAUDE_DATA_PATH=/docker/appdata/claudepantheon

# Or use a relative path
CLAUDE_DATA_PATH=./data

# Or any absolute path
CLAUDE_DATA_PATH=/home/user/claudepantheon-data
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
make health   # Check ttyd web terminal health
make version  # Show Claude Code version
make tree     # Show data directory structure

# Maintenance
make backup   # Backup entire data directory
make update   # Update Claude Code to latest
make clean    # Remove container and images (keeps data)
make purge    # Remove everything including data
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
  - /home/randolph:/mounts/randolph
  - /media/TheBigDHF:/mounts/TheBigDHF
  - /var/www:/mounts/www:ro  # read-only
```

Inside the container, access mounted directories at `/mounts/`:
```bash
ls /mounts/randolph/projects
cd /mounts/TheBigDHF/code
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

1. **Set TTYD_CREDENTIAL** in `docker/.env` - Prevents unauthorized access
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

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Browser                              │
│                  http://localhost:7681                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                     ttyd                                     │
│              (Web Terminal Server)                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   oh-my-zsh                                  │
│         (with custom aliases: cc, cc-new, etc.)              │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 Claude Code                                  │
│    --continue flag ensures session persistence               │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                  MCP Servers                                 │
│    (GitHub, Home Assistant, Postgres, etc.)                  │
└─────────────────────────────────────────────────────────────┘
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
<em>"We implement. Not just advise."</em> - Project Hospitality
</p>
