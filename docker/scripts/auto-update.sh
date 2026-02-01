#!/bin/bash
# ╔═══════════════════════════════════════════════════════════╗
# ║           ClaudePantheon Auto-Update System               ║
# ╚═══════════════════════════════════════════════════════════╝
#
# Automatic update system for ClaudePantheon with version checking
# and intelligent update scheduling
#
# Features:
# - GitHub releases API version checking
# - Smart update scheduling (daily/on-demand)
# - Automatic backup before updates
# - Rollback capability
# - Update history tracking

set -euo pipefail

# Configuration
DATA_DIR="${DATA_DIR:-/app/data}"
UPDATE_CONFIG="${DATA_DIR}/.update-config"
UPDATE_HISTORY="${DATA_DIR}/.update-history"
GITHUB_REPO="RandomSynergy17/ClaudePantheon"
CURRENT_VERSION_FILE="${DATA_DIR}/.version"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[Update]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[Update]${NC} $*"
}

error() {
    echo -e "${RED}[Update]${NC} $*"
}

# Initialize update configuration
init_update_config() {
    if [ ! -f "$UPDATE_CONFIG" ]; then
        cat > "$UPDATE_CONFIG" << 'EOF'
# ClaudePantheon Auto-Update Configuration
#
# AUTO_UPDATE_ENABLED: Enable automatic updates (true/false)
# UPDATE_CHANNEL: stable, beta, or latest
# UPDATE_SCHEDULE: startup, daily, weekly, manual
# BACKUP_BEFORE_UPDATE: Create backup before updating (true/false)
# UPDATE_COMPONENTS: Comma-separated list (container,claude-cli,scripts,all)

AUTO_UPDATE_ENABLED=false
UPDATE_CHANNEL=stable
UPDATE_SCHEDULE=manual
BACKUP_BEFORE_UPDATE=true
UPDATE_COMPONENTS=all
LAST_UPDATE_CHECK=0
SKIP_VERSION=""
EOF
        log "Created update configuration at ${UPDATE_CONFIG}"
    fi
}

# Load configuration
load_config() {
    if [ -f "$UPDATE_CONFIG" ]; then
        # shellcheck source=/dev/null
        source "$UPDATE_CONFIG"
    fi
}

# Get current version
get_current_version() {
    if [ -f "$CURRENT_VERSION_FILE" ]; then
        cat "$CURRENT_VERSION_FILE"
    else
        # Try to get from docker image label
        docker inspect claudepantheon 2>/dev/null | \
            jq -r '.[0].Config.Labels.version // "unknown"' || echo "unknown"
    fi
}

# Get latest release from GitHub
get_latest_release() {
    local channel="${1:-stable}"

    case "$channel" in
        stable)
            # Get latest non-prerelease
            curl -sf "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | \
                jq -r '.tag_name // empty'
            ;;
        beta)
            # Get latest prerelease
            curl -sf "https://api.github.com/repos/${GITHUB_REPO}/releases" | \
                jq -r '[.[] | select(.prerelease == true)] | first | .tag_name // empty'
            ;;
        latest)
            # Get absolute latest (including drafts)
            curl -sf "https://api.github.com/repos/${GITHUB_REPO}/releases" | \
                jq -r 'first | .tag_name // empty'
            ;;
    esac
}

# Compare versions
version_gt() {
    # Returns 0 (true) if $1 > $2
    local ver1="$1"
    local ver2="$2"

    # Remove 'v' prefix if present
    ver1="${ver1#v}"
    ver2="${ver2#v}"

    # Use sort -V for version comparison
    [ "$(printf '%s\n%s' "$ver1" "$ver2" | sort -V | tail -n1)" = "$ver1" ] && \
    [ "$ver1" != "$ver2" ]
}

# Check if update should run based on schedule
should_check_update() {
    local schedule="${UPDATE_SCHEDULE:-manual}"
    local last_check="${LAST_UPDATE_CHECK:-0}"
    local now=$(date +%s)

    case "$schedule" in
        startup)
            return 0  # Always check on startup
            ;;
        daily)
            # Check if 24 hours have passed
            [ $((now - last_check)) -gt 86400 ]
            ;;
        weekly)
            # Check if 7 days have passed
            [ $((now - last_check)) -gt 604800 ]
            ;;
        manual)
            # Only when explicitly called
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# Update last check timestamp
update_check_timestamp() {
    sed -i "s/^LAST_UPDATE_CHECK=.*/LAST_UPDATE_CHECK=$(date +%s)/" "$UPDATE_CONFIG"
}

# Create backup
create_backup() {
    local backup_dir="${DATA_DIR}/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/claudepantheon_${timestamp}.tar.gz"

    mkdir -p "$backup_dir"

    log "Creating backup: ${backup_file}"

    # Backup critical directories
    tar -czf "$backup_file" \
        -C "$DATA_DIR" \
        --exclude='backups' \
        --exclude='logs' \
        --exclude='npm-cache' \
        workspace claude mcp ssh gitconfig custom-packages.txt 2>/dev/null || true

    if [ -f "$backup_file" ]; then
        log "Backup created: $(du -h "$backup_file" | cut -f1)"
        echo "$backup_file"
    else
        error "Backup creation failed"
        return 1
    fi
}

