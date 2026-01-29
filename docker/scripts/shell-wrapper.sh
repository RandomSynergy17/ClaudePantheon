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
CLAUDE_CONFIG_DIR="${DATA_DIR}/claude"
MCP_CONFIG="${DATA_DIR}/mcp/mcp.json"

# Community content source
COMMUNITY_REPO_URL="https://raw.githubusercontent.com/affaan-m/everything-claude-code/main"

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
    echo -e "  ${GREEN}cc-new${NC}        Start a NEW Claude session"
    echo -e "  ${GREEN}cc${NC}            Continue last session"
    echo -e "  ${GREEN}cc-resume${NC}     Resume specific session"
    echo -e "  ${GREEN}cc-list${NC}       List all sessions"
    echo -e "  ${GREEN}cc-setup${NC}      Re-run CLAUDE.md setup wizard"
    echo -e "  ${GREEN}cc-mcp${NC}        Manage MCP servers"
    echo -e "  ${GREEN}cc-community${NC}  Install community skills & commands"
    echo ""
}

# Check if first run
is_first_run() {
    [ ! -f "${FIRST_RUN_FLAG}" ]
}

# ═══════════════════════════════════════════════════════════
# Network & Download Utilities
# ═══════════════════════════════════════════════════════════

check_network() {
    if curl -fsSL --connect-timeout 3 "https://raw.githubusercontent.com" -o /dev/null 2>/dev/null; then
        return 0
    else
        echo -e "${YELLOW}No network access detected. This feature requires internet connectivity.${NC}"
        return 1
    fi
}

