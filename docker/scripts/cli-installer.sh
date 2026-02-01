#!/bin/bash
# ╔═══════════════════════════════════════════════════════════╗
# ║        Codex & Gemini CLI Installation Wizard            ║
# ╚═══════════════════════════════════════════════════════════╝
#
# Interactive installer for OpenAI Codex and Google Gemini CLI tools
#
# Features:
# - Automatic detection of installed CLIs
# - API key configuration
# - Integration testing
# - Claude Octopus integration
# - Uninstall support

set -euo pipefail

# Configuration
DATA_DIR="${DATA_DIR:-/app/data}"
CLI_CONFIG="${DATA_DIR}/.cli-config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Logging
log() {
    echo -e "${GREEN}[CLI Installer]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[CLI Installer]${NC} $*"
}

error() {
    echo -e "${RED}[CLI Installer]${NC} $*"
}

# Safe password read
_read_password() {
    local prompt="$1"
    local varname="$2"
    local _pw_cancelled=false

    trap 'stty echo 2>/dev/null; echo ""; echo -e "${YELLOW}Cancelled.${NC}"; _pw_cancelled=true' INT
    read -rs "${varname}?${prompt}"
    echo " [hidden]"
    trap - INT

    if [ "$_pw_cancelled" = "true" ]; then
        return 1
    fi
}

# Check if CLI is installed
check_cli_installed() {
    local cli_name="$1"
    command -v "$cli_name" &>/dev/null
}

# Get CLI version
get_cli_version() {
    local cli_name="$1"

    case "$cli_name" in
        codex)
            codex --version 2>/dev/null | head -1 || echo "unknown"
            ;;
        gemini)
            gemini --version 2>/dev/null | head -1 || echo "unknown"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Show installation status banner
show_status_banner() {
    local codex_status="✗ Not installed"
    local gemini_status="✗ Not installed"
    local codex_version=""
    local gemini_version=""

    if check_cli_installed codex; then
        codex_version=$(get_cli_version codex)
        codex_status="✓ Installed (${codex_version})"
    fi

    if check_cli_installed gemini; then
        gemini_version=$(get_cli_version gemini)
        gemini_status="✓ Installed (${gemini_version})"
    fi

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        AI CLI Installation Wizard                         ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${MAGENTA}OpenAI Codex CLI:${NC}  ${codex_status}"
    echo -e "  ${BLUE}Google Gemini CLI:${NC} ${gemini_status}"
    echo -e "  ${GREEN}Claude API:${NC}        ✓ Available (via @anthropic-ai/claude-code)"
    echo ""
}

# Install Codex CLI
install_codex() {
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║              Install OpenAI Codex CLI                     ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if check_cli_installed codex; then
        warn "Codex CLI is already installed ($(get_cli_version codex))"
        read -r -p "Reinstall? [y/N]: " reinstall
        if [[ ! "${reinstall,,}" =~ ^(y|yes)$ ]]; then
            return 0
        fi
    fi

    echo -e "${CYAN}Installation Method:${NC}"
    echo "  1. npm (recommended)"
    echo "  2. Manual download"
    echo "  3. Skip"
    read -r -p "Select [1]: " install_method

    case "${install_method:-1}" in
        1)
            log "Installing Codex CLI via npm..."

            if npm install -g openai-codex-cli 2>/dev/null; then
                log "Codex CLI installed successfully"
            else
                # Fallback: try alternative package name
                warn "Trying alternative installation..."
                if npm install -g codex-cli 2>/dev/null || \
                   npm install -g @openai/codex-cli 2>/dev/null; then
                    log "Codex CLI installed"
                else
                    error "Installation failed. You may need to install manually."
                    echo ""
                    echo "Manual installation:"
                    echo "  pip install openai-codex"
                    echo "  # or"
                    echo "  npm install -g codex-cli"
                    return 1
                fi
            fi
            ;;
        2)
            echo ""
            echo "Manual installation instructions:"
            echo "  1. Visit: https://github.com/openai/codex-cli"
            echo "  2. Download the binary for your platform"
            echo "  3. Move to /usr/local/bin/codex"
            echo "  4. chmod +x /usr/local/bin/codex"
            return 0
            ;;
        *)
            log "Skipped Codex CLI installation"
            return 0
            ;;
    esac

    # Configure API key
    echo ""
    log "Codex CLI installed. Configuring API key..."

    echo ""
    echo "Get your OpenAI API key:"
    echo "  1. Visit: https://platform.openai.com/api-keys"
    echo "  2. Click 'Create new secret key'"
    echo "  3. Copy the key (starts with 'sk-')"
    echo ""

    local api_key
    _read_password "  OpenAI API Key: " api_key || return 1

    if [ -z "$api_key" ]; then
        warn "No API key provided. Configure later with: export OPENAI_API_KEY=sk-..."
        return 0
    fi

    # Save to configuration
    mkdir -p "$(dirname "$CLI_CONFIG")"
    echo "OPENAI_API_KEY=${api_key}" >> "$CLI_CONFIG"
    export OPENAI_API_KEY="$api_key"

    # Test connection
    echo ""
    log "Testing Codex connection..."
    if codex test 2>/dev/null || echo "test" | codex "echo hello" 2>/dev/null; then
        log "Codex CLI configured successfully!"
    else
        warn "Connection test failed. Verify your API key."
    fi

    unset api_key
}

