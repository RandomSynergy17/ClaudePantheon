# ╔═══════════════════════════════════════════════════════════╗
# ║                    ClaudePantheon                         ║
# ║              Zsh Configuration                            ║
# ╚═══════════════════════════════════════════════════════════╝

# Oh My Zsh configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
    git
    docker
    npm
    python
    history
    sudo
    web-search
    copypath
    copyfile
    jsontools
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Fix color bleeding from Claude Code errors
# Force terminal color reset before AND after every command
precmd() {
    # Reset all attributes, then explicitly set to normal
    printf '\033[0m\033[39m\033[49m'
}

preexec() {
    # Reset colors before executing any command
    printf '\033[0m'
}

# Environment
export EDITOR='nano'
export LANG='en_US.UTF-8'
export PATH="$HOME/.local/bin:$PATH"

# History configuration
HISTFILE="$HOME/.zsh_history_dir/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS

# ClaudePantheon functions
run_setup_wizard() {
    /app/data/scripts/shell-wrapper.sh --setup-only
}

claude_mcp() {
    local MCP_CONFIG="/app/data/mcp/mcp.json"
    echo "\033[0;36mMCP Server Management\033[0m"
    echo ""
    echo "1. View current configuration"
    echo "2. Edit configuration"
    echo "3. Show documentation"
    echo ""
    read "choice?Select option: "
    case $choice in
        1) echo "" && echo "\033[0;32mCurrent MCP Configuration:\033[0m" && cat "${MCP_CONFIG}" 2>/dev/null | jq . || echo "No configuration found" ;;
        2) ${EDITOR:-nano} "${MCP_CONFIG}" ;;
        3) echo "Documentation: https://docs.anthropic.com/en/docs/claude-code/mcp" ;;
    esac
}

# Settings file for runtime configuration
CLAUDE_SETTINGS_FILE="/app/data/claude/.settings"
CLAUDE_SESSION_FILE="/app/data/claude/.last_session"

# Claude Code command builder (handles bypass permissions)
# Checks settings file first, falls back to env var
_claude_cmd() {
    local cmd="claude"
    local bypass="false"

    # Check file-based setting first (runtime toggle)
    if [ -f "$CLAUDE_SETTINGS_FILE" ]; then
        bypass=$(grep "^BYPASS_PERMISSIONS=" "$CLAUDE_SETTINGS_FILE" 2>/dev/null | cut -d'=' -f2)
    fi

    # Fall back to env var if not set in file
    if [ -z "$bypass" ]; then
        bypass="${CLAUDE_BYPASS_PERMISSIONS:-false}"
    fi

    if [ "$bypass" = "true" ]; then
        cmd="claude --dangerously-skip-permissions"
    fi
    echo "$cmd"
}

# Get current bypass setting
_get_bypass_status() {
    local bypass="false"
    if [ -f "$CLAUDE_SETTINGS_FILE" ]; then
        bypass=$(grep "^BYPASS_PERMISSIONS=" "$CLAUDE_SETTINGS_FILE" 2>/dev/null | cut -d'=' -f2)
    fi
    [ -z "$bypass" ] && bypass="${CLAUDE_BYPASS_PERMISSIONS:-false}"
    echo "$bypass"
}

# Record session start time
_record_session_start() {
    mkdir -p "$(dirname "$CLAUDE_SESSION_FILE")"
    echo "LAST_SESSION_START=$(date '+%Y-%m-%d %H:%M:%S')" > "$CLAUDE_SESSION_FILE"
}

# Get last session info
_get_last_session_info() {
    if [ -f "$CLAUDE_SESSION_FILE" ]; then
        grep "^LAST_SESSION_START=" "$CLAUDE_SESSION_FILE" 2>/dev/null | cut -d'=' -f2
    fi
}

# Toggle bypass permissions at runtime
cc_bypass() {
    # Ensure settings file exists
    if [ ! -f "$CLAUDE_SETTINGS_FILE" ]; then
        mkdir -p "$(dirname "$CLAUDE_SETTINGS_FILE")"
        echo "BYPASS_PERMISSIONS=false" > "$CLAUDE_SETTINGS_FILE"
    fi

    local current=$(_get_bypass_status)

    case "$1" in
        on|true|enable)
            sed -i 's/^BYPASS_PERMISSIONS=.*/BYPASS_PERMISSIONS=true/' "$CLAUDE_SETTINGS_FILE"
            echo "\033[0;32m✅ Bypass permissions ENABLED\033[0m"
            echo "\033[1;33m⚠️  Claude will execute without asking for confirmation\033[0m"
            ;;
        off|false|disable)
            sed -i 's/^BYPASS_PERMISSIONS=.*/BYPASS_PERMISSIONS=false/' "$CLAUDE_SETTINGS_FILE"
            echo "\033[0;32m✅ Bypass permissions DISABLED\033[0m"
            echo "Claude will ask before executing commands"
            ;;
        ""|toggle)
            if [ "$current" = "true" ]; then
                sed -i 's/^BYPASS_PERMISSIONS=.*/BYPASS_PERMISSIONS=false/' "$CLAUDE_SETTINGS_FILE"
                echo "\033[0;32m✅ Bypass permissions DISABLED\033[0m"
                echo "Claude will ask before executing commands"
            else
                sed -i 's/^BYPASS_PERMISSIONS=.*/BYPASS_PERMISSIONS=true/' "$CLAUDE_SETTINGS_FILE"
                echo "\033[0;32m✅ Bypass permissions ENABLED\033[0m"
                echo "\033[1;33m⚠️  Claude will execute without asking for confirmation\033[0m"
            fi
            ;;
        status|show)
            if [ "$current" = "true" ]; then
                echo "Bypass permissions: \033[1;33mON\033[0m (dangerous)"
            else
                echo "Bypass permissions: \033[0;32mOFF\033[0m (safe)"
            fi
            ;;
        *)
            echo "Usage: cc-bypass [on|off|toggle|status]"
            echo ""
            echo "  on      Enable bypass (Claude executes without asking)"
            echo "  off     Disable bypass (Claude asks before executing)"
            echo "  toggle  Toggle current setting (default)"
            echo "  status  Show current setting"
            ;;
    esac
}

