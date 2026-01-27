# ╔═══════════════════════════════════════════════════════════╗
# ║                    ClaudePantheon                         ║
# ║              Makefile for Docker Management               ║
# ╚═══════════════════════════════════════════════════════════╝
#
# Convenience commands for managing the ClaudePantheon container.
# Run from the docker/ directory.
#
# USAGE:
#   make [target]
#   make help        # Show all available targets
#
# QUICK START:
#   make build       # Build the image
#   make up          # Start the container
#   make shell       # Open a shell inside
#
# MAKEFILE SYNTAX NOTES:
#   - Lines starting with @ suppress command echo
#   - $$ escapes $ for shell variables (Makefile uses $ for its own vars)
#   - Indentation MUST be tabs, not spaces
#   - .PHONY declares targets that aren't files

# ─────────────────────────────────────────────────────────────
# LOAD CONFIGURATION FROM .env
# ─────────────────────────────────────────────────────────────
# Include .env if it exists (- prefix ignores errors if missing)
-include .env

# Default data path (used by status, tree, backup, purge targets)
# Override by setting CLAUDE_DATA_PATH in .env
CLAUDE_DATA_PATH ?= ./data

.PHONY: help build up down logs shell restart clean status backup update purge rebuild dev health version tree

# ─────────────────────────────────────────────────────────────
# DEFAULT TARGET (runs when you just type 'make')
# ─────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "🏛️  ClaudePantheon"
	@echo "═══════════════════════════════════════"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Container Lifecycle:"
	@echo "  build      Build the Docker image"
	@echo "  up         Start container (detached)"
	@echo "  down       Stop container"
	@echo "  restart    Restart container"
	@echo "  rebuild    Stop, rebuild, and start"
	@echo ""
	@echo "Access & Development:"
	@echo "  shell      Open zsh shell in container"
	@echo "  logs       Follow container logs"
	@echo "  dev        Run in foreground (with logs)"
	@echo ""
	@echo "Status & Health:"
	@echo "  status     Show container status and resources"
	@echo "  health     Check if web interface is responding"
	@echo "  version    Show Claude Code version"
	@echo "  tree       Show data directory structure"
	@echo ""
	@echo "Maintenance:"
	@echo "  backup     Backup data directory to tarball"
	@echo "  update     Update Claude Code to latest"
	@echo "  clean      Remove container and images (keeps data)"
	@echo "  purge      Remove EVERYTHING including data"
	@echo ""
	@echo "Quick start:"
	@echo "  1. make build"
	@echo "  2. make up"
	@echo "  3. Open http://localhost:7681"
	@echo ""
	@echo "Services (single port architecture):"
	@echo "  /           Landing page"
	@echo "  /terminal/  Claude Code terminal"
	@echo "  /files/     File browser"
	@echo "  /webdav/    WebDAV (if enabled)"
	@echo ""

# ─────────────────────────────────────────────────────────────
# CONTAINER LIFECYCLE
# ─────────────────────────────────────────────────────────────

# Build the Docker image from Dockerfile
# Rebuilds only layers that changed (Docker caching)
build:
	@echo "🏗️  Building ClaudePantheon..."
	docker compose build

# Start container in detached mode (background)
# Creates data directory structure on first run
up:
	@echo "🚀 Starting ClaudePantheon..."
	docker compose up -d
	@echo ""
	@echo "🏛️  ClaudePantheon is ready!"
	@echo "   Landing page: http://localhost:7681"
	@echo "   Terminal:     http://localhost:7681/terminal/"
	@echo "   Files:        http://localhost:7681/files/"
	@echo "   Data dir:     $(CLAUDE_DATA_PATH)"
	@echo ""
	@echo "   Use 'make logs' to view output"

# Stop the container (preserves data)
down:
	@echo "⏹️  Stopping ClaudePantheon..."
	docker compose down

# Restart without rebuilding
restart:
	@echo "🔄 Restarting ClaudePantheon..."
	docker compose restart
	@echo "✅ ClaudePantheon restarted!"

# Full rebuild: stop → build → start
rebuild: down build up
	@echo "✅ Rebuild complete!"

# ─────────────────────────────────────────────────────────────
# ACCESS & DEVELOPMENT
# ─────────────────────────────────────────────────────────────

