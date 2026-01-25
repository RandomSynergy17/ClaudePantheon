#!/bin/sh
# ╔═══════════════════════════════════════════════════════════╗
# ║                    ClaudePantheon                         ║
# ║              Entrypoint Script (Alpine)                   ║
# ╚═══════════════════════════════════════════════════════════╝
# Handles data directory setup, user mapping, packages, and services
# This script can be customized - edit $DATA_DIR/scripts/entrypoint.sh

set -e

# Configuration
USERNAME="claude"
HOME_DIR="/home/${USERNAME}"
DATA_DIR="/app/data"
DEFAULTS_DIR="/opt/claudepantheon/defaults"
CUSTOM_ENTRYPOINT="${DATA_DIR}/scripts/entrypoint.sh"

# Entrypoint redirect loop detection
if [ -z "${CLAUDEPANTHEON_DEPTH:-}" ]; then
    export CLAUDEPANTHEON_DEPTH=0
fi
if [ "${CLAUDEPANTHEON_DEPTH}" -gt 2 ]; then
    echo "[ERROR] Entrypoint redirect loop detected. Check ${CUSTOM_ENTRYPOINT}"
    exit 1
fi

# Check if custom entrypoint exists and we're running from defaults
SCRIPT_PATH="$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")"
if [ -f "${CUSTOM_ENTRYPOINT}" ] && [ "${SCRIPT_PATH}" = "${DEFAULTS_DIR}/entrypoint.sh" ]; then
    export CLAUDEPANTHEON_DEPTH=$((CLAUDEPANTHEON_DEPTH + 1))
    exec "${CUSTOM_ENTRYPOINT}" "$@"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# User mapping defaults
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# Validate PUID/PGID are integers
case "${PUID}" in
    ''|*[!0-9]*) echo "[ERROR] PUID must be a valid integer, got: ${PUID}"; exit 1 ;;
esac
case "${PGID}" in
    ''|*[!0-9]*) echo "[ERROR] PGID must be a valid integer, got: ${PGID}"; exit 1 ;;
esac

# Logging configuration
LOG_TO_FILE="${LOG_TO_FILE:-false}"
LOG_FILE="${DATA_DIR}/logs/claudepantheon.log"