download_community_file() {
    local base_url="$1"
    local remote_path="$2"
    local local_dir="$3"
    local local_filename="${4:-$(basename "$remote_path")}"

    mkdir -p "$local_dir"
    local target="$local_dir/$local_filename"

    if [ -f "$target" ]; then
        echo -e "  ${YELLOW}Already exists: $local_filename (skipping)${NC}"
        return 0
    fi

    if curl -fsSL --connect-timeout 5 --max-time 15 \
        "${base_url}/${remote_path}" -o "$target" 2>/dev/null; then
        # Verify non-empty download (catches truncated/empty responses)
        if [ ! -s "$target" ]; then
            echo -e "  ${RED}✗ Empty file: $remote_path${NC}"
            rm -f "$target"
            return 1
        fi
        echo -e "  ${GREEN}✓ Downloaded: $local_filename${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Failed: $remote_path${NC}"
        rm -f "$target"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# Community Content Installer
# ═══════════════════════════════════════════════════════════

write_attribution() {
    local attr_file="${CLAUDE_CONFIG_DIR}/COMMUNITY_CREDITS.md"
    cat > "$attr_file" << 'ATTR'
# Community Content Credits

The following Claude Code skills, commands, and rules were installed from
community-maintained open-source repositories.

## Sources

### everything-claude-code
- **Author:** Affaan M
- **Repository:** https://github.com/affaan-m/everything-claude-code
- **License:** See repository for details
- **Content:** Commands, skills, rules, agents

### claude-code-best-practice
- **Author:** Shan Raisshan (shanraisshan)
- **Repository:** https://github.com/shanraisshan/claude-code-best-practice
- **Content:** Architecture patterns, CLAUDE.md best practices, workflow guidance

## About

These community resources were installed via the ClaudePantheon community
content wizard (`cc-community`). ClaudePantheon does not claim authorship
of this content — all credit belongs to the original authors above.
ATTR
}

install_community_content() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       ClaudePantheon - Community Content Installer       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Install curated Claude Code commands and rules from the community."
    echo -e "${BLUE}Sources:${NC}"
    echo -e "  ${BLUE}•${NC} github.com/affaan-m/everything-claude-code"
    echo -e "  ${BLUE}•${NC} github.com/shanraisshan/claude-code-best-practice"
    echo ""

    if ! check_network; then
        return 1
    fi

    echo -e "${MAGENTA}  COMMANDS${NC} (slash commands for Claude Code):"
    echo -e "    ${GREEN} 1.${NC} /plan            Plan before coding"
    echo -e "    ${GREEN} 2.${NC} /code-review     Structured code review"
    echo -e "    ${GREEN} 3.${NC} /tdd             Test-driven development"
    echo -e "    ${GREEN} 4.${NC} /build-fix       Fix build errors iteratively"
    echo -e "    ${GREEN} 5.${NC} /refactor-clean  Clean up and remove dead code"
    echo -e "    ${GREEN} 6.${NC} /verify          Verify changes before committing"
    echo -e "    ${GREEN} 7.${NC} /checkpoint      Save verification state"
    echo ""
    echo -e "${MAGENTA}  RULES${NC} (always-active guidelines):"
    echo -e "    ${GREEN} 8.${NC} Security         Prevent credential leaks, injection flaws"
    echo -e "    ${GREEN} 9.${NC} Coding Style     Clean code standards"
    echo -e "    ${GREEN}10.${NC} Testing          Test coverage requirements"
    echo -e "    ${GREEN}11.${NC} Git Workflow     Clean commit practices"
    echo ""
    echo -e "${MAGENTA}  BUNDLES:${NC}"
    echo -e "    ${GREEN}[E]${NC} Essentials   /plan, /code-review, /verify + security rule"
    echo -e "    ${GREEN}[A]${NC} All          Everything listed above"
    echo ""
    read -r "selection?  Select (e.g. \"1 2 8\" or \"E\" or \"A\", Enter to skip): "

    if [ -z "$selection" ]; then
        echo -e "${YELLOW}Skipped community content installation.${NC}"
        return 0
    fi

    # Expand bundles
    case "$selection" in
        [Ee]) selection="1 2 6 8" ;;
        [Aa]) selection="1 2 3 4 5 6 7 8 9 10 11" ;;
    esac

    local installed=0

    for item in ${=selection}; do
        case "$item" in
            1) download_community_file "$COMMUNITY_REPO_URL" "commands/plan.md" "${CLAUDE_CONFIG_DIR}/commands" && ((installed++)) ;;
            2) download_community_file "$COMMUNITY_REPO_URL" "commands/code-review.md" "${CLAUDE_CONFIG_DIR}/commands" && ((installed++)) ;;
            3) download_community_file "$COMMUNITY_REPO_URL" "commands/tdd.md" "${CLAUDE_CONFIG_DIR}/commands" && ((installed++)) ;;
            4) download_community_file "$COMMUNITY_REPO_URL" "commands/build-fix.md" "${CLAUDE_CONFIG_DIR}/commands" && ((installed++)) ;;
            5) download_community_file "$COMMUNITY_REPO_URL" "commands/refactor-clean.md" "${CLAUDE_CONFIG_DIR}/commands" && ((installed++)) ;;
            6) download_community_file "$COMMUNITY_REPO_URL" "commands/verify.md" "${CLAUDE_CONFIG_DIR}/commands" && ((installed++)) ;;
            7) download_community_file "$COMMUNITY_REPO_URL" "commands/checkpoint.md" "${CLAUDE_CONFIG_DIR}/commands" && ((installed++)) ;;
            8) download_community_file "$COMMUNITY_REPO_URL" "rules/security.md" "${CLAUDE_CONFIG_DIR}/rules" && ((installed++)) ;;
            9) download_community_file "$COMMUNITY_REPO_URL" "rules/coding-style.md" "${CLAUDE_CONFIG_DIR}/rules" && ((installed++)) ;;
            10) download_community_file "$COMMUNITY_REPO_URL" "rules/testing.md" "${CLAUDE_CONFIG_DIR}/rules" && ((installed++)) ;;
            11) download_community_file "$COMMUNITY_REPO_URL" "rules/git-workflow.md" "${CLAUDE_CONFIG_DIR}/rules" && ((installed++)) ;;
            *) echo -e "  ${YELLOW}Unknown item: $item (skipping)${NC}" ;;
        esac
    done

    if [ "$installed" -gt 0 ]; then
        write_attribution
        echo ""
        echo -e "${GREEN}✓ Installed $installed item(s)${NC}"
        echo -e "  Commands: ${CLAUDE_CONFIG_DIR}/commands/"
        echo -e "  Rules:    ${CLAUDE_CONFIG_DIR}/rules/"
        echo -e "  Credits:  ${CLAUDE_CONFIG_DIR}/COMMUNITY_CREDITS.md"
    else
        echo -e "${YELLOW}No items were installed.${NC}"
    fi
    echo ""
}

