# ╔═══════════════════════════════════════════════════════════╗
# ║                    ClaudePantheon                         ║
# ║     Persistent Claude Code Environment with Web Access    ║
# ╚═══════════════════════════════════════════════════════════╝
#
# Alpine-based Docker image providing:
#   - Claude Code CLI with session persistence
#   - Web terminal access via ttyd
#   - Oh My Zsh with plugins
#   - MCP (Model Context Protocol) support
#   - Runtime user mapping (PUID/PGID)
#   - Custom package installation without rebuild
#
# BUILD:
#   docker compose build
#   # or: docker build -t claudepantheon .
#
# DOCKERFILE SYNTAX REFERENCE:
#   FROM      - Base image to build upon
#   ARG       - Build-time variables (only available during build)
#   ENV       - Runtime environment variables (persist in container)
#   RUN       - Execute commands during build (creates new layer)
#   COPY      - Copy files from build context into image
#   USER      - Set user for subsequent commands
#   WORKDIR   - Set working directory
#   EXPOSE    - Document which ports the container listens on
#   HEALTHCHECK - Define how Docker checks if container is healthy
#   ENTRYPOINT - Command that runs when container starts

# ─────────────────────────────────────────────────────────────
# BASE IMAGE
# Node.js 22 on Alpine Linux (minimal footprint, ~50MB base)
# ─────────────────────────────────────────────────────────────
FROM node:22-alpine

# Image metadata (visible in 'docker inspect')
LABEL maintainer="RandomSynergy"
LABEL description="ClaudePantheon - Persistent Claude Code environment with web terminal access"
LABEL project="ClaudePantheon"

# ─────────────────────────────────────────────────────────────
# BUILD ARGUMENTS
# Only available during build, not at runtime
# Note: UID/GID are remapped to host values at runtime by entrypoint.sh
# ─────────────────────────────────────────────────────────────
ARG USERNAME=claude
# Use standard 1000:1000 at build time - entrypoint remaps to PUID/PGID at runtime
ARG USER_UID=1000
ARG USER_GID=1000

# ─────────────────────────────────────────────────────────────
# ENVIRONMENT VARIABLES
# Available at runtime in the container
# ─────────────────────────────────────────────────────────────
# Default shell
ENV SHELL=/bin/zsh
# Terminal type for color support
ENV TERM=xterm-256color
# Claude Code mode
ENV CLAUDE_CODE_ENTRYPOINT=cli
# Locale settings
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ─────────────────────────────────────────────────────────────
# SYSTEM PACKAGES
# Alpine uses 'apk' package manager (not apt/yum)
# --no-cache: Don't store package index (smaller image)
# ─────────────────────────────────────────────────────────────
RUN apk add --no-cache \
    # ── Core Utilities ──
    git \
    curl \
    wget \
    vim \
    nano \
    htop \
    tree \
    jq \
    unzip \
    zip \
    file \
    less \
    # ── Shell & Terminal ──
    zsh \
    zsh-vcs \
    tmux \
    ttyd \
    # ── Network Tools ──
    openssh \
    openssh-server \
    rsync \
    net-tools \
    iputils \
    bind-tools \
    # ── Development ──
    build-base \
    python3 \
    py3-pip \
    # ── Web Server & PHP ──
    nginx \
    nginx-mod-http-dav-ext \
    php83 \
    php83-fpm \
    php83-json \
    php83-openssl \
    openssl \
    # ── System Utilities ──
    shadow \
    sudo \
    ca-certificates \
    gnupg \
    bash \
    coreutils \
    findutils \
    grep \
    sed \
    gawk

# ─────────────────────────────────────────────────────────────
# USER SETUP
# Create non-root user with sudo access
# UID/GID are remapped at runtime by entrypoint.sh
# Note: node:alpine has node user at UID/GID 1000, remove it first
# ─────────────────────────────────────────────────────────────
RUN deluser --remove-home node 2>/dev/null || true \
    && delgroup node 2>/dev/null || true \
    && addgroup -g ${USER_GID} ${USERNAME} \
    && adduser -D -u ${USER_UID} -G ${USERNAME} -s /bin/zsh ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# ─────────────────────────────────────────────────────────────