# Logging functions
log() {
    MSG="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    printf "${GREEN}${MSG}${NC}\n"
    if [ "${LOG_TO_FILE}" = "true" ] && [ -d "${DATA_DIR}/logs" ]; then
        echo "${MSG}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

warn() {
    MSG="[WARNING] $1"
    printf "${YELLOW}${MSG}${NC}\n"
    if [ "${LOG_TO_FILE}" = "true" ] && [ -d "${DATA_DIR}/logs" ]; then
        echo "${MSG}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

error() {
    MSG="[ERROR] $1"
    printf "${RED}${MSG}${NC}\n"
    if [ "${LOG_TO_FILE}" = "true" ] && [ -d "${DATA_DIR}/logs" ]; then
        echo "${MSG}" >> "${LOG_FILE}" 2>/dev/null || true
    fi
}

# Validate data directory is writable
validate_data_directory() {
    if [ ! -d "${DATA_DIR}" ]; then
        error "Data directory ${DATA_DIR} does not exist"
        error "Check volume mount in docker-compose.yml"
        exit 1
    fi

    # Test write access
    if ! touch "${DATA_DIR}/.write_test" 2>/dev/null; then
        error "Data directory ${DATA_DIR} is not writable"
        error "Check host directory permissions (run: sudo chown -R \$(id -u):\$(id -g) <data_path>)"
        exit 1
    fi
    rm -f "${DATA_DIR}/.write_test"
}

# Check available disk space
check_disk_space() {
    # Require at least 100MB free
    REQUIRED_KB=102400
    AVAILABLE_KB=$(df -k "${DATA_DIR}" 2>/dev/null | tail -1 | awk '{print $4}')

    if [ -n "${AVAILABLE_KB}" ] && [ "${AVAILABLE_KB}" -lt "${REQUIRED_KB}" ]; then
        error "Insufficient disk space. Required: 100MB, Available: $((AVAILABLE_KB/1024))MB"
        exit 1
    fi
}

# Initialize logging directory early
init_logging() {
    if [ "${LOG_TO_FILE}" = "true" ]; then
        mkdir -p "${DATA_DIR}/logs" 2>/dev/null || {
            warn "Cannot create log directory - logging to console only"
            LOG_TO_FILE="false"
            return
        }

        # Test write access and do basic rotation (keep last 10MB)
        if [ -f "${LOG_FILE}" ]; then
            FILE_SIZE=$(stat -c%s "${LOG_FILE}" 2>/dev/null || stat -f%z "${LOG_FILE}" 2>/dev/null || echo 0)
            if [ "${FILE_SIZE}" -gt 10485760 ]; then
                mv "${LOG_FILE}" "${LOG_FILE}.old" 2>/dev/null || true
            fi
        fi

        if ! touch "${LOG_FILE}" 2>/dev/null; then
            warn "Cannot write to log file - logging to console only"
            LOG_TO_FILE="false"
        fi
    fi
}

# Adjust user/group IDs to match host
setup_user_mapping() {
    CURRENT_UID=$(id -u ${USERNAME})
    CURRENT_GID=$(id -g ${USERNAME})

    log "User mapping: PUID=${PUID}, PGID=${PGID} (current: ${CURRENT_UID}:${CURRENT_GID})"

    # Adjust GID if different
    if [ "${PGID}" != "${CURRENT_GID}" ]; then
        log "Adjusting group ID from ${CURRENT_GID} to ${PGID}..."
        if getent group "${PGID}" > /dev/null 2>&1; then
            EXISTING_GROUP=$(getent group "${PGID}" | cut -d: -f1)
            if [ "${EXISTING_GROUP}" != "${USERNAME}" ]; then
                # Find an unused GID for temporary reassignment
                TEMP_GID=50000
                while getent group "${TEMP_GID}" > /dev/null 2>&1; do
                    TEMP_GID=$((TEMP_GID + 1))
                done
                groupmod -g "${TEMP_GID}" "${EXISTING_GROUP}" 2>/dev/null || warn "Could not move group ${EXISTING_GROUP}"
            fi
        fi
        groupmod -g "${PGID}" "${USERNAME}" || { error "Failed to set group ID"; exit 1; }
    fi

    # Adjust UID if different
    if [ "${PUID}" != "${CURRENT_UID}" ]; then
        log "Adjusting user ID from ${CURRENT_UID} to ${PUID}..."
        if getent passwd "${PUID}" > /dev/null 2>&1; then
            EXISTING_USER=$(getent passwd "${PUID}" | cut -d: -f1)
            if [ "${EXISTING_USER}" != "${USERNAME}" ]; then
                # Find an unused UID for temporary reassignment
                TEMP_UID=50000
                while getent passwd "${TEMP_UID}" > /dev/null 2>&1; do
                    TEMP_UID=$((TEMP_UID + 1))
                done
                usermod -u "${TEMP_UID}" "${EXISTING_USER}" 2>/dev/null || warn "Could not move user ${EXISTING_USER}"
            fi
        fi
        usermod -u "${PUID}" "${USERNAME}" || { error "Failed to set user ID"; exit 1; }
    fi

    # Fix home directory ownership
    chown -R "${PUID}:${PGID}" "${HOME_DIR}" 2>/dev/null || true

    log "User mapping complete: ${USERNAME} (${PUID}:${PGID})"
}

# Copy default scripts to data directory (only if not exists)
init_scripts() {
    log "Checking scripts in data directory..."

    mkdir -p "${DATA_DIR}/scripts"

    # Copy scripts from defaults if they don't exist (preserves user customizations)
    if [ ! -f "${DATA_DIR}/scripts/entrypoint.sh" ]; then
        cp "${DEFAULTS_DIR}/entrypoint.sh" "${DATA_DIR}/scripts/"
        chmod +x "${DATA_DIR}/scripts/entrypoint.sh"
        log "Installed default entrypoint.sh"
    fi

    if [ ! -f "${DATA_DIR}/scripts/shell-wrapper.sh" ]; then
        cp "${DEFAULTS_DIR}/shell-wrapper.sh" "${DATA_DIR}/scripts/"
        chmod +x "${DATA_DIR}/scripts/shell-wrapper.sh"
        log "Installed default shell-wrapper.sh"
    fi

    if [ ! -f "${DATA_DIR}/scripts/.zshrc" ]; then
        cp "${DEFAULTS_DIR}/.zshrc" "${DATA_DIR}/scripts/"
        log "Installed default .zshrc"
    fi

    chown -R "${PUID}:${PGID}" "${DATA_DIR}/scripts"
}

# Initialize data directory structure on first run
init_data_directory() {
    log "Initializing data directory structure..."

    # Create flat directory structure
    mkdir -p "${DATA_DIR}/workspace"
    mkdir -p "${DATA_DIR}/claude"
    mkdir -p "${DATA_DIR}/mcp"
    mkdir -p "${DATA_DIR}/ssh"
    mkdir -p "${DATA_DIR}/logs"
    mkdir -p "${DATA_DIR}/zsh-history"
    touch "${DATA_DIR}/zsh-history/.zsh_history"
    chmod 600 "${DATA_DIR}/zsh-history/.zsh_history"
    mkdir -p "${DATA_DIR}/npm-cache"
    mkdir -p "${DATA_DIR}/python-venvs"
    mkdir -p "${DATA_DIR}/scripts"

    # Initialize scripts from defaults
    init_scripts

    # Create default custom-packages.txt if not exists
    if [ ! -f "${DATA_DIR}/custom-packages.txt" ]; then
        cat > "${DATA_DIR}/custom-packages.txt" << 'EOF'
# ╔═══════════════════════════════════════════════════════════╗
# ║              ClaudePantheon Custom Packages               ║
# ╚═══════════════════════════════════════════════════════════╝
#
# Add Alpine packages here (one per line).
# Only alphanumeric characters, dash, underscore, and dot allowed.
# Installed on every container start - no rebuild needed.
#
# Examples:
# docker-cli
# postgresql-client
# go
# rust
#
# Find packages: https://pkgs.alpinelinux.org/packages

EOF
        log "Created custom-packages.txt template"
    fi

    # Create default mcp.json if not exists
    if [ ! -f "${DATA_DIR}/mcp/mcp.json" ]; then
        cat > "${DATA_DIR}/mcp/mcp.json" << 'EOF'
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/app/data/workspace"]
    }
  }
}
EOF
        log "Created default mcp.json"
    fi

    # Create default gitconfig if not exists
    if [ ! -f "${DATA_DIR}/gitconfig" ]; then
        cat > "${DATA_DIR}/gitconfig" << 'EOF'