# Perform update
perform_update() {
    local new_version="$1"
    local components="${UPDATE_COMPONENTS:-all}"

    log "Starting update to version ${new_version}"

    # Create backup if enabled
    if [ "${BACKUP_BEFORE_UPDATE:-true}" = "true" ]; then
        local backup_file
        backup_file=$(create_backup) || {
            error "Backup failed, aborting update"
            return 1
        }
    fi

    # Update based on components
    case "$components" in
        container|all)
            update_container "$new_version"
            ;;
    esac

    case "$components" in
        claude-cli|all)
            update_claude_cli
            ;;
    esac

    case "$components" in
        scripts|all)
            update_scripts "$new_version"
            ;;
    esac

    # Record update in history
    echo "$(date +%Y-%m-%d\ %H:%M:%S) - Updated to ${new_version}" >> "$UPDATE_HISTORY"
    echo "$new_version" > "$CURRENT_VERSION_FILE"

    log "Update to ${new_version} completed successfully"
}

# Update Docker container
update_container() {
    local version="$1"

    log "Updating Docker container to ${version}"

    # Pull new image
    if docker pull "ghcr.io/randomsynergy17/claudepantheon:${version}" || \
       docker pull "ghcr.io/randomsynergy17/claudepantheon:latest"; then
        log "New container image pulled"
        warn "Restart container to apply: docker compose restart"
    else
        error "Failed to pull new container image"
        return 1
    fi
}

# Update Claude CLI
update_claude_cli() {
    log "Updating Claude CLI"

    if command -v claude &>/dev/null; then
        # Run Claude update command
        claude update 2>/dev/null || \
        npm update -g @anthropic-ai/claude-code 2>/dev/null || \
        warn "Claude CLI update not available"
    fi
}

# Update scripts from repository
update_scripts() {
    local version="$1"

    log "Updating scripts to ${version}"

    # Fetch latest scripts from GitHub
    local temp_dir=$(mktemp -d)

    if curl -sL "https://github.com/${GITHUB_REPO}/archive/refs/tags/${version}.tar.gz" | \
       tar -xz -C "$temp_dir" --strip-components=2 "*/docker/scripts" 2>/dev/null; then

        # Update scripts (preserve .keep files)
        if [ ! -f "${DATA_DIR}/scripts/.keep" ]; then
            cp -r "$temp_dir"/* "${DATA_DIR}/scripts/" 2>/dev/null || true
            log "Scripts updated"
        else
            warn "Scripts update skipped (.keep file present)"
        fi
    fi

    rm -rf "$temp_dir"
}

# Check for updates
check_updates() {
    local force="${1:-false}"

    load_config

    # Check if auto-update is enabled or forced
    if [ "$force" != "true" ] && [ "${AUTO_UPDATE_ENABLED:-false}" != "true" ]; then
        return 0
    fi

    # Check schedule
    if [ "$force" != "true" ] && ! should_check_update; then
        return 0
    fi

    log "Checking for updates..."

    local current_version
    current_version=$(get_current_version)

    local latest_version
    latest_version=$(get_latest_release "${UPDATE_CHANNEL:-stable}")

    update_check_timestamp

    if [ -z "$latest_version" ]; then
        warn "Could not fetch latest version from GitHub"
        return 1
    fi

    log "Current version: ${current_version}"
    log "Latest version: ${latest_version}"

    # Check if user explicitly skipped this version
    if [ "${SKIP_VERSION:-}" = "$latest_version" ]; then
        log "Update to ${latest_version} was skipped by user"
        return 0
    fi

    if version_gt "$latest_version" "$current_version"; then
        log "Update available: ${current_version} → ${latest_version}"

        # Prompt user
        if [ "$force" = "true" ] || [ -t 0 ]; then
            prompt_update "$current_version" "$latest_version"
        else
            log "Run 'cc-update' to install the update"
        fi
    else
        log "Already on latest version (${current_version})"
    fi
}

# Prompt user for update
prompt_update() {
    local current="$1"
    local latest="$2"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "  ${GREEN}Update Available:${NC} ${current} → ${latest}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    # Fetch release notes
    local release_notes
    release_notes=$(curl -sf "https://api.github.com/repos/${GITHUB_REPO}/releases/tags/${latest}" | \
                    jq -r '.body // "No release notes available"' | head -20)

    echo -e "${YELLOW}Release Notes:${NC}"
    echo "$release_notes"
    echo ""

    read -r -p "Install update now? [Y/n/s(kip)]: " response

    case "${response,,}" in
        s|skip)
            log "Skipping version ${latest}"
            sed -i "s/^SKIP_VERSION=.*/SKIP_VERSION=${latest}/" "$UPDATE_CONFIG"
            ;;
        n|no)
            log "Update postponed"
            ;;
        *)
            perform_update "$latest"
            ;;
    esac
}