# SSH SERVER SETUP (Optional feature, enabled via ENABLE_SSH)
# ─────────────────────────────────────────────────────────────
RUN mkdir -p /var/run/sshd \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ─────────────────────────────────────────────────────────────
# USER ENVIRONMENT SETUP
# Install oh-my-zsh and plugins as the container user
# ─────────────────────────────────────────────────────────────
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Oh My Zsh - popular zsh configuration framework
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Zsh plugins for better shell experience
RUN git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# ─────────────────────────────────────────────────────────────
# CLAUDE CODE INSTALLATION
# Using native installer (recommended by Anthropic)
# Installs to ~/.local/bin/claude with auto-updates
# ─────────────────────────────────────────────────────────────
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Create .config directory for Claude Code settings
RUN mkdir -p /home/${USERNAME}/.config

# ─────────────────────────────────────────────────────────────
# FILEBROWSER QUANTUM INSTALLATION
# Web-based file manager (~30MB static binary)
# https://github.com/gtsteffaniak/filebrowser
# ─────────────────────────────────────────────────────────────
USER root
ARG FB_VERSION=v1.1.1-stable
RUN wget -qO /usr/local/bin/filebrowser \
        "https://github.com/gtsteffaniak/filebrowser/releases/download/${FB_VERSION}/linux-amd64-filebrowser" \
    && chmod +x /usr/local/bin/filebrowser

# ─────────────────────────────────────────────────────────────
# SCRIPTS AND DEFAULTS SETUP
# Default scripts are stored in /opt/claudepantheon/defaults/
# On first run, they're copied to /app/data/ for customization
# ─────────────────────────────────────────────────────────────
USER root

RUN mkdir -p /opt/claudepantheon/defaults/nginx \
    && mkdir -p /opt/claudepantheon/defaults/webroot/public_html

# Copy default scripts into image
COPY scripts/entrypoint.sh /opt/claudepantheon/defaults/entrypoint.sh
COPY scripts/shell-wrapper.sh /opt/claudepantheon/defaults/shell-wrapper.sh
COPY scripts/.zshrc /opt/claudepantheon/defaults/.zshrc
COPY scripts/start-services.sh /opt/claudepantheon/defaults/start-services.sh

# Copy nginx and webroot defaults
COPY defaults/nginx/nginx.conf /opt/claudepantheon/defaults/nginx/nginx.conf
COPY defaults/webroot/public_html/index.php /opt/claudepantheon/defaults/webroot/public_html/index.php

# Make scripts executable
RUN chmod +x /opt/claudepantheon/defaults/*.sh

# ─────────────────────────────────────────────────────────────
# DATA DIRECTORY
# Mount point for persistent data volume
# Actual data stored on host via docker-compose volume mount
# ─────────────────────────────────────────────────────────────
RUN mkdir -p /app/data && chown ${USERNAME}:${USERNAME} /app/data

# ─────────────────────────────────────────────────────────────
# NETWORK PORTS
# EXPOSE documents ports; actual mapping is in docker-compose.yml
# 7681 = ttyd web terminal
# 22   = SSH server (optional, enabled via ENABLE_SSH)
# ─────────────────────────────────────────────────────────────
EXPOSE 7681 22

# ─────────────────────────────────────────────────────────────
# HEALTH CHECK
# Docker uses this to determine if container is healthy
# Checks: ttyd responding + Claude Code installed
# ─────────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget -q --spider http://localhost:7681/health

# ─────────────────────────────────────────────────────────────
# ENTRYPOINT
# Runs as root to handle user mapping and package installation
# Then drops privileges before starting ttyd
# ─────────────────────────────────────────────────────────────
USER root
ENTRYPOINT ["/opt/claudepantheon/defaults/entrypoint.sh"]