[user]
    name = Claude User
    email = claude@example.com
[init]
    defaultBranch = main
[core]
    editor = vim
[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
EOF
        log "Created default gitconfig"
    fi

    # Create default settings file if not exists (runtime settings)
    if [ ! -f "${DATA_DIR}/claude/.settings" ]; then
        cat > "${DATA_DIR}/claude/.settings" << 'EOF'
# ClaudePantheon Runtime Settings
# These can be toggled at runtime with cc-bypass, cc-settings
BYPASS_PERMISSIONS=false
EOF
        log "Created default settings file"
    fi

    # Set ownership
    chown -R "${PUID}:${PGID}" "${DATA_DIR}"

    log "Data directory initialized"
}

# Create symlinks from home directory to data directory
setup_symlinks() {
    log "Setting up symlinks..."

    # Remove existing directories/files and create symlinks
    rm -rf "${HOME_DIR}/workspace" && ln -sf "${DATA_DIR}/workspace" "${HOME_DIR}/workspace"
    rm -rf "${HOME_DIR}/.claude" && ln -sf "${DATA_DIR}/claude" "${HOME_DIR}/.claude"
    rm -rf "${HOME_DIR}/.config/claude-code" && mkdir -p "${HOME_DIR}/.config" && ln -sf "${DATA_DIR}/mcp" "${HOME_DIR}/.config/claude-code"
    rm -rf "${HOME_DIR}/.ssh" && ln -sf "${DATA_DIR}/ssh" "${HOME_DIR}/.ssh"
    rm -rf "${HOME_DIR}/.npm" && ln -sf "${DATA_DIR}/npm-cache" "${HOME_DIR}/.npm"
    rm -rf "${HOME_DIR}/.venvs" && ln -sf "${DATA_DIR}/python-venvs" "${HOME_DIR}/.venvs"

    # Zsh history
    rm -rf "${HOME_DIR}/.zsh_history_dir" && ln -sf "${DATA_DIR}/zsh-history" "${HOME_DIR}/.zsh_history_dir"
    rm -f "${HOME_DIR}/.zsh_history" && ln -sf "${DATA_DIR}/zsh-history/.zsh_history" "${HOME_DIR}/.zsh_history"

    # Zshrc from data/scripts (user can customize)
    rm -f "${HOME_DIR}/.zshrc" && ln -sf "${DATA_DIR}/scripts/.zshrc" "${HOME_DIR}/.zshrc"

    # Git config (copy, not symlink, so user can have local overrides)
    if [ -f "${DATA_DIR}/gitconfig" ]; then
        cp "${DATA_DIR}/gitconfig" "${HOME_DIR}/.gitconfig"
        chown "${PUID}:${PGID}" "${HOME_DIR}/.gitconfig"
    fi

    log "Symlinks configured"
}