# ═══════════════════════════════════════════════════════════
# MCP Auto-Configuration
# ═══════════════════════════════════════════════════════════

add_mcp_server() {
    local server_name="$1"
    local server_json="$2"

    if jq -e ".mcpServers.\"${server_name}\"" "$MCP_CONFIG" >/dev/null 2>&1; then
        echo -e "  ${YELLOW}Server '${server_name}' already configured. Overwrite? [y/N]${NC}"
        read -r "overwrite? "
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            echo -e "  Skipped ${server_name}."
            return 0
        fi
    fi

    local tmp_file=$(mktemp) || {
        echo -e "  ${RED}✗ Failed to create temp file${NC}"
        return 1
    }
    if jq --argjson server "$server_json" \
       ".mcpServers.\"${server_name}\" = \$server" \
       "$MCP_CONFIG" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$MCP_CONFIG"
        echo -e "  ${GREEN}✓ Added MCP server: ${server_name}${NC}"
        return 0
    else
        rm -f "$tmp_file"
        echo -e "  ${RED}✗ Failed to add ${server_name} (JSON error)${NC}"
        return 1
    fi
}

configure_mcp_github() {
    echo -e "${CYAN}GitHub${NC} — PR management, issue tracking, repo operations"
    echo "  Requires: Personal Access Token (github.com/settings/tokens)"
    read -r "gh_token?  Enter GitHub PAT (Enter to skip): "
    [ -z "$gh_token" ] && echo "  Skipped." && return 0
    local json=$(jq -n --arg token "$gh_token" \
        '{command: "npx", args: ["-y", "@modelcontextprotocol/server-github"], env: {GITHUB_PERSONAL_ACCESS_TOKEN: $token}}')
    add_mcp_server "github" "$json"
}

configure_mcp_brave() {
    echo -e "${CYAN}Brave Search${NC} — Web search from Claude"
    echo "  Requires: API Key (brave.com/search/api)"
    read -r "brave_key?  Enter Brave API Key (Enter to skip): "
    [ -z "$brave_key" ] && echo "  Skipped." && return 0
    local json=$(jq -n --arg key "$brave_key" \
        '{command: "npx", args: ["-y", "@modelcontextprotocol/server-brave-search"], env: {BRAVE_API_KEY: $key}}')
    add_mcp_server "brave-search" "$json"
}

configure_mcp_memory() {
    echo -e "${CYAN}Memory${NC} — Persistent memory across Claude sessions"
    echo "  No configuration needed."
    add_mcp_server "memory" '{"command":"npx","args":["-y","@modelcontextprotocol/server-memory"]}'
}

configure_mcp_postgres() {
    echo -e "${CYAN}PostgreSQL${NC} — Query databases directly from Claude"
    echo "  Requires: Connection URL (e.g., postgresql://user:pass@host:5432/db)"
    read -r "pg_url?  Enter PostgreSQL URL (Enter to skip): "
    [ -z "$pg_url" ] && echo "  Skipped." && return 0
    local json=$(jq -n --arg url "$pg_url" \
        '{command: "npx", args: ["-y", "@modelcontextprotocol/server-postgres", $url]}')
    add_mcp_server "postgres" "$json"
}

configure_mcp_filesystem() {
    echo -e "${CYAN}Filesystem (extra paths)${NC} — Give Claude access to additional directories"
    echo "  The workspace (/app/data/workspace) is already accessible."
    read -r "fs_path?  Enter additional path (Enter to skip): "
    [ -z "$fs_path" ] && echo "  Skipped." && return 0
    local json=$(jq -n --arg path "$fs_path" \
        '{command: "npx", args: ["-y", "@modelcontextprotocol/server-filesystem", $path]}')
    add_mcp_server "filesystem-extra" "$json"
}

