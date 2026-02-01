#!/bin/zsh
# ╔═══════════════════════════════════════════════════════════╗
# ║         Dropbox Quick Setup for ClaudePantheon           ║
# ╚═══════════════════════════════════════════════════════════╝
# Enhanced Dropbox integration with clearer instructions
#
# This function will be integrated into shell-wrapper.sh

# Quick setup: Dropbox
rmount_quick_dropbox() {
    echo -e "\n${CYAN}Quick Setup: Dropbox${NC}\n"
    echo -e "  ${YELLOW}Dropbox requires an app token for headless auth.${NC}"
    echo -e ""
    echo -e "  ${CYAN}Setup steps:${NC}"
    echo -e "    ${GREEN}1.${NC} Visit: ${CYAN}https://www.dropbox.com/developers/apps${NC}"
    echo -e "    ${GREEN}2.${NC} Click 'Create app'"
    echo -e "    ${GREEN}3.${NC} Choose 'Scoped access' → 'Full Dropbox' or 'App folder'"
    echo -e "    ${GREEN}4.${NC} Name your app (e.g., 'ClaudePantheon')"
    echo -e "    ${GREEN}5.${NC} On the Settings tab, scroll to 'Generated access token'"
    echo -e "    ${GREEN}6.${NC} Click 'Generate' → copy the token"
    echo -e "    ${GREEN}7.${NC} Paste it below"
    echo -e ""
    echo -e "  ${YELLOW}Note:${NC} Generated tokens have no expiration"
    echo -e "  ${YELLOW}Security:${NC} Keep your token secret — it grants full access to your Dropbox"
    echo ""

    read -r "db_name?  Remote name (e.g., dropbox): "
    if ! rmount_validate_name "$db_name"; then
        return 1
    fi

    echo ""
    echo -e "  ${CYAN}Access scope:${NC}"
    echo -e "    ${GREEN}1.${NC} Full Dropbox (all files)"
    echo -e "    ${GREEN}2.${NC} App folder only (sandboxed to /Apps/YourApp/)"
    read -r "db_scope?  Select [1]: "

    case "${db_scope:-1}" in
        2)
            echo -e "  ${YELLOW}Note: Files will be in /Apps/[your-app-name]/ in Dropbox${NC}"
            ;;
        *)
            echo -e "  ${YELLOW}Note: Full access to all Dropbox files${NC}"
            ;;
    esac

    echo ""
    _read_password "  Dropbox Access Token: " db_token || return

    if [ -z "$db_token" ]; then
        echo -e "${YELLOW}No token provided. Cancelled.${NC}"
        return 1
    fi

    # Validate token format (basic check - Dropbox tokens are long alphanumeric strings)
    if ! echo "$db_token" | grep -qE '^[a-zA-Z0-9_-]{60,}$'; then
        echo -e "${YELLOW}Warning: Token format looks unusual. Dropbox tokens are typically 60+ alphanumeric characters.${NC}"
        read -r "continue?  Continue anyway? [y/N]: "
        if [[ "$continue" != "y" && "$continue" != "Y" ]]; then
            echo -e "${YELLOW}Cancelled.${NC}"
            return 1
        fi
    fi

    # Create remote config
    if rclone config create "$db_name" dropbox token "{\"access_token\":\"$db_token\"}" --obscure; then
        echo -e "\n${GREEN}✓ Remote '${db_name}' saved to rclone.conf${NC}"

        # Test connection
        echo -e "\n  Testing connection..."
        if timeout 10 rclone lsd "${db_name}:" 2>/dev/null >/dev/null; then
            echo -e "  ${GREEN}✓ Connection successful!${NC}"
            _offer_mount "$db_name"
        else
            echo -e "  ${YELLOW}⚠ Connection test failed${NC}"
            echo -e "  Remote saved but may not be accessible."
            echo -e "  Verify your token and network connection."
            echo -e ""
            echo -e "  Test manually: ${CYAN}rclone lsd ${db_name}:${NC}"
        fi
    else
        echo -e "\n${RED}Failed to create remote. See error above.${NC}"
    fi

    unset db_token
}