# Fix SSH and file permissions after ownership is set
fix_permissions() {
    log "Fixing permissions..."

    # SSH permissions (directories 700, files 600, public keys 644)
    if [ -d "${DATA_DIR}/ssh" ]; then
        chmod 700 "${DATA_DIR}/ssh" 2>/dev/null || true
        find "${DATA_DIR}/ssh" -maxdepth 2 -type f ! -type l -exec chmod 600 {} \; 2>/dev/null || true
        find "${DATA_DIR}/ssh" -maxdepth 2 -type f -name "*.pub" ! -type l -exec chmod 644 {} \; 2>/dev/null || true
        find "${DATA_DIR}/ssh" -maxdepth 2 -type d ! -type l -exec chmod 700 {} \; 2>/dev/null || true
    fi

    # Mark workspace as safe git directory (only add if not already present)
    su -s /bin/sh ${USERNAME} -c "
        if ! git config --global --get-all safe.directory 2>/dev/null | grep -qxF '${DATA_DIR}/workspace'; then
            git config --global --add safe.directory ${DATA_DIR}/workspace
        fi
    " 2>/dev/null || warn "Failed to configure git safe.directory"
}

# Install custom packages with validation
install_custom_packages() {
    if [ -f "${DATA_DIR}/custom-packages.txt" ]; then
        log "Checking for custom packages..."

        PACKAGES=""
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                \#*|"") continue ;;
            esac

            # Validate package name (alphanumeric, dash, underscore, dot only)
            if ! echo "$line" | grep -qE '^[a-zA-Z0-9._-]+$'; then
                error "Invalid package name: $line"
                error "Only alphanumeric characters, dash, underscore, and dot allowed"
                exit 1
            fi

            PACKAGES="${PACKAGES} ${line}"
        done < "${DATA_DIR}/custom-packages.txt"

        if [ -n "${PACKAGES}" ]; then
            log "Installing packages:${PACKAGES}"
            apk add --no-cache ${PACKAGES} || warn "Some packages failed to install"
        fi
    fi
}

# Verify Claude Code installation
verify_claude() {
    if ! command -v claude > /dev/null 2>&1; then
        error "Claude Code not found. Installing..."
        if ! su -s /bin/sh ${USERNAME} -c "npm install -g @anthropic-ai/claude-code"; then
            error "Failed to install Claude Code. Container cannot start."
            exit 1
        fi
        log "Claude Code installed successfully"
    fi
    VERSION=$(su -s /bin/sh ${USERNAME} -c "claude --version 2>/dev/null" || echo 'unknown')
    log "Claude Code version: ${VERSION}"
}