configure_mcp_puppeteer() {
    echo -e "${CYAN}Puppeteer${NC} — Browser automation and web scraping"
    echo "  No configuration needed."
    add_mcp_server "puppeteer" '{"command":"npx","args":["-y","@modelcontextprotocol/server-puppeteer"]}'
}

configure_mcp_context7() {
    echo -e "${CYAN}Context7${NC} — Up-to-date library documentation lookup"
    echo "  No configuration needed."
    add_mcp_server "context7" '{"command":"npx","args":["-y","@upstash/context7-mcp@latest"]}'
}

add_common_mcp() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         ClaudePantheon - MCP Server Setup                ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Configure MCP servers for Claude Code integrations."
    echo -e "Current config: ${MCP_CONFIG}"
    echo ""
    echo -e "  ${GREEN}1.${NC} GitHub              (needs PAT)"
    echo -e "  ${GREEN}2.${NC} Brave Search        (needs API key)"
    echo -e "  ${GREEN}3.${NC} Memory              (no config needed)"
    echo -e "  ${GREEN}4.${NC} PostgreSQL           (needs connection URL)"
    echo -e "  ${GREEN}5.${NC} Filesystem (extra)   (needs path)"
    echo -e "  ${GREEN}6.${NC} Puppeteer            (no config needed)"
    echo -e "  ${GREEN}7.${NC} Context7             (no config needed)"
    echo ""
    echo -e "  ${GREEN}[Q]${NC} Quick setup — Memory + Context7 (no tokens required)"
    echo -e "  ${GREEN}[A]${NC} All — configure each one"
    echo ""
    read -r "mcp_selection?  Select (e.g. \"1 3 7\" or \"Q\" or \"A\", Enter to skip): "

    if [ -z "$mcp_selection" ]; then
        echo -e "${YELLOW}Skipped MCP configuration.${NC}"
        return 0
    fi

    case "$mcp_selection" in
        [Qq]) mcp_selection="3 7" ;;
        [Aa]) mcp_selection="1 2 3 4 5 6 7" ;;
    esac

    echo ""
    for item in ${=mcp_selection}; do
        case "$item" in
            1) configure_mcp_github ;;
            2) configure_mcp_brave ;;
            3) configure_mcp_memory ;;
            4) configure_mcp_postgres ;;
            5) configure_mcp_filesystem ;;
            6) configure_mcp_puppeteer ;;
            7) configure_mcp_context7 ;;
            *) echo -e "  ${YELLOW}Unknown option: $item${NC}" ;;
        esac
        echo ""
    done

    echo -e "${GREEN}MCP configuration updated.${NC}"
    echo -e "View with: ${CYAN}jq . ${MCP_CONFIG}${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════
