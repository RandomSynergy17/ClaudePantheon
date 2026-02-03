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

# Before redirecting to custom entrypoint, update scripts from image defaults
# This ensures bug fixes propagate even when the data volume has old copies
SCRIPT_PATH="$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")"
if [ "${SCRIPT_PATH}" = "${DEFAULTS_DIR}/entrypoint.sh" ]; then
    # Update scripts from image defaults (unless .keep marker exists)
    if [ -d "${DATA_DIR}" ] && [ ! -f "${DATA_DIR}/scripts/.keep" ]; then
        mkdir -p "${DATA_DIR}/scripts"
        for _SCRIPT in entrypoint.sh shell-wrapper.sh start-services.sh .zshrc; do
            _SRC="${DEFAULTS_DIR}/${_SCRIPT}"
            _DST="${DATA_DIR}/scripts/${_SCRIPT}"
            if [ -f "${_SRC}" ]; then
                cp "${_SRC}" "${_DST}"
                case "${_SCRIPT}" in
                    *.sh) chmod +x "${_DST}" ;;
                esac
            fi
        done
    fi

    # Update nginx config from image defaults (unless .keep marker exists)
    if [ -d "${DATA_DIR}" ] && [ ! -f "${DATA_DIR}/nginx/.keep" ]; then
        mkdir -p "${DATA_DIR}/nginx"
        if [ -f "${DEFAULTS_DIR}/nginx/nginx.conf" ]; then
            cp "${DEFAULTS_DIR}/nginx/nginx.conf" "${DATA_DIR}/nginx/nginx.conf"
        fi
    fi

    # Redirect to custom entrypoint if it exists
    if [ -f "${CUSTOM_ENTRYPOINT}" ]; then
        export CLAUDEPANTHEON_DEPTH=$((CLAUDEPANTHEON_DEPTH + 1))
        exec "${CUSTOM_ENTRYPOINT}" "$@"
    fi
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
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

# Copy default scripts to data directory
# Always updates from image defaults unless user creates a .keep marker
# To prevent overwrite: touch /app/data/scripts/.keep
init_scripts() {
    log "Checking scripts in data directory..."

    mkdir -p "${DATA_DIR}/scripts"

    # If .keep exists, only copy missing scripts (preserves user customizations)
    # Otherwise, always update from image defaults to pick up bug fixes
    COPY_MODE="update"
    if [ -f "${DATA_DIR}/scripts/.keep" ]; then
        COPY_MODE="missing"
        log "Scripts .keep marker found - only installing missing scripts"
    fi

    for SCRIPT in entrypoint.sh shell-wrapper.sh start-services.sh .zshrc; do
        SRC="${DEFAULTS_DIR}/${SCRIPT}"
        DST="${DATA_DIR}/scripts/${SCRIPT}"

        if [ ! -f "${SRC}" ]; then
            continue
        fi

        if [ "${COPY_MODE}" = "missing" ] && [ -f "${DST}" ]; then
            continue
        fi

        cp "${SRC}" "${DST}"
        case "${SCRIPT}" in
            *.sh) chmod +x "${DST}" ;;
        esac
        log "Installed default ${SCRIPT}"
    done

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
    mkdir -p "${DATA_DIR}/rclone"
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
    editor = nano
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
# Uses ln -sfn: -s=symbolic, -f=force overwrite, -n=don't follow existing symlink/dir
setup_symlinks() {
    log "Setting up symlinks..."

    # Directory symlinks (ln -sfn prevents creating link inside existing target dir)
    mkdir -p "${HOME_DIR}/.config"
    ln -sfn "${DATA_DIR}/workspace" "${HOME_DIR}/workspace"
    ln -sfn "${DATA_DIR}/claude" "${HOME_DIR}/.claude"
    ln -sfn "${DATA_DIR}/mcp" "${HOME_DIR}/.config/claude-code"
    ln -sfn "${DATA_DIR}/ssh" "${HOME_DIR}/.ssh"
    ln -sfn "${DATA_DIR}/npm-cache" "${HOME_DIR}/.npm"
    ln -sfn "${DATA_DIR}/python-venvs" "${HOME_DIR}/.venvs"
    ln -sfn "${DATA_DIR}/zsh-history" "${HOME_DIR}/.zsh_history_dir"

    # File symlinks (ln -sf is sufficient for files)
    ln -sf "${DATA_DIR}/zsh-history/.zsh_history" "${HOME_DIR}/.zsh_history"
    ln -sf "${DATA_DIR}/scripts/.zshrc" "${HOME_DIR}/.zshrc"
    ln -sf "${DATA_DIR}/gitconfig" "${HOME_DIR}/.gitconfig"

    # Rclone config symlink
    mkdir -p "${HOME_DIR}/.config/rclone"
    ln -sf "${DATA_DIR}/rclone/rclone.conf" "${HOME_DIR}/.config/rclone/rclone.conf"

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
            if ! echo "$line" | grep -qE '^[a-zA-Z][a-zA-Z0-9._-]*$'; then
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
    # Native installer puts claude at ~/.local/bin/claude
    CLAUDE_BIN="${HOME_DIR}/.local/bin/claude"

    if [ ! -x "${CLAUDE_BIN}" ]; then
        log "Claude Code not found. Installing via native installer..."
        if ! su -s /bin/sh ${USERNAME} -c "export PATH=\"${HOME_DIR}/.local/bin:\$PATH\" && curl -fsSL https://claude.ai/install.sh | bash"; then
            error "Failed to install Claude Code. Container cannot start."
            exit 1
        fi
        log "Claude Code installed successfully"
    fi

    # Get version
    VERSION=$(su -s /bin/sh ${USERNAME} -c "${CLAUDE_BIN} --version 2>/dev/null" || echo 'unknown')
    log "Claude Code version: ${VERSION}"
}