# Enhanced Google Drive wizard with better instructions
rmount_quick_gdrive_enhanced() {
    echo -e "\n${CYAN}Quick Setup: Google Drive${NC}\n"
    echo -e "  ${YELLOW}Google Drive requires OAuth2 authentication.${NC}"
    echo -e "  ${CYAN}For headless servers (like this container), use one of these methods:${NC}"
    echo -e ""
    echo -e "  ${GREEN}Method 1: Token from another machine (RECOMMENDED)${NC}"
    echo -e "    ${CYAN}On your laptop/desktop:${NC}"
    echo -e "      1. Install rclone: ${GREEN}curl https://rclone.org/install.sh | sudo bash${NC}"
    echo -e "      2. Run: ${GREEN}rclone authorize \"drive\"${NC}"
    echo -e "      3. Browser opens → log in to Google → approve access"
    echo -e "      4. Copy the full JSON token from terminal output"
    echo -e "      5. Paste it below in this container"
    echo -e ""
    echo -e "  ${GREEN}Method 2: Service Account (for advanced users)${NC}"
    echo -e "    - Use a Google Cloud service account JSON key"
    echo -e "    - Better for automated/server environments"
    echo -e "    - Requires Google Cloud project setup"
    echo -e ""
    echo -e "  ${GREEN}Method 3: Full rclone config wizard${NC}"
    echo -e "    - Interactive setup with all options"
    echo -e "    - Includes shared drives, team drives"
    echo -e ""

    read -r "gd_name?  Remote name (e.g., gdrive): "
    if ! rmount_validate_name "$gd_name"; then
        return 1
    fi

    echo ""
    echo -e "  ${GREEN}1.${NC} Paste OAuth token from 'rclone authorize' (recommended)"
    echo -e "  ${GREEN}2.${NC} Use service account JSON"
    echo -e "  ${GREEN}3.${NC} Launch full rclone config wizard"
    read -r "gd_method?  Select [1]: "

    case "${gd_method:-1}" in
        1)
            echo ""
            read -r "gd_token?  Paste OAuth token JSON: "
            if [ -z "$gd_token" ]; then
                echo -e "${YELLOW}No token provided. Cancelled.${NC}"
                return 1
            fi

            # Validate JSON format
            if ! echo "$gd_token" | jq . >/dev/null 2>&1; then
                echo -e "${RED}Invalid JSON format. Token must be valid JSON.${NC}"
                echo -e "Run ${GREEN}rclone authorize \"drive\"${NC} on a machine with a browser."
                echo -e "Copy the full JSON output that looks like:"
                echo -e "${CYAN}{\"access_token\":\"...\",\"token_type\":\"Bearer\",\"refresh_token\":\"...\",\"expiry\":\"...\"}${NC}"
                return 1
            fi

            if rclone config create "$gd_name" drive token "$gd_token"; then
                echo -e "\n${GREEN}✓ Remote '${gd_name}' saved to rclone.conf${NC}"

                # Test connection
                echo -e "\n  Testing connection..."
                if timeout 10 rclone lsd "${gd_name}:" 2>/dev/null >/dev/null; then
                    echo -e "  ${GREEN}✓ Connection successful!${NC}"
                    _offer_mount "$gd_name"
                else
                    echo -e "  ${YELLOW}⚠ Connection test failed${NC}"
                    echo -e "  Test manually: ${CYAN}rclone lsd ${gd_name}:${NC}"
                fi
            else
                echo -e "\n${RED}Failed to create remote. See error above.${NC}"
            fi
            ;;
        2)
            echo ""
            echo -e "  ${CYAN}Service Account Setup:${NC}"
            read -r "sa_file?  Path to service account JSON key: "
            if [ -z "$sa_file" ] || [ ! -f "$sa_file" ]; then
                echo -e "${RED}File not found: ${sa_file}${NC}"
                return 1
            fi

            if ! jq . "$sa_file" >/dev/null 2>&1; then
                echo -e "${RED}Invalid JSON in service account file${NC}"
                return 1
            fi

            if rclone config create "$gd_name" drive service_account_file "$sa_file"; then
                echo -e "\n${GREEN}✓ Remote '${gd_name}' configured with service account${NC}"
                _offer_mount "$gd_name"
            else
                echo -e "\n${RED}Failed to create remote. See error above.${NC}"
            fi
            ;;
        3)
            echo -e "\n${CYAN}Launching rclone config for Google Drive...${NC}"
            echo -e "${YELLOW}Note: OAuth flow may not work in headless environments.${NC}"
            echo -e "${YELLOW}Consider using Method 1 (token paste) instead.${NC}\n"
            rclone config
            ;;
        *)
            echo -e "${YELLOW}Invalid option.${NC}"
            ;;
    esac
}
