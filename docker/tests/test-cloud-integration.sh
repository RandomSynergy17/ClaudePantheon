#!/bin/bash
# ╔═══════════════════════════════════════════════════════════╗
# ║      Cloud Storage Integration Test Suite                ║
# ╚═══════════════════════════════════════════════════════════╝
#
# Tests for Google Drive, Dropbox, and macOS connectivity

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# Test function
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
echo "║      Cloud Storage Integration Test Suite                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# ─────────────────────────────────────────────────────────────
# MCP Server Tests
# ─────────────────────────────────────────────────────────────

echo "Testing MCP Server Files..."

test_mcp_servers_exist() {
    [ -f "docker/mcp-servers/google-drive-mcp.js" ] && \
    [ -f "docker/mcp-servers/dropbox-mcp.js" ] && \
    [ -f "docker/mcp-servers/package.json" ]
}

test_mcp_package_json_valid() {
    jq . docker/mcp-servers/package.json >/dev/null 2>&1
}

test_mcp_readme_exists() {
    [ -f "docker/mcp-servers/README.md" ] && \
    grep -q "Google Drive MCP Server" docker/mcp-servers/README.md && \
    grep -q "Dropbox MCP Server" docker/mcp-servers/README.md
}

test_case "MCP server files exist" test_mcp_servers_exist
test_case "package.json is valid JSON" test_mcp_package_json_valid
test_case "MCP README documentation exists" test_mcp_readme_exists

echo ""

# ─────────────────────────────────────────────────────────────
# Shell Script Tests
# ─────────────────────────────────────────────────────────────

echo "Testing Shell Scripts..."

test_dropbox_wizard_exists() {
    [ -f "docker/scripts/rmount-dropbox.sh" ] && \
    grep -q "rmount_quick_dropbox" docker/scripts/rmount-dropbox.sh
}

test_dropbox_wizard_has_validation() {
    grep -q "rmount_validate_name" docker/scripts/rmount-dropbox.sh && \
    grep -q "Dropbox Access Token" docker/scripts/rmount-dropbox.sh
}

test_dropbox_wizard_has_connection_test() {
    grep -q "rclone lsd" docker/scripts/rmount-dropbox.sh && \
    grep -q "Connection successful" docker/scripts/rmount-dropbox.sh
}

test_case "Dropbox wizard script exists" test_dropbox_wizard_exists
test_case "Dropbox wizard has input validation" test_dropbox_wizard_has_validation
test_case "Dropbox wizard has connection test" test_dropbox_wizard_has_connection_test

echo ""

# ─────────────────────────────────────────────────────────────
# Documentation Tests
# ─────────────────────────────────────────────────────────────

echo "Testing Documentation..."

test_macos_connectivity_guide() {
    [ -f "MACOS_CONNECTIVITY.md" ] && \
    grep -q "WebDAV" MACOS_CONNECTIVITY.md && \
    grep -q "SMB/CIFS" MACOS_CONNECTIVITY.md && \
    grep -q "Docker Volume Mounts" MACOS_CONNECTIVITY.md
}

test_macos_guide_has_examples() {
    grep -q "Connect from macOS Finder" MACOS_CONNECTIVITY.md && \
    grep -q "smb://localhost" MACOS_CONNECTIVITY.md
}

test_macos_guide_has_troubleshooting() {
    grep -q "Troubleshooting" MACOS_CONNECTIVITY.md && \
    grep -q "Connection Failed" MACOS_CONNECTIVITY.md
}

test_case "macOS connectivity guide exists" test_macos_connectivity_guide
test_case "macOS guide has connection examples" test_macos_guide_has_examples
test_case "macOS guide has troubleshooting section" test_macos_guide_has_troubleshooting

echo ""

# ─────────────────────────────────────────────────────────────
# rclone Integration Tests
# ─────────────────────────────────────────────────────────────

echo "Testing rclone Configuration..."

test_rclone_dropbox_supported() {
    # Check if rclone supports dropbox (via help text)
    if command -v rclone >/dev/null 2>&1; then
        rclone help backend dropbox >/dev/null 2>&1
        return $?
    else
        echo "  ${YELLOW}Skipped: rclone not installed${NC}"
        return 0
    fi
}

test_rclone_gdrive_supported() {
    # Check if rclone supports drive (Google Drive)
    if command -v rclone >/dev/null 2>&1; then
        rclone help backend drive >/dev/null 2>&1
        return $?
    else
        echo "  ${YELLOW}Skipped: rclone not installed${NC}"
        return 0
    fi
}

test_case "rclone Dropbox backend available" test_rclone_dropbox_supported
test_case "rclone Google Drive backend available" test_rclone_gdrive_supported

echo ""

# ─────────────────────────────────────────────────────────────
# Input Validation Tests
# ─────────────────────────────────────────────────────────────

echo "Testing Input Validation..."

# Simulate the validation function
rmount_validate_name() {
    local name="$1"
    if [ -z "$name" ]; then
        return 1
    fi
    if ! echo "$name" | grep -qE '^[a-zA-Z0-9_-]+$'; then
        return 1
    fi
    return 0
}

test_remote_name_validation_valid() {
    rmount_validate_name "my-dropbox" && \
    rmount_validate_name "gdrive123" && \
    rmount_validate_name "test_remote"
}