# Configure auto-update
configure_auto_update() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Auto-Update Configuration                      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Enable/disable
    read -r -p "Enable automatic updates? [y/N]: " enable
    if [[ "${enable,,}" =~ ^(y|yes)$ ]]; then
        sed -i "s/^AUTO_UPDATE_ENABLED=.*/AUTO_UPDATE_ENABLED=true/" "$UPDATE_CONFIG"

        # Schedule
        echo ""
        echo "Update schedule:"
        echo "  1. On container startup"
        echo "  2. Daily (24 hours)"
        echo "  3. Weekly (7 days)"
        echo "  4. Manual only"
        read -r -p "Select [4]: " schedule_choice

        case "${schedule_choice:-4}" in
            1) sed -i "s/^UPDATE_SCHEDULE=.*/UPDATE_SCHEDULE=startup/" "$UPDATE_CONFIG" ;;
            2) sed -i "s/^UPDATE_SCHEDULE=.*/UPDATE_SCHEDULE=daily/" "$UPDATE_CONFIG" ;;
            3) sed -i "s/^UPDATE_SCHEDULE=.*/UPDATE_SCHEDULE=weekly/" "$UPDATE_CONFIG" ;;
            *) sed -i "s/^UPDATE_SCHEDULE=.*/UPDATE_SCHEDULE=manual/" "$UPDATE_CONFIG" ;;
        esac

        # Channel
        echo ""
        echo "Update channel:"
        echo "  1. Stable (recommended)"
        echo "  2. Beta (pre-releases)"
        echo "  3. Latest (all releases)"
        read -r -p "Select [1]: " channel_choice

        case "${channel_choice:-1}" in
            2) sed -i "s/^UPDATE_CHANNEL=.*/UPDATE_CHANNEL=beta/" "$UPDATE_CONFIG" ;;
            3) sed -i "s/^UPDATE_CHANNEL=.*/UPDATE_CHANNEL=latest/" "$UPDATE_CONFIG" ;;
            *) sed -i "s/^UPDATE_CHANNEL=.*/UPDATE_CHANNEL=stable/" "$UPDATE_CONFIG" ;;
        esac

        log "Auto-update enabled"
    else
        sed -i "s/^AUTO_UPDATE_ENABLED=.*/AUTO_UPDATE_ENABLED=false/" "$UPDATE_CONFIG"
        log "Auto-update disabled"
    fi

    echo ""
    log "Configuration saved to ${UPDATE_CONFIG}"
}

# Show update status
show_status() {
    load_config

    local current_version
    current_version=$(get_current_version)

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           ClaudePantheon Update Status                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Current Version:    ${GREEN}${current_version}${NC}"
    echo -e "  Auto-Update:        $([ "${AUTO_UPDATE_ENABLED:-false}" = "true" ] && echo -e "${GREEN}Enabled${NC}" || echo -e "${YELLOW}Disabled${NC}")"
    echo -e "  Update Channel:     ${UPDATE_CHANNEL:-stable}"
    echo -e "  Update Schedule:    ${UPDATE_SCHEDULE:-manual}"
    echo -e "  Backup Enabled:     ${BACKUP_BEFORE_UPDATE:-true}"
    echo ""

    if [ -f "$UPDATE_HISTORY" ]; then
        echo -e "${CYAN}Recent Updates:${NC}"
        tail -5 "$UPDATE_HISTORY" | sed 's/^/  /'
        echo ""
    fi
}

# Main command dispatcher
main() {
    init_update_config

    case "${1:-check}" in
        check)
            check_updates "${2:-false}"
            ;;
        force|now)
            check_updates true
            ;;
        configure|config|setup)
            configure_auto_update
            ;;
        status)
            show_status
            ;;
        enable)
            sed -i "s/^AUTO_UPDATE_ENABLED=.*/AUTO_UPDATE_ENABLED=true/" "$UPDATE_CONFIG"
            log "Auto-update enabled"
            ;;
        disable)
            sed -i "s/^AUTO_UPDATE_ENABLED=.*/AUTO_UPDATE_ENABLED=false/" "$UPDATE_CONFIG"
            log "Auto-update disabled"
            ;;
        history)
            [ -f "$UPDATE_HISTORY" ] && cat "$UPDATE_HISTORY" || log "No update history"
            ;;
        help|--help|-h)
            cat << 'EOF'
ClaudePantheon Auto-Update System

Usage:
  auto-update.sh [command]

Commands:
  check          Check for updates (respects schedule)
  force          Force update check now
  configure      Configure auto-update settings
  status         Show update status and configuration
  enable         Enable auto-updates
  disable        Disable auto-updates
  history        Show update history
  help           Show this help

Examples:
  auto-update.sh check       # Check based on schedule
  auto-update.sh force       # Check immediately
  auto-update.sh configure   # Interactive configuration
  auto-update.sh status      # Show current status

Configuration file: /app/data/.update-config
EOF
            ;;
        *)
            error "Unknown command: $1"
            echo "Run 'auto-update.sh help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
