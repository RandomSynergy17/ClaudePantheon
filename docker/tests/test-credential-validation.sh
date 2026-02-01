#!/bin/bash
# ╔═══════════════════════════════════════════════════════════╗
# ║       Credential Validation Security Test Suite          ║
# ╚═══════════════════════════════════════════════════════════╝
# Tests for credential validation when authentication is enabled

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

# Test function
test_credential_validation() {
    local test_name="$1"
    local internal_auth="$2"
    local internal_cred="$3"
    local expected_result="$4"  # "valid" or "invalid"

    # Simulate validation logic from start-services.sh
    is_valid="true"

    if [ "$internal_auth" = "true" ]; then
        # Check if credential is empty
        if [ -z "$internal_cred" ]; then
            is_valid="false"
        # Check if credential has colon
        elif ! echo "$internal_cred" | grep -q ':'; then
            is_valid="false"
        else
            # Extract username and password
            user=$(echo "$internal_cred" | cut -d: -f1)
            pass=$(echo "$internal_cred" | cut -d: -f2-)

            # Check if either is empty
            if [ -z "$user" ] || [ -z "$pass" ]; then
                is_valid="false"
            fi
        fi
    fi

    # Check result
    if [ "$is_valid" = "$expected_result" ]; then
        printf "${GREEN}✓ PASS${NC}: %s\n" "$test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "${RED}✗ FAIL${NC}: %s (expected %s, got %s)\n" "$test_name" "$expected_result" "$is_valid"
        printf "  Input: AUTH=%s CRED='%s'\n" "$internal_auth" "$internal_cred"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║       Credential Validation Security Tests               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Valid configurations
echo "Testing VALID credential configurations:"
test_credential_validation "Auth disabled, no creds" "false" "" "true"
test_credential_validation "Auth disabled, with creds" "false" "admin:password" "true"
test_credential_validation "Auth enabled, valid creds" "true" "admin:password123" "true"
test_credential_validation "Auth enabled, long password" "true" "admin:verylongpasswordhere12345" "true"
test_credential_validation "Username with special chars" "true" "admin@example:pass" "true"
test_credential_validation "Password with special chars" "true" "admin:p@ssw0rd!#" "true"
test_credential_validation "Multiple colons in password" "true" "admin:pass:word:123" "true"
echo ""

# Invalid configurations
echo "Testing INVALID credential configurations:"
test_credential_validation "Auth enabled, no credentials" "true" "" "false"
test_credential_validation "Auth enabled, no colon" "true" "adminpassword" "false"
test_credential_validation "Auth enabled, empty username" "true" ":password" "false"
test_credential_validation "Auth enabled, empty password" "true" "admin:" "false"
test_credential_validation "Auth enabled, only colon" "true" ":" "false"
test_credential_validation "Auth enabled, whitespace only" "true" "   " "false"
echo ""

# Password strength warnings (these are valid but warn)
echo "Testing password strength (valid but may warn):"
test_credential_validation "Short password (8 chars)" "true" "admin:short123" "true"
test_credential_validation "Minimum password (1 char)" "true" "admin:x" "true"
echo ""

# Summary
echo "════════════════════════════════════════════════════════════"
printf "Results: ${GREEN}%d PASSED${NC}, ${RED}%d FAILED${NC}\n" "$PASS_COUNT" "$FAIL_COUNT"
echo "════════════════════════════════════════════════════════════"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi

echo ""
echo "✅ All credential validation tests passed!"
exit 0
