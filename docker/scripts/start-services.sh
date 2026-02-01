#!/bin/sh
# ╔═══════════════════════════════════════════════════════════╗
# ║                    ClaudePantheon                         ║
# ║              Service Supervisor Script                    ║
# ╚═══════════════════════════════════════════════════════════╝
#
# Lightweight process supervisor that starts:
#   - php-fpm (background) - for landing page
#   - nginx (background) - reverse proxy on port 7681
#   - filebrowser (background, optional) - file manager
#   - ttyd (foreground) - main process, container dies with it
#
# Called by entrypoint.sh after user setup and package installation.

set -e

DATA_DIR="/app/data"
DEFAULTS_DIR="/opt/claudepantheon/defaults"

# ─────────────────────────────────────────────────────────────
# COLOR OUTPUT
# ─────────────────────────────────────────────────────────────
log_info() { printf '\033[0;36m[INFO]\033[0m %s\n' "$1"; }
log_success() { printf '\033[0;32m[OK]\033[0m %s\n' "$1"; }
log_warn() { printf '\033[0;33m[WARN]\033[0m %s\n' "$1"; }
log_error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$1"; }

# ─────────────────────────────────────────────────────────────
# CLEANUP HANDLER
# ─────────────────────────────────────────────────────────────
cleanup() {
    log_info "Shutting down services..."

    # Stop rclone processes first (prevents new I/O during unmount)
    if pgrep -x rclone >/dev/null 2>&1; then
        pkill -TERM -x rclone 2>/dev/null || true
        # Wait up to 5s for graceful shutdown
        _rclone_wait=0
        while pgrep -x rclone >/dev/null 2>&1 && [ "$_rclone_wait" -lt 5 ]; do
            sleep 1
            _rclone_wait=$((_rclone_wait + 1))
        done
        pkill -9 -x rclone 2>/dev/null || true
    fi

    # Unmount all rclone FUSE mounts (graceful first, lazy fallback)
    if [ -d /mounts/rclone ]; then
        for mount_dir in /mounts/rclone/*/; do
            [ -d "$mount_dir" ] || continue
            if mountpoint -q "$mount_dir" 2>/dev/null || ! timeout 3 stat "$mount_dir" >/dev/null 2>&1; then
                timeout 5 fusermount -u "$mount_dir" 2>/dev/null || \
                    fusermount -uz "$mount_dir" 2>/dev/null || true
            fi
        done
    fi

    # Kill background processes
    [ -n "$NGINX_PID" ] && kill "$NGINX_PID" 2>/dev/null || true
    [ -n "$PHPFPM_PID" ] && kill "$PHPFPM_PID" 2>/dev/null || true
    [ -n "$FILEBROWSER_PID" ] && kill "$FILEBROWSER_PID" 2>/dev/null || true

    # Wait for processes to terminate
    wait 2>/dev/null || true

    log_info "Cleanup complete"
}

trap cleanup EXIT INT TERM

# ─────────────────────────────────────────────────────────────
# COPY DEFAULT CONFIGS
# ─────────────────────────────────────────────────────────────
log_info "Setting up configuration files..."

# nginx config
mkdir -p "$DATA_DIR/nginx"
if [ ! -f "$DATA_DIR/nginx/nginx.conf" ]; then
    cp "$DEFAULTS_DIR/nginx/nginx.conf" "$DATA_DIR/nginx/nginx.conf"
    log_success "Created default nginx.conf"
fi

# webroot
mkdir -p "$DATA_DIR/webroot/public_html"
if [ ! -f "$DATA_DIR/webroot/public_html/index.php" ]; then
    cp "$DEFAULTS_DIR/webroot/public_html/index.php" "$DATA_DIR/webroot/public_html/index.php"
    log_success "Created default landing page"
fi
# Always update 404 page from defaults (not user-customized)
if [ -f "$DEFAULTS_DIR/webroot/public_html/404.php" ]; then
    cp "$DEFAULTS_DIR/webroot/public_html/404.php" "$DATA_DIR/webroot/public_html/404.php"
fi

# filebrowser database directory
mkdir -p "$DATA_DIR/filebrowser"

# ─────────────────────────────────────────────────────────────
# AUTHENTICATION SETUP
# ─────────────────────────────────────────────────────────────
log_info "Configuring authentication..."

# Backward compatibility: TTYD_CREDENTIAL -> INTERNAL_CREDENTIAL
if [ -n "$TTYD_CREDENTIAL" ] && [ -z "$INTERNAL_CREDENTIAL" ]; then
    INTERNAL_CREDENTIAL="$TTYD_CREDENTIAL"
fi

# Create htpasswd files
HTPASSWD_INTERNAL="/tmp/htpasswd-internal"
HTPASSWD_WEBROOT="/tmp/htpasswd-webroot"

# Internal zone authentication
if [ "$INTERNAL_AUTH" = "true" ]; then
    # Validation: Credentials must be set when auth is enabled
    if [ -z "$INTERNAL_CREDENTIAL" ]; then
        log_error "INTERNAL_AUTH=true but INTERNAL_CREDENTIAL is not set"
        log_error ""
        log_error "Security requirement: Authentication cannot be enabled without credentials"
        log_error ""
        log_error "Fix this by either:"
        log_error "  1. Set INTERNAL_CREDENTIAL=username:password in .env"
        log_error "  2. Use Docker secrets (recommended for production):"
        log_error "     mkdir -p docker/secrets"
        log_error "     echo 'admin:strongpassword' > docker/secrets/internal_credential.txt"
        log_error "     chmod 600 docker/secrets/internal_credential.txt"
        log_error "  3. Set INTERNAL_AUTH=false to disable authentication"
        log_error ""
        exit 1
    fi

    # Validate credential format (must contain username:password)
    if ! echo "$INTERNAL_CREDENTIAL" | grep -q ':'; then
        log_error "INTERNAL_CREDENTIAL must be in format: username:password"
        log_error "Current value does not contain ':' separator"
        exit 1
    fi

    INTERNAL_USER=$(echo "$INTERNAL_CREDENTIAL" | cut -d: -f1)
    INTERNAL_PASS=$(echo "$INTERNAL_CREDENTIAL" | cut -d: -f2-)

    # Validate username and password are not empty
    if [ -z "$INTERNAL_USER" ] || [ -z "$INTERNAL_PASS" ]; then
        log_error "INTERNAL_CREDENTIAL has empty username or password"
        log_error "Format: username:password (both parts required)"
        exit 1
    fi

    # Warn about weak passwords
    pass_len=${#INTERNAL_PASS}
    if [ "$pass_len" -lt 12 ]; then
        log_warn "INTERNAL_CREDENTIAL password is short ($pass_len chars)"
        log_warn "Recommendation: Use at least 12 characters for security"
        log_warn "Generate strong password: openssl rand -base64 32"
    fi

    # Generate htpasswd (using openssl for password hash)
    INTERNAL_HASH=$(echo "$INTERNAL_PASS" | openssl passwd -apr1 -stdin)
    echo "${INTERNAL_USER}:${INTERNAL_HASH}" > "$HTPASSWD_INTERNAL"
    chmod 600 "$HTPASSWD_INTERNAL"
    log_success "Internal zone authentication enabled (user: $INTERNAL_USER)"
else
    rm -f "$HTPASSWD_INTERNAL"
    log_info "Internal zone authentication disabled"
fi

# Webroot zone authentication
if [ "$WEBROOT_AUTH" = "true" ]; then
    # Use WEBROOT_CREDENTIAL if set, otherwise fall back to INTERNAL_CREDENTIAL
    if [ -n "$WEBROOT_CREDENTIAL" ]; then
        WEBROOT_CRED="$WEBROOT_CREDENTIAL"
        CRED_SOURCE="WEBROOT_CREDENTIAL"
    elif [ -n "$INTERNAL_CREDENTIAL" ]; then
        WEBROOT_CRED="$INTERNAL_CREDENTIAL"
        CRED_SOURCE="INTERNAL_CREDENTIAL (fallback)"
    else
        # Validation: Credentials must be set when auth is enabled
        log_error "WEBROOT_AUTH=true but no credentials provided"
        log_error ""
        log_error "Fix this by either:"
        log_error "  1. Set WEBROOT_CREDENTIAL=username:password in .env"
        log_error "  2. Set INTERNAL_CREDENTIAL (will be used as fallback)"
        log_error "  3. Use Docker secrets (recommended)"
        log_error "  4. Set WEBROOT_AUTH=false to disable authentication"
        log_error ""
        exit 1
    fi

    # Validate credential format
    if ! echo "$WEBROOT_CRED" | grep -q ':'; then
        log_error "${CRED_SOURCE} must be in format: username:password"
        exit 1
    fi

    WEBROOT_USER=$(echo "$WEBROOT_CRED" | cut -d: -f1)
    WEBROOT_PASS=$(echo "$WEBROOT_CRED" | cut -d: -f2-)

    # Validate username and password are not empty
    if [ -z "$WEBROOT_USER" ] || [ -z "$WEBROOT_PASS" ]; then
        log_error "${CRED_SOURCE} has empty username or password"
        exit 1
    fi

    WEBROOT_HASH=$(echo "$WEBROOT_PASS" | openssl passwd -apr1 -stdin)
    echo "${WEBROOT_USER}:${WEBROOT_HASH}" > "$HTPASSWD_WEBROOT"
    chmod 600 "$HTPASSWD_WEBROOT"
    log_success "Webroot zone authentication enabled (user: $WEBROOT_USER, source: $CRED_SOURCE)"
else
    rm -f "$HTPASSWD_WEBROOT"
    log_info "Webroot zone authentication disabled"
fi

# ─────────────────────────────────────────────────────────────
# NGINX CONFIGURATION
# ─────────────────────────────────────────────────────────────
log_info "Configuring nginx..."

# Create working nginx config from template
NGINX_CONF="/tmp/nginx.conf"
cp "$DATA_DIR/nginx/nginx.conf" "$NGINX_CONF"

# Internal zone auth: write include file
AUTH_INTERNAL_INCLUDE="/tmp/auth-internal.conf"
if [ -f "$HTPASSWD_INTERNAL" ]; then
    cat > "$AUTH_INTERNAL_INCLUDE" <<'AUTHEOF'
auth_basic "ClaudePantheon Internal";
auth_basic_user_file /tmp/htpasswd-internal;
AUTHEOF
else
    : > "$AUTH_INTERNAL_INCLUDE"
fi

# Webroot zone auth: write include file
AUTH_WEBROOT_INCLUDE="/tmp/auth-webroot.conf"
if [ -f "$HTPASSWD_WEBROOT" ]; then
    cat > "$AUTH_WEBROOT_INCLUDE" <<'AUTHEOF'
auth_basic "ClaudePantheon";
auth_basic_user_file /tmp/htpasswd-webroot;
AUTHEOF
else
    : > "$AUTH_WEBROOT_INCLUDE"
fi

# Replace auth placeholders with include directives
sed -i 's|# AUTH_INTERNAL_PLACEHOLDER.*|include /tmp/auth-internal.conf;|g' "$NGINX_CONF"
sed -i 's|# AUTH_WEBROOT_PLACEHOLDER.*|include /tmp/auth-webroot.conf;|g' "$NGINX_CONF"

# WebDAV configuration
if [ "$ENABLE_WEBDAV" != "true" ]; then
    # Remove WebDAV location block
    sed -i '/# WEBDAV_LOCATION_START/,/# WEBDAV_LOCATION_END/d' "$NGINX_CONF"
    log_info "WebDAV disabled"
else
    log_success "WebDAV enabled at /webdav/"
fi

# Create nginx temp directories
mkdir -p /tmp/nginx-client-body /tmp/nginx-proxy /tmp/nginx-fastcgi /tmp/nginx-uwsgi /tmp/nginx-scgi

# ─────────────────────────────────────────────────────────────
# PHP-FPM CONFIGURATION
# ─────────────────────────────────────────────────────────────
log_info "Configuring PHP-FPM..."

# Create PHP-FPM config for non-root operation
PHP_FPM_CONF="/tmp/php-fpm.conf"
PHP_FPM_LOG="/tmp/php-fpm.log"
touch "$PHP_FPM_LOG"
cat > "$PHP_FPM_CONF" << EOF
[global]
error_log = $PHP_FPM_LOG
daemonize = no

[www]
user = claude
group = claude
listen = 127.0.0.1:9000
listen.owner = claude
listen.group = claude

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

php_admin_value[error_log] = $PHP_FPM_LOG
php_admin_flag[log_errors] = on
EOF

# ─────────────────────────────────────────────────────────────
# START PHP-FPM
# ─────────────────────────────────────────────────────────────
log_info "Starting PHP-FPM..."
php-fpm83 -F -y "$PHP_FPM_CONF" &
PHPFPM_PID=$!
sleep 1

if kill -0 "$PHPFPM_PID" 2>/dev/null; then
    log_success "PHP-FPM started (PID: $PHPFPM_PID)"
else
    log_error "Failed to start PHP-FPM"
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# START NGINX
# ─────────────────────────────────────────────────────────────
log_info "Starting nginx..."
nginx -c "$NGINX_CONF" &
NGINX_PID=$!
sleep 1

if kill -0 "$NGINX_PID" 2>/dev/null; then
    log_success "nginx started (PID: $NGINX_PID) - listening on port 7681"
else
    log_error "Failed to start nginx"
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# START FILEBROWSER (Optional)
# FileBrowser Quantum uses YAML config
# ─────────────────────────────────────────────────────────────
if [ "$ENABLE_FILEBROWSER" != "false" ]; then
    log_info "Starting FileBrowser..."

    # FileBrowser Quantum configuration file
    FB_CONFIG="$DATA_DIR/filebrowser/config.yaml"

    # Create minimal config file for FileBrowser Quantum
    # Using correct YAML structure based on official docs
    # baseURL must match nginx location - nginx no longer strips prefix
    cat > "$FB_CONFIG" << EOF
server:
  port: 7683
  baseURL: /files
  database: $DATA_DIR/filebrowser/database.db
  cacheDir: $DATA_DIR/filebrowser/tmp
  sources:
    - path: $DATA_DIR
      config:
        defaultEnabled: true
EOF

    # Start FileBrowser Quantum from its config directory
    cd "$DATA_DIR/filebrowser"
    filebrowser -c "$FB_CONFIG" &
    FILEBROWSER_PID=$!
    cd - > /dev/null
    sleep 2

    if kill -0 "$FILEBROWSER_PID" 2>/dev/null; then
        log_success "FileBrowser started (PID: $FILEBROWSER_PID) at /files/"
    else
        log_warn "Failed to start FileBrowser - continuing without it"
        FILEBROWSER_PID=""
    fi
else
    log_info "FileBrowser disabled"
fi

# ─────────────────────────────────────────────────────────────
# START TTYD (Main Process - Foreground)
# ─────────────────────────────────────────────────────────────
log_info "Starting ttyd web terminal..."

# Build ttyd command
TTYD_CMD="ttyd"
TTYD_CMD="$TTYD_CMD --port 7682"
TTYD_CMD="$TTYD_CMD --interface 127.0.0.1"
TTYD_CMD="$TTYD_CMD --writable"

# Build bypass permissions flag
BYPASS_FLAG=""
if [ "$CLAUDE_BYPASS_PERMISSIONS" = "true" ] || [ -f "$DATA_DIR/.bypass_permissions" ]; then
    BYPASS_FLAG="--dangerously-skip-permissions"
fi

# Shell wrapper with optional bypass
SHELL_CMD="$DATA_DIR/scripts/shell-wrapper.sh $BYPASS_FLAG"

log_success "Services ready!"
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                    ClaudePantheon                         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "  Landing Page:  http://localhost:7681/"
echo "  Terminal:      http://localhost:7681/terminal/"
[ "$ENABLE_FILEBROWSER" != "false" ] && echo "  File Browser:  http://localhost:7681/files/"
[ "$ENABLE_WEBDAV" = "true" ] && echo "  WebDAV:        http://localhost:7681/webdav/"
echo ""

# Run ttyd in foreground (container dies if ttyd dies)
exec $TTYD_CMD $SHELL_CMD