# Install Gemini CLI
install_gemini() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║             Install Google Gemini CLI                     ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if check_cli_installed gemini; then
        warn "Gemini CLI is already installed ($(get_cli_version gemini))"
        read -r -p "Reinstall? [y/N]: " reinstall
        if [[ ! "${reinstall,,}" =~ ^(y|yes)$ ]]; then
            return 0
        fi
    fi

    echo -e "${CYAN}Installation Method:${NC}"
    echo "  1. npm (recommended)"
    echo "  2. pip (Python)"
    echo "  3. Manual download"
    echo "  4. Skip"
    read -r -p "Select [1]: " install_method

    case "${install_method:-1}" in
        1)
            log "Installing Gemini CLI via npm..."

            if npm install -g @google/generative-ai-cli 2>/dev/null || \
               npm install -g gemini-cli 2>/dev/null; then
                log "Gemini CLI installed successfully"
            else
                error "npm installation failed. Try pip method."
                return 1
            fi
            ;;
        2)
            log "Installing Gemini CLI via pip..."

            if pip install google-generativeai 2>/dev/null && \
               pip install gemini-cli 2>/dev/null; then
                log "Gemini CLI installed successfully"
            else
                error "pip installation failed."
                return 1
            fi
            ;;
        3)
            echo ""
            echo "Manual installation instructions:"
            echo "  1. Visit: https://ai.google.dev/gemini-api/docs/cli"
            echo "  2. Download the CLI tool"
            echo "  3. Follow platform-specific instructions"
            return 0
            ;;
        *)
            log "Skipped Gemini CLI installation"
            return 0
            ;;
    esac

    # Configure API key
    echo ""
    log "Gemini CLI installed. Configuring API key..."

    echo ""
    echo "Get your Google AI API key:"
    echo "  1. Visit: https://makersuite.google.com/app/apikey"
    echo "  2. Click 'Create API key'"
    echo "  3. Copy the key"
    echo ""

    local api_key
    _read_password "  Google AI API Key: " api_key || return 1

    if [ -z "$api_key" ]; then
        warn "No API key provided. Configure later with: export GOOGLE_AI_API_KEY=..."
        return 0
    fi

    # Save to configuration
    mkdir -p "$(dirname "$CLI_CONFIG")"
    echo "GOOGLE_AI_API_KEY=${api_key}" >> "$CLI_CONFIG"
    export GOOGLE_AI_API_KEY="$api_key"

    # Test connection
    echo ""
    log "Testing Gemini connection..."
    if gemini test 2>/dev/null || echo "test" | gemini "say hello" 2>/dev/null; then
        log "Gemini CLI configured successfully!"
    else
        warn "Connection test failed. Verify your API key."
    fi

    unset api_key
}

# Uninstall CLI
uninstall_cli() {
    local cli_name="$1"

    if ! check_cli_installed "$cli_name"; then
        warn "${cli_name} is not installed"
        return 0
    fi

    read -r -p "Uninstall ${cli_name} CLI? [y/N]: " confirm
    if [[ ! "${confirm,,}" =~ ^(y|yes)$ ]]; then
        return 0
    fi

    case "$cli_name" in
        codex)
            npm uninstall -g openai-codex-cli codex-cli @openai/codex-cli 2>/dev/null || \
            pip uninstall -y openai-codex 2>/dev/null || \
            warn "Could not uninstall via package manager. Remove manually."
            ;;
        gemini)
            npm uninstall -g @google/generative-ai-cli gemini-cli 2>/dev/null || \
            pip uninstall -y gemini-cli google-generativeai 2>/dev/null || \
            warn "Could not uninstall via package manager. Remove manually."
            ;;
    esac

    log "${cli_name} CLI uninstalled"
}