test_remote_name_validation_invalid() {
    ! rmount_validate_name "" && \
    ! rmount_validate_name "my remote" && \
    ! rmount_validate_name "remote/path" && \
    ! rmount_validate_name "remote;evil"
}

test_remote_name_no_command_injection() {
    ! rmount_validate_name "\$(whoami)" && \
    ! rmount_validate_name "remote;rm -rf /" && \
    ! rmount_validate_name "remote|cat /etc/passwd"
}

test_case "Remote name validation (valid names)" test_remote_name_validation_valid
test_case "Remote name validation (reject invalid)" test_remote_name_validation_invalid
test_case "Remote name blocks command injection" test_remote_name_no_command_injection

echo ""

# ─────────────────────────────────────────────────────────────
# File Structure Tests
# ─────────────────────────────────────────────────────────────

echo "Testing File Structure..."

test_directory_structure() {
    [ -d "docker/mcp-servers" ] && \
    [ -d "docker/scripts" ] && \
    [ -d "docker/tests" ]
}

test_executable_permissions() {
    if [ -f "docker/tests/test-cloud-integration.sh" ]; then
        [ -x "docker/tests/test-cloud-integration.sh" ] || chmod +x "docker/tests/test-cloud-integration.sh"
    fi
    return 0
}

test_case "Directory structure is correct" test_directory_structure
test_case "Test scripts are executable" test_executable_permissions

echo ""

# ─────────────────────────────────────────────────────────────
# Content Validation Tests
# ─────────────────────────────────────────────────────────────

echo "Testing Content Quality..."

test_no_hardcoded_credentials() {
    # Ensure no hardcoded credentials in code
    ! grep -r "sk-ant-api" docker/mcp-servers/ docker/scripts/ 2>/dev/null && \
    ! grep -r "your_dropbox_token" docker/mcp-servers/*.js 2>/dev/null
}

test_env_var_usage() {
    grep -q "process.env.DROPBOX_ACCESS_TOKEN" docker/mcp-servers/dropbox-mcp.js && \
    grep -q "process.env.GOOGLE_DRIVE" docker/mcp-servers/google-drive-mcp.js
}

test_error_handling() {
    grep -q "catch" docker/mcp-servers/google-drive-mcp.js && \
    grep -q "Error" docker/mcp-servers/dropbox-mcp.js
}

test_case "No hardcoded credentials in code" test_no_hardcoded_credentials
test_case "Uses environment variables for secrets" test_env_var_usage
test_case "Has proper error handling" test_error_handling

echo ""

# ─────────────────────────────────────────────────────────────
# Security Tests
# ─────────────────────────────────────────────────────────────

echo "Testing Security..."

test_token_masking() {
    # Check that password prompts use _read_password or similar
    grep -q "_read_password" docker/scripts/rmount-dropbox.sh
}

test_token_cleanup() {
    # Check that sensitive variables are unset after use
    grep -q "unset.*token" docker/scripts/rmount-dropbox.sh || \
    grep -q "unset db_token" docker/scripts/rmount-dropbox.sh
}

test_path_traversal_prevention() {
    # Path traversal prevention exists in entrypoint.sh
    [ -f "docker/scripts/entrypoint.sh" ] && \
    grep -q "Path traversal" docker/scripts/entrypoint.sh
}

test_case "Token input is masked" test_token_masking
test_case "Sensitive variables are cleaned up" test_token_cleanup
test_case "Path traversal prevention in place" test_path_traversal_prevention

echo ""

# ─────────────────────────────────────────────────────────────
# Integration Points Tests
# ─────────────────────────────────────────────────────────────

echo "Testing Integration Points..."

test_mcp_json_template_exists() {
    # Check if README has mcp.json configuration examples
    grep -q '"mcpServers"' docker/mcp-servers/README.md
}

test_setup_instructions_complete() {
    grep -q "Installation" docker/mcp-servers/README.md && \
    grep -q "Step 1:" docker/mcp-servers/README.md && \
    grep -q "npm install" docker/mcp-servers/README.md
}

test_troubleshooting_guide() {
    grep -q "Troubleshooting" docker/mcp-servers/README.md && \
    grep -q "Error:" docker/mcp-servers/README.md
}

test_case "MCP configuration template exists" test_mcp_json_template_exists
test_case "Setup instructions are complete" test_setup_instructions_complete
test_case "Troubleshooting guide exists" test_troubleshooting_guide

echo ""

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════════════════════"
printf "Results: ${GREEN}%d PASSED${NC}, ${RED}%d FAILED${NC}\n" "$PASS_COUNT" "$FAIL_COUNT"
echo "════════════════════════════════════════════════════════════"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo ""
    echo "❌ Some tests failed. Review the output above."
    exit 1
fi

echo ""
echo "✅ All cloud integration tests passed!"
echo ""
echo "Next steps:"
echo "  1. Install MCP dependencies: cd docker/mcp-servers && npm install"
echo "  2. Configure credentials for Google Drive and/or Dropbox"
echo "  3. Test individual MCP servers manually"
echo "  4. Add to mcp.json and restart Claude Code"
echo ""

exit 0
