#!/bin/bash
# ╔═══════════════════════════════════════════════════════════╗
# ║              ClaudePantheon Secrets Setup                 ║
# ╚═══════════════════════════════════════════════════════════╝
# Interactive script to configure Docker secrets securely

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SECRETS_DIR="./secrets"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              ClaudePantheon Secrets Setup                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Create secrets directory
if [ ! -d "$SECRETS_DIR" ]; then
    mkdir -p "$SECRETS_DIR"
    echo -e "${GREEN}✓${NC} Created secrets directory"
else
    echo -e "${YELLOW}⚠${NC}  Secrets directory already exists"
fi

# Setup Anthropic API Key
echo ""
echo -e "${CYAN}1. Anthropic API Key${NC}"
echo "   Get your key from: https://console.anthropic.com/"
echo ""
read -p "   Do you have an Anthropic API key? (y/N): " has_key

if [ "$has_key" = "y" ] || [ "$has_key" = "Y" ]; then
    read -p "   Enter your API key: " api_key
    if [ -n "$api_key" ]; then
        echo "$api_key" > "$SECRETS_DIR/anthropic_api_key.txt"
        chmod 600 "$SECRETS_DIR/anthropic_api_key.txt"
        echo -e "${GREEN}✓${NC} Saved API key to secrets/anthropic_api_key.txt"
    fi
else
    echo -e "${YELLOW}⚠${NC}  Skipping API key (you can use browser auth later)"
fi

# Setup Internal Credentials
echo ""
echo -e "${CYAN}2. Internal Zone Credentials${NC}"
echo "   Protects: /terminal/, /files/, /webdav/"
echo ""
read -p "   Enable authentication for internal services? (Y/n): " enable_internal

if [ "$enable_internal" != "n" ] && [ "$enable_internal" != "N" ]; then
    read -p "   Username (default: admin): " internal_user
    internal_user=${internal_user:-admin}

    echo "   Password options:"
    echo "     1. Generate strong random password (recommended)"
    echo "     2. Enter custom password"
    read -p "   Choice (1/2): " pass_choice

    if [ "$pass_choice" = "2" ]; then
        read -s -p "   Enter password: " internal_pass
        echo ""
        read -s -p "   Confirm password: " internal_pass_confirm
        echo ""

        if [ "$internal_pass" != "$internal_pass_confirm" ]; then
            echo -e "${RED}✗${NC} Passwords don't match, using generated password instead"
            internal_pass=$(openssl rand -base64 32)
        fi
    else
        internal_pass=$(openssl rand -base64 32)
    fi

    echo "${internal_user}:${internal_pass}" > "$SECRETS_DIR/internal_credential.txt"
    chmod 600 "$SECRETS_DIR/internal_credential.txt"

    echo -e "${GREEN}✓${NC} Saved internal credentials:"
    echo "   Username: ${internal_user}"
    if [ "$pass_choice" = "1" ]; then
        echo "   Password: ${internal_pass}"
        echo -e "   ${YELLOW}⚠  Save this password! It won't be shown again.${NC}"
    fi
else
    echo -e "${YELLOW}⚠${NC}  Internal authentication disabled"
fi

# Setup Webroot Credentials
echo ""
echo -e "${CYAN}3. Webroot Zone Credentials${NC}"
echo "   Protects: Landing page (/) and custom PHP apps"
echo ""
read -p "   Enable separate webroot authentication? (y/N): " enable_webroot

if [ "$enable_webroot" = "y" ] || [ "$enable_webroot" = "Y" ]; then
    read -p "   Username (default: guest): " webroot_user
    webroot_user=${webroot_user:-guest}

    webroot_pass=$(openssl rand -base64 24)

    echo "${webroot_user}:${webroot_pass}" > "$SECRETS_DIR/webroot_credential.txt"
    chmod 600 "$SECRETS_DIR/webroot_credential.txt"

    echo -e "${GREEN}✓${NC} Saved webroot credentials:"
    echo "   Username: ${webroot_user}"
    echo "   Password: ${webroot_pass}"
    echo -e "   ${YELLOW}⚠  Save this password! It won't be shown again.${NC}"
else
    echo -e "${YELLOW}⚠${NC}  Webroot will use internal credentials (if enabled)"
fi

# Update docker-compose.yml
echo ""
echo -e "${CYAN}4. Updating docker-compose.yml${NC}"

if grep -q "^#secrets:" docker-compose.yml 2>/dev/null; then
    echo "   Uncommenting secrets sections..."

    # Uncomment top-level secrets section
    sed -i.bak '/^# secrets:/,/^#     file:.*webroot_credential.txt/ s/^# //' docker-compose.yml

    # Uncomment service-level secrets section
    sed -i.bak '/^    # secrets:/,/^    #   - webroot_credential/ s/^    # /    /' docker-compose.yml

    rm docker-compose.yml.bak 2>/dev/null || true

    echo -e "${GREEN}✓${NC} Enabled Docker secrets in docker-compose.yml"
else
    echo -e "${YELLOW}⚠${NC}  Secrets already enabled in docker-compose.yml"
fi

# Summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Setup Complete!                        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. Review settings in .env file"
echo "  2. Start ClaudePantheon:"
echo "     ${CYAN}docker compose up -d${NC}"
echo ""
echo "Security notes:"
echo "  ✓ Secrets are in secrets/*.txt (mode 600)"
echo "  ✓ These files are in .gitignore"
echo "  ✓ Backup these files to a secure location"
echo ""
echo "Access URLs:"
echo "  Landing page: http://localhost:7681/"
echo "  Terminal:     http://localhost:7681/terminal/"
echo "  Files:        http://localhost:7681/files/"
echo ""

# Check if container is running
if docker compose ps --format '{{.State}}' claudepantheon 2>/dev/null | grep -q "running"; then
    echo -e "${YELLOW}⚠  Container is currently running${NC}"
    echo ""
    read -p "Restart now to apply secrets? (y/N): " restart_now

    if [ "$restart_now" = "y" ] || [ "$restart_now" = "Y" ]; then
        echo "Restarting container..."
        docker compose restart
        echo -e "${GREEN}✓${NC} Container restarted"
    else
        echo "Run ${CYAN}docker compose restart${NC} when ready to apply changes"
    fi
fi

echo ""
echo "Done!"