# Setup Wizard
# ═══════════════════════════════════════════════════════════

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

    echo ""

    # Community content installation
    echo -e "${GREEN}11. Install community Claude Code content?${NC}"
    echo -e "   Curated commands (/plan, /code-review, /tdd, etc.) and rules"
    echo -e "   from the open-source community. Requires internet."
    read -r "install_community?   Install now? [y/N]: "

    if [[ "$install_community" == "y" || "$install_community" == "Y" ]]; then
        install_community_content
    fi

    echo ""

    # MCP server configuration
    echo -e "${GREEN}12. Configure MCP servers?${NC}"
    echo -e "   Auto-configure GitHub, search, memory, and other integrations."
    read -r "configure_mcp?   Configure now? [y/N]: "

    if [[ "$configure_mcp" == "y" || "$configure_mcp" == "Y" ]]; then
        add_common_mcp
    fi

    # Mark as initialized with timestamp
    echo "Initialized: $(date '+%Y-%m-%d %H:%M:%S')" > "${FIRST_RUN_FLAG}"

    echo ""
    echo -e "${GREEN}✓ Setup complete!${NC}"
    echo -e "${GREEN}✓ CLAUDE.md created at: ${CLAUDE_MD_PATH}${NC}"
    echo ""
    echo -e "${CYAN}You can edit this file anytime or run 'cc-setup' to reconfigure.${NC}"
    echo -e "${CYAN}Run 'cc-community' to install more community content later.${NC}"
    echo -e "${CYAN}Run 'cc-mcp' to manage MCP servers later.${NC}"
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
cc            # Continue last Claude session
cc-new        # Start fresh session
cc-resume     # Resume specific session
cc-list       # List sessions
cc-setup      # Re-run setup wizard
cc-mcp        # Manage MCP servers
cc-community  # Install community skills & commands
\`\`\`

### File Locations
- **Workspace:** /app/data/workspace
- **MCP Config:** /app/data/mcp/mcp.json
- **Session History:** /app/data/claude/
- **Community Content:** /app/data/claude/commands/, /app/data/claude/rules/
- **SSH Keys:** /app/data/ssh/
- **Logs:** /app/data/logs/
- **Custom Packages:** /app/data/custom-packages.txt
CLAUDE_MD

    echo -e "${GREEN}✓ CLAUDE.md generated${NC}"
}

# MCP management (elaborate version for first-run context)
claude_mcp() {
    echo -e "${CYAN}MCP Server Management${NC}"
    echo ""
    echo "1. View current configuration"
    echo "2. Edit configuration"
    echo "3. Add/configure MCP server"
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

# ═══════════════════════════════════════════════════════════
# Factory Reset
# ═══════════════════════════════════════════════════════════

# Word list for challenge phrase (short, easy to type, unambiguous)
RESET_WORDS=(
    brick flame orbit delta surge
    maple drift cloud ember forge
    stone river pixel chord blaze
    crane solar frost lunar spark
    prime vault lance ridge shore
    steel arrow coral plume flint
    scope tiger cedar prism quartz
)

generate_challenge_words() {
    local words=()
    local count=${#RESET_WORDS[@]}
    for i in 1 2 3; do
        local idx=$((RANDOM % count + 1))
        words+=("${RESET_WORDS[$idx]}")
    done
    echo "${words[*]}"
}

factory_reset() {
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║          ClaudePantheon - FACTORY RESET                  ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}WARNING: This will delete ALL data and return to a fresh install.${NC}"
    echo ""
    echo -e "  The following will be ${RED}PERMANENTLY DELETED${NC}:"
    echo -e "    • Workspace files and projects"
    echo -e "    • Claude session history and conversations"
    echo -e "    • MCP server configuration"
    echo -e "    • Community commands, rules, and skills"
    echo -e "    • Custom packages list"
    echo -e "    • nginx, webroot, and landing page customizations"
    echo -e "    • Shell configuration (.zshrc customizations)"
    echo -e "    • FileBrowser database"
    echo -e "    • Git configuration"
    echo -e "    • Logs and caches"
    echo ""
    echo -e "  The following will be ${GREEN}PRESERVED${NC}:"
    echo -e "    • SSH keys (${DATA_DIR}/ssh/)"
    echo -e "    • Host volume mounts (/mounts/)"
    echo ""
    echo -e "  After reset, the container will restart and run the first-run"
    echo -e "  setup wizard as if freshly installed."
    echo ""

    # ── Confirmation 1: Are you sure? ──
    echo -e "${YELLOW}Step 1/3: Are you sure you want to factory reset?${NC}"
    read -r "confirm1?  Type 'yes' to continue (anything else to abort): "
    if [ "$confirm1" != "yes" ]; then
        echo -e "${GREEN}Factory reset aborted.${NC}"
        return 0
    fi
    echo ""

    # ── Confirmation 2: Are you REALLY sure? ──
    echo -e "${YELLOW}Step 2/3: This action CANNOT be undone.${NC}"
    read -r "confirm2?  Type 'YES' (uppercase) to confirm: "
    if [ "$confirm2" != "YES" ]; then
        echo -e "${GREEN}Factory reset aborted.${NC}"
        return 0
    fi
    echo ""

    # ── Confirmation 3: Challenge phrase ──
    local challenge=$(generate_challenge_words)
    echo -e "${YELLOW}Step 3/3: Type the following words exactly to proceed:${NC}"
    echo ""
    echo -e "    ${CYAN}${challenge}${NC}"
    echo ""
    read -r "confirm3?  > "
    if [ "$confirm3" != "$challenge" ]; then
        echo -e "${RED}Challenge phrase does not match. Factory reset aborted.${NC}"
        return 1
    fi
    echo ""

    # ── Optional: Also wipe SSH keys? ──
    echo -e "${YELLOW}SSH keys are preserved by default.${NC}"
    echo -e "Do you also want to delete SSH keys? (requires double confirmation)"
    read -r "wipe_ssh?  Delete SSH keys too? [y/N]: "
    local delete_ssh=false
    if [[ "$wipe_ssh" == "y" || "$wipe_ssh" == "Y" ]]; then
        echo -e "${RED}Confirm: Delete ALL SSH keys permanently?${NC}"
        read -r "wipe_ssh2?  Type 'DELETE SSH' to confirm: "
        if [ "$wipe_ssh2" = "DELETE SSH" ]; then
            delete_ssh=true
            echo -e "  ${RED}SSH keys WILL be deleted.${NC}"
        else
            echo -e "  ${GREEN}SSH keys will be preserved.${NC}"
        fi
    fi
    echo ""

    # ── Execute reset ──
    echo -e "${RED}Performing factory reset...${NC}"
    echo ""

    # Back up SSH if preserving
    local ssh_backup=""
    if [ "$delete_ssh" = "false" ] && [ -d "${DATA_DIR}/ssh" ]; then
        ssh_backup=$(mktemp -d) || {
            echo -e "  ${RED}✗ Failed to create temp dir for SSH backup${NC}"
            echo -e "  ${RED}Factory reset aborted to protect SSH keys.${NC}"
            return 1
        }
        if ! cp -a "${DATA_DIR}/ssh/." "$ssh_backup/" 2>/dev/null; then
            echo -e "  ${RED}✗ Failed to backup SSH keys${NC}"
            rm -rf "$ssh_backup"
            echo -e "  ${RED}Factory reset aborted to protect SSH keys.${NC}"
            return 1
        fi
        echo -e "  ${GREEN}✓ SSH keys backed up${NC}"
    fi

    # Delete everything under /app/data/
    # Use find to delete contents without removing the mount point itself
    if ! find "${DATA_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +; then
        echo -e "  ${YELLOW}⚠ Some files could not be deleted (check permissions)${NC}"
    fi
    echo -e "  ${GREEN}✓ Data directory wiped${NC}"

    # Restore SSH if preserved
    if [ -n "$ssh_backup" ] && [ -d "$ssh_backup" ]; then
        mkdir -p "${DATA_DIR}/ssh"
        cp -a "$ssh_backup/." "${DATA_DIR}/ssh/" 2>/dev/null
        rm -rf "$ssh_backup"
        echo -e "  ${GREEN}✓ SSH keys restored${NC}"
    fi

    echo ""
    echo -e "${GREEN}Factory reset complete.${NC}"
    echo -e "${CYAN}The container will now restart to re-initialize from defaults...${NC}"
    echo ""

    # Signal container restart by killing the main process (PID 1 = ttyd)
    # This causes the container to stop, and Docker's restart policy brings it back
    sleep 2
    kill 1 2>/dev/null || sudo kill 1 2>/dev/null
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

# CLI argument handling
if [ "$1" = "--setup-only" ]; then
    run_setup_wizard
    exit 0
fi

if [ "$1" = "--community-only" ]; then
    install_community_content
    exit 0
fi

if [ "$1" = "--mcp-add" ]; then
    add_common_mcp
    exit 0
fi

if [ "$1" = "--factory-reset" ]; then
    factory_reset
    exit $?
fi

# Run main
main