# Configure for Claude Octopus
configure_octopus_integration() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         Claude Octopus Integration                        ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local codex_available=$(check_cli_installed codex && echo "✓" || echo "✗")
    local gemini_available=$(check_cli_installed gemini && echo "✓" || echo "✗")

    echo -e "  Codex CLI:  ${codex_available}"
    echo -e "  Gemini CLI: ${gemini_available}"
    echo ""

    if [ "$codex_available" = "✗" ] && [ "$gemini_available" = "✗" ]; then
        warn "No additional AI CLIs installed. Claude Octopus will use Claude only."
        return 0
    fi

    log "AI CLIs detected! Claude Octopus can use multiple AI providers."
    echo ""
    echo "Benefits:"
    echo "  • Multi-perspective research (discover phase)"
    echo "  • Consensus building (define phase)"
    echo "  • Quality validation (deliver phase)"
    echo ""

    log "Claude Octopus automatically detects available CLIs at runtime."
    log "No additional configuration needed!"
}

# Main wizard
main_wizard() {
    show_status_banner

    echo "What would you like to do?"
    echo ""
    echo "  ${MAGENTA}1.${NC} Install Codex CLI"
    echo "  ${BLUE}2.${NC} Install Gemini CLI"
    echo "  ${GREEN}3.${NC} Install both"
    echo "  ${CYAN}4.${NC} Configure Claude Octopus integration"
    echo "  ${YELLOW}5.${NC} Show status"
    echo "  ${RED}6.${NC} Uninstall Codex CLI"
    echo "  ${RED}7.${NC} Uninstall Gemini CLI"
    echo "  8. Exit"
    echo ""
    read -r -p "Select option [8]: " choice

    case "${choice:-8}" in
        1)
            install_codex
            configure_octopus_integration
            ;;
        2)
            install_gemini
            configure_octopus_integration
            ;;
        3)
            install_codex
            install_gemini
            configure_octopus_integration
            ;;
        4)
            configure_octopus_integration
            ;;
        5)
            show_status_banner
            ;;
        6)
            uninstall_cli codex
            ;;
        7)
            uninstall_cli gemini
            ;;
        *)
            log "Exiting"
            exit 0
            ;;
    esac

    echo ""
    read -r -p "Return to menu? [Y/n]: " again
    if [[ ! "${again,,}" =~ ^(n|no)$ ]]; then
        main_wizard
    fi
}

# Main entry point
main() {
    case "${1:-wizard}" in
        wizard|interactive)
            main_wizard
            ;;
        install-codex)
            install_codex
            ;;
        install-gemini)
            install_gemini
            ;;
        install-all)
            install_codex
            install_gemini
            ;;
        uninstall-codex)
            uninstall_cli codex
            ;;
        uninstall-gemini)
            uninstall_cli gemini
            ;;
        status)
            show_status_banner
            ;;
        help|--help|-h)
            cat << 'EOF'
AI CLI Installation Wizard

Usage:
  cli-installer.sh [command]

Commands:
  wizard              Interactive installation wizard (default)
  install-codex       Install OpenAI Codex CLI
  install-gemini      Install Google Gemini CLI
  install-all         Install both CLIs
  uninstall-codex     Uninstall Codex CLI
  uninstall-gemini    Uninstall Gemini CLI
  status              Show installation status
  help                Show this help

Examples:
  cli-installer.sh                    # Interactive wizard
  cli-installer.sh install-codex      # Install Codex only
  cli-installer.sh install-all        # Install both CLIs
  cli-installer.sh status             # Check what's installed

Integration:
  Installed CLIs are automatically detected by Claude Octopus
  for multi-provider AI workflows (discover, define, deliver phases).

Configuration file: /app/data/.cli-config
EOF
            ;;
        *)
            error "Unknown command: $1"
            echo "Run 'cli-installer.sh help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