# Setup SSH server (optional)
setup_ssh() {
    if [ "${ENABLE_SSH:-}" = "true" ]; then
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

        chown root:root "${SSH_HOST_KEYS_DIR}"
        chmod 700 "${SSH_HOST_KEYS_DIR}"
        find "${SSH_HOST_KEYS_DIR}" -type f -name "*.pub" -exec chmod 644 {} \;
        find "${SSH_HOST_KEYS_DIR}" -type f ! -name "*.pub" -exec chmod 600 {} \;

        # Unlock user for SSH key authentication (change ! to * in shadow)
        # This allows pubkey auth while keeping password login disabled
        if grep -q "^${USERNAME}:!" /etc/shadow 2>/dev/null; then
            sed -i "s/^${USERNAME}:!/${USERNAME}:*/" /etc/shadow
            log "Unlocked ${USERNAME} account for SSH key authentication"
        fi

        log "Starting SSH server..."
        /usr/sbin/sshd || warn "Failed to start SSH server"
    fi
}

# Setup rclone remote mounts (optional)
setup_rclone() {
    if [ "${ENABLE_RCLONE:-false}" != "true" ]; then
        return 0
    fi

    log "Setting up rclone remote mounts..."

    # Create mountpoint base directory
    mkdir -p /mounts/rclone
    chown "${PUID}:${PGID}" /mounts/rclone

    # Create default rclone config if missing
    if [ ! -f "${DATA_DIR}/rclone/rclone.conf" ]; then
        touch "${DATA_DIR}/rclone/rclone.conf"
        chown "${PUID}:${PGID}" "${DATA_DIR}/rclone/rclone.conf"
        log "Created empty rclone.conf"
    fi
    # Ensure rclone.conf is owner-only (contains credentials)
    chmod 600 "${DATA_DIR}/rclone/rclone.conf"

    # Create default automount.conf if missing
    if [ ! -f "${DATA_DIR}/rclone/automount.conf" ]; then
        cat > "${DATA_DIR}/rclone/automount.conf" << 'RCLONE_EOF'
# ╔═══════════════════════════════════════════════════════════╗
# ║           ClaudePantheon rclone Auto-Mount                ║
# ╚═══════════════════════════════════════════════════════════╝
#
# Remotes listed here are mounted automatically on container start.
# Format: remote_name:/path  [--vfs-cache-mode=MODE] [other rclone flags]
# Lines starting with # are ignored. Blank lines are ignored.
#
# Examples:
# gdrive:/Documents  --vfs-cache-mode=writes
# s3bucket:/data     --vfs-cache-mode=minimal
# mysftp:/home       --vfs-cache-mode=off
#
# Cache modes: off, minimal, writes, full
# See: https://rclone.org/commands/rclone_mount/#vfs-file-caching
RCLONE_EOF
        chown "${PUID}:${PGID}" "${DATA_DIR}/rclone/automount.conf"
        log "Created automount.conf template"
    fi

    # Check for FUSE device
    if [ ! -c /dev/fuse ]; then
        warn "FUSE device not available - rclone mounting disabled"
        warn "Uncomment devices, cap_add, and apparmor:unconfined in docker-compose.yml"
        return 0
    fi

    # Detect unclean shutdown (SIGKILL recovery)
    RCLONE_PID_FILE="/tmp/rclone-supervisor.pid"
    if [ -f "$RCLONE_PID_FILE" ]; then
        _old_pid=$(cat "$RCLONE_PID_FILE" 2>/dev/null)
        if [ -n "$_old_pid" ]; then
            # Check if old PID is still running AND is actually our entrypoint process
            # Use /proc/cmdline (NUL-delimited full command) for reliable identification
            # /proc/comm is truncated to 15 chars and sh/ash are too generic
            if [ -d "/proc/$_old_pid" ] && [ -f "/proc/$_old_pid/cmdline" ]; then
                _old_cmdline=$(tr '\0' ' ' < "/proc/$_old_pid/cmdline" 2>/dev/null || true)
                if [ -z "$_old_cmdline" ]; then
                    # Empty cmdline: likely kernel thread or zombie after our entrypoint died
                    # Safer to cleanup (false positive is harmless, false negative leaves stale mounts)
                    warn "PID $_old_pid exists but cmdline empty (likely PID reused). Cleaning up rclone."
                    pkill -9 -x rclone 2>/dev/null || true
                    sleep 1
                elif echo "$_old_cmdline" | grep -qF "entrypoint.sh"; then
                    : # Still our process, no cleanup needed
                else
                    # PID reused by different process — treat as stale
                    warn "Detected unclean shutdown (PID reused). Cleaning up rclone state..."
                    pkill -9 -x rclone 2>/dev/null || true
                    sleep 1
                fi
            elif ! kill -0 "$_old_pid" 2>/dev/null; then
                # Process is dead — unclean shutdown
                warn "Detected unclean shutdown (stale PID file). Cleaning up rclone state..."
                pkill -9 -x rclone 2>/dev/null || true
                sleep 1
            fi
        fi
    fi
    # Write current supervisor PID for next-startup detection
    echo $$ > "$RCLONE_PID_FILE"

    # Clean stale FUSE mounts (under lock to prevent races with cc-rmount)
    RCLONE_LOCKFILE="/tmp/rclone-mount.lock"
    _rclone_lock_held=false
    exec 9>"$RCLONE_LOCKFILE"
    if ! flock -w 10 9; then
        exec 9>&-
        warn "Could not acquire rclone mount lock — skipping stale cleanup and automount"
    else
        _rclone_lock_held=true
        if [ -d /mounts/rclone ]; then
            for mount_dir in /mounts/rclone/*/; do
                [ -d "$mount_dir" ] || continue

                # Skip if properly mounted
                if mountpoint -q "$mount_dir" 2>/dev/null; then
                    continue
                fi

                # Check if stale (stat fails on dead FUSE mount)
                # Use timeout to prevent D-state hang on unresponsive FUSE
                if ! timeout 3 stat "$mount_dir" >/dev/null 2>&1; then
                    log "Cleaning stale mount: $mount_dir"
                    fusermount -u "$mount_dir" 2>/dev/null || \
                        fusermount -uz "$mount_dir" 2>/dev/null || true
                    # Only rmdir if unmount succeeded and dir is empty
                    if ! mountpoint -q "$mount_dir" 2>/dev/null; then
                        rmdir "$mount_dir" 2>/dev/null || true
                    fi
                fi
            done
        fi
    fi
    # Keep fd 9 open — reused for automount below (same lock)

    # Process automount.conf (only if lock is held — prevents race with cc-rmount)
    if [ "$_rclone_lock_held" != "true" ]; then
        warn "Skipping automount — no lock held"
    elif [ -f "${DATA_DIR}/rclone/automount.conf" ]; then
        _mount_success=0
        _mount_total=0

        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                \#*|"") continue ;;
            esac

            # Parse: first token is remote spec, rest is mount options
            REMOTE_SPEC="${line%% *}"
            MOUNT_OPTS="${line#"${REMOTE_SPEC}"}"
            MOUNT_OPTS="${MOUNT_OPTS# }"  # trim leading space
            # If line had no space, MOUNT_OPTS equals REMOTE_SPEC — clear it
            [ "$MOUNT_OPTS" = "$REMOTE_SPEC" ] && MOUNT_OPTS=""

            # Remote name is everything before first colon
            REMOTE_NAME="${REMOTE_SPEC%%:*}"

            if [ -z "$REMOTE_NAME" ]; then
                continue
            fi

            # Validate remote name (alphanumeric, dash, underscore)
            if ! echo "$REMOTE_NAME" | grep -qE '^[a-zA-Z0-9_-]+$'; then
                warn "Invalid remote name in automount.conf: ${REMOTE_NAME}"
                continue
            fi

            # Validate mount options (whitelist: only allow safe rclone flag characters)
            if [ -n "$MOUNT_OPTS" ] && ! echo "$MOUNT_OPTS" | grep -qE '^[a-zA-Z0-9=_./:@ -]*$'; then
                warn "Unsafe characters in mount options for ${REMOTE_NAME}, skipping"
                continue
            fi

            # Check remote exists in rclone config
            if ! su -s /bin/sh "${USERNAME}" -c "rclone listremotes 2>/dev/null" | grep -qxF "${REMOTE_NAME}:"; then
                warn "Remote '${REMOTE_NAME}' not found in rclone.conf, skipping"
                continue
            fi

            MOUNT_PATH="/mounts/rclone/${REMOTE_NAME}"
            mkdir -p "$MOUNT_PATH"
            chown "${PUID}:${PGID}" "$MOUNT_PATH"

            _mount_total=$((_mount_total + 1))
            log "Auto-mounting rclone remote: ${REMOTE_SPEC} -> ${MOUNT_PATH}"
            if timeout 30 su -s /bin/sh "${USERNAME}" -c "rclone mount \"${REMOTE_SPEC}\" \"${MOUNT_PATH}\" --daemon --allow-other ${MOUNT_OPTS}" 2>&1; then
                # Verify mount succeeded (--daemon returns immediately)
                sleep 2
                if mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
                    log "Mounted: ${REMOTE_SPEC} -> ${MOUNT_PATH}"
                    _mount_success=$((_mount_success + 1))
                else
                    warn "Mount command succeeded but mountpoint not active: ${REMOTE_SPEC}"
                    # Kill orphaned rclone daemon for this failed mount
                    # Use fixed-string grep to find exact PID, avoiding regex injection
                    _orphan_pids=$(ps aux 2>/dev/null | grep -F "rclone mount" | grep -F -- "$MOUNT_PATH" | grep -v grep | awk '{print $2}')
                    if [ -n "$_orphan_pids" ]; then
                        echo "$_orphan_pids" | xargs kill 2>/dev/null || true
                    fi
                    rmdir "$MOUNT_PATH" 2>/dev/null || true
                fi
            else
                warn "Failed to mount ${REMOTE_SPEC} (timed out or error)"
            fi
        done < "${DATA_DIR}/rclone/automount.conf"

        if [ "$_mount_total" -gt 0 ]; then
            log "Auto-mount summary: ${_mount_success}/${_mount_total} remotes mounted"
        fi
    fi

    # Release lock (covers both stale cleanup and automount)
    exec 9>&-

    log "rclone setup complete"
}

# Start all services via start-services.sh
# This runs nginx, php-fpm, filebrowser (optional), and ttyd
start_services() {
    log "Starting ClaudePantheon services..."

    # Export environment variables for start-services.sh
    export PUID PGID
    export INTERNAL_AUTH="${INTERNAL_AUTH:-false}"
    export INTERNAL_CREDENTIAL="${INTERNAL_CREDENTIAL:-${TTYD_CREDENTIAL:-}}"
    export WEBROOT_AUTH="${WEBROOT_AUTH:-false}"
    export WEBROOT_CREDENTIAL="${WEBROOT_CREDENTIAL:-}"
    export ENABLE_FILEBROWSER="${ENABLE_FILEBROWSER:-true}"
    export ENABLE_WEBDAV="${ENABLE_WEBDAV:-false}"
    export CLAUDE_BYPASS_PERMISSIONS="${CLAUDE_BYPASS_PERMISSIONS:-false}"
    export ENABLE_RCLONE="${ENABLE_RCLONE:-false}"

    # Run start-services.sh as claude user
    exec su -s /bin/sh ${USERNAME} -c "${DATA_DIR}/scripts/start-services.sh"
}

# Main execution
main() {
    printf "\n"
    printf "${CYAN}                            ~MMM~${NC}\n"
    printf "${CYAN}                       ~MMMMMMMMMMMMM~${NC}\n"
    printf "${CYAN}                    ~MMMMMMMMMMMMMMMMMMMM~${NC}\n"
    printf "${CYAN}                 ~MMMMMMMMMMMMMMMMMMMMMMMMMM~${NC}\n"
    printf "${CYAN}              ~MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM~${NC}\n"
    printf "${CYAN}           ~MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM~${NC}\n"
    printf "${CYAN}         ~MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM~${NC}\n"
    printf "${CYAN}       . ~MM${NC}                                        ${CYAN}MM~ .${NC}\n"
    printf "${CYAN}       . ~MM${NC}    ${BOLD}CLAUDEPANTHEON${NC}  |  ${DIM}RandomSynergy${NC}     ${CYAN}MM~ .${NC}\n"
    printf "${CYAN}       . ~MM${NC}    ${DIM}Your consciousness persists here${NC}    ${CYAN}MM~ .${NC}\n"
    printf "${CYAN}       . ~MM${NC}                                        ${CYAN}MM~ .${NC}\n"
    printf "${CYAN}       . ~MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM~ .${NC}\n"
    printf "${CYAN}       ... MMM .... MMM .... MMM .... MMM .... MMM .... MMM ...${NC}\n"
    printf "${CYAN}       ... MMM .... MMM .... MMM .... MMM .... MMM .... MMM ...${NC}\n"
    printf "${CYAN}       ... MMM .... MMM .... MMM .... MMM .... MMM .... MMM ...${NC}\n"
    printf "${CYAN}       ... MMM .... MMM .... MMM .... MMM .... MMM .... MMM ...${NC}\n"
    printf "${CYAN}       ~MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM~${NC}\n"
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
    setup_rclone

    # Check for first run
    if [ ! -f "${DATA_DIR}/claude/.initialized" ]; then
        log "First run detected - setup wizard will launch on first terminal connection"
    else
        log "Existing installation detected"
    fi

    start_services
}

main "$@"
