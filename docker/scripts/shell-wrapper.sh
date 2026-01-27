#!/bin/zsh
# ╔═══════════════════════════════════════════════════════════╗
# ║                    ClaudePantheon                         ║
# ║              Shell Wrapper Script                         ║
# ╚═══════════════════════════════════════════════════════════╝
# Handles first-run setup wizard and automatic session continuation

# Source zsh config
source ~/.zshrc 2>/dev/null || true

# Configuration
DATA_DIR="/app/data"
WORKSPACE_DIR="${DATA_DIR}/workspace"
FIRST_RUN_FLAG="${DATA_DIR}/claude/.initialized"
CLAUDE_MD_PATH="${WORKSPACE_DIR}/CLAUDE.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Print banner
print_banner() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "       ${MAGENTA}ClaudePantheon${NC}"
    echo -e "  Persistent Claude Code Workstation"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "  ${GREEN}cc-new${NC}      Start a NEW Claude session"
    echo -e "  ${GREEN}cc${NC}          Continue last session"
    echo -e "  ${GREEN}cc-resume${NC}   Resume specific session"
    echo -e "  ${GREEN}cc-list${NC}     List all sessions"
    echo -e "  ${GREEN}cc-setup${NC}    Re-run CLAUDE.md setup wizard"
    echo -e "  ${GREEN}cc-mcp${NC}      Manage MCP servers"
    echo ""
}

# Check if first run
is_first_run() {
    [ ! -f "${FIRST_RUN_FLAG}" ]
}

# Setup wizard for CLAUDE.md
run_setup_wizard() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           ClaudePantheon - Setup Wizard                   ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Let's configure your ClaudePantheon environment.${NC}"
    echo -e "${YELLOW}This information will be saved to CLAUDE.md for context.${NC}"
    echo ""

    # Project/Workspace Name
    echo -e "${GREEN}1. What should we call this workspace?${NC}"
    echo -e "   (e.g., 'Personal Dev Environment', 'Project Alpha')"
    read -r "workspace_name?   > "
    workspace_name="${workspace_name:-My Claude Workspace}"

    echo ""

    # Primary Use Case
    echo -e "${GREEN}2. What's the primary purpose of this environment?${NC}"
    echo -e "   (e.g., 'Full-stack development', 'Data analysis', 'DevOps automation')"
    read -r "primary_purpose?   > "
    primary_purpose="${primary_purpose:-General development and automation}"

    echo ""

    # User Context
    echo -e "${GREEN}3. Tell me about yourself (role, expertise level):${NC}"
    echo -e "   (e.g., 'Senior developer with focus on Python and React')"
    read -r "user_context?   > "
    user_context="${user_context:-Developer}"

    echo ""

    # Tech Stack
    echo -e "${GREEN}4. Primary technologies/languages you work with:${NC}"
    echo -e "   (comma-separated, e.g., 'Python, TypeScript, Docker, PostgreSQL')"
    read -r "tech_stack?   > "
    tech_stack="${tech_stack:-Various}"

    echo ""

    # Coding Style Preferences
    echo -e "${GREEN}5. Coding style preferences:${NC}"
    echo -e "   (e.g., 'Prefer functional programming, extensive comments, TypeScript strict mode')"
    read -r "coding_style?   > "
    coding_style="${coding_style:-Clean, well-documented code}"

    echo ""

    # Communication Style
    echo -e "${GREEN}6. How should Claude communicate with you?${NC}"
    echo -e "   (e.g., 'Concise and direct', 'Detailed explanations', 'Ask before making changes')"
    read -r "comm_style?   > "
    comm_style="${comm_style:-Clear and helpful}"

    echo ""

    # Active Projects
    echo -e "${GREEN}7. Current projects or focus areas (optional):${NC}"
    echo -e "   (e.g., 'Building a SaaS app, API integrations, automation scripts')"
    read -r "active_projects?   > "
    active_projects="${active_projects:-}"

    echo ""

    # MCP Integrations
    echo -e "${GREEN}8. Systems to integrate with via MCP (optional):${NC}"
    echo -e "   (e.g., 'GitHub, Home Assistant, Notion, custom APIs')"
    read -r "mcp_systems?   > "
    mcp_systems="${mcp_systems:-}"

    echo ""

    # Important Conventions
    echo -e "${GREEN}9. Any important conventions or rules to follow?${NC}"
    echo -e "   (e.g., 'Always use TypeScript, test before commit, follow company style guide')"
    read -r "conventions?   > "
    conventions="${conventions:-}"

    echo ""

    # Additional Context
    echo -e "${GREEN}10. Anything else Claude should know about this workspace?${NC}"
    read -r "additional_context?   > "
    additional_context="${additional_context:-}"

    echo ""
    echo -e "${YELLOW}Generating CLAUDE.md...${NC}"

    # Generate CLAUDE.md
    generate_claude_md

    # Mark as initialized with timestamp
    echo "Initialized: $(date '+%Y-%m-%d %H:%M:%S')" > "${FIRST_RUN_FLAG}"

    echo ""
    echo -e "${GREEN}✓ Setup complete!${NC}"
    echo -e "${GREEN}✓ CLAUDE.md created at: ${CLAUDE_MD_PATH}${NC}"
    echo ""
    echo -e "${CYAN}You can edit this file anytime or run 'cc-setup' to reconfigure.${NC}"
    echo ""
}

