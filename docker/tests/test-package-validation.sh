#!/bin/sh
# ╔═══════════════════════════════════════════════════════════╗
# ║         Package Validation Security Test Suite           ║
# ╚═══════════════════════════════════════════════════════════╝
# Tests for command injection prevention in package names

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# Test function
test_package_name() {
    local test_name="$1"
    local package_name="$2"
    local expected_result="$3"  # "valid" or "invalid"

    # Simulate the validation logic from entrypoint.sh
    line="$(echo "$package_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    # Sanitize
    clean_pkg="$(echo "$line" | tr -cd 'a-zA-Z0-9._-')"

    # Validate
    is_valid="true"

    if [ "$clean_pkg" != "$line" ]; then
        is_valid="false"
    elif ! echo "$clean_pkg" | grep -qE '^[a-zA-Z][a-zA-Z0-9._-]+$'; then
        is_valid="false"
    else
        pkg_len=${#clean_pkg}
        if [ "$pkg_len" -gt 100 ]; then
            is_valid="false"
        fi
    fi

    # Check result
    if [ "$is_valid" = "$expected_result" ]; then
        printf "${GREEN}✓ PASS${NC}: %s\n" "$test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}✗ FAIL${NC}: %s (expected %s, got %s)\n" "$test_name" "$expected_result" "$is_valid"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Package Validation Security Tests                ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Valid package names
echo "Testing VALID package names:"
test_package_name "Simple package" "curl" "true"
test_package_name "Package with dash" "docker-cli" "true"
test_package_name "Package with underscore" "build_base" "true"
test_package_name "Package with dot" "php8.3" "true"
test_package_name "Complex valid name" "postgresql-client" "true"
test_package_name "Numbers in name" "node22" "true"
test_package_name "With whitespace trimming" "  git  " "true"
echo ""

# Invalid package names (security tests)
echo "Testing INVALID/MALICIOUS package names:"
test_package_name "Command injection attempt" "curl; rm -rf /" "false"
test_package_name "Backtick injection" "curl\`whoami\`" "false"
test_package_name "Dollar command substitution" "curl\$(whoami)" "false"
test_package_name "Pipe injection" "curl|sh" "false"
test_package_name "Ampersand background" "curl&" "false"
test_package_name "Newline injection" "curl\nrm -rf /" "false"
test_package_name "Null byte injection" "curl\x00rm" "false"
test_package_name "Starts with number" "1curl" "false"
test_package_name "Special characters" "curl@#$" "false"
test_package_name "Path traversal" "../curl" "false"
test_package_name "Empty string" "" "false"
test_package_name "Only whitespace" "   " "false"
LONG_NAME="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
test_package_name "Too long name" "$LONG_NAME" "false"
test_package_name "Single character" "c" "false"
echo ""

# Summary
echo "════════════════════════════════════════════════════════════"
printf "Results: ${GREEN}%d PASSED${NC}, ${RED}%d FAILED${NC}\n" "$PASS_COUNT" "$FAIL_COUNT"
echo "════════════════════════════════════════════════════════════"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi

echo ""
echo "✅ All security validation tests passed!"
exit 0