# Setup SSH server (optional)
setup_ssh() {
    if [ -n "${ENABLE_SSH:-}" ]; then
        # Persist SSH host keys across container rebuilds
        SSH_HOST_KEYS_DIR="${DATA_DIR}/ssh-host-keys"
        mkdir -p "${SSH_HOST_KEYS_DIR}"

        # Copy existing host keys to persistent storage if not already there
        for key_type in rsa ecdsa ed25519; do
            KEY_FILE="/etc/ssh/ssh_host_${key_type}_key"
            PERSISTENT_KEY="${SSH_HOST_KEYS_DIR}/ssh_host_${key_type}_key"
            if [ -f "${PERSISTENT_KEY}" ]; then
                # Use persistent keys
                cp "${PERSISTENT_KEY}" "${KEY_FILE}"
                cp "${PERSISTENT_KEY}.pub" "${KEY_FILE}.pub"
                chmod 600 "${KEY_FILE}"
                chmod 644 "${KEY_FILE}.pub"
            elif [ -f "${KEY_FILE}" ]; then
                # Save generated keys for persistence
                cp "${KEY_FILE}" "${PERSISTENT_KEY}"
                cp "${KEY_FILE}.pub" "${PERSISTENT_KEY}.pub"
            fi
        done

        chown -R "${PUID}:${PGID}" "${SSH_HOST_KEYS_DIR}"
        log "Starting SSH server..."
        /usr/sbin/sshd || warn "Failed to start SSH server"
    fi
}

# Start ttyd - separate exec paths to avoid command injection
start_ttyd() {
    log "Starting ttyd on port ${TTYD_PORT:-7681}..."

    if [ -n "${TTYD_CREDENTIAL:-}" ]; then
        # Validate credential format (must contain colon)
        case "${TTYD_CREDENTIAL}" in
            *:*)
                log "ttyd authentication enabled"
                # Use separate exec with -c flag to avoid shell injection
                exec ttyd -p "${TTYD_PORT:-7681}" \
                    -u "${PUID}" -g "${PGID}" \
                    -t "fontSize=14" \
                    -t "fontFamily=JetBrains Mono, Menlo, Monaco, monospace" \
                    -t "theme={\"background\":\"#1e1e2e\",\"foreground\":\"#cdd6f4\"}" \
                    -c "${TTYD_CREDENTIAL}" \
                    "${DATA_DIR}/scripts/shell-wrapper.sh"
                ;;
            *)
                error "TTYD_CREDENTIAL must be in format 'username:password'"
                exit 1
                ;;
        esac
    else
        warn "ttyd running without authentication - set TTYD_CREDENTIAL in .env for security"
        # Exec without -c flag
        exec ttyd -p "${TTYD_PORT:-7681}" \
            -u "${PUID}" -g "${PGID}" \
            -t "fontSize=14" \
            -t "fontFamily=JetBrains Mono, Menlo, Monaco, monospace" \
            -t "theme={\"background\":\"#1e1e2e\",\"foreground\":\"#cdd6f4\"}" \
            "${DATA_DIR}/scripts/shell-wrapper.sh"
    fi
}

# Main execution
main() {
    printf "\n"
    printf "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║                    ClaudePantheon                         ║${NC}\n"
    printf "${CYAN}║     Project Hospitality - We implement. Not just advise.  ║${NC}\n"
    printf "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"

    # Early validation
    validate_data_directory
    check_disk_space
    init_logging

    # Must run as root for setup
    if [ "$(id -u)" = "0" ]; then
        setup_user_mapping
        init_data_directory
        setup_symlinks
        install_custom_packages
        # Final ownership fix after all file operations
        chown -R "${PUID}:${PGID}" "${DATA_DIR}" 2>/dev/null || true
        chown -R "${PUID}:${PGID}" "${HOME_DIR}" 2>/dev/null || true
        # Fix permissions AFTER ownership is set
        fix_permissions
    fi

    verify_claude
    setup_ssh

    # Check for first run
    if [ ! -f "${DATA_DIR}/claude/.initialized" ]; then
        log "First run detected - setup wizard will launch on first terminal connection"
    else
        log "Existing installation detected"
    fi

    start_ttyd
}

main "$@"