# Show all ClaudePantheon settings
cc_settings() {
    echo ""
    echo "\033[0;36m🔧 ClaudePantheon Settings\033[0m"
    echo "═══════════════════════════════════════"
    echo ""

    # Bypass permissions
    local bypass=$(_get_bypass_status)
    if [ "$bypass" = "true" ]; then
        echo "  Bypass permissions:  \033[1;33m✅ ON\033[0m (dangerous)"
    else
        echo "  Bypass permissions:  \033[0;32m⬚ OFF\033[0m (safe)"
    fi

    # Shell
    echo "  Shell:               ${CLAUDE_CODE_SHELL:-/bin/zsh}"

    # API Key status
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        echo "  API Key:             \033[0;32m✅ Set\033[0m"
    else
        echo "  API Key:             \033[1;33m⬚ Not set\033[0m (browser auth)"
    fi

    # Auto continue
    echo "  Auto continue:       ${AUTO_CONTINUE:-true}"

    # Last session info
    local last_session=$(_get_last_session_info)
    if [ -n "$last_session" ]; then
        echo "  Last session:        $last_session"
    fi

    echo ""
    echo "Toggle bypass: \033[0;36mcc-bypass [on|off]\033[0m"
    echo ""
}

# Claude Code wrapper functions (with session tracking)
cc_continue() {
    cd /app/data/workspace
    _record_session_start
    eval "$(_claude_cmd) --continue"
}

cc_new() {
    cd /app/data/workspace
    _record_session_start
    eval "$(_claude_cmd)"
}

cc_resume() {
    cd /app/data/workspace
    _record_session_start
    eval "$(_claude_cmd) --continue"
}

cc_list() {
    cd /app/data/workspace
    eval "$(_claude_cmd) --resume"
}

# Claude Code aliases
alias cc='cc_continue'
alias cc-new='cc_new'
alias cc-resume='cc_resume'
alias cc-list='cc_list'
alias cc-setup='run_setup_wizard'
alias cc-mcp='claude_mcp'
alias cc-bypass='cc_bypass'
alias cc-settings='cc_settings'
alias cc-info='cc_settings && claude --version'
alias cc-help='echo "
ClaudePantheon Commands:

Starting Sessions:
  cc-new      - Start a NEW Claude session (use this first!)
  cc          - Continue LAST session (requires existing session)
  cc-resume   - Resume specific session (interactive picker)
  cc-list     - List all sessions

Configuration:
  cc-setup    - Run CLAUDE.md setup wizard
  cc-mcp      - Manage MCP servers
  cc-bypass   - Toggle bypass permissions [on|off]
  cc-settings - Show current settings
  cc-info     - Show environment info

Navigation:
  ccw         - Go to workspace
  ccd         - Go to data directory

Note: If you see \"No conversation found\", use cc-new to start!"'

# Navigation aliases
alias ccw='cd /app/data/workspace'
alias ccd='cd /app/data'
alias ccmnt='cd /mounts && ls -la'
alias cce='${EDITOR:-nano} /app/data/workspace/CLAUDE.md'
alias ccm='${EDITOR:-nano} /app/data/mcp/mcp.json'
alias ccp='${EDITOR:-nano} /app/data/custom-packages.txt'

# Utility aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -10'
alias gd='git diff'

# Docker aliases (if docker is available)
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'

# Welcome message on shell start
echo ""
echo "🏛️  ClaudePantheon - Quick Start:"
echo "   'cc-new'   → Start a NEW Claude session"
echo "   'cc'       → Continue last session"
echo "   'cc-help'  → Show all commands"
echo ""
echo "   Data directory: /app/data"

# Security warning if no authentication is configured
if [ "${INTERNAL_AUTH:-}" != "true" ] && [ -z "${TTYD_CREDENTIAL:-}" ] && [ -z "${INTERNAL_CREDENTIAL:-}" ]; then
    echo ""
    echo "\033[1;33m⚠️  WARNING: Web terminal has NO AUTHENTICATION\033[0m"
    echo "   Set INTERNAL_AUTH=true and INTERNAL_CREDENTIAL in docker/.env for security"
fi
echo ""