# Generate CLAUDE.md file
generate_claude_md() {
    cat > "${CLAUDE_MD_PATH}" << CLAUDE_MD
# ${workspace_name}

> Auto-generated by ClaudePantheon Setup Wizard
> Last updated: $(date '+%Y-%m-%d %H:%M:%S')

## About This Workspace

**Purpose:** ${primary_purpose}

**User Context:** ${user_context}

## Technical Environment

### Technology Stack
${tech_stack}

### Coding Style Preferences
${coding_style}

### Communication Style
${comm_style}

## Session Continuity

This is a **persistent Claude Code environment**. Key behaviors:

1. **Always continue from the last session** - Use context from previous conversations
2. **Remember decisions made** - Don't re-ask about settled preferences
3. **Track ongoing work** - Reference and continue incomplete tasks
4. **Maintain consistency** - Use the same patterns and conventions throughout

## Active Projects & Focus Areas

${active_projects:-No active projects specified yet. Update this section as needed.}

## MCP Integrations

${mcp_systems:-No MCP integrations configured yet.}

$(if [ -n "${mcp_systems}" ]; then
echo "
### Configured MCP Servers
Check \`/app/data/mcp/mcp.json\` for current configuration.
"
fi)

## Conventions & Rules

${conventions:-No specific conventions defined yet.}

## Important Notes

${additional_context:-}

---

## Session Log

<!-- Claude: Use this section to track important decisions and state across sessions -->

### Initialized
- **Date:** $(date '+%Y-%m-%d %H:%M:%S')
- **Environment:** Docker persistent container
- **Access:** ttyd web terminal

### Recent Activity
<!-- This section can be updated to track ongoing work -->

---

## Quick Reference

### Common Commands
\`\`\`bash
cc          # Continue last Claude session
cc-new      # Start fresh session
cc-resume   # Resume specific session
cc-list     # List sessions
cc-setup    # Re-run setup wizard
cc-mcp      # Manage MCP servers
\`\`\`

### File Locations
- **Workspace:** /app/data/workspace
- **MCP Config:** /app/data/mcp/mcp.json
- **Session History:** /app/data/claude/
- **SSH Keys:** /app/data/ssh/
- **Logs:** /app/data/logs/
- **Custom Packages:** /app/data/custom-packages.txt
CLAUDE_MD

    echo -e "${GREEN}✓ CLAUDE.md generated${NC}"
}

# MCP management (elaborate version for first-run context)
claude_mcp() {
    local MCP_CONFIG="/app/data/mcp/mcp.json"

    echo -e "${CYAN}MCP Server Management${NC}"
    echo ""
    echo "1. View current configuration"
    echo "2. Edit configuration"
    echo "3. Add common MCP server"
    echo "4. Test MCP connection"
    echo "5. Back to shell"
    echo ""
    read -r "choice?Select option: "

    case $choice in
        1)
            echo ""
            echo -e "${GREEN}Current MCP Configuration:${NC}"
            cat "${MCP_CONFIG}" 2>/dev/null | jq . || echo "No configuration found"
            ;;
        2)
            ${EDITOR:-nano} "${MCP_CONFIG}"
            ;;
        3)
            add_common_mcp
            ;;
        4)
            echo -e "${YELLOW}Testing MCP... (start a Claude session to verify)${NC}"
            ;;
        5)
            return
            ;;
    esac
}

# Add common MCP servers
add_common_mcp() {
    echo ""
    echo "Common MCP Servers:"
    echo "1. GitHub"
    echo "2. Filesystem (extended access)"
    echo "3. PostgreSQL"
    echo "4. Brave Search"
    echo "5. Home Assistant"
    echo "6. Notion"
    echo "7. Custom"
    echo ""
    read -r "mcp_choice?Select MCP to add: "

    echo -e "${YELLOW}Please edit /app/data/mcp/mcp.json to add the MCP server.${NC}"
    echo -e "${YELLOW}Documentation: https://docs.anthropic.com/en/docs/claude-code/mcp${NC}"
}

# Main logic
main() {
    print_banner

    # Check if first run
    if is_first_run; then
        echo -e "${YELLOW}First run detected! Let's set up your environment.${NC}"
        echo ""
        read -r "run_setup?Run setup wizard now? [Y/n]: "

        if [[ "${run_setup}" != "n" && "${run_setup}" != "N" ]]; then
            run_setup_wizard
        else
            echo -e "${YELLOW}Skipping setup. Run 'cc-setup' later to configure.${NC}"
            echo "Initialized: $(date '+%Y-%m-%d %H:%M:%S') (setup skipped)" > "${FIRST_RUN_FLAG}"
        fi
    fi

    # Check for API key
    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        echo -e "${YELLOW}Note: ANTHROPIC_API_KEY not set. Claude will prompt for authentication.${NC}"
        echo ""
    fi

    # Start interactive shell (loads .zshrc with all aliases)
    exec /bin/zsh
}

# Check for setup-only mode (called from .zshrc cc-setup alias)
if [ "$1" = "--setup-only" ]; then
    run_setup_wizard
    exit 0
fi

# Run main
main
