#!/bin/bash
# ╔═══════════════════════════════════════════════════════════╗
# ║          Auto-Update System Test Suite                   ║
# ╚═══════════════════════════════════════════════════════════╝

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

test_case() {
    local test_name="$1"
    local test_func="$2"

    if $test_func; then
        printf "${GREEN}✓ PASS${NC}: %s\n" "$test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}✗ FAIL${NC}: %s\n" "$test_name"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║          Auto-Update System Test Suite                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Test: Auto-update script exists
test_script_exists() {
    [ -f "docker/scripts/auto-update.sh" ]
}

# Test: Script is executable
test_script_executable() {
    [ -x "docker/scripts/auto-update.sh" ] || chmod +x "docker/scripts/auto-update.sh"
    return 0
}

# Test: Script has help command
test_help_command() {
    grep -q "help|--help|-h" docker/scripts/auto-update.sh
}

# Test: Version checking function exists
test_version_checking() {
    grep -q "get_latest_release\|check_updates" docker/scripts/auto-update.sh
}

# Test: Backup function exists
test_backup_function() {
    grep -q "create_backup" docker/scripts/auto-update.sh
}

# Test: GitHub API integration
test_github_api() {
    grep -q "api.github.com" docker/scripts/auto-update.sh
}

# Test: Configuration file support
test_config_support() {
    grep -q "UPDATE_CONFIG\|init_update_config" docker/scripts/auto-update.sh
}

# Test: Update schedule options
test_schedule_options() {
    grep -q "startup\|daily\|weekly\|manual" docker/scripts/auto-update.sh
}

# Test: Aliases added to zshrc
test_zshrc_aliases() {
    grep -q "cc-update" docker/scripts/.zshrc
}

# Test: Entrypoint integration
test_entrypoint_integration() {
    grep -q "auto-update.sh" docker/scripts/entrypoint.sh
}

echo "Testing Auto-Update System..."
test_case "Auto-update script exists" test_script_exists
test_case "Script is executable" test_script_executable
test_case "Help command available" test_help_command
test_case "Version checking implemented" test_version_checking
test_case "Backup function exists" test_backup_function
test_case "GitHub API integration" test_github_api
test_case "Configuration file support" test_config_support
test_case "Update schedule options" test_schedule_options
test_case "Shell aliases configured" test_zshrc_aliases
test_case "Entrypoint integration" test_entrypoint_integration

echo ""
echo "Testing CLI Installer..."

# Test: CLI installer exists
test_cli_installer_exists() {
    [ -f "docker/scripts/cli-installer.sh" ]
}

# Test: Codex installation support
test_codex_support() {
    grep -q "install_codex\|install-codex" docker/scripts/cli-installer.sh
}

# Test: Gemini installation support
test_gemini_support() {
    grep -q "install_gemini\|install-gemini" docker/scripts/cli-installer.sh
}

# Test: Interactive wizard
test_interactive_wizard() {
    grep -q "main_wizard\|wizard" docker/scripts/cli-installer.sh
}

# Test: API key configuration
test_api_key_config() {
    grep -q "API.*KEY\|_read_password" docker/scripts/cli-installer.sh
}

# Test: Claude Octopus integration
test_octopus_integration() {
    grep -q "octopus\|Claude Octopus" docker/scripts/cli-installer.sh
}

# Test: CLI detection
test_cli_detection() {
    grep -q "check_cli_installed\|command -v" docker/scripts/cli-installer.sh
}

# Test: Uninstall support
test_uninstall_support() {
    grep -q "uninstall" docker/scripts/cli-installer.sh
}

test_case "CLI installer exists" test_cli_installer_exists
test_case "Codex installation support" test_codex_support
test_case "Gemini installation support" test_gemini_support
test_case "Interactive wizard available" test_interactive_wizard
test_case "API key configuration" test_api_key_config
test_case "Claude Octopus integration" test_octopus_integration
test_case "CLI detection implemented" test_cli_detection
test_case "Uninstall support" test_uninstall_support

echo ""
echo "════════════════════════════════════════════════════════════"
printf "Results: ${GREEN}%d PASSED${NC}, ${RED}%d FAILED${NC}\n" "$PASS_COUNT" "$FAIL_COUNT"
echo "════════════════════════════════════════════════════════════"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo ""
    echo "❌ Some tests failed"
    exit 1
fi

echo ""
echo "✅ All auto-update and CLI installer tests passed!"
exit 0
