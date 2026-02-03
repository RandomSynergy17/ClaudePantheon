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
    echo -e "  ${GREEN}cc${NC}            Continue last session (most recent)"
    echo -e "  ${GREEN}cc-resume${NC}     Resume a session (interactive picker)"
    echo -e "  ${GREEN}cc-setup${NC}      Re-run CLAUDE.md setup wizard"
    echo -e "  ${GREEN}cc-mcp${NC}        Manage MCP servers"
    echo -e "  ${GREEN}cc-community${NC}  Install community skills & commands"
    echo -e "  ${GREEN}cc-help${NC}       Show all commands"
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
    # Pre-compute dynamic values to avoid shell expansion in heredoc
    local _timestamp
    _timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local _mcp_section=""
    if [ -n "${mcp_systems}" ]; then
        _mcp_section="
### Configured MCP Servers
Check \`/app/data/mcp/mcp.json\` for current configuration.
"
    fi

    # Use quoted heredoc ('CLAUDE_MD') to prevent shell expansion of user input
    cat > "${CLAUDE_MD_PATH}" << 'CLAUDE_MD'
# __WORKSPACE_NAME__

> Auto-generated by ClaudePantheon Setup Wizard
> Last updated: __TIMESTAMP__

## About This Workspace

**Purpose:** __PRIMARY_PURPOSE__

**User Context:** __USER_CONTEXT__

## Technical Environment

### Technology Stack
__TECH_STACK__

### Coding Style Preferences
__CODING_STYLE__

### Communication Style
__COMM_STYLE__

## Session Continuity

This is a **persistent Claude Code environment**. Key behaviors:

1. **Always continue from the last session** - Use context from previous conversations
2. **Remember decisions made** - Don't re-ask about settled preferences
3. **Track ongoing work** - Reference and continue incomplete tasks
4. **Maintain consistency** - Use the same patterns and conventions throughout

## Active Projects & Focus Areas

__ACTIVE_PROJECTS__

## MCP Integrations

__MCP_SYSTEMS__
__MCP_SECTION__

## Conventions & Rules

__CONVENTIONS__

## Important Notes

__ADDITIONAL_CONTEXT__

---

## Session Log

<!-- Claude: Use this section to track important decisions and state across sessions -->

### Initialized
- **Date:** __TIMESTAMP__
- **Environment:** Docker persistent container
- **Access:** ttyd web terminal

### Recent Activity
<!-- This section can be updated to track ongoing work -->

---

## Quick Reference

### Common Commands
```bash
cc            # Continue last session (most recent)
cc-new        # Start fresh session
cc-resume     # Resume a session (interactive picker)
cc-setup      # Re-run setup wizard
cc-mcp        # Manage MCP servers
cc-community  # Install community skills & commands
cc-help       # Show all commands
```

### File Locations
- **Workspace:** /app/data/workspace
- **MCP Config:** /app/data/mcp/mcp.json
- **Session History:** /app/data/claude/
- **Community Content:** /app/data/claude/commands/, /app/data/claude/rules/
- **SSH Keys:** /app/data/ssh/
- **Logs:** /app/data/logs/
- **Custom Packages:** /app/data/custom-packages.txt
CLAUDE_MD

    # Substitute placeholders with actual values using sed
    # Sanitize user input to prevent sed injection (escape | & \ characters)
    local safe_workspace_name=$(printf '%s' "$workspace_name" | sed 's/[|&\\]/\\&/g')
    local safe_primary_purpose=$(printf '%s' "$primary_purpose" | sed 's/[|&\\]/\\&/g')
    local safe_user_context=$(printf '%s' "$user_context" | sed 's/[|&\\]/\\&/g')
    # Using | as delimiter to avoid conflicts with / in paths
    sed -i "s|__WORKSPACE_NAME__|${safe_workspace_name}|g" "${CLAUDE_MD_PATH}"
    sed -i "s|__TIMESTAMP__|${_timestamp}|g" "${CLAUDE_MD_PATH}"
    sed -i "s|__PRIMARY_PURPOSE__|${safe_primary_purpose}|g" "${CLAUDE_MD_PATH}"
    sed -i "s|__USER_CONTEXT__|${safe_user_context}|g" "${CLAUDE_MD_PATH}"
    # Multi-line substitutions use a temp approach
    local _tmpfile
    _tmpfile=$(mktemp)
    # For multi-line variables, use awk for safe substitution
    awk -v val="${tech_stack}" '{gsub(/__TECH_STACK__/, val)}1' "${CLAUDE_MD_PATH}" > "$_tmpfile" && mv "$_tmpfile" "${CLAUDE_MD_PATH}"
    awk -v val="${coding_style}" '{gsub(/__CODING_STYLE__/, val)}1' "${CLAUDE_MD_PATH}" > "$_tmpfile" && mv "$_tmpfile" "${CLAUDE_MD_PATH}"
    awk -v val="${comm_style}" '{gsub(/__COMM_STYLE__/, val)}1' "${CLAUDE_MD_PATH}" > "$_tmpfile" && mv "$_tmpfile" "${CLAUDE_MD_PATH}"
    awk -v val="${active_projects:-No active projects specified yet. Update this section as needed.}" '{gsub(/__ACTIVE_PROJECTS__/, val)}1' "${CLAUDE_MD_PATH}" > "$_tmpfile" && mv "$_tmpfile" "${CLAUDE_MD_PATH}"
    awk -v val="${mcp_systems:-No MCP integrations configured yet.}" '{gsub(/__MCP_SYSTEMS__/, val)}1' "${CLAUDE_MD_PATH}" > "$_tmpfile" && mv "$_tmpfile" "${CLAUDE_MD_PATH}"
    awk -v val="${_mcp_section}" '{gsub(/__MCP_SECTION__/, val)}1' "${CLAUDE_MD_PATH}" > "$_tmpfile" && mv "$_tmpfile" "${CLAUDE_MD_PATH}"
    awk -v val="${conventions:-No specific conventions defined yet.}" '{gsub(/__CONVENTIONS__/, val)}1' "${CLAUDE_MD_PATH}" > "$_tmpfile" && mv "$_tmpfile" "${CLAUDE_MD_PATH}"
    awk -v val="${additional_context:-}" '{gsub(/__ADDITIONAL_CONTEXT__/, val)}1' "${CLAUDE_MD_PATH}" > "$_tmpfile" && mv "$_tmpfile" "${CLAUDE_MD_PATH}"
    rm -f "$_tmpfile"

    echo -e "${GREEN}✓ CLAUDE.md generated${NC}"
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
    echo -e "  ${CYAN}Tip: Run 'make backup' from the host first to create a restore point.${NC}"
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

    # Unmount any active rclone mounts before wiping data
    if [ -d /mounts/rclone ]; then
        local had_mounts=false
        for mount_dir in /mounts/rclone/*/; do
            [ -d "$mount_dir" ] || continue
            if mountpoint -q "$mount_dir" 2>/dev/null || ! timeout 3 stat "$mount_dir" >/dev/null 2>&1; then
                local mname=$(basename "$mount_dir")
                echo -e "  Unmounting rclone: ${mname}"
                timeout 5 fusermount -u "$mount_dir" 2>/dev/null || \
                    fusermount -uz "$mount_dir" 2>/dev/null || true
                had_mounts=true
            fi
        done
        if [ "$had_mounts" = "true" ]; then
            # Wait for rclone FUSE processes to fully exit
            local wait_count=0
            while pgrep -x rclone >/dev/null 2>&1 && [ $wait_count -lt 10 ]; do
                sleep 1
                wait_count=$((wait_count + 1))
            done
            if pgrep -x rclone >/dev/null 2>&1; then
                echo -e "  ${YELLOW}Forcing rclone processes to stop...${NC}"
                pkill -9 -x rclone 2>/dev/null || true
                sleep 1
            fi
        fi
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

# ═══════════════════════════════════════════════════════════
# Remote Mount Manager (rclone)
# ═══════════════════════════════════════════════════════════

RCLONE_MOUNT_BASE="/mounts/rclone"
RCLONE_CONF="${DATA_DIR}/rclone/rclone.conf"
RCLONE_AUTOMOUNT="${DATA_DIR}/rclone/automount.conf"

# Validate rclone remote name (shared helper)
rmount_validate_name() {
    local name="$1"
    if [ -z "$name" ]; then
        return 1
    fi
    if ! echo "$name" | grep -qE '^[a-zA-Z0-9_-]+$'; then
        echo -e "${RED}Invalid remote name: '${name}'${NC}"
        echo -e "  Use only letters, numbers, dash (-), and underscore (_). Example: ${GREEN}my-remote${NC}"
        return 1
    fi
    return 0
}

# Safe password read that restores terminal echo on Ctrl+C
# Usage: _read_password "prompt text" variable_name
# Returns 1 if cancelled via Ctrl+C, 0 on success
_read_password() {
    local prompt="$1"
    local varname="$2"
    local _pw_cancelled=false
    # Use flag variable instead of return inside trap (zsh compatibility)
    trap 'stty echo 2>/dev/null; echo ""; echo -e "${YELLOW}Cancelled.${NC}"; _pw_cancelled=true' INT
    read -rs "${varname}?${prompt}"
    echo " [hidden]"
    trap - INT
    if [ "$_pw_cancelled" = "true" ]; then
        return 1
    fi
}

# Check if FUSE device is available
rmount_check_fuse() {
    if [ ! -c /dev/fuse ]; then
        echo -e "${RED}FUSE device not available.${NC}"
        echo ""
        echo -e "To enable rclone remote mounts, update ${CYAN}docker-compose.yml${NC}:"
        echo ""
        echo -e "  1. Uncomment ${GREEN}devices: [/dev/fuse]${NC}"
        echo -e "  2. Uncomment ${GREEN}cap_add: [SYS_ADMIN]${NC}"
        echo -e "  3. Uncomment ${GREEN}apparmor:unconfined${NC} in security_opt"
        echo -e "  4. Set ${GREEN}ENABLE_RCLONE=true${NC} in .env"
        echo -e "  5. Run: ${CYAN}make rebuild${NC}"
        echo ""
        return 1
    fi
    return 0
}

# List active mounts and configured remotes
rmount_list() {
    echo -e "${CYAN}Active rclone mounts:${NC}"
    echo ""
    local found=false
    for mount_dir in ${RCLONE_MOUNT_BASE}/*/; do
        [ -d "$mount_dir" ] || continue
        local name=$(basename "$mount_dir")
        if mountpoint -q "$mount_dir" 2>/dev/null; then
            local auto_marker=""
            if grep -q "^${name}:" "$RCLONE_AUTOMOUNT" 2>/dev/null; then
                auto_marker=" ${GREEN}[auto]${NC}"
            fi
            echo -e "  ${GREEN}●${NC} ${name} -> ${mount_dir}${auto_marker}"
            found=true
        elif ! timeout 3 stat "$mount_dir" >/dev/null 2>&1; then
            echo -e "  ${YELLOW}✗${NC} ${name} -> ${mount_dir} ${YELLOW}(dead FUSE mount — cleaned on next startup)${NC}"
            found=true
        fi
    done
    if [ "$found" = "false" ]; then
        echo -e "  ${YELLOW}No active mounts.${NC}"
    fi
    echo ""

    echo -e "${CYAN}Configured remotes (rclone.conf):${NC}"
    local remotes=$(rclone listremotes 2>/dev/null)
    if [ -n "$remotes" ]; then
        echo "$remotes" | while read -r r; do
            echo -e "  ${GREEN}•${NC} $r"
        done
    else
        echo -e "  ${YELLOW}No remotes configured. Use 'Add remote' to set one up.${NC}"
    fi
    echo ""
}

# Offer to mount a newly created remote immediately
# Usage: _offer_mount "remote_name"
_offer_mount() {
    local rname="$1"
    echo ""
    read -r "mount_now?  Mount '${rname}' now? [Y/n]: "
    if [[ "$mount_now" != "n" && "$mount_now" != "N" ]]; then
        rmount_mount_direct "$rname"
    else
        echo -e "  Mount later with: ${CYAN}cc-rmount${NC} → Mount remote"
    fi
}

# Shared mount logic: acquire lock, mount, verify, report
# Usage: _do_rclone_mount <remote_spec> <mount_path> <cache_mode>
_do_rclone_mount() {
    local remote_spec="$1" mount_path="$2" cache_mode="$3"

    mkdir -p "$mount_path" 2>/dev/null || {
        echo -e "  ${RED}Cannot create mount directory: ${mount_path}${NC}"
        return 1
    }

    # Check if already mounted
    if mountpoint -q "$mount_path" 2>/dev/null; then
        echo -e "  ${YELLOW}Already mounted at ${mount_path}${NC}"
        return 0
    fi

    echo -e "  Mounting ${CYAN}${remote_spec}${NC} -> ${CYAN}${mount_path}${NC} (cache: ${cache_mode})..."

    # Acquire lock to prevent races with automount
    local RCLONE_LOCKFILE="/tmp/rclone-mount.lock"
    exec 8>"$RCLONE_LOCKFILE"
    if ! flock -w 10 8; then
        echo -e "  ${RED}Could not acquire mount lock (automount may be running). Try again shortly.${NC}"
        exec 8>&-
        return 1
    fi

    if rclone mount "$remote_spec" "$mount_path" \
        --daemon \
        --allow-other \
        --vfs-cache-mode="$cache_mode"; then
        echo -n "  Verifying mount"
        local retries=0
        local mounted=false
        while [ $retries -lt 5 ]; do
            sleep 1; echo -n "."
            if mountpoint -q "$mount_path" 2>/dev/null; then mounted=true; break; fi
            retries=$((retries + 1))
        done
        echo ""
        if [ "$mounted" = "true" ]; then
            exec 8>&-
            echo -e "  ${GREEN}Mounted successfully.${NC}"
            echo -e "  Browse: ${CYAN}cd ${mount_path}${NC}"
            echo -e "  Unmount: ${CYAN}cc-rmount${NC} → Unmount"
            return 0
        else
            exec 8>&-
            echo -e "  ${RED}Mount command succeeded but mountpoint is not active after 5s.${NC}"
            echo -e "  Debug: ${CYAN}rclone ls ${remote_spec} --max-depth 1${NC}"
            return 1
        fi
    else
        exec 8>&-
        echo -e "  ${RED}Mount failed. Check remote config and FUSE support.${NC}"
        echo -e "  Debug: ${CYAN}rclone ls ${remote_spec} --max-depth 1${NC}"
        return 1
    fi
    exec 8>&-
}

# Mount a remote directly by name (used by _offer_mount after wizard)
rmount_mount_direct() {
    local rname="$1"
    _do_rclone_mount "${rname}:/" "${RCLONE_MOUNT_BASE}/${rname}" "writes"
}

# Quick setup: S3 / S3-compatible
rmount_quick_s3() {
    echo -e "\n${CYAN}Quick Setup: S3 / S3-Compatible Storage${NC}\n"
    read -r "s3_name?  Remote name (e.g., myaws): "
    rmount_validate_name "$s3_name" || return

    echo -e "  Provider options: AWS, Minio, Wasabi, DigitalOcean, Cloudflare, Other"
    read -r "s3_provider?  Provider [AWS]: "
    s3_provider="${s3_provider:-AWS}"
    read -r "s3_key?  Access Key ID: "
    [ -z "$s3_key" ] && echo -e "${YELLOW}Access Key ID required. Cancelled.${NC}" && return
    _read_password "  Secret Access Key: " s3_secret || return
    [ -z "$s3_secret" ] && echo -e "${YELLOW}Secret Access Key required. Cancelled.${NC}" && return
    read -r "s3_region?  Region [us-east-1]: "
    s3_region="${s3_region:-us-east-1}"
    read -r "s3_endpoint?  Endpoint URL (leave empty for AWS): "

    local -a rclone_args=(config create "$s3_name" s3
        provider "$s3_provider"
        access_key_id "$s3_key"
        secret_access_key "$s3_secret"
        region "$s3_region"
    )
    [ -n "$s3_endpoint" ] && rclone_args+=(endpoint "$s3_endpoint")
    rclone_args+=(--obscure)

    if rclone "${rclone_args[@]}"; then
        echo -e "\n${GREEN}✓ Remote '${s3_name}' saved to rclone.conf${NC}"
        _offer_mount "$s3_name"
    else
        echo -e "\n${RED}Failed to create remote. See error above.${NC}"
    fi
    unset s3_secret
}

# Quick setup: Google Drive
rmount_quick_gdrive() {
    echo -e "\n${CYAN}Quick Setup: Google Drive${NC}\n"
    echo -e "  ${YELLOW}Google Drive requires OAuth (browser login).${NC}"
    echo -e "  ${CYAN}On your laptop/desktop (not this container):${NC}"
    echo -e "    1. Install rclone: ${GREEN}curl https://rclone.org/install.sh | sudo bash${NC}"
    echo -e "    2. Run: ${GREEN}rclone authorize \"drive\"${NC}"
    echo -e "    3. Browser opens → log in to Google → approve access"
    echo -e "    4. Copy the full JSON token from terminal output"
    echo -e "    5. Paste it below"
    echo -e "    (Token looks like: ${CYAN}{\"access_token\":\"...\",\"token_type\":\"Bearer\",...}${NC})"
    echo ""
    read -r "gd_name?  Remote name (e.g., gdrive): "
    rmount_validate_name "$gd_name" || return

    echo ""
    echo -e "  ${GREEN}1.${NC} Paste token from 'rclone authorize'"
    echo -e "  ${GREEN}2.${NC} Launch full rclone config wizard"
    read -r "gd_method?  Select [2]: "

    if [ "${gd_method:-2}" = "1" ]; then
        read -r "gd_token?  Paste OAuth token JSON: "
        if [ -z "$gd_token" ]; then
            echo -e "${YELLOW}No token provided. Cancelled.${NC}"
            return
        fi
        # Validate JSON format
        if ! echo "$gd_token" | jq . >/dev/null 2>&1; then
            echo -e "${RED}Invalid JSON format. Token must be valid JSON.${NC}"
            echo -e "Run ${GREEN}rclone authorize \"drive\"${NC} on a machine with a browser and copy the full JSON output."
            return 1
        fi
        if rclone config create "$gd_name" drive token "$gd_token"; then
            echo -e "\n${GREEN}✓ Remote '${gd_name}' saved to rclone.conf${NC}"
            _offer_mount "$gd_name"
        else
            echo -e "\n${RED}Failed to create remote. See error above.${NC}"
        fi
    else
        echo -e "\n${CYAN}Launching rclone config for Google Drive...${NC}\n"
        rclone config
    fi
}

# Quick setup: SFTP
rmount_quick_sftp() {
    echo -e "\n${CYAN}Quick Setup: SFTP${NC}\n"
    read -r "sftp_name?  Remote name (e.g., myserver): "
    rmount_validate_name "$sftp_name" || return

    read -r "sftp_host?  Host (e.g., 192.168.1.100): "
    [ -z "$sftp_host" ] && echo -e "${YELLOW}Host required. Cancelled.${NC}" && return
    read -r "sftp_port?  Port [22]: "
    sftp_port="${sftp_port:-22}"
    read -r "sftp_user?  Username: "
    [ -z "$sftp_user" ] && echo -e "${YELLOW}Username required. Cancelled.${NC}" && return

    echo -e "  Auth method:"
    echo -e "    ${GREEN}1.${NC} Password"
    echo -e "    ${GREEN}2.${NC} SSH key (uses container's ~/.ssh/id_rsa)"
    read -r "sftp_auth?  Select [1]: "

    local -a rclone_args=(config create "$sftp_name" sftp
        host "$sftp_host"
        port "$sftp_port"
        user "$sftp_user"
    )
    if [ "${sftp_auth:-1}" = "2" ]; then
        local key_path="${HOME}/.ssh/id_rsa"
        if [ ! -f "$key_path" ]; then
            echo -e "${YELLOW}Warning: ${key_path} not found.${NC}"
            read -r "custom_key?  Path to SSH private key [${key_path}]: "
            key_path="${custom_key:-$key_path}"
            if [ ! -f "$key_path" ]; then
                echo -e "${RED}Key file not found. Cannot create remote without valid key.${NC}"
                return 1
            fi
        fi
        rclone_args+=(key_file "$key_path")
    else
        _read_password "  Password: " sftp_pass || return
        [ -z "$sftp_pass" ] && echo -e "${YELLOW}Password required. Cancelled.${NC}" && return
        rclone_args+=(pass "$sftp_pass" --obscure)
    fi

    if rclone "${rclone_args[@]}"; then
        echo -e "\n${GREEN}✓ Remote '${sftp_name}' saved to rclone.conf${NC}"
        _offer_mount "$sftp_name"
    else
        echo -e "\n${RED}Failed to create remote. See error above.${NC}"
    fi
    unset sftp_pass
}

# Quick setup: SMB/CIFS
rmount_quick_smb() {
    echo -e "\n${CYAN}Quick Setup: SMB / CIFS (Windows Shares)${NC}\n"
    read -r "smb_name?  Remote name (e.g., nas): "
    rmount_validate_name "$smb_name" || return

    read -r "smb_host?  Host (e.g., 192.168.1.100): "
    [ -z "$smb_host" ] && echo -e "${YELLOW}Host required. Cancelled.${NC}" && return
    read -r "smb_user?  Username: "
    [ -z "$smb_user" ] && echo -e "${YELLOW}Username required. Cancelled.${NC}" && return
    _read_password "  Password: " smb_pass || return
    [ -z "$smb_pass" ] && echo -e "${YELLOW}Password required. Cancelled.${NC}" && return
    read -r "smb_domain?  Domain (leave empty if none): "

    local -a rclone_args=(config create "$smb_name" smb
        host "$smb_host"
        user "$smb_user"
        pass "$smb_pass"
    )
    [ -n "$smb_domain" ] && rclone_args+=(domain "$smb_domain")
    rclone_args+=(--obscure)

    if rclone "${rclone_args[@]}"; then
        echo -e "\n${GREEN}✓ Remote '${smb_name}' saved to rclone.conf${NC}"
        _offer_mount "$smb_name"
    else
        echo -e "\n${RED}Failed to create remote. See error above.${NC}"
    fi
    unset smb_pass
}

# Quick setup: WebDAV
rmount_quick_webdav() {
    echo -e "\n${CYAN}Quick Setup: WebDAV${NC}\n"
    read -r "wd_name?  Remote name (e.g., nextcloud): "
    rmount_validate_name "$wd_name" || return

    read -r "wd_url?  WebDAV URL (e.g., https://cloud.example.com/remote.php/dav/files/user/): "
    [ -z "$wd_url" ] && echo -e "${YELLOW}URL required. Cancelled.${NC}" && return

    echo -e "  Vendor:"
    echo -e "    ${GREEN}1.${NC} Nextcloud"
    echo -e "    ${GREEN}2.${NC} Owncloud"
    echo -e "    ${GREEN}3.${NC} SharePoint"
    echo -e "    ${GREEN}4.${NC} Other"
    read -r "wd_vendor_choice?  Select [4]: "
    case "${wd_vendor_choice:-4}" in
        1) wd_vendor="nextcloud" ;;
        2) wd_vendor="owncloud" ;;
        3) wd_vendor="sharepoint" ;;
        *) wd_vendor="other" ;;
    esac

    read -r "wd_user?  Username: "
    [ -z "$wd_user" ] && echo -e "${YELLOW}Username required. Cancelled.${NC}" && return
    _read_password "  Password: " wd_pass || return
    [ -z "$wd_pass" ] && echo -e "${YELLOW}Password required. Cancelled.${NC}" && return

    if rclone config create "$wd_name" webdav \
        url "$wd_url" \
        vendor "$wd_vendor" \
        user "$wd_user" \
        pass "$wd_pass" \
        --obscure; then
        echo -e "\n${GREEN}✓ Remote '${wd_name}' saved to rclone.conf${NC}"
        _offer_mount "$wd_name"
    else
        echo -e "\n${RED}Failed to create remote. See error above.${NC}"
    fi
    unset wd_pass
}

# Quick setup: FTP
rmount_quick_ftp() {
    echo -e "\n${CYAN}Quick Setup: FTP${NC}\n"
    read -r "ftp_name?  Remote name (e.g., ftpserver): "
    rmount_validate_name "$ftp_name" || return

    read -r "ftp_host?  Host (e.g., ftp.example.com): "
    [ -z "$ftp_host" ] && echo -e "${YELLOW}Host required. Cancelled.${NC}" && return
    read -r "ftp_port?  Port [21]: "
    ftp_port="${ftp_port:-21}"
    read -r "ftp_user?  Username: "
    [ -z "$ftp_user" ] && echo -e "${YELLOW}Username required. Cancelled.${NC}" && return
    _read_password "  Password: " ftp_pass || return
    [ -z "$ftp_pass" ] && echo -e "${YELLOW}Password required. Cancelled.${NC}" && return

    echo -e "  Use explicit TLS?"
    echo -e "    ${GREEN}1.${NC} No (plain FTP)"
    echo -e "    ${GREEN}2.${NC} Yes (FTPS)"
    read -r "ftp_tls?  Select [1]: "

    local -a rclone_args=(config create "$ftp_name" ftp
        host "$ftp_host"
        port "$ftp_port"
        user "$ftp_user"
        pass "$ftp_pass"
    )
    [ "${ftp_tls:-1}" = "2" ] && rclone_args+=(explicit_tls true)
    rclone_args+=(--obscure)

    if rclone "${rclone_args[@]}"; then
        echo -e "\n${GREEN}✓ Remote '${ftp_name}' saved to rclone.conf${NC}"
        _offer_mount "$ftp_name"
    else
        echo -e "\n${RED}Failed to create remote. See error above.${NC}"
    fi
    unset ftp_pass
}

# Add a new remote
rmount_add_remote() {
    echo -e "\n${CYAN}Add Remote Storage${NC}\n"
    echo -e "  ${GREEN}1.${NC} Interactive wizard (rclone config - all providers)"
    echo -e "  ${GREEN}2.${NC} Quick setup: S3 / S3-compatible"
    echo -e "  ${GREEN}3.${NC} Quick setup: Google Drive"
    echo -e "  ${GREEN}4.${NC} Quick setup: SFTP"
    echo -e "  ${GREEN}5.${NC} Quick setup: SMB / CIFS (Windows shares)"
    echo -e "  ${GREEN}6.${NC} Quick setup: WebDAV"
    echo -e "  ${GREEN}7.${NC} Quick setup: FTP"
    echo ""
    read -r "add_choice?  Select option: "

    case "$add_choice" in
        1) rclone config ;;
        2) rmount_quick_s3 ;;
        3) rmount_quick_gdrive ;;
        4) rmount_quick_sftp ;;
        5) rmount_quick_smb ;;
        6) rmount_quick_webdav ;;
        7) rmount_quick_ftp ;;
        *) echo -e "${YELLOW}Invalid option.${NC}" ;;
    esac
}

# Mount a configured remote
rmount_mount() {
    local remotes=$(rclone listremotes 2>/dev/null)
    if [ -z "$remotes" ]; then
        echo -e "\n${YELLOW}No remotes configured. Use 'Add remote' first.${NC}"
        return
    fi

    echo -e "\n${CYAN}Available remotes:${NC}"
    local i=1
    echo "$remotes" | while read -r r; do
        echo -e "  ${GREEN}${i}.${NC} $r"
        i=$((i+1))
    done
    echo ""
    read -r "mount_remote?  Remote name (e.g., 'myremote' or 'myremote:'): "
    [ -z "$mount_remote" ] && return

    # Ensure trailing colon for rclone
    case "$mount_remote" in
        *:) ;;
        *) mount_remote="${mount_remote}:" ;;
    esac

    read -r "mount_subpath?  Remote path [/]: "
    mount_subpath="${mount_subpath:-/}"

    # Validate subpath (allow only path-safe characters, block traversal)
    if ! echo "$mount_subpath" | grep -qE '^[a-zA-Z0-9/_. -]*$'; then
        echo -e "${RED}Invalid path. Use only letters, numbers, /, _, ., space, and dash.${NC}"
        return 1
    fi
    if echo "$mount_subpath" | grep -qE '(^|/)\.\.(/|$)'; then
        echo -e "${RED}Path traversal (..) is not allowed.${NC}"
        return 1
    fi

    local remote_spec="${mount_remote}${mount_subpath}"

    local remote_name="${mount_remote%:}"
    local default_path="${RCLONE_MOUNT_BASE}/${remote_name}"
    read -r "mount_path?  Local mount path [${default_path}]: "
    mount_path="${mount_path:-$default_path}"

    echo -e "\n${CYAN}VFS Cache mode:${NC}"
    echo -e "  ${GREEN}1.${NC} off     - No caching (streaming only, minimal disk use)"
    echo -e "  ${GREEN}2.${NC} minimal - Metadata only (faster listings, reads still remote)"
    echo -e "  ${GREEN}3.${NC} writes  - Cache writes locally (${GREEN}recommended${NC} — fast writes, safe for editing)"
    echo -e "  ${GREEN}4.${NC} full    - Cache all I/O (fastest, uses disk space equal to accessed files)"
    echo -e "  ${CYAN}Tip:${NC} Use 'writes' for editing files, 'minimal' for read-only browsing."
    echo ""
    read -r "cache_choice?  Select [3]: "
    case "${cache_choice:-3}" in
        1) cache_mode="off" ;;
        2) cache_mode="minimal" ;;
        4) cache_mode="full" ;;
        *) cache_mode="writes" ;;
    esac

    # Warn if mount path is outside the standard rclone directory
    case "$mount_path" in
        "${RCLONE_MOUNT_BASE}"/*)
            ;;
        *)
            echo -e "${YELLOW}Warning: Mount path is outside ${RCLONE_MOUNT_BASE}${NC}"
            echo -e "  Non-standard paths won't be managed by auto-mount or cleanup."
            read -r "confirm_path?  Continue anyway? [y/N]: "
            if [[ "$confirm_path" != "y" && "$confirm_path" != "Y" ]]; then
                echo -e "${YELLOW}Cancelled.${NC}"
                return 1
            fi
            ;;
    esac

    _do_rclone_mount "$remote_spec" "$mount_path" "$cache_mode"
}

# Unmount a remote
rmount_unmount() {
    echo -e "\n${CYAN}Active mounts:${NC}"
    local found=false
    for mount_dir in ${RCLONE_MOUNT_BASE}/*/; do
        [ -d "$mount_dir" ] || continue
        local name=$(basename "$mount_dir")
        if mountpoint -q "$mount_dir" 2>/dev/null; then
            echo -e "  ${GREEN}●${NC} $name (mounted)"
            found=true
        elif ! timeout 3 stat "$mount_dir" >/dev/null 2>&1; then
            echo -e "  ${RED}✗${NC} $name (stale — needs cleanup)"
            found=true
        fi
    done

    if [ "$found" = "false" ]; then
        echo -e "  ${YELLOW}No active mounts to unmount.${NC}"
        return
    fi

    echo ""
    read -r "umount_name?  Mount name to unmount (or 'all'): "
    [ -z "$umount_name" ] && return

    if [ "$umount_name" = "all" ]; then
        echo -e "  ${YELLOW}Warning: This will close all files on remote mounts (unsaved changes may be lost).${NC}"
        read -r "confirm_all?  Unmount ALL remotes? [y/N]: "
        if [[ "$confirm_all" != "y" && "$confirm_all" != "Y" ]]; then
            echo -e "${YELLOW}Cancelled.${NC}"
            return 0
        fi
        local count=0
        for mount_dir in ${RCLONE_MOUNT_BASE}/*/; do
            [ -d "$mount_dir" ] || continue
            local name=$(basename "$mount_dir")

            # Only unmount if actually mounted or stale
            if mountpoint -q "$mount_dir" 2>/dev/null || ! timeout 3 stat "$mount_dir" >/dev/null 2>&1; then
                if timeout 5 fusermount -u "$mount_dir" 2>/dev/null; then
                    echo -e "  ${GREEN}✓ Unmounted: ${name}${NC}"
                    rmdir "$mount_dir" 2>/dev/null || true
                    count=$((count + 1))
                elif fusermount -uz "$mount_dir" 2>/dev/null; then
                    echo -e "  ${YELLOW}✓ Force unmounted: ${name}${NC}"
                    rmdir "$mount_dir" 2>/dev/null || true
                    count=$((count + 1))
                else
                    echo -e "  ${RED}✗ Failed: ${name}${NC}"
                fi
            fi
        done
        echo -e "\n${GREEN}Unmounted ${count} mount(s).${NC}"
    else
        local target="${RCLONE_MOUNT_BASE}/${umount_name}"

        if [ ! -d "$target" ]; then
            echo -e "${RED}Mount '${umount_name}' not found.${NC}"
            return 1
        fi

        # Check if actually mounted or stale
        if ! mountpoint -q "$target" 2>/dev/null && timeout 3 stat "$target" >/dev/null 2>&1; then
            echo -e "${YELLOW}'${umount_name}' is not an active mount.${NC}"
            echo -e "  Remove empty directory: ${CYAN}rmdir /mounts/rclone/${umount_name}${NC}"
            return 1
        fi

        if fusermount -u "$target" 2>/dev/null; then
            echo -e "${GREEN}✓ Unmounted: ${umount_name}${NC}"
            rmdir "$target" 2>/dev/null || true
        elif fusermount -uz "$target" 2>/dev/null; then
            echo -e "${YELLOW}✓ Force unmounted: ${umount_name}${NC}"
            rmdir "$target" 2>/dev/null || true
        else
            echo -e "${RED}✗ Failed to unmount ${umount_name}${NC}"
            echo -e "  Check for open files: ${CYAN}lsof ${target}${NC}"
            return 1
        fi
    fi
}

# Auto-mount configuration
rmount_automount() {
    echo -e "\n${CYAN}Auto-Mount Configuration${NC}"
    echo -e "  Remotes in automount.conf are mounted on every container start.\n"
    echo -e "  ${GREEN}1.${NC} View current auto-mount config"
    echo -e "  ${GREEN}2.${NC} Edit auto-mount config"
    echo -e "  ${GREEN}3.${NC} Add active mounts to auto-mount"
    echo ""
    read -r "am_choice?  Select option: "

    case "$am_choice" in
        1)
            echo ""
            if [ -f "$RCLONE_AUTOMOUNT" ]; then
                while IFS= read -r _am_line || [ -n "$_am_line" ]; do
                    case "$_am_line" in
                        \#*|"")
                            echo "  $_am_line"
                            continue
                            ;;
                    esac
                    local _am_remote="${_am_line%% *}"
                    local _am_name="${_am_remote%%:*}"
                    local _am_path="/mounts/rclone/${_am_name}"
                    if mountpoint -q "$_am_path" 2>/dev/null; then
                        echo -e "  ${GREEN}✓${NC} $_am_line  ${GREEN}[mounted]${NC}"
                    else
                        echo -e "  ${YELLOW}✗${NC} $_am_line  ${YELLOW}[not mounted]${NC}"
                    fi
                done < "$RCLONE_AUTOMOUNT"
            else
                echo -e "${YELLOW}No automount.conf found.${NC}"
            fi
            ;;
        2)
            ${EDITOR:-nano} "$RCLONE_AUTOMOUNT"
            # Validate after editing
            if [ -f "$RCLONE_AUTOMOUNT" ]; then
                local errors=0
                local line_num=0
                while IFS= read -r am_line || [ -n "$am_line" ]; do
                    line_num=$((line_num + 1))
                    case "$am_line" in
                        \#*|"") continue ;;
                    esac
                    local am_remote="${am_line%% *}"
                    local am_name="${am_remote%%:*}"
                    if [ -z "$am_name" ]; then
                        echo -e "  ${RED}Line ${line_num}: Empty remote name: ${am_line}${NC}"
                        errors=$((errors + 1))
                    elif ! echo "$am_name" | grep -qE '^[a-zA-Z0-9_-]+$'; then
                        echo -e "  ${RED}Line ${line_num}: Invalid remote name '${am_name}' (use letters, numbers, dash, underscore)${NC}"
                        errors=$((errors + 1))
                    elif echo "$am_line" | grep -vqE '^[a-zA-Z0-9=_./:@ -]*$'; then
                        echo -e "  ${RED}Line ${line_num}: Unsafe characters in: ${am_line}${NC}"
                        errors=$((errors + 1))
                    fi
                done < "$RCLONE_AUTOMOUNT"
                if [ "$errors" -gt 0 ]; then
                    echo -e "\n${YELLOW}Found ${errors} issue(s). Fix them to avoid mount failures on startup.${NC}"
                    read -r "retry_edit?  Re-edit now? [Y/n]: "
                    if [[ "$retry_edit" != "n" && "$retry_edit" != "N" ]]; then
                        ${EDITOR:-nano} "$RCLONE_AUTOMOUNT"
                        echo -e "${CYAN}Config saved. Validation will run on next container start.${NC}"
                    fi
                else
                    echo -e "\n${GREEN}Config looks valid.${NC}"
                fi
            fi
            ;;
        3)
            local added=false
            for mount_dir in ${RCLONE_MOUNT_BASE}/*/; do
                [ -d "$mount_dir" ] || continue
                if mountpoint -q "$mount_dir" 2>/dev/null; then
                    local name=$(basename "$mount_dir")
                    if ! grep -q "^${name}:" "$RCLONE_AUTOMOUNT" 2>/dev/null; then
                        echo "${name}:/  --vfs-cache-mode=writes" >> "$RCLONE_AUTOMOUNT"
                        echo -e "  ${GREEN}Added: ${name}${NC}"
                        added=true
                    else
                        echo -e "  ${YELLOW}Already in config: ${name}${NC}"
                    fi
                fi
            done
            if [ "$added" = "false" ]; then
                echo -e "  ${YELLOW}No new mounts to add.${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}Invalid option.${NC}"
            ;;
    esac
}

# Test connection to a configured remote
rmount_test_connection() {
    local remotes=$(rclone listremotes 2>/dev/null)
    if [ -z "$remotes" ]; then
        echo -e "\n${YELLOW}No remotes configured. Use 'Add remote' first.${NC}"
        return
    fi

    echo -e "\n${CYAN}Configured remotes:${NC}"
    echo "$remotes" | while read -r r; do
        echo -e "  ${GREEN}•${NC} $r"
    done
    echo ""
    read -r "test_remote?  Remote name to test (e.g., 'myremote'): "
    [ -z "$test_remote" ] && return

    # Ensure trailing colon
    case "$test_remote" in
        *:) ;;
        *) test_remote="${test_remote}:" ;;
    esac

    echo -e "\n${CYAN}Testing connection to ${test_remote}...${NC} (15s timeout)"
    timeout 15 rclone lsd "$test_remote" --max-depth 0 2>&1
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "\n${GREEN}✓ Connection successful.${NC}"
    elif [ $exit_code -eq 124 ]; then
        echo -e "\n${YELLOW}Connection timed out after 15s.${NC}"
        echo -e "  Remote may be slow or unreachable. Check network connectivity."
    else
        echo -e "\n${RED}✗ Connection failed.${NC}"
        echo -e "  Check credentials and remote configuration."
        echo -e "  Edit config: ${CYAN}cc-rmount${NC} → Edit rclone config"
    fi
}

# Main rclone mount manager menu
manage_rclone_mounts() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        ClaudePantheon - Remote Mount Manager             ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if ! rmount_check_fuse; then
        return 1
    fi

    # Show current mounts/remotes on first entry
    rmount_list

    while true; do
        echo ""
        echo -e "  ${GREEN}1.${NC} Refresh mounts & remotes"
        echo -e "  ${GREEN}2.${NC} Add remote"
        echo -e "  ${GREEN}3.${NC} Mount remote"
        echo -e "  ${GREEN}4.${NC} Unmount remote"
        echo -e "  ${GREEN}5.${NC} Test remote connection"
        echo -e "  ${GREEN}6.${NC} Edit rclone config (rclone config)"
        echo -e "  ${GREEN}7.${NC} Auto-mount setup"
        echo -e "  ${GREEN}q.${NC} Exit"
        echo ""
        read -r "rmount_choice?  Select option (or Enter to exit): "

        echo ""
        case "$rmount_choice" in
            1) rmount_list ;;
            2) rmount_add_remote ;;
            3) rmount_mount ;;
            4) rmount_unmount ;;
            5) rmount_test_connection ;;
            6) rclone config ;;
            7) rmount_automount ;;
            q|Q|"") echo -e "  ${GREEN}Goodbye.${NC}"; return 0 ;;
            *) echo -e "${YELLOW}Invalid option.${NC}" ;;
        esac
    done
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

if [ "$1" = "--rmount-only" ]; then
    manage_rclone_mounts
    exit 0
fi

# Run main
main