# Open interactive zsh shell in running container
# Requires container to be running
shell:
	@if ! docker compose ps --format '{{.State}}' claudepantheon 2>/dev/null | grep -q "running"; then \
		echo "❌ Container is not running. Run 'make up' first."; \
		exit 1; \
	fi
	docker compose exec claudepantheon /bin/zsh

# Follow container logs (Ctrl+C to exit)
logs:
	docker compose logs -f

# Run in foreground with logs (useful for debugging)
# Ctrl+C stops the container
dev:
	docker compose up

# ─────────────────────────────────────────────────────────────
# STATUS & HEALTH
# ─────────────────────────────────────────────────────────────

# Show container status, data directory, and resource usage
status:
	@echo ""
	@echo "🏛️  ClaudePantheon Status:"
	@docker compose ps
	@echo ""
	@echo "📁 Data Directory ($(CLAUDE_DATA_PATH)):"
	@ls -la "$(CLAUDE_DATA_PATH)" 2>/dev/null || echo "   (not yet initialized - run 'make up' first)"
	@echo ""
	@echo "📊 Resources:"
	@docker stats --no-stream claudepantheon 2>/dev/null || echo "   Container not running"

# Quick health check - tests if nginx reverse proxy responds
health:
	@wget -q --spider http://localhost:7681/ && echo "✅ Web interface is responding" || echo "❌ Web interface not responding"

# Show installed Claude Code version
version:
	@if ! docker compose ps --format '{{.State}}' claudepantheon 2>/dev/null | grep -q "running"; then \
		echo "❌ Container is not running. Run 'make up' first."; \
		exit 1; \
	fi
	@docker compose exec claudepantheon claude --version

# Show data directory structure (requires 'tree' command, falls back to ls)
tree:
	@echo "📁 Data Directory Structure ($(CLAUDE_DATA_PATH)):"
	@tree "$(CLAUDE_DATA_PATH)" 2>/dev/null || ls -laR "$(CLAUDE_DATA_PATH)"

# ─────────────────────────────────────────────────────────────
# MAINTENANCE
# ─────────────────────────────────────────────────────────────

# Create timestamped backup of data directory
# Warns if container is running (potential inconsistency)
backup:
	@echo "💾 Creating backup of $(CLAUDE_DATA_PATH)..."
	@if docker compose ps --format '{{.State}}' claudepantheon 2>/dev/null | grep -q "running"; then \
		echo "⚠️  Warning: Container is running. Consider 'make down' first for consistent backup."; \
		read -p "Continue anyway? (y/N): " confirm; \
		[ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || exit 0; \
	fi
	@mkdir -p backups
	@BACKUP_NAME="backup_$$(date +%Y%m%d_%H%M%S).tar.gz"; \
	tar -czf "backups/$$BACKUP_NAME" "$(CLAUDE_DATA_PATH)"; \
	echo "✅ Backup created: backups/$$BACKUP_NAME"

# Update Claude Code to latest version inside container
# Native installer auto-updates, but this forces an immediate update
update:
	@if ! docker compose ps --format '{{.State}}' claudepantheon 2>/dev/null | grep -q "running"; then \
		echo "❌ Container is not running. Run 'make up' first."; \
		exit 1; \
	fi
	@echo "⬆️  Updating Claude Code..."
	docker compose exec -u claude claudepantheon sh -c 'curl -fsSL https://claude.ai/install.sh | bash'
	@echo "✅ Claude Code updated!"

# Remove container and locally-built images (preserves data directory)
clean:
	@echo "🧹 Cleaning up containers and images..."
	docker compose down --rmi local
	@echo "✅ Cleanup complete! Data preserved in $(CLAUDE_DATA_PATH)"

# DANGEROUS: Remove everything including all data
# Requires typing 'DELETE' to confirm
purge:
	@echo ""
	@echo "⚠️  WARNING: This will permanently delete:"
	@echo "   - All Claude Code session history"
	@echo "   - All workspace files"
	@echo "   - All SSH keys and configurations"
	@echo "   - Docker images"
	@echo "   - Data path: $(CLAUDE_DATA_PATH)"
	@echo ""
	@read -p "Type 'DELETE' to confirm permanent deletion: " confirm; \
	if [ "$$confirm" = "DELETE" ]; then \
		docker compose down --rmi local; \
		rm -rf "$(CLAUDE_DATA_PATH)"/*; \
		echo "✅ Full purge complete!"; \
	else \
		echo "❌ Cancelled."; \
	fi
